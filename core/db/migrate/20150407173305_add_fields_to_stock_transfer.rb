class AddFieldsToStockTransfer < ActiveRecord::Migration
  def change
    add_column :spree_stock_transfers, :shipped_at, :datetime
    add_column :spree_stock_transfers, :closed_at, :datetime
    add_column :spree_stock_transfers, :tracking_number, :string

    add_index :spree_stock_transfers, :shipped_at
    add_index :spree_stock_transfers, :closed_at
  end
end
