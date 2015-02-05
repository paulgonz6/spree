module Spree
  module Behaviors
    module Order
      class CalculatePromotions < Base
        self.post_run_list = [DenormalizeTotals]

        def run
          object.line_items.each { |li| PromotionHandler::Cart.new(object, li).activate }
        end
      end
    end
  end
end
