# This class represents all of the actions one can take to modify an Order after it is complete
class Spree::OrderCancellations
  def initialize(order)
    @order = order
  end

  def short_ship(inventory_units, whodunnit:nil)
    if inventory_units.map(&:order_id).uniq != [@order.id]
      raise ArgumentError, "Not all inventory units belong to this order"
    end

    Spree::OrderMutex.with_lock!(@order) do
      inventory_units.each { |iu| short_ship_unit(iu, whodunnit: whodunnit) }
      @order.update!
    end
  end

  private

  def short_ship_unit(inventory_unit, whodunnit:nil)
    calculator = Spree::UnprocessedInventoryUnitAmountCalculator.new(inventory_unit)

    Spree::InventoryUnit.transaction do
      unit_cancel = Spree::UnitCancel.create!(
        inventory_unit: inventory_unit,
        price: calculator.price_total,
        promo_total: calculator.promotion_total,
        additional_tax_total: calculator.additional_tax_total,
        included_tax_total: calculator.included_tax_total,
        order_adjustment_total: calculator.order_adjustment_total,
        reason: Spree::UnitCancel::SHORT_SHIP,
        created_by: whodunnit,
      )

      unit_cancel.adjust!
      inventory_unit.cancel!
      return unit_cancel
    end
  end
end
