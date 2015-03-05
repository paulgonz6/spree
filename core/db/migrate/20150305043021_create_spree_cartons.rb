class CreateSpreeCartons < ActiveRecord::Migration
  def change
    create_table "spree_cartons" do |t|
      t.string "number", index: true

      t.integer "order_id", index: true
      t.integer "stock_location_id", index: true
      t.integer "address_id"
      t.integer "shipping_method_id"

      t.string "tracking"

      t.string "state"
      t.datetime "shipped_at"

      t.timestamps
    end

    add_column "spree_inventory_units", "carton_id", :integer, index: true
  end
end
