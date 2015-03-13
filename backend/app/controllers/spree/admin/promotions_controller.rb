module Spree
  module Admin
    class PromotionsController < ResourceController
      before_filter :load_data
      before_filter :load_bulk_code_information, only: [:edit]

      create.before :build_promotion_codes

      helper 'spree/promotion_rules'

      protected
        def build_promotion_codes
          @bulk_base = params[:bulk_base] if params[:bulk_base].present?
          @bulk_number = Integer(params[:bulk_number]) if params[:bulk_number].present?

          if @bulk_base && @bulk_number
            @promotion.build_promotion_codes(
              base_code: @bulk_base,
              number_of_codes: @bulk_number,
            )
          end
        end

        def load_bulk_code_information
          @bulk_base = @promotion.codes.first.try!(:value)
          @bulk_number = @promotion.codes.count
          @bulk_number_max = Spree::Promotion.max_number_of_codes
        end

        def location_after_save
          spree.edit_admin_promotion_url(@promotion)
        end

        def load_data
          @calculators = Rails.application.config.spree.calculators.promotion_actions_create_adjustments
          @promotion_categories = Spree::PromotionCategory.order(:name)
        end

        def collection
          return @collection if @collection.present?
          params[:q] ||= HashWithIndifferentAccess.new
          params[:q][:s] ||= 'id desc'

          @collection = super
          @search = @collection.ransack(params[:q])
          @collection = @search.result(distinct: true).
            includes(promotion_includes).
            page(params[:page]).
            per(params[:per_page] || Spree::Config[:promotions_per_page])

          @collection
        end

        def promotion_includes
          [:promotion_actions]
        end
    end
  end
end
