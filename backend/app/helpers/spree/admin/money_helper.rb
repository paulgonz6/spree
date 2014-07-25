module Spree
  module Admin
    module MoneyHelper
      def display_currency(amount, currency)
        Spree::Money.new(amount, { currency: currency })
      end
    end
  end
end
