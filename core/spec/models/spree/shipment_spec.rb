require 'spec_helper'
require 'benchmark'

describe Spree::Shipment do
  let(:order) { create(:order_ready_to_ship, line_items_count: 1) }
  let(:shipping_method) { create(:shipping_method, name: "UPS") }
  let(:stock_location) { create(:stock_location) }
  let(:shipment) do
    order.shipments.create!(
      state: 'pending',
      cost: 1,
      address: order.ship_address,
      inventory_units: order.inventory_units,
      shipping_rates: [
        Spree::ShippingRate.new(
          shipping_method: shipping_method,
          selected: true,
        ),
      ],
      stock_location: stock_location,
    )
  end

  let(:variant) { mock_model(Spree::Variant) }
  let(:line_item) { mock_model(Spree::LineItem, variant: variant) }

  # Regression test for #4063
  context "number generation" do
    before do
      order.stub :update!
    end

    it "generates a number containing a letter + 11 numbers" do
      shipment.save
      shipment.number[0].should == "H"
      /\d{11}/.match(shipment.number).should_not be_nil
      shipment.number.length.should == 12
    end
  end

  it 'is backordered if one if its inventory_units is backordered' do
    shipment.inventory_units = [
      build(:inventory_unit, state: 'backordered', shipment: nil),
      build(:inventory_unit, state: 'shipped', shipment: nil),
    ]
    shipment.should be_backordered
  end

  context "display_amount" do
    it "retuns a Spree::Money" do
      shipment.cost = 21.22
      shipment.display_amount.should == Spree::Money.new(21.22)
    end
  end

  context "display_final_price" do
    it "retuns a Spree::Money" do
      shipment.stub(:final_price) { 21.22 }
      shipment.display_final_price.should == Spree::Money.new(21.22)
    end
  end

  context "display_item_cost" do
    it "retuns a Spree::Money" do
      shipment.stub(:item_cost) { 21.22 }
      shipment.display_item_cost.should == Spree::Money.new(21.22)
    end
  end

  it "#item_cost" do
    shipment = create(:shipment, order: create(:order_with_totals))
    shipment.item_cost.should eql(10.0)
  end

  it "#discounted_cost" do
    shipment = create(:shipment)
    shipment.cost = 10
    shipment.promo_total = -1
    shipment.discounted_cost.should == 9
  end

  it "#tax_total with included taxes" do
    shipment = Spree::Shipment.new
    expect(shipment.tax_total).to eq(0)
    shipment.included_tax_total = 10
    expect(shipment.tax_total).to eq(10)
  end

  it "#tax_total with additional taxes" do
    shipment = Spree::Shipment.new
    expect(shipment.tax_total).to eq(0)
    shipment.additional_tax_total = 10
    expect(shipment.tax_total).to eq(10)
  end

  it "#final_price" do
    shipment = Spree::Shipment.new
    shipment.cost = 10
    shipment.promo_total = -2
    shipment.included_tax_total = 1
    expect(shipment.final_price).to eq(9)
  end

  context "manifest" do
    let(:order) { Spree::Order.create }
    let(:variant) { create(:variant) }
    let!(:line_item) { order.contents.add variant }
    let!(:shipment) { order.create_proposed_shipments.first }

    it "returns variant expected" do
      expect(shipment.manifest.first.variant).to eq variant
    end

    context "variant was removed" do
      before { variant.destroy }

      it "still returns variant expected" do
        expect(shipment.manifest.first.variant).to eq variant
      end
    end
  end

  context 'shipping_rates' do
    let(:shipment) { create(:shipment) }
    let(:shipping_method1) { create(:shipping_method) }
    let(:shipping_method2) { create(:shipping_method) }
    let(:shipping_rates) { [
      Spree::ShippingRate.new(shipping_method: shipping_method1, cost: 10.00, selected: true),
      Spree::ShippingRate.new(shipping_method: shipping_method2, cost: 20.00)
    ] }

    it 'returns shipping_method from selected shipping_rate' do
      shipment.shipping_rates.delete_all
      shipment.shipping_rates.create shipping_method: shipping_method1, cost: 10.00, selected: true
      shipment.shipping_method.should eq shipping_method1
    end

    context 'refresh_rates' do
      let(:mock_estimator) { double('estimator', shipping_rates: shipping_rates) }
      before { shipment.stub(:can_get_rates?){ true } }

      it 'should request new rates, and maintain shipping_method selection' do
        Spree::Stock::Estimator.should_receive(:new).with(shipment.order).and_return(mock_estimator)
        shipment.stub(shipping_method: shipping_method2)

        shipment.refresh_rates.should == shipping_rates
        shipment.reload.selected_shipping_rate.shipping_method_id.should == shipping_method2.id
      end

      it 'should handle no shipping_method selection' do
        Spree::Stock::Estimator.should_receive(:new).with(shipment.order).and_return(mock_estimator)
        shipment.stub(shipping_method: nil)
        shipment.refresh_rates.should == shipping_rates
        shipment.reload.selected_shipping_rate.should_not be_nil
      end

      it 'should not refresh if shipment is shipped' do
        Spree::Stock::Estimator.should_not_receive(:new)
        shipment.shipping_rates.delete_all
        shipment.stub(shipped?: true)
        shipment.refresh_rates.should == []
      end

      it "can't get rates without a shipping address" do
        shipment.order(ship_address: nil)
        expect(shipment.refresh_rates).to eq([])
      end

      context 'to_package' do
        let(:inventory_units) do
          [build(:inventory_unit, line_item: line_item, variant: variant, state: 'on_hand'),
           build(:inventory_unit, line_item: line_item, variant: variant, state: 'backordered')]
        end

        it 'should use symbols for states when adding contents to package' do
          shipment.stub(:inventory_units) { inventory_units }
          package = shipment.to_package
          package.on_hand.count.should eq 1
          package.backordered.count.should eq 1
        end
      end
    end
  end

  context "#update!" do
    shared_examples_for "immutable once shipped" do
      it "should remain in shipped state once shipped" do
        shipment.state = 'shipped'
        shipment.should_receive(:update_columns).with(state: 'shipped', updated_at: kind_of(Time))
        shipment.update!(order)
      end
    end

    shared_examples_for "pending if backordered" do
      it "should have a state of pending if backordered" do
        shipment.stub(inventory_units: [mock_model(Spree::InventoryUnit, backordered?: true)])
        shipment.should_receive(:update_columns).with(state: 'pending', updated_at: kind_of(Time))
        shipment.update!(order)
      end
    end

    context "when order cannot ship" do
      before { order.stub can_ship?: false }
      it "should result in a 'pending' state" do
        shipment.should_receive(:update_columns).with(state: 'pending', updated_at: kind_of(Time))
        shipment.update!(order)
      end
    end

    context "when order is paid" do
      before { order.stub paid?: true }
      it "should result in a 'ready' state" do
        shipment.should_receive(:update_columns).with(state: 'ready', updated_at: kind_of(Time))
        shipment.update!(order)
      end
      it_should_behave_like 'immutable once shipped'
      it_should_behave_like 'pending if backordered'
    end

    context "when payment is not required" do
      before do
        @original_require_payment = Spree::Config[:require_payment_to_ship]
        Spree::Config[:require_payment_to_ship] = false
      end

      after do
        Spree::Config[:require_payment_to_ship] = @original_require_payment
      end

      it "should result in a 'ready' state" do
        shipment.should_receive(:update_columns).with(state: 'ready', updated_at: kind_of(Time))
        shipment.update!(order)
      end
      it_should_behave_like 'immutable once shipped'
      it_should_behave_like 'pending if backordered'
    end

    context "when order has balance due" do
      before { order.stub paid?: false }
      it "should result in a 'pending' state" do
        shipment.state = 'ready'
        shipment.should_receive(:update_columns).with(state: 'pending', updated_at: kind_of(Time))
        shipment.update!(order)
      end
      it_should_behave_like 'immutable once shipped'
      it_should_behave_like 'pending if backordered'
    end

    context "when order has a credit owed" do
      before { order.stub payment_state: 'credit_owed', paid?: true }
      it "should result in a 'ready' state" do
        shipment.state = 'pending'
        shipment.should_receive(:update_columns).with(state: 'ready', updated_at: kind_of(Time))
        shipment.update!(order)
      end
      it_should_behave_like 'immutable once shipped'
      it_should_behave_like 'pending if backordered'
    end

    context "when shipment state changes to shipped" do
      it "should call after_ship" do
        shipment.state = 'pending'
        shipment.should_receive :after_ship
        shipment.stub determine_state: 'shipped'
        shipment.should_receive(:update_columns).with(state: 'shipped', updated_at: kind_of(Time))
        shipment.update!(order)
      end

      # Regression test for #4347
      context "with adjustments" do
        before do
          shipment.adjustments << Spree::Adjustment.create(order: order, label: "Label", amount: 5)
        end

        it "transitions to shipped" do
          shipment.update_column(:state, "ready")
          lambda { shipment.ship! }.should_not raise_error
        end
      end
    end
  end

  context "when order is completed" do
    after { Spree::Config.set track_inventory_levels: true }

    before do
      order.stub completed?: true
      order.stub canceled?: false
    end

    context "with inventory tracking" do
      before { Spree::Config.set track_inventory_levels: true }

      it "should validate with inventory" do
        shipment.inventory_units = [create(:inventory_unit)]
        shipment.valid?.should be true
      end
    end

    context "without inventory tracking" do
      before { Spree::Config.set track_inventory_levels: false }

      it "should validate with no inventory" do
        shipment.valid?.should be true
      end
    end
  end

  context "#cancel" do
    it 'cancels the shipment' do
      shipment.order.stub(:update!)

      shipment.state = 'pending'
      shipment.should_receive(:after_cancel)
      shipment.cancel!
      shipment.state.should eq 'canceled'
    end

    it 'restocks the items' do
      variant = shipment.inventory_units.first.variant
      shipment.stock_location = mock_model(Spree::StockLocation)
      shipment.stock_location.should_receive(:restock).with(variant, 1, shipment)
      shipment.after_cancel
    end

    context "with backordered inventory units" do
      let(:order) { create(:order) }
      let(:variant) { create(:variant) }
      let(:other_order) { create(:order) }

      before do
        order.contents.add variant
        order.create_proposed_shipments

        other_order.contents.add variant
        other_order.create_proposed_shipments
      end

      it "doesn't fill backorders when restocking inventory units" do
        shipment = order.shipments.first
        expect(shipment.inventory_units.count).to eq 1
        expect(shipment.inventory_units.first).to be_backordered

        other_shipment = other_order.shipments.first
        expect(other_shipment.inventory_units.count).to eq 1
        expect(other_shipment.inventory_units.first).to be_backordered

        expect {
          shipment.cancel!
        }.not_to change { other_shipment.inventory_units.first.state }
      end
    end
  end

  context "#resume" do
    let(:inventory_unit) { create(:inventory_unit) }

    before { shipment.state = 'canceled' }

    context "when order cannot ship" do
      before { order.stub(can_ship?: false) }
      it "should result in a 'pending' state" do
        shipment.resume!
        shipment.state.should eq 'pending'
      end
    end

    context "when order is not paid" do
      before { order.stub(paid?: false) }
      it "should result in a 'ready' state" do
        shipment.resume!
        shipment.state.should eq 'pending'
      end
    end

    context "when any inventory is backordered" do
      before { allow_any_instance_of(Spree::InventoryUnit).to receive(:backordered?).and_return(true) }
      it "should result in a 'ready' state" do
        shipment.resume!
        shipment.state.should eq 'pending'
      end
    end

    context "when the order is paid, shippable, and not backordered" do
      before do
        order.stub(can_ship?: true)
        order.stub(paid?: true)
        allow_any_instance_of(Spree::InventoryUnit).to receive(:backordered?).and_return(false)
      end

      it "should result in a 'ready' state" do
        shipment.resume!
        shipment.state.should eq 'ready'
      end
    end

    it 'unstocks them items' do
      variant = shipment.inventory_units.first.variant
      shipment.stock_location = mock_model(Spree::StockLocation)
      shipment.stock_location.should_receive(:unstock).with(variant, 1, shipment)
      shipment.after_resume
    end
  end

  context "#ship" do
    context "when the shipment is canceled" do
      let(:shipment_with_inventory_units) do
        create(
          :shipment,
          order: create(:order_with_line_items, line_items_count: 2),
          state: 'canceled',
        )
      end
      let(:subject) { shipment_with_inventory_units.ship! }
      before do
        order.stub(:update!)
        shipment_with_inventory_units.stub(require_inventory: false, update_order: true)
      end

      it 'unstocks them items' do
        shipment_with_inventory_units.stock_location.should_receive(:unstock).exactly(2).times
        subject
      end
    end

    ['ready', 'canceled'].each do |state|
      context "from #{state}" do
        before do
          order.stub(:update!)
          shipment.stub(require_inventory: false, update_order: true, state: state)
        end

        it "should call fulfill_order_with_stock_location" do
          expect(Spree::OrderStockLocation).to(
            receive(:fulfill_for_order_with_stock_location).
            with(order, stock_location)
          )
          shipment.ship!
        end

        it "finalizes adjustments" do
          shipment.adjustments.each do |adjustment|
            expect(adjustment).to receive(:finalize!)
          end
          shipment.ship!
        end
      end
    end
  end

  context "#ready" do
    # Regression test for #2040
    it "cannot ready a shipment for an order if the order is unpaid" do
      order.stub(paid?: false)
      assert !shipment.can_ready?
    end
  end

  context "updates cost when selected shipping rate is present" do
    let(:shipment) { create(:shipment) }

    before { shipment.stub_chain :selected_shipping_rate, cost: 5 }

    it "updates shipment totals" do
      shipment.update_amounts
      shipment.reload.cost.should == 5
    end

    it "factors in additional adjustments to adjustment total" do
      shipment.adjustments.create!(
        order:    order,
        label:    "Additional",
        amount:   5,
        included: false,
        state:    "closed"
      )
      shipment.update_amounts
      shipment.reload.adjustment_total.should == 5
    end

    it "does not factor in included adjustments to adjustment total" do
      shipment.adjustments.create!(
        order:    order,
        label:    "Included",
        amount:   5,
        included: true,
        state:    "closed"
      )
      shipment.update_amounts
      shipment.reload.adjustment_total.should == 0
    end
  end

  context "after_save" do
    context "line item changes" do
      before do
        shipment.cost = shipment.cost + 10
      end

      it "triggers adjustment total recalculation" do
        shipment.should_receive(:recalculate_adjustments)
        shipment.save
      end

      it "does not trigger adjustment recalculation if shipment has shipped" do
        shipment.state = 'shipped'
        shipment.should_not_receive(:recalculate_adjustments)
        shipment.save
      end
    end

    context "line item does not change" do
      it "does not trigger adjustment total recalculation" do
        shipment.should_not_receive(:recalculate_adjustments)
        shipment.save
      end
    end
  end

  context "currency" do
    it "returns the order currency" do
      shipment.currency.should == order.currency
    end
  end

  context "nil costs" do
    it "sets cost to 0" do
      shipment = Spree::Shipment.new
      shipment.valid?
      expect(shipment.cost).to eq 0
    end
  end

  context "#tracking_url" do
    subject do
      shipment.tracking_url
    end

    before do
      shipping_method.update!(tracking_url: "https://example.com/:tracking")
      shipment.tracking = '1Z12345'
    end

    it "uses shipping method to determine url" do
      is_expected.to eq("https://example.com/1Z12345")
    end
  end

  context "set up new inventory units" do
    # let(:line_item) { double(
    let(:variant) { double("Variant", id: 9) }

    let(:inventory_units) { double }

    let(:params) do
      { variant_id: variant.id, state: 'on_hand', order_id: order.id, line_item_id: line_item.id }
    end

    before { shipment.stub inventory_units: inventory_units }

    it "associates variant and order" do
      expect(inventory_units).to receive(:create).with(params)
      unit = shipment.set_up_inventory('on_hand', variant, order, line_item)
    end
  end

  # Regression test for #3349
  context "#destroy" do
    it "destroys linked shipping_rates" do
      reflection = Spree::Shipment.reflect_on_association(:shipping_rates)
      reflection.options[:dependent] = :destroy
    end
  end

  # Regression test for #4072 (kinda)
  # The need for this was discovered in the research for #4702
  context "state changes" do
    before do
      # Must be stubbed so transition can succeed
      order.stub :paid? => true
    end

    it "are logged to the database" do
      shipment.state_changes.should be_empty
      expect(shipment.ready!).to be true
      shipment.state_changes.count.should == 1
      state_change = shipment.state_changes.first
      expect(state_change.previous_state).to eq('pending')
      expect(state_change.next_state).to eq('ready')
    end
  end

  context "don't require shipment" do
    let(:stock_location) { create(:stock_location, fulfillable: false)}
    let(:unshippable_shipment) do
      create(
        :shipment,
        stock_location: stock_location,
        inventory_units: [build(:inventory_unit)],
      )
    end

    before { order.stub paid?: true }

    it 'proceeds automatically to shipped state' do
      unshippable_shipment.ready!
      expect(unshippable_shipment.state).to eq('shipped')
    end

    it 'does not send a confirmation email' do
      expect(unshippable_shipment).to_not receive(:send_shipment_email)
      unshippable_shipment.ready!
      unshippable_shipment.inventory_units.each do |unit|
        expect(unit.state).to eq('shipped')
      end
    end
  end
end
