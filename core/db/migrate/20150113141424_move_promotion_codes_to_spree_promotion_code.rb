class MovePromotionCodesToSpreePromotionCode < ActiveRecord::Migration
  def up
    Spree::Promotion.find_each do |promo|
      if promo.read_attribute(:code).present?
        promo.codes.create!(value: promo.read_attribute(:code), usage_limit: promo.usage_limit)

        promo.actions.each do |action|
          Spree::Adjustment.where(source_id: action.id).find_each do |adjustment|
            adjustment.update_attributes(promotion_code_id: promo.codes.first.id)
          end
        end
      end
    end
  end

  def down
  end
end
