require 'spec_helper'

describe Spree::CartonCapturing do
  let(:carton_capturing) { Spree::CartonCapturing.new(carton) }
  let(:order) { create(:order_with_line_items) }
  let(:carton) { Spree::OrderShipping.new(order).ship_shipment(order.shipments.first) }
  let(:shipment) { order.shipments.first }

  describe "#capture" do
    subject { carton_capturing.capture }

    context "a simple order" do
      it "creates a carton capture" do
        expect { subject }.to change { Spree::CartonCapture.count }.by(1)
      end

      it "creates a inventory unit capture with the correct amounts" do
        expect { subject }.to change { Spree::InventoryUnitCapture.count }.by(1)

        capture = Spree::InventoryUnitCapture.last
        expect(capture.carton_capture).to eq Spree::CartonCapture.last
        expect(capture.price).to eq 10
        expect(capture.currency).to eq 'USD'
        expect(capture.promo_total).to eq 0
        expect(capture.additional_tax_total).to eq 0
        expect(capture.included_tax_total).to eq 0
        expect(capture.order_adjustment_total).to eq 0
      end
    end

    context "when there are multiple captures" do
      let!(:promotion) { create(:promotion_with_item_adjustment, adjustment_rate: 1.66, code: 'PROMO') }
      let(:inventory_unit2) { order.inventory_units[1] }
      let(:inventory_unit3) { order.inventory_units[2] }
      let(:carton_captures) { order.cartons.flat_map(&:carton_captures) }

      let(:carton2) do
        Spree::OrderShipping.new(order).ship(
          inventory_units: [inventory_unit2],
          stock_location: shipment.stock_location,
          address: shipment.address,
          shipping_method: shipment.shipping_method,
          shipped_at: Time.now,
        )
      end

      let(:carton3) do
        Spree::OrderShipping.new(order).ship(
          inventory_units: [inventory_unit3],
          stock_location: shipment.stock_location,
          address: shipment.address,
          shipping_method: shipment.shipping_method,
          shipped_at: Time.now,
        )
      end

      let!(:order) { create(:order, ship_address: create(:address)) }
      let!(:product) { create(:product, price: 10.00) }
      let!(:variant) do
        create(:variant, price: 10, product: product, track_inventory: false, tax_category: tax_rate.tax_category)
      end
      let!(:shipping_method) { create(:free_shipping_method) }
      let(:tax_rate) { create(:tax_rate, amount: 0.1, zone: create(:global_zone, name: "Some Tax Zone")) }

      before do
        order.contents.add(variant, 3)
        order.contents.apply_coupon_code('PROMO')
        Spree::Adjustment.create!(order: order, adjustable: order, label: 'Some Label', amount: -1.66)
        order.contents.advance
        create(:payment, order: order, amount: order.total)
        order.complete!
        order.reload
        Spree::CartonCapturing.new(carton2).capture
        Spree::CartonCapturing.new(carton3).capture
      end

      it "the carton capture totals equal the order total" do
        subject
        expect(carton_captures.sum(&:total)).to eq order.total
      end

      context "the inventory unit capture totals" do
        let(:inventory_captures) { carton_captures.flat_map(&:inventory_unit_captures) }

        before { subject }

        it "has the correct price breakdown" do
          expect(inventory_captures.map(&:price)).to match_array([10.0, 10.0, 10.0])
        end

        it "has the correct promo breakdown" do
          expect(inventory_captures.map(&:promo_total)).to match_array([-0.55, -0.55, -0.56].map(&:to_d))
        end

        it "has the correct additional tax breakdown" do
          expect(inventory_captures.map(&:additional_tax_total)).to match_array([0.94, 0.94, 0.95].map(&:to_d))
        end

        it "has the correct included tax breakdown" do
          expect(inventory_captures.map(&:included_tax_total)).to match_array([0.0, 0.0, 0.0])
        end

        it "has the correct order adjustment breakdown" do
          expect(inventory_captures.map(&:order_adjustment_total)).to match_array([-0.55, -0.55, -0.56].map(&:to_d))
        end
      end

      context "the payment capture totals" do
        before { subject }
        let(:capture_events) { order.payments.flat_map(&:capture_events) }

        it "has three payment captures" do
          expect(capture_events.size).to eq 3
        end

        it "fully charges the order" do
          expect(capture_events.sum(&:amount)).to eq(order.total)
        end
      end
    end

    context "when we are trying to charge too much" do
      before do
        allow_any_instance_of(Spree::UnprocessedInventoryUnitAmountCalculator).to receive(:price_total).and_return(order.total + 1)
      end

      it "raises an error and does not create any captures" do
        expect {
          expect {
            expect { subject }.to raise_error(Spree::CartonCapturing::CaptureTooLargeError)
          }.to_not change { Spree::InventoryUnitCapture.count }
        }.to_not change { Spree::CartonCapture.count }
      end
    end

  end
end
