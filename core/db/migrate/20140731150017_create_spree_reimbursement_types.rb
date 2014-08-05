class CreateSpreeReimbursementTypes < ActiveRecord::Migration
  def change
    create_table :spree_reimbursement_types do |t|
      t.string :name
      t.boolean :active, default: true
      t.boolean :mutable, default: true

      t.timestamps
    end

    Spree::ReimbursementType.create!(name: Spree::ReimbursementType::REFUND)

    add_column :spree_return_items, :preferred_reimbursement_type_id, :integer
    add_index :spree_return_items, :preferred_reimbursement_type_id, name: 'index_return_items_on_preferred_reimbursement_type_id'

    add_column :spree_return_items, :override_reimbursement_type_id, :integer
    add_index :spree_return_items, :override_reimbursement_type_id, name: 'index_return_items_on_override_reimbursement_type_id'
  end
end
