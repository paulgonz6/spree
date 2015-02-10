module Spree
  module Stock
    class Quantifier
      attr_reader :stock_items

      def initialize(variant, order_stock_locations = nil)
        @variant = variant
        @stock_items = Spree::StockItem.joins(:stock_location).where(:variant_id => @variant, Spree::StockLocation.table_name => {id: stock_location_ids(order_stock_locations)})
      end

      def total_on_hand
        if @variant.should_track_inventory?
          stock_items.sum(:count_on_hand)
        else
          Float::INFINITY
        end
      end

      def backorderable?
        stock_items.any?(&:backorderable)
      end

      def can_supply?(required)
        total_on_hand >= required || backorderable?
      end

      private

      def stock_location_ids(order_stock_locations)
        if order_stock_locations.present?
          order_stock_locations.pluck(:stock_location_id)
        else
          Spree::StockLocation.active.pluck(:id)
        end
      end
    end
  end
end
