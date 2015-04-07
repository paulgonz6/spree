class CreateUnitCancels < ActiveRecord::Migration
  def change
    create_table :spree_unit_cancels do |t|
      t.references :inventory_unit, index: true, null: false
      t.references :created_by
      t.string :reason
      t.timestamps
    end
  end
end
