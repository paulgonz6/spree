module Spree
  module Behaviors
    class PersistOrderTotals < OrderBase
      def run
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
    end
  end
end
