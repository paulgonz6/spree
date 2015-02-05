module Spree
  class Behavior
    class_attribute :registry
    self.registry = {
      order_updater: [
        Behaviors::DenormalizeTotals,
        Behaviors::CalculateAdjustments,
        Behaviors::DenormalizeTotals,
        Behaviors::AdvanceShipments,
        Behaviors::DenormalizeTotals,
        Behaviors::PersistOrder,
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
