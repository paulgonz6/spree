# Updates the +payment_state+ attribute according to the following logic:
#
# paid          when +payment_total+ is equal to +total+
# balance_due   when +payment_total+ is less than +total+
# credit_owed   when +payment_total+ is greater than +total+
# failed        when most recent payment is in the failed state
#
# The +payment_state+ value helps with reporting, etc. since it provides a quick and easy way to locate Orders needing attention.
module Spree
  module Behaviors
    class UpdateOrderPaymentState < OrderBase

      def run
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

    end
  end
end
