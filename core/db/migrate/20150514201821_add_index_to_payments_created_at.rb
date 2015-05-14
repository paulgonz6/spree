class AddIndexToPaymentsCreatedAt < ActiveRecord::Migration
  def change
    add_index :spree_payments, :created_at
  end
end
