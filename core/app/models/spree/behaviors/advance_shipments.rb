module Spree
  module Behaviors
    class AdvanceShipments < OrderBase
      def run
        return unless order.completed?
        order.shipments.select(&:persisted?).each { |shipment| shipment.update!(order) }
      end
    end
  end
end
