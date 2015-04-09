module Spree
  module Admin
    module Concerns
      module StockManagement
        extend ActiveSupport::Concern

        private

        def load_stock_management_data
          load_stock_locations
          load_stock_item_stock_locations
          load_filtered_variants
        end

        def load_stock_locations
          @stock_locations = Spree::StockLocation.accessible_by(current_ability, :read)
        end

        def load_stock_item_stock_locations
          selected_stock_location = find_selected_stock_location
          @stock_item_stock_locations = selected_stock_location.present? ? [selected_stock_location] : @stock_locations
        end

        def find_selected_stock_location
          @stock_locations.find { |sl| sl.id == params[:stock_location_id].to_i }
        end

        def load_filtered_variants
          results = if params[:variant_search_term].blank?
            variant_scope
          else
            Spree::Core::Search::Variant.new(params[:variant_search_term], scope: variant_scope).results
          end
          @variants = results.order(:sku).page(params[:page]).per(params[:per_page] || Spree::Config[:orders_per_page])
        end
      end
    end
  end
end