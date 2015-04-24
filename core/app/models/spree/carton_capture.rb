class Spree::CartonCapture < ActiveRecord::Base
  has_many :inventory_unit_captures, inverse_of: :carton_capture
  has_many :inventory_units, through: :inventory_unit_captures
  has_many :cartons, -> { uniq }, through: :inventory_units

  has_many :carton_capture_payment_capture_events
  has_many :payment_capture_events, through: :carton_capture_payment_capture_events

  validates :captured_at, presence: true
end
