module Spree
  module Api
    class LineItemsController < Spree::Api::BaseController
      before_filter :load_order, only: [:create, :update, :destroy]
      around_filter :lock_order, only: [:create, :update, :destroy]

      def create
        variant = Spree::Variant.find(params[:line_item][:variant_id])
        @line_item = @order.contents.add(variant, params[:line_item][:quantity] || 1, stock_location_quantities: params[:line_item][:stock_location_quantities])
        if @line_item.errors.empty?
          respond_with(@line_item, status: 201, default_template: :show)
        else
          invalid_resource!(@line_item)
        end
      end

      def update
        @line_item = find_line_item
        if @order.contents.update_cart(line_items_attributes)
          @order.ensure_updated_shipments
          @line_item.reload
          respond_with(@line_item, default_template: :show)
        else
          invalid_resource!(@line_item)
        end
      end

      def destroy
        @line_item = find_line_item
        variant = Spree::Variant.find(@line_item.variant_id)
        @order.contents.remove(variant, @line_item.quantity)
        respond_with(@line_item, status: 204)
      end

      private
        def load_order
          @order ||= Spree::Order.includes(:line_items).find_by!(number: order_id)
          authorize! :update, @order, order_token
        end

        def find_line_item
          id = params[:id].to_i
          @order.line_items.detect {|line_item| line_item.id == id} or
            raise ActiveRecord::RecordNotFound
        end

        def line_items_attributes
          { line_items_attributes: {
            id: params[:id],
            quantity: params[:line_item][:quantity]
          } }
        end

        def line_item_params
          params.require(:line_item).permit(:quantity, :variant_id)
        end
    end
  end
end
