module Spree
  module Admin
    module ReimbursementTypeHelper
      def reimbursement_type_name(reimbursement_type)
        reimbursement_type.present? ? reimbursement_type.name.humanize : Spree.t(:none_selected)
      end
    end
  end
end
