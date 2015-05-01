require 'spec_helper'

describe Spree::UnitCancel do
  let(:inventory_unit) { create(:inventory_unit) }

  describe '#adjust!' do
    subject { unit_cancel.adjust! }

    let(:unit_cancel) { Spree::UnitCancel.create!(inventory_unit: inventory_unit, reason: Spree::UnitCancel::SHORT_SHIP, price: 10.0) }

    it "creates an adjustment with the correct attributes" do
      expect { subject }.to change{ Spree::Adjustment.count }.by(1)

      adjustment = Spree::Adjustment.last
      expect(adjustment.adjustable).to eq inventory_unit.line_item
      expect(adjustment.amount).to eq -10.0
      expect(adjustment.order).to eq inventory_unit.order
      expect(adjustment.label).to eq "Cancellation - Short Ship"
      expect(adjustment.eligible).to eq true
      expect(adjustment.state).to eq 'closed'
    end

    context "when an adjustment has already been created" do
      before { unit_cancel.adjust! }

      it "raises" do
        expect { subject }.to raise_error("Adjustment is already created")
      end
    end
  end

  describe '#compute_amount' do
    subject { unit_cancel.compute_amount(line_item) }

    let(:line_item) { inventory_unit.line_item }
    let!(:inventory_unit2) { create(:inventory_unit, line_item: inventory_unit.line_item) }
    let(:unit_cancel) do
      Spree::UnitCancel.create!(
        inventory_unit: inventory_unit,
        reason: Spree::UnitCancel::SHORT_SHIP,
        price: 10.0,
        promo_total: 1.1,
        additional_tax_total: 2.2,
        included_tax_total: 3.3,
        order_adjustment_total: 4.4,
      )
    end

    it "sums all unit cancel's the breakdown totals" do
      expect(subject).to eq -17.7
    end

    context "it is called with a line item that doesnt belong to the inventory unit" do
      let(:line_item) { create(:line_item) }

      it "raises an error" do
        expect { subject }.to raise_error
      end
    end
  end

end
