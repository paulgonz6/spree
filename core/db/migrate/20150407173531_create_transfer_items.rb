class CreateTransferItems < ActiveRecord::Migration
  def change
    create_table :spree_transfer_items do |t|
      t.integer :stock_location_id
      t.integer :variant_id
      t.integer :stock_transfer_id
      t.datetime :received_at
      t.timestamps
    end

    add_index :spree_transfer_items, :stock_transfer_id
    add_index :spree_transfer_items, :stock_location_id
    add_index :spree_transfer_items, :variant_id
  end
end
