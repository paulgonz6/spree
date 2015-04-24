class CartonCaptureModels < ActiveRecord::Migration
  def change
    create_table :spree_carton_captures do |t|
      t.datetime :captured_at

      t.timestamps
    end

    create_table :spree_shipment_captures do |t|
      t.references :shipment, index: true, unique: true
      t.datetime :captured_at

      t.decimal :cost,                 precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :promo_total,          precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :additional_tax_total, precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :included_tax_total,   precision: 10, scale: 2, default: 0.0, null: false

      t.timestamps
    end

    create_table :spree_inventory_unit_captures do |t|
      t.references :inventory_unit, index: true, unique: true
      t.references :carton_capture, index: true

      t.string :currency
      t.decimal :price,                  precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :promo_total,            precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :additional_tax_total,   precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :included_tax_total,     precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :order_adjustment_total, precision: 10, scale: 2, default: 0.0, null: false

      t.timestamps
    end

    create_table :spree_carton_capture_payment_capture_events do |t|
      t.references :carton_capture
      t.references :payment_capture_event

      t.timestamps
    end

    create_table :spree_shipment_capture_payment_capture_events do |t|
      t.references :shipment_capture
      t.references :payment_capture_event

      t.timestamps
    end

    change_table :spree_unit_cancels do |t|
      t.string :currency
      t.decimal :price,                  precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :promo_total,            precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :additional_tax_total,   precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :included_tax_total,     precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :order_adjustment_total, precision: 10, scale: 2, default: 0.0, null: false
    end

    # The default index names for these are too long for sqlite/mysql/postgres
    add_index(
      :spree_carton_capture_payment_capture_events,
      :carton_capture_id,
      name: 'index_spree_carton_payment_captures_on_carton_capture_id',
    )
    add_index(
      :spree_carton_capture_payment_capture_events,
      :payment_capture_event_id,
      name: 'index_spree_carton_payment_captures_on_payment_capture_id',
    )
    add_index(
      :spree_shipment_capture_payment_capture_events,
      :shipment_capture_id,
      name: 'index_spree_shipment_payment_captures_on_carton_capture_id',
    )
    add_index(
      :spree_carton_capture_payment_capture_events,
      :payment_capture_event_id,
      name: 'index_spree_shipment_payment_captures_on_payment_capture_id',
    )
  end
end
