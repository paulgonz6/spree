require 'spec_helper'

describe Spree::UnprocessedInventoryUnitAmountCalculator do
  let(:calculator) { Spree::UnprocessedInventoryUnitAmountCalculator.new(inventory_unit) }
  let(:order) { create(:order_ready_to_ship) }
  let!(:inventory_unit) { order.inventory_units.first }

  context "when inventory has promotions" do
    subject { calculator.promotion_total }

    before { allow_any_instance_of(Spree::LineItem).to receive(:promo_total).and_return(9.11) }

    it "calculates the promotion total" do
      expect(subject).to eq 9.11
    end

    context "when there is a previously canceled inventory unit" do
      let!(:inventory_unit2) { create(:inventory_unit, line_item: inventory_unit.line_item, order: inventory_unit.order) }

      before { Spree::OrderCancellations.new(order).short_ship([inventory_unit2]) }

      it "calculates the promotion total based on canceled inventory" do
        expect(subject).to eq 4.55
      end
    end

    context "when there is a previously captured inventory unit" do
      let!(:inventory_unit2) { create(:inventory_unit, line_item: inventory_unit.line_item, order: inventory_unit.order) }
      let(:carton1) { create(:carton, inventory_units: [inventory_unit2]) }

      before do
        allow_any_instance_of(Spree::CartonPaymentStrategy).to receive(:capture_payments)
        Spree::CartonCapturing.new(carton1).capture
      end

      it "calculates the promotion total based on captured inventory" do
        expect(subject).to eq 4.55
      end
    end
  end

  context "when order has order promotions" do
    subject { calculator.order_adjustment_total }

    before { Spree::Adjustment.create!(order: order, adjustable: order, label: 'Some Label', amount: 9.11) }

    it "calculates the promotion total" do
      expect(subject).to eq 9.11.to_d
    end

    context "when there is a previously canceled inventory unit" do
      let!(:inventory_unit2) { create(:inventory_unit, line_item: inventory_unit.line_item, order: inventory_unit.order) }

      before { Spree::OrderCancellations.new(order).short_ship([inventory_unit2]) }

      it "calculates the promotion total based on canceled inventory" do
        expect(subject).to eq 4.55
      end
    end

    context "when there is a previously captured inventory unit" do
      let!(:inventory_unit2) { create(:inventory_unit, line_item: inventory_unit.line_item, order: inventory_unit.order) }
      let(:carton1) { create(:carton, inventory_units: [inventory_unit2]) }

      before do
        allow_any_instance_of(Spree::CartonPaymentStrategy).to receive(:capture_payments)
        Spree::CartonCapturing.new(carton1).capture
      end

      it "calculates the promotion total based on captured inventory" do
        expect(subject).to eq 4.55
      end
    end

  end

  context "when inventory has included tax" do
    subject { calculator.included_tax_total }

    before { allow_any_instance_of(Spree::LineItem).to receive(:included_tax_total).and_return(9.11) }

    it "calculates the tax total" do
      expect(subject).to eq 9.11
    end

    context "when there is a previously canceled inventory unit" do
      let!(:inventory_unit2) { create(:inventory_unit, line_item: inventory_unit.line_item, order: inventory_unit.order) }

      before { Spree::OrderCancellations.new(order).short_ship([inventory_unit2]) }

      it "calculates the tax total based on canceled inventory" do
        expect(subject).to eq 4.55
      end
    end

    context "when there is a previously captured inventory unit" do
      let!(:inventory_unit2) { create(:inventory_unit, line_item: inventory_unit.line_item, order: inventory_unit.order) }
      let(:carton1) { create(:carton, inventory_units: [inventory_unit2]) }

      before do
        allow_any_instance_of(Spree::CartonPaymentStrategy).to receive(:capture_payments)
        Spree::CartonCapturing.new(carton1).capture
      end

      it "calculates the tax total based on captured inventory" do
        expect(subject).to eq 4.55
      end
    end
  end

  context "when inventory has additional tax" do
    subject { calculator.additional_tax_total }

    before { allow_any_instance_of(Spree::LineItem).to receive(:additional_tax_total).and_return(9.11) }

    it "calculates the tax total" do
      expect(subject).to eq 9.11
    end

    context "when there is a previously canceled inventory unit" do
      let!(:inventory_unit2) { create(:inventory_unit, line_item: inventory_unit.line_item, order: inventory_unit.order) }

      before { Spree::OrderCancellations.new(order).short_ship([inventory_unit2]) }

      it "calculates the tax total based on canceled inventory" do
        expect(subject).to eq 4.55
      end
    end

    context "when there is a previously captured inventory unit" do
      let!(:inventory_unit2) { create(:inventory_unit, line_item: inventory_unit.line_item, order: inventory_unit.order) }
      let(:carton1) { create(:carton, inventory_units: [inventory_unit2]) }

      before do
        allow_any_instance_of(Spree::CartonPaymentStrategy).to receive(:capture_payments)
        Spree::CartonCapturing.new(carton1).capture
      end

      it "calculates the tax total based on captured inventory" do
        expect(subject).to eq 4.55
      end
    end
  end

  context "when we have already captured for the inventory" do
    subject { calculator }
    let(:carton1) { create(:carton, inventory_units: [inventory_unit]) }

    before do
      allow_any_instance_of(Spree::CartonPaymentStrategy).to receive(:capture_payments)
      Spree::CartonCapturing.new(carton1).capture
    end

    it "raises an error when initializing" do
      expect { subject }.to raise_error(Spree::UnprocessedInventoryUnitAmountCalculator::InventoryPreviouslyProcessedError)
    end
  end

  context "when we have already canceled the inventory" do
    subject { calculator }

    before { Spree::OrderCancellations.new(order).short_ship([inventory_unit]) }

    it "raises an error when initializing" do
      expect { subject }.to raise_error(Spree::UnprocessedInventoryUnitAmountCalculator::InventoryPreviouslyProcessedError)
    end
  end

  describe "#currency" do
    subject { calculator.currency }

    it "returns the line item's currency" do
      expect(subject).to eq inventory_unit.line_item.currency
    end
  end
end
