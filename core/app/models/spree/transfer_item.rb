module Spree
  class TransferItem < ActiveRecord::Base
    belongs_to :stock_transfer
    belongs_to :stock_location
    belongs_to :variant

    scope :received, ->{ where.not(received_at: nil) }
  end
end
