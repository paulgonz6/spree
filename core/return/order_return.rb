class OrderReturn
  @line_item_returns = []
  @refund

  def initialize(order)
    @order = order
    @refund = Refund.new
  end

  def add_line_item(line_item_return)
    @line_item_returns << line_item_return
  end

  def return_total
    @line_item_returns.map(&:total).sum
  end

  def perform_stock_return!
    @line_item_returns.each do |item_return|
      # preform actual inventory return
    end
  end

  def execute!
    self.perform_stock_return!
    self.refund.refund!
  end

  def eligible_refund_methods
    RefundMethod.eligible_for_order @order
  end

end

class LineItemReturn
  attr_accessor :line_item, :quantity, :stock_location, :should_restock

  def initialize(line_item, quantity, options = {})
    @line_item, @quantity = line_item, quantity
    @stock_location = options[:stock_location]
    @should_restock = options[:should_restock]
  end

  def total
    line_item.unit_price_on_order * quantity
  end

end

class Refund
  @credits = []

  def refund!
    @credits.each do |credit|
      credit.allocate!
    end
  end

end

class Credit
  belongs_to :refund_method
  attr_accessor :amount

  def allocate!
    # do something. something smart.
  end
end

class RefundMethod
  belongs_to :refundable, polymorphic: true
  # payment or something to credit the user

  def self.eligible_for_order(order)
    # something really smart
  end
end
