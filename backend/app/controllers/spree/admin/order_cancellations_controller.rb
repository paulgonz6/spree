module Spree
  module Admin
    class OrderCancellationsController < Spree::Admin::BaseController
      before_filter :load_order, :only => [:show, :cancel]

      def show
        @inventory_units = @order.inventory_units.cancelable
      end

      def cancel
        inventory_units = Spree::InventoryUnit.where(id: params[:inventory_unit_ids])

        if inventory_units.size != params[:inventory_unit_ids].size
          flash[:error] = Spree.t(:unable_to_find_all_inventory_units)
          redirect_to admin_order_cancellation_path(@order)
        elsif inventory_units.empty?
          flash[:error] = Spree.t(:no_inventory_selected)
          redirect_to admin_order_cancellation_path(@order)
        else
          @order.cancellations(whodunnit: whodunnit).short_ship(inventory_units)

          flash[:success] = Spree.t(:inventory_canceled)
          redirect_to edit_admin_order_url(@order)
        end
      end

      private

      def whodunnit
        try_spree_current_user.try(:email)
      end

      def load_order
        @order = Order.find_by_number!(params[:id])
        authorize! action, @order
      end
    end
  end
end
