# This class represents all of the actions one can take to modify an Order after it is complete
class Spree::OrderAmendments
  def short_ship_unit(inventory_unit)
    Spree::InventoryUnit.transaction do
      inventory_unit.cancel!
      Spree::UnitCancel.create!(inventory_unit: inventory_unit, reason: Spree::UnitCancel::SHORT_SHIP)
    end
  end
end
