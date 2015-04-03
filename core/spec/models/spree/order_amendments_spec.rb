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
  end
end
