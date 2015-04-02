# This represents an inventory unit that has been canceled from an order after it has already been completed
# The reason specifies why it was canceled.
# This class should encapsulate logic related to canceling inventory after order complete
class Spree::UnitCancel < ActiveRecord::Base
  SHORT_SHIP = 'short_ship'
  belongs_to :inventory_unit
end
