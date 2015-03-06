class MoveShippedShipmentsToCartons < ActiveRecord::Migration
  # Prevent everything from running in one giant transaction in postrgres.
  # This migration should be safe to run multiple times if it errors part way
  # through.
  disable_ddl_transaction!

  # Doing this via SQL because for large stores with lots of shipments and lots
  # of inventory units this would take excessively long to do via ActiveRecord
  # one at a time.

  def up
    if Spree::ShippingRate.where(selected: true).group(:shipment_id).having("count(0) > 1").exists?
      # This would end up generating multiple cartons for a single shipment
      raise "Error: You have shipments with more than one 'selected' shipping rate.
             The migration code will not work correctly.".squish
    end

    add_column :spree_cartons, :imported_from_shipment_id, :integer
    add_index :spree_cartons, :imported_from_shipment_id

    say_with_time 'generating cartons' do
      Spree::Carton.connection.execute(<<-SQL.strip_heredoc)
        insert into spree_cartons
          (
            imported_from_shipment_id, order_id, stock_location_id, address_id,
            shipping_method_id, tracking, shipped_at, created_at, updated_at
          )
        select
          spree_shipments.id,
          spree_shipments.order_id,
          spree_shipments.stock_location_id,
          spree_shipments.address_id,
          spree_shipping_rates.shipping_method_id,
          spree_shipments.tracking,
          spree_shipments.shipped_at,
          '#{Time.now.to_s(:db)}',
          '#{Time.now.to_s(:db)}'
        from spree_shipments
        left join spree_shipping_rates
          on spree_shipping_rates.shipment_id = spree_shipments.id
          and spree_shipping_rates.selected = #{Spree::Carton.connection.quoted_true}
        left join spree_cartons
          on spree_shipments.id = spree_cartons.imported_from_shipment_id
        where spree_shipments.state = 'shipped'
        and spree_cartons.id is null
      SQL
    end

    say_with_time 'linking inventory units to cartons' do
      last_id = Spree::InventoryUnit.
        where(carton_id: nil).
        where.not(shipment_id: nil).
        last.try!(:id) || 0

      # large stores will have lots of inventory units so do this in batches
      in_batches(last_id: last_id) do |start_id, end_id|
        say_with_time "processing inventory units #{start_id} to #{end_id}" do
          Spree::InventoryUnit.connection.execute(<<-SQL.strip_heredoc)
            update spree_inventory_units
            set carton_id = (
              select spree_cartons.id
              from spree_shipments
              inner join spree_cartons
                on spree_cartons.imported_from_shipment_id = spree_shipments.id
              where spree_shipments.id = spree_inventory_units.shipment_id
            )
            where spree_inventory_units.carton_id is null
            and spree_inventory_units.shipment_id is not null
            and spree_inventory_units.id >= #{start_id}
            and spree_inventory_units.id <= #{end_id}
          SQL
        end
      end
    end
  end

  def down
    say_with_time 'unlinking inventory units from cartons' do
      in_batches(last_id: last_id) do |start_id, end_id|
        say_with_time "processing inventory units #{start_id} to #{end_id}" do
          Spree::InventoryUnit.connection.execute(<<-SQL.strip_heredoc)
            update spree_inventory_units
            set carton_id = null
            where carton_id in (
              select spree_cartons.id
              from spree_cartons
              where spree_cartons.imported_from_shipment_id is not null
            )
            and spree_inventory_units.id >= #{start_id}
            and spree_inventory_units.id <= #{end_id}
          SQL
        end
      end
    end

    Spree::Carton.where.not(imported_from_shipment_id: nil).delete_all
  end

  private

  def in_batches(last_id:)
    start_id = 1
    batch_size = 10_000

    while start_id <= last_id
      end_id = start_id + batch_size - 1

      yield start_id, end_id

      start_id += batch_size
    end
  end
end
