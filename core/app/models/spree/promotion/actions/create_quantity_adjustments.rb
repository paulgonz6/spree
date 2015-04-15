module Spree::Promotion::Actions
  class CreateQuantityAdjustments < CreateItemAdjustments
    include Spree::Core::CalculatedAdjustments

    preference :group_size, :integer, default: 1

    # Computes the amount for the adjustment based on the line item and any
    # other applicable items in the order. The rules for this specific
    # adjustment are as follows:
    #
    # = Setup
    #
    # We have a quantity group promotion on t-shirts. If a user orders 3
    # t-shirts, they get $5 off of each. The shirts come in one size and three
    # colours: red, blue, and white.
    #
    # == Scenario 1
    #
    # User has 2 red shirts, 1 white shirt, and 1 blue shirt in their
    # order. We want to compute the adjustment amount for the white shirt.
    #
    # *Result:* -$5
    #
    # *Reasoning:* There are a total of 4 items that are eligible for the
    # promotion. Since that is greater than 3, we can discount the items. The
    # white shirt has a quantity of 1, therefore it will get discounted by
    # +adjustment_amount * 1+ or $5.
    #
    # === Scenario 1-1
    #
    # What about the blue shirt? How much does it get discounted?
    #
    # *Result:* $0
    #
    # *Reasoning:* We have a total quantity of 4. However, we only apply the
    # adjustment to groups of 3. Assuming the white and red shirts have already
    # had their adjustment calculated, that means 3 units have been discounted.
    # Leaving us with a lonely blue shirt that isn't part of a group of 3.
    # Therefore, it does not receive the discount.
    #
    # == Scenario 2
    #
    # User has 4 red shirts in their order. What is the amount?
    #
    # *Result:* -$15
    #
    # *Reasoning:* The total quantity of eligible items is 4, so we the
    # adjustment will be non-zero. However, we only apply it to groups of 3,
    # therefore there is one extra item that is not eligible for the
    # adjustment. +adjustment_amount * 3+ or $15.
    #
    def compute_amount(line_item)
      adjustment_amount = calculator.compute(line_item).to_f.abs

      order = line_item.order
      line_items = actionable_line_items(order)

      all_matching_adjustments = order.line_item_adjustments.select { |a| a.source == self }
      other_adjustments = all_matching_adjustments - line_item.adjustments

      applicable_quantity = total_applicable_quantity(line_items)
      used_quantity = other_adjustments.sum(&:amount) / adjustment_amount * -1
      usable_quantity = [
        applicable_quantity - used_quantity,
        line_item.quantity
      ].min

      amount = adjustment_amount * usable_quantity
      [line_item.amount, amount].min * -1
    end

    private

    def actionable_line_items(order)
      order.line_items.select do |item|
        promotion.line_item_actionable? order, item
      end
    end

    def total_applicable_quantity(line_items)
      total_quantity = line_items.sum(&:quantity)
      extra_quantity = total_quantity % preferred_group_size

      total_quantity - extra_quantity
    end

    # Overriden since we don't currently support percent.
    def ensure_action_has_calculator
      return if self.calculator
      self.calculator = Calculator::FlatRate.new
    end
  end
end
