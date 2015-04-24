FactoryGirl.define do
  factory :shipment_capture, class: Spree::ShipmentCapture do
    shipment
    captured_at { Time.now }
  end
end
