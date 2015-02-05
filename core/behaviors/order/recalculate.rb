module Spree
  module Behaviors
    module Order
      class Recalculate < Base
        self.pre_run_list = [
          DenormalizeTotals,
          CalculateAdjustments,
          CalculatePromotions,
          # CalculateTaxes, # This doesn't happen in order updater currently, but this seems like the right place to me
          Advance,
          AdvanceShipments
        ]

        def run
          object.save
        end
      end
    end
  end
end
