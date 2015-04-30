class Spree::CartonPaymentStrategy
  class_attribute :eligible_payments
  self.eligible_payments = []

  def initialize(carton_capture)
    @carton_capture = carton_capture
  end

  def capture_payments
    order_unit_capture_groups.each do |order, unit_captures|
      uncaptured_amount = @carton_capture.total(unit_captures)

      Spree::OrderMutex.with_lock!(order) do
        while uncaptured_amount > 0 do
          payment = sorted_eligible_payments(order).shift
          amount = [uncaptured_amount, payment.uncaptured_amount].min
          payment.capture!((amount * 100).to_i)
          uncaptured_amount -= amount
        end
      end
    end
  end

  private

  def sorted_eligible_payments(order)
    payments = order.pending_payments
    payments = payments.sort_by { |p| [eligible_payments.index(p.payment_method.class), p.id] }
  end

  def order_unit_capture_groups
    @carton_capture.inventory_unit_captures.group_by{|iuc| iuc.inventory_unit.order }
  end
end
