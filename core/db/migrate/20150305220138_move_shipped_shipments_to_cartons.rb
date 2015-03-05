class MoveShippedShipmentsToCartons < ActiveRecord::Migration
  def change
    Spree::Shipment.shipped.find_each |shipment| do
      Spree::Carton.create!(
        order_id: shipment.order_id,
        stock_location_id: shipment.stock_location_id,
        address_id: shipment.address_id,
        shipping_method_id: shipment.shipping_method_id,
        inventory_unit_ids: shipment.inventory_unit_ids,
        )
    end

    Spree::Shipment.shipped.update_all(state: 'ready')
  end
end
