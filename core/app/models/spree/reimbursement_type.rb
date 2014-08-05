module Spree
  class ReimbursementType < Spree::Base
    include Spree::NamedType

    REFUND = 'refund'

    has_many :return_items
  end
end
