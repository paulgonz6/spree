module Spree
  class OrderUpdater
    attr_reader :order

    def initialize(order)
      @order = order
    end

    def update
      Spree::Behavior.call(:order_updater, order: order)
    end

    def recalculate_adjustments
      Spree::Behaviors::CalculateAdjustments.new(order: order).run
    end

    def update_totals
      Spree::Behaviors::UpdateOrderTotals.new(order: order).run
    end

    def update_shipments
      Spree::Behaviors::AdvanceShipments.new(order: order).run
    end

    def update_shipment_total
      Spree::Behaviors::UpdateOrderTotals.new(order: order).run
    end

    def update_order_total
      Spree::Behaviors::UpdateOrderTotals.new(order: order).run
    end

    def update_adjustment_total
      Spree::Behaviors::CalculateAdjustments.new(order: order).run
      Spree::Behaviors::UpdateOrderTotals.new(order: order).run
    end

    def update_item_count
      Spree::Behaviors::UpdateOrderTotals.new(order: order).run
    end

    def update_item_total
      Spree::Behaviors::UpdateOrderTotals.new(order: order).run
    end

    def persist_totals
      Spree::Behaviors::PersistOrderTotals.new(order: order).run
    end

    def update_shipment_state
      Spree::Behaviors::UpdateOrderShipmentState.new(order: order).run
    end

    def update_payment_state
      Spree::Behaviors::UpdateOrderPaymentState.new(order: order).run
    end
  end
end
