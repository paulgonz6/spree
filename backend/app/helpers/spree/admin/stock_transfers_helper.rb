module Spree
  module Admin
    module StockTransfersHelper
      def handle_stock_transfer(stock_transfer)
        if stock_transfer.closed_at? && can?(:edit, stock_transfer)
          link_to stock_transfer.number, edit_admin_stock_transfer_path(stock_transfer)
        elsif can?(:show, stock_transfer)
          link_to stock_transfer.number, admin_stock_transfer_path(stock_transfer)
        else
          stock_transfer.number
        end
      end
    end
  end
end
