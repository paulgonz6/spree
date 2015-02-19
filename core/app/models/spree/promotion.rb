module Spree
  class Promotion < ActiveRecord::Base
    MATCH_POLICIES = %w(all any)
    UNACTIVATABLE_ORDER_STATES = ["complete", "awaiting_return", "returned"]

    belongs_to :promotion_category

    has_many :promotion_rules, autosave: true, dependent: :destroy
    alias_method :rules, :promotion_rules

    has_many :promotion_actions, autosave: true, dependent: :destroy
    alias_method :actions, :promotion_actions

    has_many :promotion_codes, dependent: :destroy
    alias_method :codes, :promotion_codes

    has_many :order_promotions, class_name: 'Spree::OrderPromotion'
    has_many :orders, through: :order_promotions

    accepts_nested_attributes_for :promotion_actions, :promotion_rules
    accepts_nested_attributes_for :promotion_codes, allow_destroy: true

    validates_associated :rules
    validates_associated :promotion_codes

    validates :name, presence: true
    validates :path, uniqueness: true, allow_blank: true
    validates :usage_limit, numericality: { greater_than: 0, allow_nil: true }
    validates :description, length: { maximum: 255 }

    before_save :normalize_blank_values

    def self.advertised
      where(advertise: true)
    end

    def self.with_coupon_code(coupon_code)
      joins(:promotion_codes).where(
        Spree::PromotionCode.arel_table[:value].matches(coupon_code.strip)
      ).first
    end

    def self.active
      where('starts_at IS NULL OR starts_at < ?', Time.now).
        where('expires_at IS NULL OR expires_at > ?', Time.now)
    end

    def self.order_activatable?(order)
      order && !UNACTIVATABLE_ORDER_STATES.include?(order.state)
    end

    def expired?
      !!(starts_at && Time.now < starts_at || expires_at && Time.now > expires_at)
    end

    def promotion_code(coupon_code)
      codes.where(Spree::PromotionCode.arel_table[:value].matches("%#{coupon_code}")).first
    end

    def activate(payload)
      order = payload[:order]
      return unless self.class.order_activatable?(order)

      payload[:promotion] = self

      # Track results from actions to see if any action has been taken.
      # Actions should return nil/false if no action has been taken.
      # If an action returns true, then an action has been taken.
      results = actions.map do |action|
        action.perform(payload)
      end

      self.order_promotions.create(order: order, promotion_code: payload[:promotion_code])

      # If an action has been taken, report back to whatever activated this promotion.
      return results.include?(true)
    end

    # called anytime order.update! happens
    def eligible?(promotable, coupon_code = nil)
      return false if expired? ||
                        blacklisted?(promotable) ||
                        usage_limit_exceeded?(promotable, coupon_code)
      !!eligible_rules(promotable, {})
    end

    # eligible_rules returns an array of promotion rules where eligible? is true for the promotable
    # if there are no such rules, an empty array is returned
    # if the rules make this promotable ineligible, then nil is returned (i.e. this promotable is not eligible)
    def eligible_rules(promotable, options = {})
      # Promotions without rules are eligible by default.
      return [] if rules.none?
      eligible = lambda { |r| r.eligible?(promotable, options) }
      specific_rules = rules.for(promotable)
      return [] if specific_rules.none?

      if match_all?
        # If there are rules for this promotion, but no rules for this
        # particular promotable, then the promotion is ineligible by default.
        return nil unless specific_rules.all?(&eligible)
        specific_rules
      else
        return nil unless specific_rules.any?(&eligible)
        specific_rules.select(&eligible)
      end
    end

    def usage_limit_exceeded?(promotable, coupon_code)
      if coupon_code.present?
        promotion_code(coupon_code).usage_limit_exceeded?(promotable)
      else
        usage_limit.present? && usage_limit.to_i > 0 && (usage_count - usage_count_for_promotable(promotable)) >= usage_limit
      end
    end

    def usage_count
      Adjustment.eligible.promotion.where(source_id: actions.map(&:id)).count
    end

    def used_by?(user, excluded_orders = [])
      orders.where.not(id: excluded_orders.map(&:id)).complete.where(user_id: user.id).exists?
    end

    def line_item_actionable?(order, line_item, promotion_code)
      if eligible? order, promotion_code.try(:value)
        rules = eligible_rules(order)
        if rules.blank?
          true
        else
          rules.send(match_all? ? :all? : :any?) do |rule|
            rule.actionable? line_item
          end
        end
      else
        false
      end
    end

    private
    def blacklisted?(promotable)
      case promotable
      when Spree::LineItem
        !promotable.product.promotionable?
      when Spree::Order
        promotable.line_items.any? &&
          promotable.line_items.joins(:product).where(spree_products: {promotionable: false}).any?
      end
    end

    def normalize_blank_values
      self[:path] = nil if self[:path].blank?
    end

    def match_all?
      match_policy == 'all'
    end

    def usage_count_for_promotable(promotable)
      promotable.adjustments.where(source_id: actions.map(&:id)).count
    end
  end
end
