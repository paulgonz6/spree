module Spree
  module Behaviors
    module Order
      class CalculateAdjustments < Base

        self.post_run_list = [DenormalizeTotals]

        def run
          object.all_adjustments.includes(:adjustable).map(&:adjustable).uniq.each { |adjustable| Spree::ItemAdjustments.new(adjustable).update }
        end
      end
    end
  end
end
