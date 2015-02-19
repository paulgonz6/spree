module Spree
  class OrderPromotion < ActiveRecord::Base
    self.table_name = 'spree_orders_promotions'

    belongs_to :order, class_name: 'Spree::Order'
    belongs_to :promotion, class_name: 'Spree::Promotion'
    belongs_to :promotion_code, class_name: 'Spree::PromotionCode'
  end
end
