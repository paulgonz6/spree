FactoryGirl.define do
  factory :promotion_code, class: 'Spree::PromotionCode' do
    promotion
    value { generate(:random_code) }
    usage_limit 10
  end
end
