module Spree
  module Behaviors
    class CalculateAdjustments < OrderBase

      def run
        order.all_adjustments.includes(:adjustable).map(&:adjustable).uniq.each do |adjustable|
          Spree::ItemAdjustments.new(adjustable).update
        end
      end
    end
  end
end
