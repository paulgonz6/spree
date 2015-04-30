class Spree::CartonCapturing
  class CaptureTooLargeError < StandardError; end

  class_attribute :carton_payments_strategy_class
  self.carton_payments_strategy_class = Spree::CartonPaymentStrategy

  def initialize(carton)
    @carton = carton
  end

  def capture
    carton_capture = Spree::CartonCapture.new(captured_at: Time.now)

    carton_inventory_units_by_order = @carton.inventory_units.includes(
      line_item: {inventory_units: :inventory_unit_capture}
    ).group_by(&:order)

    carton_inventory_units_by_order.each do |order, order_inventory_units|
      build_order_unit_captures(
        carton_capture: carton_capture,
        order: order,
        inventory_units: order_inventory_units,
      )
    end

    carton_payments_strategy_class.new(carton_capture).capture_payments
    carton_capture.save!
    carton_capture
  end

  private

  def build_order_unit_captures(carton_capture:, order:, inventory_units:)
    inventory_units.each do |inventory_unit|
      calculator = Spree::UnprocessedInventoryUnitAmountCalculator.new(inventory_unit)

      carton_capture.inventory_unit_captures.build(
        inventory_unit: inventory_unit,
        currency: calculator.currency,
        price: calculator.price_total,
        promo_total: calculator.promotion_total,
        additional_tax_total: calculator.additional_tax_total,
        included_tax_total: calculator.included_tax_total,
        order_adjustment_total: calculator.order_adjustment_total,
      )
    end

    if carton_capture.total > order.total
      raise CaptureTooLargeError, "Total capture amount is larger than order total"
    end
  end
end
