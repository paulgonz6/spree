module Spree
  class Promotion < ActiveRecord::Base
    MATCH_POLICIES = %w(all any)
    UNACTIVATABLE_ORDER_STATES = ["complete", "awaiting_return", "returned"]

    belongs_to :promotion_category

    has_many :promotion_rules, autosave: true, dependent: :destroy
    alias_method :rules, :promotion_rules

    has_many :promotion_actions, autosave: true, dependent: :destroy
    alias_method :actions, :promotion_actions

    has_many :order_promotions, class_name: 'Spree::OrderPromotion'
    has_many :orders, through: :order_promotions

    has_many :codes, class_name: 'Spree::PromotionCode', inverse_of: :promotion
    alias_method :promotion_codes, :codes

    accepts_nested_attributes_for :promotion_actions, :promotion_rules

    validates_associated :rules

    validates :name, presence: true
    validates :path, uniqueness: true, allow_blank: true
    validates :usage_limit, numericality: { greater_than: 0, allow_nil: true }
    validates :per_code_usage_limit, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates :description, length: { maximum: 255 }

    before_save :normalize_blank_values

    # temporary code. remove after the column is dropped from the db.
    def columns
      super.reject { |column| column.name == 'code' }
    end

    def self.advertised
      where(advertise: true)
    end

    def self.active
      where('starts_at IS NULL OR starts_at < ?', Time.now).
        where('expires_at IS NULL OR expires_at > ?', Time.now)
    end

    def self.order_activatable?(order)
      order && !UNACTIVATABLE_ORDER_STATES.include?(order.state)
    end

    def code
      raise 'Attempted to call code on a Spree::Promotion. Promotions are now tied to multiple code records'
    end

    def code=(val)
      raise 'Attempted to call code= on a Spree::Promotion. Promotions are now tied to multiple code records'
    end

    def as_json(options={})
      options[:except] ||= :code
      super
    end

    def expired?
      !active?
    end

    def active?
      (starts_at.nil? || starts_at < Time.now) &&
        (expires_at.nil? || expires_at > Time.now)
    end

    def activate(order:, line_item: nil, user: nil, path: nil, promotion_code: nil)
      return unless self.class.order_activatable?(order)

      payload = {
        order: order,
        promotion: self,
        line_item: line_item,
        user: user,
        path: path,
        promotion_code: promotion_code,
      }

      # Track results from actions to see if any action has been taken.
      # Actions should return nil/false if no action has been taken.
      # If an action returns true, then an action has been taken.
      results = actions.map do |action|
        action.perform(payload)
      end
      # If an action has been taken, report back to whatever activated this promotion.
      action_taken = results.include?(true)

      if action_taken
        # connect to the order
        order_promotions.find_or_create_by!(
          order_id: order.id,
          promotion_code_id: promotion_code.try!(:id),
        )
      end

      return action_taken
    end

    # called anytime order.update! happens
    def eligible?(promotable, promotion_code: nil)
      return false if expired?
      return false if usage_limit_exceeded?(promotable)
      return false if promotion_code && promotion_code.usage_limit_exceeded?
      return false if blacklisted?(promotable)
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

    # Whether the given promotable would violate the usage restrictions
    #
    # @param promotable object (e.g. order/line item/shipment)
    # @return true or false
    def usage_limit_exceeded?(promotable)
      # TODO: This logic appears to be wrong.
      # Currently if you have:
      # - 2 different line item level actions on a promotion
      # - 2 line items in an order
      # Then using the promo on that order will create 4 adjustments and count as 4
      # usages.
      # See also PromotionCode#usage_limit_exceeded?
      if usage_limit
        usage_count - usage_count_for(promotable) >= usage_limit
      end
    end

    # Number of times the code has been used overall
    #
    # @return [Integer] usage count
    def usage_count
      adjustment_promotion_scope(Spree::Adjustment.eligible).count
    end

    def used_by?(user, excluded_orders = [])
      orders.where.not(id: excluded_orders.map(&:id)).complete.where(user_id: user.id).exists?
    end

    def line_item_actionable?(order, line_item, promotion_code: nil)
      if eligible?(order, promotion_code: promotion_code)
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

    def adjustment_promotion_scope(adjustment_scope)
      adjustment_scope.promotion.where(source_id: actions.map(&:id))
    end

    def normalize_blank_values
      self[:path] = nil if self[:path].blank?
    end

    def match_all?
      match_policy == 'all'
    end

    def usage_count_for(promotable)
      adjustment_promotion_scope(promotable.adjustments).count
    end
  end
end
