module Spree
  module Admin
    class StockItemsController < Spree::Admin::BaseController
      before_filter :determine_backorderable, only: :update
      before_filter :load_user_stock_locations, only: :index

      def index
        @stock_location_id = params[:stock_location_id]
        ransack_result = Spree::Core::Search::Variant.new(params[:variant_search_term] || "", scope: Spree::Variant.all)
        @variants = ransack_result.results.page(params[:page]).per(params[:per_page] || Spree::Config[:orders_per_page])
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

        def load_user_stock_locations
          # TODO - this should filter the stock locations
          # to only include the ones that the user has access to
          @stock_locations = Spree::StockLocation.all
        end
    end
  end
end
