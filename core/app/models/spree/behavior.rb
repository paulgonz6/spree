module Spree
  class Behavior
    class_attribute :registry
    self.registry = {
      order_updater: [
        Behaviors::CalculateAdjustments,
        Behaviors::UpdateOrderTotals,
        Behaviors::UpdateOrderPaymentState,
        Behaviors::AdvanceShipments,
        Behaviors::UpdateOrderShipmentState,
        Behaviors::CalculateAdjustments,
        Behaviors::UpdateOrderTotals,
        Behaviors::PersistOrderTotals,
      ]
    }

    def self.call(name, context = {})
      behavior = self.registry[name]
      raise BehaviorNotFoundError unless behavior
      behavior.each { |run_item| run_item.new(context).run }
    end

    class BehaviorNotFoundError < StandardError; end
  end
end
