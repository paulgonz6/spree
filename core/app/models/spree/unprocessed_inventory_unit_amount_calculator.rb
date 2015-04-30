class Spree::UnprocessedInventoryUnitAmountCalculator
  class InventoryPreviouslyProcessedError < StandardError; end

  def initialize(inventory_unit)
    @inventory_unit = inventory_unit

    raise InventoryPreviouslyProcessedError if previously_processed?

    @line_item = inventory_unit.line_item
    @order = inventory_unit.order
    inventory_units = @line_item.inventory_units.reject(&:original_return_item)

    captured, uncaptured = inventory_units.partition(&:inventory_unit_capture)
    canceled, @unprocessed = uncaptured.partition(&:unit_cancel)

    @cancels = canceled.map(&:unit_cancel)
    @captures = captured.map(&:inventory_unit_capture)
  end

  def price_total
    @line_item.price
  end

  def promotion_total
    amount_to_process(
      total: @line_item.promo_total,
      processed_amount: @captures.sum(&:promo_total) + @cancels.sum(&:promo_total),
    )
  end

  def additional_tax_total
    amount_to_process(
      total: @line_item.additional_tax_total,
      processed_amount: @captures.sum(&:additional_tax_total) + @cancels.sum(&:additional_tax_total),
    )
  end

  def included_tax_total
    amount_to_process(
      total: @line_item.included_tax_total,
      processed_amount: @captures.sum(&:included_tax_total) + @cancels.sum(&:included_tax_total),
    )
  end

  def order_adjustment_total
    amount_to_process(
      total: @order.adjustments.eligible.sum(:amount),
      processed_amount: @captures.sum(&:order_adjustment_total) + @cancels.sum(&:order_adjustment_total),
    )
  end

  def currency
    @line_item.currency
  end

  private

  def amount_to_process(total:, processed_amount:)
    unprocessed_amount = total - processed_amount
    (unprocessed_amount / @unprocessed.count).round(2)
  end

  def previously_processed?
    @inventory_unit.inventory_unit_capture.present? ||
      @inventory_unit.unit_cancel.present?
  end
end
