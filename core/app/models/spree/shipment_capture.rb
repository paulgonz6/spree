class Spree::ShipmentCapture < ActiveRecord::Base
  belongs_to :shipment, class_name: 'Spree::Shipment', inverse_of: :shipment_capture

  has_many :shipment_capture_payment_capture_events
  has_many :payment_capture_events, through: :shipment_capture_payment_capture_events

  validates :shipment, presence: true
  validates :captured_at, presence: true
end
