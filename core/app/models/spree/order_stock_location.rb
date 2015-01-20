module Spree
  class OrderStockLocation < ActiveRecord::Base
    belongs_to :variant, class_name: "Spree::Variant"
    belongs_to :stock_location, class_name: "Spree::StockLocation"
    belongs_to :order, class_name: "Spree::Order"
  end
end