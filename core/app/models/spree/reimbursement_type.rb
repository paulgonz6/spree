module Spree
  class ReimbursementType < Spree::Base
    include Spree::NamedType

    has_many :return_items
  end
end
