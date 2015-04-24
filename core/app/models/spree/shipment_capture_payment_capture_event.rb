class Spree::ShipmentCapturePaymentCaptureEvent < ActiveRecord::Base
  belongs_to :shipment_capture, class_name: 'Spree::ShipmentCapture'
  belongs_to :payment_capture_event, class_name: 'Spree::PaymentCaptureEvent'

  validates :shipment_capture, presence: true
  validates :payment_capture_event, presence: true
end
