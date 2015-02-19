class Spree::PromotionCode < ActiveRecord::Base
  belongs_to :promotion
  has_many :adjustments, as: :source

  validates :usage_limit, numericality: { greater_than: 0, allow_nil: true }
  validates :value, presence: true, uniqueness: true
  validates :promotion_id, presence: true

  def usage_limit_exceeded?(promotable)
    usage_limit.to_i > 0 && usage_for_promotion_code_count(promotable) >= usage_limit
  end

  def usage_for_promotion_code_count(promotable)
    adjustment_promotion_scope(Spree::Adjustment.eligible).count - adjustment_promotion_scope(promotable.adjustments).count
  end

  private

  def adjustment_promotion_scope(adjustments)
    adjustments.promotion.where(source_id: promotion.actions.map(&:id), promotion_code_id: self.id)
  end
end
