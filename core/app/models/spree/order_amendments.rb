# This class represents all of the actions one can take to modify an Order after it is complete
class Spree::OrderAmendments
  def short_ship_units(inventory_units)
    inventory_units.each {|iu| short_ship_unit(iu) }
    inventory_units.map(&:order).uniq.map{|o| o.update! }
  end

  private

  def short_ship_unit(inventory_unit)
    Spree::InventoryUnit.transaction do
      unit_cancel = Spree::UnitCancel.create!(inventory_unit: inventory_unit, reason: Spree::UnitCancel::SHORT_SHIP)
      unit_cancel.adjust
      inventory_unit.cancel!
    end
  end
end
