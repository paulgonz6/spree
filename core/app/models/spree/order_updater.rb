module Spree
  class OrderUpdater
    attr_reader :order

    def initialize(order)
      @order = order
    end

    def update
      Spree::Behavior.call(:order_updater, order: order)
    end

    def run_hooks
      ActiveSupport::Deprecation.warn "This is deprecated and will be removed in a future version of Spree, use OrderUpdater#update instead", caller
      order.update_hooks.each { |hook| order.send hook }
    end

    def recalculate_adjustments
      ActiveSupport::Deprecation.warn "This is deprecated and will be removed in a future version of Spree, use OrderUpdater#update instead", caller
      Spree::Behaviors::CalculateAdjustments.new(order: order).run
    end

    def update_totals
      ActiveSupport::Deprecation.warn "This is deprecated and will be removed in a future version of Spree, use OrderUpdater#update instead", caller
      Spree::Behaviors::DenormalizeTotals.new(order: order).run
    end

    def update_shipments
      ActiveSupport::Deprecation.warn "This is deprecated and will be removed in a future version of Spree, use OrderUpdater#update instead", caller
      Spree::Behaviors::AdvanceShipments.new(order: order).run
    end

    def update_shipment_total
      ActiveSupport::Deprecation.warn "This is deprecated and will be removed in a future version of Spree, use OrderUpdater#update instead", caller
      Spree::Behaviors::DenormalizeTotals.new(order: order).run
    end

    def update_order_total
      ActiveSupport::Deprecation.warn "This is deprecated and will be removed in a future version of Spree, use OrderUpdater#update instead", caller
      Spree::Behaviors::DenormalizeTotals.new(order: order).run
    end

    def update_adjustment_total
      ActiveSupport::Deprecation.warn "This is deprecated and will be removed in a future version of Spree, use OrderUpdater#update instead", caller
      Spree::Behaviors::CalculateAdjustments.new(order: order).run
      Spree::Behaviors::DenormalizeTotals.new(order: order).run
    end

    def update_item_count
      ActiveSupport::Deprecation.warn "This is deprecated and will be removed in a future version of Spree, use OrderUpdater#update instead", caller
      Spree::Behaviors::DenormalizeTotals.new(order: order).run
    end

    def update_item_total
      ActiveSupport::Deprecation.warn "This is deprecated and will be removed in a future version of Spree, use OrderUpdater#update instead", caller
      Spree::Behaviors::DenormalizeTotals.new(order: order).run
    end

    def persist_totals
      ActiveSupport::Deprecation.warn "This is deprecated and will be removed in a future version of Spree, use OrderUpdater#update instead", caller
      Spree::Behaviors::DenormalizeTotals.new(order: order).run
    end

    def update_shipment_state
      ActiveSupport::Deprecation.warn "This is deprecated and will be removed in a future version of Spree, use OrderUpdater#update instead", caller
      Spree::Behaviors::DenormalizeTotals.new(order: order).run
    end

    def update_payment_state
      ActiveSupport::Deprecation.warn "This is deprecated and will be removed in a future version of Spree, use OrderUpdater#update instead", caller
      Spree::Behaviors::DenormalizeTotals.new(order: order).run
    end
  end
end
