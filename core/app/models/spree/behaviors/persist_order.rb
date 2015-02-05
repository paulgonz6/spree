module Spree
  module Behaviors
    class PersistOrder < OrderBase

      def run
        order.save!
      end

    end
  end
end
