# Updates the following Order total values:
#
# +payment_total+      The total value of all finalized Payments (NOTE: non-finalized Payments are excluded)
# +item_total+         The total value of all LineItems
# +adjustment_total+   The total value of all adjustments (promotions, credits, etc.)
# +promo_total+        The total value of all promotion adjustments
# +total+              The so-called "order total."  This is equivalent to +item_total+ plus +adjustment_total+.
module Spree
  module Behaviors
    class UpdateOrderTotals < OrderBase
      def run
        # ITEM COUNT
        order.item_count = quantity

        # PAYMENT TOTAL
        order.payment_total = payments.completed.sum(:amount)

        # ITEM TOTAL
        order.item_total = line_items.map(&:amount).sum

        # SHIPMENT TOTAL
        order.shipment_total = shipments.sum(:cost)

        # ADJUSTMENT TOTALS
        order.adjustment_total = line_items.sum(:adjustment_total) +
                                 shipments.sum(:adjustment_total)  +
                                 adjustments.eligible.sum(:amount)
        order.included_tax_total = line_items.sum(:included_tax_total) + shipments.sum(:included_tax_total)
        order.additional_tax_total = line_items.sum(:additional_tax_total) + shipments.sum(:additional_tax_total)

        order.promo_total = line_items.sum(:promo_total) +
                            shipments.sum(:promo_total) +
                            adjustments.promotion.eligible.sum(:amount)

        # ORDER TOTAL
        order.total = order.item_total + order.shipment_total + order.adjustment_total
      end
    end
  end
end
