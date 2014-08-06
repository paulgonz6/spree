class CreateSpreeReimbursementItems < ActiveRecord::Migration
  def change
    create_table :spree_reimbursement_items do |t|
      t.integer :reimbursement_id
      t.integer :inventory_unit_id
      t.integer :return_item_id

      t.decimal :pre_tax_amount, precision: 12, scale: 4, default: 0.0, null: false
      t.decimal :included_tax_total, precision: 12, scale: 4, default: 0.0, null: false
      t.decimal :additional_tax_total, precision: 12, scale: 4, default: 0.0, null: false

      t.integer  :override_reimbursement_type_id

      t.timestamps
    end
  end
end
