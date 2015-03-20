module Spree
  module Behaviors
    class AdvanceShipments < OrderBase
      def run
        order.shipments.select(&:persisted?).each { |shipment| shipment.update!(order) }
      end
    end
  end
end
