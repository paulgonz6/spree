module Spree
  module PromotionHandler
    # Used for activating promotions with shipping rules
    class FreeShipping
      attr_reader :order
      attr_accessor :error, :success

      def initialize(order)
        @order = order
      end

      def activate
        promotions.each do |promotion|
          if promotion.eligible?(order, nil)
            promotion.activate(order: order)
          end
        end
      end

      private

        def promotions
          Spree::Promotion.
            joins('LEFT JOIN "spree_promotion_codes" on "spree_promotions"."id" = "spree_promotion_codes"."promotion_id"').where({
              id: Spree::Promotion::Actions::FreeShipping.pluck(:promotion_id),
              spree_promotion_codes: {id: nil},
              path: nil
            })
        end
    end
  end
end
