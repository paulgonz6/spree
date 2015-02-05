module Spree
  module Behaviors
    class OrderBase
      def initialize(order: order)
        @order = order
      end

      def order
        @order
      end
    end
  end
end
