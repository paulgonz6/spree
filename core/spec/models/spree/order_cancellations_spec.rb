require 'spec_helper'

describe Spree::OrderCancellations do
  describe "#short_ship" do
    subject { order.cancellations.short_ship([inventory_unit]) }

    let(:order) { create(:order_ready_to_ship, line_items_count: 1) }
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

    context "with a who" do
      subject { order.cancellations.short_ship([inventory_unit], whodunnit: 'some automated system') }

      let(:user) { order.user }

      it "sets the user on the UnitCancel" do
        expect { subject }.to change { Spree::UnitCancel.count }.by(1)
        expect(Spree::UnitCancel.last.created_by).to eq("some automated system")
      end
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
        order.cancellations.short_ship([inventory_unit_1])
        order.cancellations.short_ship([inventory_unit_2])
        expect(line_item.adjustments.non_tax.sum(:amount)).to eq -1.67
        expect(line_item.total).to eq 0
      end
    end


    context "when exchanges are present" do
      let!(:order) { create(:order, ship_address: create(:address)) }
      let!(:product) { create(:product, price: 10.00) }
      let!(:variant) do
        create(:variant, price: 10, product: product, track_inventory: false)
      end
      let!(:shipping_method) { create(:free_shipping_method) }
      let(:exchange_variant) do
        create(:variant, product: variant.product, price: 10, track_inventory: false)
      end

      before do
        @old_expedited_exchanges_value = Spree::Config[:expedited_exchanges]
        Spree::Config[:expedited_exchanges] = true
      end
      after do
        Spree::Config[:expedited_exchanges] = @old_expedited_exchanges_value
      end

      # This sets up an order with one shipped inventory unit, one unshipped
      # inventory unit, and one unshipped exchange inventory unit.
      before do
        # Complete an order with 1 line item with quantity=2
        order.contents.add(variant, 2)
        order.contents.advance
        create(:payment, order: order, amount: order.total)
        order.complete!
        order.reload

        # Ship _one_ of the inventory units
        @shipment = order.shipments.first
        @shipped_inventory_unit = order.inventory_units[0]
        @unshipped_inventory_unit = order.inventory_units[1]
        order.shipping.ship(
          inventory_units: [@shipped_inventory_unit],
          stock_location: @shipment.stock_location,
          address: order.ship_address,
          shipping_method: @shipment.shipping_method,
        )

        # Create an expedited exchange for the shipped inventory unit.
        # This generates a new inventory unit attached to the existing line item.
        Spree::ReturnAuthorization.create!(
          order: order,
          stock_location: @shipment.stock_location,
          reason: create(:return_authorization_reason),
          return_items: [
            Spree::ReturnItem.new(
              inventory_unit: @shipped_inventory_unit,
              exchange_variant: exchange_variant,
            ),
          ],
        )
        @exchange_inventory_unit = order.inventory_units.reload[2]
      end

      context 'when canceling an unshipped inventory unit from the original order' do
        subject do
          order.cancellations.short_ship([@unshipped_inventory_unit])
        end

        it "adjusts the order by the inventory unit's value" do
          expect { subject }.to change { order.total }.by(-10.0)
        end
      end

      context 'when canceling an unshipped exchange inventory unit' do
        subject do
          order.cancellations.short_ship([@exchange_inventory_unit])
        end

        it "adjusts the order by the inventory unit's value" do
          expect { subject }.to change { order.total }.by(-10.0)
        end
      end
    end
  end
end
