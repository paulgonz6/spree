module Spree
  module Behaviors
    class OrderBase
      def initialize(order: order)
        @order = order
      end

      def order
        @order
      end

      protected

      # TODO GET RID OF ME
      def round_money(n)
        (n * 100).round / 100.0
      end

      def line_items; order.line_items; end
      def shipments; order.shipments; end
      def adjustments; order.adjustments; end
      def payments; order.payments; end
      def quantity; order.quantity; end

    end
  end
end
