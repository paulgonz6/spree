module Spree
  class StockTransfer < ActiveRecord::Base
    class CannotModifyClosedStockTransfer < StandardError; end
    class InvalidTransferMovement < StandardError; end

    has_many :stock_movements, :as => :originator
    has_many :transfer_items

    belongs_to :created_by, :class_name => Spree.user_class.to_s
    belongs_to :finalized_by, :class_name => Spree.user_class.to_s
    belongs_to :closed_by, :class_name => Spree.user_class.to_s
    belongs_to :source_location, :class_name => 'Spree::StockLocation'
    belongs_to :destination_location, :class_name => 'Spree::StockLocation'

    validates_presence_of :source_location
    validates_presence_of :destination_location, if: :finalized?

    make_permalink field: :number, prefix: 'T'

    def to_param
      number
    end

    def finalized?
      finalized_at.present?
    end

    def closed?
      closed_at.present?
    end

    def shipped?
      shipped_at.present?
    end

    def finalizable?
      !finalized? && !shipped? && !closed?
    end

    def receivable?
      finalized? && shipped? && !closed?
    end

    def ship(tracking_number: tracking_number, shipped_at: shipped_at)
      update_attributes!(tracking_number: tracking_number, shipped_at: shipped_at)
    end

    def received_item_count
      transfer_items.sum(:received_quantity)
    end

    def expected_item_count
      transfer_items.sum(:expected_quantity)
    end

    def source_movements
      stock_movements.joins(:stock_item)
        .where('spree_stock_items.stock_location_id' => source_location_id)
    end

    def destination_movements
      stock_movements.joins(:stock_item)
        .where('spree_stock_items.stock_location_id' => destination_location_id)
    end

    def finalize(finalized_by)
      if finalizable?
        self.update_attributes({ finalized_at: Time.now, finalized_by: finalized_by })
      else
        errors.add(:base, Spree.t(:stock_transfer_cannot_be_finalized))
        false
      end
    end

    def transfer
      transaction do
        transfer_items.each do |item|
          raise InvalidTransferMovement unless item.valid?
          source_location.unstock(item.variant, item.expected_quantity, self)
        end
      end
    rescue InvalidTransferMovement
      errors.add(:base, Spree.t(:not_enough_stock))
      false
    end

    def close(closed_by)
      if receivable?
        self.update_attributes({ closed_at: Time.now, closed_by: closed_by })
      else
        errors.add(:base, Spree.t(:stock_transfer_must_be_receivable))
        false
      end
    end

  end
end
