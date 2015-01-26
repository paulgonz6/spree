# Used by Prioritizer to adjust item quantities
# see prioritizer_spec for use cases
module Spree
  module Stock
    class Adjuster
      attr_accessor :inventory_unit, :status, :fulfilled

      def initialize(inventory_unit, status)
        @inventory_unit = inventory_unit
        @status = status
        @fulfilled = false
      end

      def adjust(package)
        if fulfilled?  || (is_preferred?(package) && is_fulfillable_at_preference(package))
          self.fulfilled = true
        else
          package.remove(inventory_unit)
        end
      end

      def fulfilled?
        fulfilled
      end

      # def is_preferred?(package)
      #   inventory_unit.line_item.stock_locations.include?(package.stock_location)
      # end
      #
      # def is_fulfillable_at_preference?(package)
      #   inventory_unit.line_item_stock_locations(package.stock_location).sum(:quantity) > 0
      # end
      #
      def is_preferred?(package)
        inventory_unit.line_item.stock_locations.include?(package.stock_location)
      end

      def is_fulfillable_at_preference?(package)
        inventory_unit.line_item_stock_locations(package.stock_location).sum(:quantity) > 0
      end

    end
  end
end
