class DeleteInventoryUnitsWithoutShipment < ActiveRecord::Migration
  def up
    Spree::InventoryUnit.where(shipment_id: nil).delete_all
  end

  def down
    # intentionally left blank
  end
end
