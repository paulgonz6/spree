module Spree
  class ReimbursementItem < ActiveRecord::Base
    belongs_to :reimbursement, inverse_of: :reimbursement_items
    belongs_to :inventory_unit, inverse_of: :reimbursement_items
    belongs_to :return_item, inverse_of: :reimbursement_item
    belongs_to :override_reimbursement_type, class_name: 'Spree::ReimbursementType'

    def total
      pre_tax_amount + additional_tax_total
    end

    def display_total
      Spree::Money.new(total, { currency: currency })
    end

    def currency
      reimbursement.currency
    end
  end
end
