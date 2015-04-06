require 'spec_helper'

describe Spree::OrderAmendments do
  describe "#short_ship_units" do
    subject { Spree::OrderAmendments.new.short_ship_units([inventory_unit]) }

    let(:order) { create(:order_ready_to_ship) }
    let(:inventory_unit) { order.inventory_units.first }

    it "creates a UnitCancel record" do
      expect { subject }.to change { Spree::UnitCancel.count }.by(1)

      unit_cancel = Spree::UnitCancel.last
      expect(unit_cancel.inventory_unit).to eq inventory_unit
      expect(unit_cancel.reason).to eq Spree::UnitCancel::SHORT_SHIP
    end

    it "cancels the inventory unit" do
      expect { subject }.to change { inventory_unit.state }.to "canceled"
    end

    it "adjusts the order" do
      expect { subject }.to change { order.total }.by(-10.0)
    end

    context "when rounding is required" do
      let(:order) { create(:order_ready_to_ship, line_items_count: 1, line_items_price: 0.83) }
      let(:line_item) { order.line_items.first }
      let(:inventory_unit_1) { line_item.inventory_units[0] }
      let(:inventory_unit_2) { line_item.inventory_units[1] }

      before do
        order.contents.add(line_item.variant)

        # make the total $1.67 so it divides unevenly
        Spree::Adjustment.tax.create!(
          order: order,
          adjustable: line_item,
          amount: 0.01,
          label: 'some fake tax',
          state: 'closed',
        )
        order.update!
      end

      it "generates the correct total amount" do
        Spree::OrderAmendments.new.short_ship_units([inventory_unit_1])
        Spree::OrderAmendments.new.short_ship_units([inventory_unit_2])
        expect(line_item.adjustments.non_tax.sum(:amount)).to eq -1.67
        expect(line_item.total).to eq 0
      end
    end
  end
end
