class Spree::OrderCapturing
  class_attribute :eligible_payments
  self.eligible_payments = []

  def initialize(order)
    @order = order
  end

  def capture_payments
    return if @order.paid?

    Spree::OrderMutex.with_lock!(@order) do
      uncaptured_amount = @order.total

      while uncaptured_amount > 0 do
        payment = sorted_eligible_payments(@order).shift
        break unless payment

        amount = [uncaptured_amount, payment.amount].min
        payment.capture!((amount * 100).to_i)
        uncaptured_amount -= amount
      end
    end
  end

  private

  def sorted_eligible_payments(order)
    payments = order.reload.pending_payments
    payments = payments.sort_by { |p| [eligible_payments.index(p.payment_method.class), p.id] }
  end
end
