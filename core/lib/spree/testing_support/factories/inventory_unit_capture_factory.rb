FactoryGirl.define do
  factory :inventory_unit_capture, class: Spree::InventoryUnitCapture do
    inventory_unit
    carton_capture
  end
end
