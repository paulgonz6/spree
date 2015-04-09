require 'ostruct'

module Spree
  class Shipment < ActiveRecord::Base
    belongs_to :order, class_name: 'Spree::Order', touch: true, inverse_of: :shipments
    belongs_to :address, class_name: 'Spree::Address', inverse_of: :shipments
    belongs_to :stock_location, class_name: 'Spree::StockLocation'

    has_many :shipping_rates, -> { order('cost ASC') }, dependent: :delete_all
    has_many :shipping_methods, through: :shipping_rates
    has_many :state_changes, as: :stateful
    has_many :inventory_units, dependent: :destroy, inverse_of: :shipment
    has_many :adjustments, as: :adjustable, dependent: :delete_all
    has_many :cartons, -> { uniq }, through: :inventory_units

    after_save :update_adjustments

    before_validation :set_cost_zero_when_nil

    attr_accessor :special_instructions

    accepts_nested_attributes_for :address
    accepts_nested_attributes_for :inventory_units

    make_permalink field: :number, length: 11, prefix: 'H'

    scope :shipped, -> { with_state('shipped') }
    scope :ready,   -> { with_state('ready') }
    scope :pending, -> { with_state('pending') }
    scope :with_state, ->(*s) { where(state: s) }

    # TODO: remove this, this belongs on carton
    scope :trackable, -> { where("tracking IS NOT NULL AND tracking != ''") }
    # sort by most recent shipped_at, falling back to created_at. add "id desc" to make specs that involve this scope more deterministic.
    scope :reverse_chronological, -> { order('coalesce(spree_shipments.shipped_at, spree_shipments.created_at) desc', id: :desc) }

    # shipment state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
    state_machine initial: :pending, use_transactions: false do
      event :ready do
        # TODO: Remove this transition and the #requires_shipment? method when
        # we stop marking shipments as shipped
        transition from: :pending, to: :shipped, if: lambda {|shipment| !shipment.requires_shipment? }

        transition from: :pending, to: :ready, if: lambda { |shipment|
          # Fix for #2040
          shipment.determine_state(shipment.order) == 'ready'
        }
      end

      event :pend do
        transition from: :ready, to: :pending
      end

      event :ship do
        transition from: [:ready, :canceled], to: :shipped
      end
      after_transition to: :shipped, do: :after_ship

      event :cancel do
        transition to: :canceled, from: [:pending, :ready]
      end
      after_transition to: :canceled, do: :after_cancel

      event :resume do
        transition from: :canceled, to: :ready, if: lambda { |shipment|
          shipment.determine_state(shipment.order) == :ready
        }
        transition from: :canceled, to: :pending, if: lambda { |shipment|
          shipment.determine_state(shipment.order) == :ready
        }
        transition from: :canceled, to: :pending
      end
      after_transition from: :canceled, to: [:pending, :ready, :shipped], do: :after_resume

      after_transition do |shipment, transition|
        shipment.state_changes.create!(
          previous_state: transition.from,
          next_state:     transition.to,
          name:           'shipment',
        )
      end
    end

    extend DisplayMoney
    money_methods :cost, :discounted_cost, :final_price, :item_cost
    alias display_amount display_cost

    def to_param
      number
    end

    def backordered?
      inventory_units.any? { |inventory_unit| inventory_unit.backordered? }
    end

    def ready_or_pending?
      self.ready? || self.pending?
    end

    def shipped=(value)
      return unless value == '1' && shipped_at.nil?
      self.shipped_at = Time.now
    end

    def shipping_method
      selected_shipping_rate.try(:shipping_method) || shipping_rates.first.try(:shipping_method)
    end

    def add_shipping_method(shipping_method, selected = false)
      shipping_rates.create(shipping_method: shipping_method, selected: selected, cost: cost)
    end

    def selected_shipping_rate
      shipping_rates.where(selected: true).first
    end

    def selected_shipping_rate_id
      selected_shipping_rate.try(:id)
    end

    def selected_shipping_rate_id=(id)
      shipping_rates.update_all(selected: false)
      shipping_rates.update(id, selected: true)
      self.save!
    end

    def tax_category
      selected_shipping_rate.try(:tax_rate).try(:tax_category)
    end

    def refresh_rates
      return shipping_rates if shipped?
      return [] unless can_get_rates?

      # StockEstimator.new assigment below will replace the current shipping_method
      original_shipping_method_id = shipping_method.try(:id)

      self.shipping_rates = Stock::Estimator.new(order).shipping_rates(to_package)

      if shipping_method
        selected_rate = shipping_rates.detect { |rate|
          rate.shipping_method_id == original_shipping_method_id
        }
        self.selected_shipping_rate_id = selected_rate.id if selected_rate
      end

      shipping_rates
    end

    def currency
      order ? order.currency : Spree::Config[:currency]
    end

    def item_cost
      line_items.map(&:amount).sum
    end

    def discounted_cost
      cost + promo_total
    end
    alias discounted_amount discounted_cost

    # Only one of either included_tax_total or additional_tax_total is set
    # This method returns the total of the two. Saves having to check if
    # tax is included or additional.
    def tax_total
      included_tax_total + additional_tax_total
    end

    def final_price
      discounted_cost + tax_total
    end

    def editable_by?(user)
      !shipped?
    end

    def line_items
      inventory_units.includes(:line_item).map(&:line_item).uniq
    end

    def manifest
      @manifest ||= Spree::ShippingManifest.new(inventory_units: inventory_units).items
    end

    def finalize!
      InventoryUnit.finalize_units!(inventory_units)
      manifest.each { |item| manifest_unstock(item) }
    end

    def after_cancel
      manifest.each { |item| manifest_restock(item) }
    end

    def after_resume
      manifest.each { |item| manifest_unstock(item) }
    end

    # Updates various aspects of the Shipment while bypassing any callbacks.  Note that this method takes an explicit reference to the
    # Order object.  This is necessary because the association actually has a stale (and unsaved) copy of the Order and so it will not
    # yield the correct results.
    def update!(order)
      old_state = state
      new_state = determine_state(order)
      update_columns(
        state: new_state,
        updated_at: Time.now,
      )
      after_ship if new_state == 'shipped' and old_state != 'shipped'
    end

    # Determines the appropriate +state+ according to the following logic:
    #
    # pending    unless order is complete and +order.payment_state+ is +paid+
    # shipped    if already shipped (ie. does not change the state)
    # ready      all other cases
    def determine_state(order)
      return 'canceled' if order.canceled?
      return 'pending' unless order.can_ship?
      return 'pending' if inventory_units.any? &:backordered?
      return 'shipped' if state == 'shipped'
      order.paid? ? 'ready' : 'pending'
    end

    def tracking_url
      @tracking_url ||= shipping_method.build_tracking_url(tracking)
    end

    def include?(variant)
      inventory_units_for(variant).present?
    end

    def inventory_units_for(variant)
      inventory_units.where(variant_id: variant.id)
    end

    def inventory_units_for_item(line_item, variant = nil)
      inventory_units.where(line_item_id: line_item.id, variant_id: line_item.variant.id || variant.id)
    end

    def to_package
      package = Stock::Package.new(stock_location)
      inventory_units.group_by(&:state).each do |state, state_inventory_units|
        package.add_multiple state_inventory_units, state.to_sym
      end
      package
    end

    def set_up_inventory(state, variant, order, line_item)
      self.inventory_units.create(
        state: state,
        variant_id: variant.id,
        order_id: order.id,
        line_item_id: line_item.id
      )
    end

    def update_amounts
      if selected_shipping_rate
        self.update_columns(
          cost: selected_shipping_rate.cost,
          adjustment_total: adjustments.additional.map(&:update!).compact.sum,
          updated_at: Time.now,
        )
      end
    end

    # Update Shipment and make sure Order states follow the shipment changes
    def update_attributes_and_order(params = {})
      if self.update_attributes params
        if params.has_key? :selected_shipping_rate_id
          # Changing the selected Shipping Rate won't update the cost (for now)
          # so we persist the Shipment#cost before calculating order shipment
          # total and updating payment state (given a change in shipment cost
          # might change the Order#payment_state)
          self.update_amounts

          order.updater.update_shipment_total
          order.updater.update_payment_state

          # Update shipment state only after order total is updated because it
          # (via Order#paid?) affects the shipment state (YAY)
          self.update_columns(
            state: determine_state(order),
            updated_at: Time.now
          )

          # And then it's time to update shipment states and finally persist
          # order changes
          order.updater.update_shipment_state
          order.updater.persist_totals
        end

        true
      end
    end

    class ShipmentTransferError < StandardError
    end

    def transfer_to_location(variant, quantity, stock_location)
      if (quantity <= 0 || !enough_stock_at_destination_location(variant, quantity, stock_location))
        raise ShipmentTransferError
      end

      transaction do
        new_shipment = order.shipments.create!(stock_location: stock_location)

        order.contents.remove(variant, quantity, self)
        order.contents.add(variant, quantity, nil, new_shipment)

        refresh_rates
        save!
        new_shipment.refresh_rates
        new_shipment.save!
      end
    end

    def transfer_to_shipment(variant, quantity, shipment_to_transfer_to)
      quantity_already_shipment_to_transfer_to = shipment_to_transfer_to.manifest.find{|mi| mi.line_item.variant == variant}.try(:quantity) || 0
      final_quantity = quantity + quantity_already_shipment_to_transfer_to

      if (quantity <= 0 || self.id == shipment_to_transfer_to.id || !enough_stock_at_destination_location(variant, final_quantity, shipment_to_transfer_to.stock_location))
        raise ShipmentTransferError
      end

      transaction do
        order.contents.remove(variant, quantity, self)
        order.contents.add(variant, quantity, nil, shipment_to_transfer_to)

        refresh_rates
        save!
        shipment_to_transfer_to.refresh_rates
        shipment_to_transfer_to.save!
      end
    end

    def requires_shipment?
      self.stock_location.fulfillable?
    end

    private
      def enough_stock_at_destination_location(variant, quantity, stock_location)
        stock_item = Spree::StockItem.where(variant: variant).
                                      where(stock_location: stock_location).first
        (stock_item.count_on_hand >= quantity || stock_item.backorderable)
      end

      def manifest_unstock(item)
        stock_location.unstock item.variant, item.quantity, self
      end

      def manifest_restock(item)
        if item.states["on_hand"].to_i > 0
         stock_location.restock item.variant, item.states["on_hand"], self
        end

        if item.states["backordered"].to_i > 0
          stock_location.restock_backordered item.variant, item.states["backordered"]
        end
      end

      def description_for_shipping_charge
        "#{Spree.t(:shipping)} (#{shipping_method.name})"
      end

      def validate_shipping_method
        unless shipping_method.nil?
          errors.add :shipping_method, Spree.t(:is_not_available_to_shipment_address) unless shipping_method.include?(address)
        end
      end

      def after_ship
        # TODO: Get this out of the model and have OrderShipping#ship_shipment
        # called directly everywhere
        order.shipping.ship_shipment(self)
      end

      def set_cost_zero_when_nil
        self.cost = 0 unless self.cost
      end

      def update_adjustments
        if cost_changed? && state != 'shipped'
          recalculate_adjustments
        end
      end

      def recalculate_adjustments
        Spree::ItemAdjustments.new(self).update
      end

      def can_get_rates?
        order.ship_address && order.ship_address.valid?
      end
  end
end
