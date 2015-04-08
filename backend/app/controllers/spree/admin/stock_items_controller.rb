module Spree
  module Admin
    class StockItemsController < Spree::Admin::BaseController
      before_filter :load_stock_locations, only: :index
      before_filter :load_stock_item_stock_locations, only: :index
      before_filter :determine_backorderable, only: :update

      def index
        results = if params[:variant_search_term].blank?
          variant_scope
        else
          Spree::Core::Search::Variant.new(params[:variant_search_term], scope: variant_scope).results
        end
        @variants = results.order("created_at DESC").page(params[:page]).per(params[:per_page] || Spree::Config[:orders_per_page])
      end

      def update
        stock_item.save
        respond_to do |format|
          format.js { head :ok }
        end
      end

      def create
        variant = Variant.find(params[:variant_id])
        stock_location = StockLocation.find(params[:stock_location_id])
        stock_movement = stock_location.stock_movements.build(stock_movement_params.merge(originator: try_spree_current_user))
        stock_movement.stock_item = stock_location.set_up_stock_item(variant)

        if stock_movement.save
          flash[:success] = flash_message_for(stock_movement, :successfully_created)
        else
          flash[:error] = stock_movement_and_item_errors(stock_movement)
        end

        redirect_to :back
      end

      def destroy
        stock_item.destroy

        respond_with(@stock_item) do |format|
          format.html { redirect_to :back }
          format.js
        end
      end

      private
        def stock_movement_and_item_errors(stock_movement)
          (stock_movement.errors.full_messages + stock_movement.stock_item.errors.full_messages).join(', ')
        end

        def stock_movement_params
          params.require(:stock_movement).permit(permitted_stock_movement_attributes)
        end

        def stock_item
          @stock_item ||= StockItem.find(params[:id])
        end

        def determine_backorderable
          stock_item.backorderable = params[:stock_item].present? && params[:stock_item][:backorderable].present?
        end

        def load_stock_locations
          @stock_locations = Spree::StockLocation.accessible_by(current_ability, :read).all
        end

        def load_stock_item_stock_locations
          selected_stock_location = find_selected_stock_location
          @stock_item_stock_locations = selected_stock_location.present? ? [selected_stock_location] : @stock_locations
        end

        def find_selected_stock_location
          @stock_locations.find { |sl| sl.id == params[:stock_location_id].to_i }
        end

        def variant_scope
          Spree::Variant.all
        end
    end
  end
end
