module Spree
  class OrderPromotion < ActiveRecord::Base
    self.table_name = 'spree_orders_promotions'

    belongs_to :order, class_name: 'Spree::Order'
    belongs_to :promotion, class_name: 'Spree::Promotion'
    belongs_to :promotion_code, class_name: 'Spree::PromotionCode'

    before_save :update_promotion_code

    private

    # Temporary to make sure data is getting written correctly
    def update_promotion_code
      if promotion.present? && promotion.promotion_code.present?
        self.promotion_code = promotion.promotion_code
      end
    end
  end
end
