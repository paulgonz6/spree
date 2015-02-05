module Spree
  module Behaviors
    module Order
      class AdvanceShipments < Base
        self.post_run_list = [DenormalizeTotals]
        def run
          return unless object.completed?
          object.shipments.select(&:persisted?).each { |shipment| shipment.update!(object) }
        end
      end
    end
  end
end
