class OrderReturn
  # can be created in 3 ways
  # 1) customer clicks checkboxes on frontend stating what they are intending to return
  # 2) admin initiates on backend stating what the customer is intending to return
  # 3) items show up and we want to refund them
  #
  # what happens when items show up that are different from what is intended to be returned
  @line_item_returns = []
  @refund
  @stock_location # a return will only receive items back to one location

  has_one :return_shipment
  has_many :order_return_refund_methods

  state_machine :state, initial: :requested do
    after_transition any => :requested, do: :notify_customer_of_refund_request

    before_transition :requested => :processed, do: :process_return_shipment
    before_transition :received => :stock_returned, do: :perform_stock_return
    before_transition :stock_returned => :refunded, do: :perform_refund

    event :transition_forward do
      transition :requested => :received
      transition :received => :stock_returned
      transition :stock_returned => :refunded
    end

  end

  def initialize(order)
    @order = order
    @refund = Refund.new
  end

  def set_line_items(item_returns)
    if !state || state == "requested"
      @line_item_returns = item_returns
    else
      raise "BOOM"
    end
  end

  def return_total
    @line_item_returns.map(&:total).sum
  end

  def returned_total
    @refund.total
  end

  def execute!(received_items)
    # when the shipment is received by the warehouse, it might not contain the same items
    # the user or admin created in the return. For now, we're going to be cool with that and
    # accept them as the line items returned, but we'll need to expand the logic here
    # to allow stores to customize what should happen in that case
    set_line_items(received_items) if received_items
    while transition_forward; end
  end

  private

  def perform_stock_return!
    @line_item_returns.select(&:should_restock).each(&:restock!)
  end

  def perform_refund
    allocate_credits!
    refund.perform
  end

  def allocate_credits!
    pending_total = return_total

    refund_methods.each do |refund_method|
      break if pending_total <= 0
      amount = [refund_method.max_amount(@order), amount].min
      refund.credits << Credit.new(refund_method: refund_method, amount: amount)
      pending_total = pending_total - amount
    end
  end

  def refund_methods
    requested_methods = order_return_refund_methods.order('priority desc').map(&:refund_method)
    all_methods = requested_methods + RefundMethod.all
  end

end

class OrderReturnRefundMethod
  belongs_to :order_return
  belongs_to :refund_method

  attr_accessible :priority
end

class LineItemReturn
  attr_accessor :line_item, :quantity, :should_restock

  def initialize(line_item, quantity, options = {})
    @line_item, @quantity = line_item, quantity
    @should_restock = options[:should_restock]
  end

  def total
    line_item.unit_price_on_order * quantity
  end

  def restock!
    line_item.variant.add_stock(quantity, order_return.stock_location)
  end

end

class LineItemExchange < LineItemReturn
  def initialize(line_item, quantity, exchange_variant, options = {})
    super(line_item, quantity, options)
  end

  def total
    0.0
  end
end

class Refund
  @credits = []

  attr_accessor :refund_strategy

  def refund!
    while amount_handled_by_current_credits < amount
      self.credits << refund_strategy.give_me_credit(unhandled_amount)

    end

    credits.each(&:perform!)
  end

  def amount_handled_by_current_credits
    @credits.sum(:amount)
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

class OrderReturnEligibility

  def initialize(order)
    @order = order
  end

  def eligible_line_items
    @order.line_items.all
  end

end

class ReturnShipment
  belongs_to :order
  belongs_to :order_return
  def instructions
  end
  def label
  end
end
