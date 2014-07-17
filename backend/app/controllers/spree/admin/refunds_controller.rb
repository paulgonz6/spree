module Spree
  module Admin
    class RefundsController < ResourceController
      belongs_to 'spree/payment'

      def location_after_save
        admin_order_payments_path(@payment.order)
      end
    end
  end
end
