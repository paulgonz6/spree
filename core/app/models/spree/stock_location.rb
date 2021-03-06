module Spree
  class StockLocation < ActiveRecord::Base
    class InvalidMovementError < StandardError; end
    has_many :shipments
    has_many :cartons, inverse_of: :stock_location
    has_many :stock_items, dependent: :delete_all
    has_many :stock_movements, through: :stock_items
    has_many :user_stock_locations, dependent: :delete_all
    has_many :users, through: :user_stock_locations

    belongs_to :state, class_name: 'Spree::State'
    belongs_to :country, class_name: 'Spree::Country'

    validates_presence_of :name
    validates_uniqueness_of :code, allow_blank: true, case_sensitive: false

    scope :active, -> { where(active: true) }
    scope :order_default, -> { order(default: :desc, name: :asc) }

    after_create :create_stock_items, :if => "self.propagate_all_variants?"
    after_save :ensure_one_default

    # Wrapper for creating a new stock item respecting the backorderable config
    def propagate_variant(variant)
      self.stock_items.create!(variant: variant, backorderable: self.backorderable_default)
    end

    # Return either an existing stock item or create a new one. Useful in
    # scenarios where the user might not know whether there is already a stock
    # item for a given variant
    def set_up_stock_item(variant)
      self.stock_item(variant) || propagate_variant(variant)
    end

    def stock_item(variant)
      stock_items.where(variant_id: variant).order(:id).first
    end

    def stock_item_or_create(variant)
      stock_item(variant) || stock_items.create(variant: variant)
    end

    def count_on_hand(variant)
      stock_item(variant).try(:count_on_hand)
    end

    def backorderable?(variant)
      stock_item(variant).try(:backorderable?)
    end

    def restock(variant, quantity, originator = nil)
      move(variant, quantity, originator)
    end

    def restock_backordered(variant, quantity, originator = nil)
      item = stock_item_or_create(variant)
      item.update_columns(
        count_on_hand: item.count_on_hand + quantity,
        updated_at: Time.now
      )
    end

    def unstock(variant, quantity, originator = nil)
      move(variant, -quantity, originator)
    end

    def move(variant, quantity, originator = nil)
      if quantity < 1 && !stock_item(variant)
        raise InvalidMovementError.new(Spree.t(:negative_movement_absent_item))
      end
      stock_item_or_create(variant).stock_movements.create!(quantity: quantity,
                                                            originator: originator)
    end

    def fill_status(variant, quantity)
      if item = stock_item(variant)

        if item.count_on_hand >= quantity
          on_hand = quantity
          backordered = 0
        else
          on_hand = item.count_on_hand
          on_hand = 0 if on_hand < 0
          backordered = item.backorderable? ? (quantity - on_hand) : 0
        end

        [on_hand, backordered]
      else
        [0, 0]
      end
    end

    private
      def create_stock_items
        Variant.find_each { |variant| self.propagate_variant(variant) }
      end

      def ensure_one_default
        if self.default
          StockLocation.where(default: true).where.not(id: self.id).each do |stock_location|
            stock_location.default = false
            stock_location.save!
          end
        end
      end
  end
end
