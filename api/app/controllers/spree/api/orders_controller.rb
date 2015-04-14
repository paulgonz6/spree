module Spree
  module Api
    class OrdersController < Spree::Api::BaseController
      class_attribute :admin_shipment_attributes
      self.admin_shipment_attributes = [:shipping_method, :stock_location, :inventory_units => [:variant_id, :sku]]

      class_attribute :admin_order_attributes
      self.admin_order_attributes = [:import, :number, :completed_at, :locked_at, :channel]

      skip_before_filter :check_for_user_or_api_key, only: :apply_coupon_code
      skip_before_filter :authenticate_user, only: :apply_coupon_code

      before_filter :find_order, except: [:create, :mine, :current, :index]
      around_filter :lock_order, except: [:create, :mine, :current, :index]

      # Dynamically defines our stores checkout steps to ensure we check authorization on each step.
      Order.checkout_steps.keys.each do |step|
        define_method step do
          authorize! :update, @order, params[:token]
        end
      end

      def cancel
        authorize! :update, @order, params[:token]
        @order.contents.cancel
        render :show
      end

      def create
        authorize! :create, Order
        @order = Spree::Core::Importer::Order.import(current_api_user, order_params)
        respond_with(@order, default_template: :show, status: 201)
      end

      def empty
        authorize! :update, @order, order_token
        @order.contents.empty
        render text: nil, status: 200
      end

      def index
        authorize! :index, Order
        @orders = Order.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
        respond_with(@orders)
      end

      def show
        authorize! :show, @order, order_token
        method = "before_#{@order.state}"
        send(method) if respond_to?(method, true)
        respond_with(@order)
      end

      def update
        authorize! :update, @order, order_token

        if @order.contents.update_cart(order_params)
          respond_with(@order, default_template: :show)
        else
          invalid_resource!(@order)
        end
      end

      def current
        @order = find_current_order
        if @order
          respond_with(@order, default_template: :show, locals: { root_object: @order })
        else
          head :no_content
        end
      end

      def mine
        if current_api_user.persisted?
          @orders = current_api_user.orders.reverse_chronological.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
        else
          render "spree/api/errors/unauthorized", status: :unauthorized
        end
      end

      def apply_coupon_code
        authorize! :update, @order, order_token
        @handler = @order.contents.apply_coupon_code(params[:coupon_code])
        status = @handler.successful? ? 200 : 422
        render "spree/api/promotions/handler", :status => status
      end

      private
        def order_params
          if params[:order]
            params[:order][:payments_attributes] = params[:order][:payments] if params[:order][:payments]
            params[:order][:shipments_attributes] = params[:order][:shipments] if params[:order][:shipments]
            params[:order][:line_items_attributes] = params[:order][:line_items] if params[:order][:line_items]
            params[:order][:ship_address_attributes] = params[:order][:ship_address] if params[:order][:ship_address].present?
            params[:order][:bill_address_attributes] = params[:order][:bill_address] if params[:order][:bill_address].present?

            params.require(:order).permit(permitted_order_attributes)
          else
            {}
          end
        end

        def permitted_order_attributes
          if is_admin?
            super + admin_order_attributes
          else
            super
          end
        end

        def permitted_shipment_attributes
          if is_admin?
            super + admin_shipment_attributes
          else
            super
          end
        end

        def find_order
          @order = Spree::Order.find_by!(number: params[:id])
        end

        def find_current_order
          current_api_user ? find_current_api_user_orders.last : nil
        end

        def find_current_api_user_orders
          last_completed_at = current_api_user.orders.complete.order(:completed_at).select(:completed_at).last.try(:completed_at)

          incomplete_orders = current_api_user.orders.incomplete.order(:created_at)
          incomplete_orders = incomplete_orders.where('created_at > ?', last_completed_at) if last_completed_at

          incomplete_orders
        end

        def before_delivery
          @order.create_proposed_shipments
        end

        def order_id
          super || params[:id]
        end
    end
  end
end
