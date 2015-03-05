class Spree::Carton < ActiveRecord::Base
  belongs_to :order, class_name: 'Spree::Order', touch: true, inverse_of: :cartons
  belongs_to :address, class_name: 'Spree::Address', inverse_of: :cartons
  belongs_to :stock_location, class_name: 'Spree::StockLocation', inverse_of: :cartons
  belongs_to :shipping_method, class_name: 'Spree::ShippingMethod', inverse_of: :cartons

  has_many :inventory_units, inverse_of: :carton

  validates :order, presence: true
  validates :address, presence: true
  validates :stock_location, presence: true
  validates :shipping_method, presence: true
  validates :inventory_units, presence: true

  accepts_nested_attributes_for :address

  after_create :mark_inventory_units_as_shipped
  after_create :update_order_shipment_state
  after_create :send_shipped_email
  after_create :fulfill_order_with_stock_location

  make_permalink field: :number, length: 11, prefix: 'C'

  scope :trackable, -> { where("tracking IS NOT NULL AND tracking != ''") }
  # sort by most recent shipped_at, falling back to created_at. add "id desc" to make specs that involve this scope more deterministic.
  scope :reverse_chronological, -> { order('coalesce(spree_shipments.shipped_at, spree_shipments.created_at) desc', id: :desc) }

  def to_param
    number
  end

  def tracking_url
    @tracking_url ||= shipping_method.build_tracking_url(tracking)
  end

  private

  def mark_inventory_units_as_shipped
    inventory_units.each &:ship!
  end

  def update_order_shipment_state
    new_state = OrderUpdater.new(order).update_shipment_state
    order.update_columns(
      shipment_state: new_state,
      updated_at: Time.now,
    )
  end

  def send_shipped_email
    ShipmentMailer.shipped_email(self.id).deliver
  end

  def fulfill_order_with_stock_location
    Spree::OrderStockLocation.fulfill_for_order_with_stock_location(order, stock_location)
  end
end
