class Spree::CartonCapturePaymentCaptureEvent < ActiveRecord::Base
  belongs_to :carton_capture, class_name: 'Spree::CartonCapture'
  belongs_to :payment_capture_event, class_name: 'Spree::PaymentCaptureEvent'

  validates :carton_capture, presence: true
  validates :payment_capture_event, presence: true
end
