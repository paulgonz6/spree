require_dependency 'spree/calculator'

module Spree
  class Calculator::TieredPercent < Calculator
    preference :base_percent, :decimal, default: 0
    preference :tiers, :hash, default: {}

    validates :preferred_base_percent, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    }
    validate :preferred_tiers_content

    def self.description
      Spree.t(:tiered_percent)
    end

    def compute(object)
      base, percent = preferred_tiers.sort.reverse.detect{ |b,_| object.amount >= b }
      (object.amount * (percent || preferred_base_percent) / 100).round(2)
    end

    def preferred_tiers_with_conversion= values
      self.preferred_tiers_without_conversion = Hash[*values.flatten.map(&:to_f)]
    end
    alias_method_chain :preferred_tiers=, :conversion

    private
    def preferred_tiers_content
      if preferred_tiers.is_a? Hash
        unless preferred_tiers.keys.all?{ |k| k.is_a?(Numeric) && k > 0 }
          errors.add(:base, :keys_should_be_positive_number)
        end
        unless preferred_tiers.values.all?{ |k| k.is_a?(Numeric) && k >= 0 && k <= 100 }
          errors.add(:base, :values_should_be_percent)
        end
      else
        errors.add(:preferred_tiers, :should_be_hash)
      end
    end
  end
end
