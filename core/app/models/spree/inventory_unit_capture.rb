class Spree::InventoryUnitCapture < ActiveRecord::Base
  belongs_to :inventory_unit, class_name: 'Spree::InventoryUnit', inverse_of: :inventory_unit_capture
  belongs_to :carton_capture, class_name: 'Spree::CartonCapture', inverse_of: :inventory_unit_captures

  validates :inventory_unit, presence: true
  validates :carton_capture, presence: true
end
