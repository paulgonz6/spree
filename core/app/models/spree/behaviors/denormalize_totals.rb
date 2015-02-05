module Spree
  module Behaviors
    class DenormalizeTotals < OrderBase
      def run
        # COUNTS
        order.item_count = line_items.sum(:quantity)

        # AMOUNTS
        order.payment_total = payments.completed.sum(:amount)
        order.item_total = line_items.map(&:amount).sum
        order.shipment_total = shipments.sum(:cost)
        order.adjustment_total = line_items.sum(:adjustment_total) +
          shipments.sum(:adjustment_total) +
          adjustments.eligible.sum(:amount)

        order.included_tax_total = line_items.sum(:included_tax_total) +
          shipments.sum(:included_tax_total)
        order.additional_tax_total = line_items.sum(:additional_tax_total) +
          shipments.sum(:additional_tax_total)

        order.promo_total = line_items.sum(:promo_total) +
          shipments.sum(:promo_total) +
          adjustments.promotion.eligible.sum(:amount)

        order.total = order.item_total + order.shipment_total + order.adjustment_total

        # PAYMENT STATE
        if order.completed?
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

        # SHIPMENT STATE
        if order.completed?
          if order.backordered?
            order.shipment_state = 'backorder'
          else
            # get all the shipment states for this order
            shipment_states = shipments.states
            if shipment_states.size > 1
              # multiple shiment states means it's most likely partially shipped
              order.shipment_state = 'partial'
            else
              # will return nil if no shipments are found
              order.shipment_state = shipment_states.first
            end
          end
          order.state_changed('shipment')
        end
      end

      private

      # TODO GET RID OF ME
      def round_money(n)
        (n * 100).round / 100.0
      end

      def line_items; order.line_items; end
      def shipments; order.shipments; end
      def adjustments; order.adjustments; end
      def payments; order.payments; end

    end
  end
end
