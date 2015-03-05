module Spree
  class OrderUpdater
    attr_reader :order
    delegate :payments, :line_items, :adjustments, :all_adjustments, :shipments, :update_hooks, :quantity, :inventory_units, to: :order

    def initialize(order)
      @order = order
    end

    # This is a multi-purpose method for processing logic related to changes in the Order.
    # It is meant to be called from various observers so that the Order is aware of changes
    # that affect totals and other values stored in the Order.
    #
    # This method should never do anything to the Order that results in a save call on the
    # object with callbacks (otherwise you will end up in an infinite recursion as the
    # associations try to save and then in turn try to call +update!+ again.)
    def update
      caller_info = caller[0..1].join(',')
      Rails.logger.info "update_caller=#{caller_info.inspect}"

      benchmark('update') do
        update_item_count
        update_totals
        if order.completed?
          update_payment_state
          update_shipments
          update_shipment_state
        end
        run_hooks
        persist_totals
      end
    end

    def run_hooks
      update_hooks.each { |hook| order.send hook }
    end

    def recalculate_adjustments
      all_adjustments.includes(:adjustable).map(&:adjustable).uniq.each { |adjustable| Spree::ItemAdjustments.new(adjustable).update }
    end

    # Updates the following Order total values:
    #
    # +payment_total+      The total value of all finalized Payments (NOTE: non-finalized Payments are excluded)
    # +item_total+         The total value of all LineItems
    # +adjustment_total+   The total value of all adjustments (promotions, credits, etc.)
    # +promo_total+        The total value of all promotion adjustments
    # +total+              The so-called "order total."  This is equivalent to +item_total+ plus +adjustment_total+.
    def update_totals
      order.payment_total = payments.completed.sum(:amount)
      update_item_total
      update_shipment_total
      update_adjustment_total
    end


    # give each of the shipments a chance to update themselves
    def update_shipments
      shipments.each { |shipment| shipment.update!(order) if shipment.persisted? }
    end

    def update_shipment_total
      order.shipment_total = shipments.sum(:cost)
      update_order_total
    end

    def update_order_total
      order.total = order.item_total + order.shipment_total + order.adjustment_total
    end

    def update_adjustment_total
      recalculate_adjustments
      order.adjustment_total = line_items.sum(:adjustment_total) +
                               shipments.sum(:adjustment_total)  +
                               adjustments.eligible.sum(:amount)
      order.included_tax_total = line_items.sum(:included_tax_total) + shipments.sum(:included_tax_total)
      order.additional_tax_total = line_items.sum(:additional_tax_total) + shipments.sum(:additional_tax_total)

      order.promo_total = line_items.sum(:promo_total) +
                          shipments.sum(:promo_total) +
                          adjustments.promotion.eligible.sum(:amount)

      update_order_total
    end

    def update_item_count
      order.item_count = quantity
    end

    def update_item_total
      order.item_total = line_items.map(&:amount).sum
      update_order_total
    end

    def persist_totals
      order.update_columns(
        payment_state: order.payment_state,
        shipment_state: order.shipment_state,
        item_total: order.item_total,
        item_count: order.item_count,
        adjustment_total: order.adjustment_total,
        included_tax_total: order.included_tax_total,
        additional_tax_total: order.additional_tax_total,
        payment_total: order.payment_total,
        shipment_total: order.shipment_total,
        promo_total: order.promo_total,
        total: order.total,
        updated_at: Time.now,
      )
    end

    # Updates the +shipment_state+ attribute according to the following logic:
    #
    # shipped   when all inventory units are in a Carton
    # partial   when some inventory units are in a Carton,
    #             or when no inventory units are in a carton and the shipments are in more than one state
    # ready     when no inventory units are in a Carton and when all Shipments are in the "ready" state
    # backorder when there is backordered inventory associated with an order
    # pending   when no inventory units are in a Carton and when all Shipments are in the "pending" state
    #
    # The +shipment_state+ value helps with reporting, etc. since it provides a quick and easy way to locate Orders needing attention.
    def update_shipment_state
      order.shipment_state = calculate_shipment_state
      order.state_changed('shipment')
      order.shipment_state
    end

    # Updates the +payment_state+ attribute according to the following logic:
    #
    # paid          when +payment_total+ is equal to +total+
    # balance_due   when +payment_total+ is less than +total+
    # credit_owed   when +payment_total+ is greater than +total+
    # failed        when most recent payment is in the failed state
    #
    # The +payment_state+ value helps with reporting, etc. since it provides a quick and easy way to locate Orders needing attention.
    def update_payment_state
      # line_item are empty when user empties cart
      if line_items.empty? || round_money(order.payment_total) < round_money(order.total)
        if payments.present?
          # The gateway refunds the payment if possible when an order is canceled, so all canceled orders
          # should have voided payments
          if order.state == 'canceled'
            order.payment_state = 'void'
          elsif payments.last.state == 'failed'
            order.payment_state = 'failed'
          elsif payments.last.state == 'checkout'
            order.payment_state = 'pending'
          elsif payments.last.state == 'completed'
            if line_items.empty?
              order.payment_state = 'credit_owed'
            else
              order.payment_state = 'balance_due'
            end
          elsif payments.last.state == 'pending'
            order.payment_state = 'balance_due'
          else
            order.payment_state = 'credit_owed'
          end
        else
          order.payment_state = 'balance_due'
        end
      elsif round_money(order.payment_total) > round_money(order.total)
        order.payment_state = 'credit_owed'
      else
        order.payment_state = 'paid'
      end

      order.state_changed('payment')
    end

    private

      def calculate_shipment_state
        shipment_states = shipments.states

        if inventory_units.any?(&:backordered?)
          'backorder'
        elsif inventory_units.any? && inventory_units.all?(&:shipped?)
          'shipped'
        elsif inventory_units.any?(&:shipped?)
          'partial'
        elsif shipment_states.size == 1
          shipment_states.first
        elsif shipment_states.size > 1
          'partial'
        else
          nil
        end
      end

      def benchmark(label)
        result = nil
        duration = Benchmark.ms do
          result = yield
        end
        Rails.logger.info("#{label}_ms=#{duration}")
        result
      end

      def round_money(n)
        (n * 100).round / 100.0
      end
  end
end
