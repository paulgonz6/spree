FactoryGirl.define do
  factory :stock_transfer, class: Spree::StockTransfer do
    source_location Spree::StockLocation.first
    destination_location Spree::StockLocation.last

    factory :stock_transfer_with_items do
      after(:create) do |stock_transfer, evaluator|
         variant_1 = create(:variant)
         variant_2 = create(:variant)
         stock_location = stock_transfer.destination_location

         stock_transfer.transfer_items.create(variant: variant_1, stock_location: stock_location)
         stock_transfer.transfer_items.create(variant: variant_2, stock_location: stock_location)
      end
    end
  end
end
