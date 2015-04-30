class Spree::CartonCapture < ActiveRecord::Base
  has_many :inventory_unit_captures, inverse_of: :carton_capture
  has_many :inventory_units, through: :inventory_unit_captures
  has_many :cartons, -> { uniq }, through: :inventory_units
  has_many :orders, -> { uniq }, through: :inventory_units

  has_many :carton_capture_payment_capture_events
  has_many :payment_capture_events, through: :carton_capture_payment_capture_events

  validates :captured_at, presence: true

  def total(inventory_unit_captures = self.inventory_unit_captures)
    inventory_unit_captures.to_a.sum do |capture|
      capture.price + capture.promo_total + capture.additional_tax_total + capture.order_adjustment_total
    end.to_d
  end
end
