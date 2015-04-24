FactoryGirl.define do
  factory :carton_capture, class: Spree::CartonCapture do
    captured_at { Time.now }
  end
end
