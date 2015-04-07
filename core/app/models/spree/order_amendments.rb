# This class represents all of the actions one can take to modify an Order after it is complete
class Spree::OrderAmendments
  def initialize(order, user:nil)
    @order = order
    @user = user
  end

  def short_ship_units(inventory_units)
    if inventory_units.map(&:order_id).uniq != [@order.id]
      raise ArgumentError, "Not all inventory units belong to this order"
    end

    Spree::OrderMutex.with_lock!(@order) do
      inventory_units.each { |iu| short_ship_unit(iu) }
      @order.update!
    end
  end

  private

  def short_ship_unit(inventory_unit)
    Spree::InventoryUnit.transaction do
      unit_cancel = Spree::UnitCancel.create!(
        inventory_unit: inventory_unit,
        reason: Spree::UnitCancel::SHORT_SHIP,
        created_by: @user,
      )
      unit_cancel.adjust
      inventory_unit.cancel!
    end
  end
end
