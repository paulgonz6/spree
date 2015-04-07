module Spree
  class StockTransfer < ActiveRecord::Base
    has_many :stock_movements, :as => :originator
    has_many :transfer_items

    belongs_to :source_location, :class_name => 'StockLocation'
    belongs_to :destination_location, :class_name => 'StockLocation'

    scope :by_location, ->(location_id){ where('source_location_id=? OR destination_location_id=?', location_id, location_id)}

    make_permalink field: :number, prefix: 'T'


    def status
      closed_at? ? Spree.t(:closed) : Spree.t(:open)
    end

    def to_param
      number
    end

    def source_movements
      stock_movements.joins(:stock_item)
        .where('spree_stock_items.stock_location_id' => source_location_id)
    end

    def destination_movements
      stock_movements.joins(:stock_item)
        .where('spree_stock_items.stock_location_id' => destination_location_id)
    end

    def transfer(source_location, destination_location, variants)
      transaction do
        variants.each_pair do |variant, quantity|
          source_location.unstock(variant, quantity, self) if source_location
          destination_location.restock(variant, quantity, self)

          self.source_location = source_location
          self.destination_location = destination_location
          self.save!
        end
      end
    end

    def receive(destination_location, variants)
      transfer(nil, destination_location, variants)
    end
  end
end
