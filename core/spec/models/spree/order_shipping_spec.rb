require 'spec_helper'

describe Spree::OrderShipping do
  let(:order) { create(:order_ready_to_ship, line_items_count: 1) }

  shared_examples 'shipment shipping' do

    it "marks the inventory units as shipped" do
      expect { subject }.to change { order.inventory_units.reload.map(&:state) }.from(['on_hand']).to(['shipped'])
    end

    it "creates a carton with the shipment's inventory units" do
      expect { subject }.to change { order.cartons.count }.by(1)
      expect(subject.inventory_units).to match_array(shipment.inventory_units)
    end

    describe "shipment email" do
      before { with_test_mail { subject } }

      def emails
        ActionMailer::Base.deliveries
      end

      it "should send a shipment email" do
        expect(emails.size).to eq(1)
        expect(emails.first.subject).to eq("Spree Demo Site Shipment Notification ##{order.number}")
      end
    end

    it "updates the order shipment state" do
      expect { subject }.to change { order.reload.shipment_state }.from('ready').to('shipped')
    end

    it "updates shipment.shipped_at" do
      future = Timecop.freeze
      expect { subject }.to change { shipment.shipped_at }.from(nil).to(future)
    end

    it "updates order.updated_at" do
      future = 1.minute.from_now
      expect do
        Timecop.freeze(future) do
          subject
        end
      end.to change { order.updated_at }.from(order.updated_at).to(future)
    end

  end

  describe "#ship" do
    subject do
      order.shipping.ship(
        inventory_units: inventory_units,
        stock_location: stock_location,
        address: address,
        shipping_method: shipping_method,
      )
    end

    let(:shipment) { order.shipments.to_a.first }
    let(:inventory_units) { shipment.inventory_units }
    let(:stock_location) { shipment.stock_location }
    let(:address) { shipment.address }
    let(:shipping_method) { shipment.shipping_method }

    it_behaves_like 'shipment shipping'

    context "with an external_number" do
      subject do
        order.shipping.ship(
          inventory_units: inventory_units,
          stock_location: stock_location,
          address: address,
          shipping_method: shipping_method,
          external_number: 'some-external-number',
        )
      end

      it "sets the external_number" do
        expect(subject.external_number).to eq 'some-external-number'
      end
    end

    context "with a tracking number" do
      subject do
        order.shipping.ship(
          inventory_units: inventory_units,
          stock_location: stock_location,
          address: address,
          shipping_method: shipping_method,
          tracking_number: 'tracking-number',
        )
      end

      it "sets the tracking-number" do
        expect(subject.tracking).to eq 'tracking-number'
      end
    end

  end

  describe "#ship_shipment" do
    subject { order.shipping.ship_shipment(shipment) }

    let(:shipment) { order.shipments.to_a.first }

    it_behaves_like 'shipment shipping'

    context "with an external_number" do
      subject do
        order.shipping.ship_shipment(
          shipment,
          external_number: 'some-external-number',
        )
      end

      it "sets the external_number" do
        expect(subject.external_number).to eq 'some-external-number'
      end
    end

    context "with a tracking number" do
      subject do
        order.shipping.ship_shipment(
          shipment,
          tracking_number: 'tracking-number',
        )
      end

      it "sets the tracking-number" do
        expect(subject.tracking).to eq 'tracking-number'
      end
    end

  end
end
