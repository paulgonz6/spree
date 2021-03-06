require 'spec_helper'
require 'spree/testing_support/order_walkthrough'

describe Spree::Order do
  let(:order) { Spree::Order.new }

  def assert_state_changed(order, from, to)
    state_change_exists = order.state_changes.where(:previous_state => from, :next_state => to).exists?
    assert state_change_exists, "Expected order to transition from #{from} to #{to}, but didn't."
  end

  context "with default state machine" do
    transitions = [
      { :address => :delivery },
      { :delivery => :payment },
      { :payment => :confirm },
      { :delivery => :confirm },
    ]

    transitions.each do |transition|
      it "transitions from #{transition.keys.first} to #{transition.values.first}" do
        transition = Spree::Order.find_transition(:from => transition.keys.first, :to => transition.values.first)
        transition.should_not be_nil
      end
    end

    it '.find_transition when contract was broken' do
      expect(Spree::Order.find_transition({foo: :bar, baz: :dog})).to be_falsey
    end

    it '.remove_transition' do
      options = {:from => transitions.first.keys.first, :to => transitions.first.values.first}
      Spree::Order.stub(:next_event_transition).and_return([options])
      Spree::Order.remove_transition(options).should be_truthy
    end

    it '.remove_transition when contract was broken' do
      expect(Spree::Order.remove_transition(nil)).to be_falsey
    end

    context "#checkout_steps" do
      context "when payment not required" do
        before { order.stub :payment_required? => false }
        specify do
          order.checkout_steps.should == %w(address delivery confirm complete)
        end
      end

      context "when payment required" do
        before { order.stub :payment_required? => true }
        specify do
          order.checkout_steps.should == %w(address delivery payment confirm complete)
        end
      end
    end

    it "starts out at cart" do
      order.state.should == "cart"
    end

    context "to address" do
      before do
        order.email = "user@example.com"
        order.save!
      end

      context "with a line item" do
        before do
          order.line_items << FactoryGirl.create(:line_item)
        end

        it "transitions to address" do
          order.next!
          assert_state_changed(order, 'cart', 'address')
          order.state.should == "address"
        end

        it "doesn't raise an error if the default address is invalid" do
          order.user = mock_model(Spree::LegacyUser, ship_address: Spree::Address.new, bill_address: Spree::Address.new)
          expect { order.next! }.to_not raise_error
        end

        context "with default addresses" do
          let(:default_address) { FactoryGirl.create(:address) }

          before do
            order.user = FactoryGirl.create(:user, "#{address_kind}_address" => default_address)
            order.next!
            order.reload
          end

          shared_examples "it cloned the default address" do
            it do
              default_attributes = default_address.attributes
              order_attributes = order.send("#{address_kind}_address".to_sym).try(:attributes) || {}

              order_attributes.except('id', 'created_at', 'updated_at').should eql(default_attributes.except('id', 'created_at', 'updated_at'))
            end
          end

          it_behaves_like "it cloned the default address" do
            let(:address_kind) { 'ship' }
          end

          it_behaves_like "it cloned the default address" do
            let(:address_kind) { 'bill' }
          end
        end
      end

      it "cannot transition to address without any line items" do
        order.line_items.should be_blank
        lambda { order.next! }.should raise_error(StateMachine::InvalidTransition, /#{Spree.t(:there_are_no_items_for_this_order)}/)
      end
    end

    context "from address" do
      let(:ship_address) { FactoryGirl.create(:ship_address) }

      before do
        order.state = 'address'
        order.ship_address = ship_address
        order.stub(:has_available_payment)
        shipment = FactoryGirl.create(:shipment, :order => order)
        order.email = "user@example.com"
        order.save!
      end

      context "no shipping address" do
        let(:ship_address) { nil }

        it "does not transition without a ship address" do
          expect { order.next! }.to raise_error
        end
      end

      it "updates totals" do
        order.stub(:ensure_available_shipping_rates => true)
        line_item = FactoryGirl.create(:line_item, :price => 10, :adjustment_total => 10)
        order.line_items << line_item
        tax_rate = create(:tax_rate, :tax_category => line_item.tax_category, :amount => 0.05)
        FactoryGirl.create(:tax_adjustment, :adjustable => line_item, :source => tax_rate, order: order)
        order.email = "user@example.com"
        order.next!
        order.adjustment_total.should == 0.5
        order.additional_tax_total.should == 0.5
        order.included_tax_total.should == 0
        order.shipment_total.should == 10
        order.total.should == 20.5
      end

      it "transitions to delivery" do
        order.stub(:ensure_available_shipping_rates => true)
        order.next!
        assert_state_changed(order, 'address', 'delivery')
        order.state.should == "delivery"
      end

      it "does not call persist_order_address if there is no address on the order" do
        # otherwise, it will crash
        order.stub(:ensure_available_shipping_rates => true)

        order.user = FactoryGirl.create(:user)
        order.save!

        expect(order.user).to_not receive(:persist_order_address).with(order)
        order.next!
      end

      it "calls persist_order_address on the order's user" do
        order.stub(:ensure_available_shipping_rates => true)

        order.user = FactoryGirl.create(:user)
        order.ship_address = FactoryGirl.create(:address)
        order.bill_address = FactoryGirl.create(:address)
        order.save!

        expect(order.user).to receive(:persist_order_address).with(order)
        order.next!
      end

      it "does not call persist_order_address on the order's user for a temporary address" do
        order.stub(:ensure_available_shipping_rates => true)

        order.user = FactoryGirl.create(:user)
        order.temporary_address = true
        order.save!

        expect(order.user).to_not receive(:persist_order_address)
        order.next!
      end
    end

    context "from delivery" do
      before do
        order.state = 'delivery'
        order.stub(:apply_free_shipping_promotions)
      end

      it "attempts to apply free shipping promotions" do
        order.should_receive(:apply_free_shipping_promotions)
        order.next!
      end

      context "with payment required" do
        before do
          order.stub :payment_required? => true
        end

        it "transitions to payment" do
          order.should_receive(:set_shipments_cost)
          order.next!
          assert_state_changed(order, 'delivery', 'payment')
          order.state.should == 'payment'
        end
      end

      context "without payment required" do
        before do
          order.stub :payment_required? => false
        end

        it "transitions to complete" do
          order.next!
          assert_state_changed(order, 'delivery', 'confirm')
          order.state.should == "confirm"
        end
      end

      context "correctly determining payment required based on shipping information" do
        let(:shipment) do
          FactoryGirl.create(:shipment)
        end

        before do
          # Needs to be set here because we're working with a persisted order object
          order.email = "test@example.com"
          order.save!
          order.shipments << shipment
        end

        context "with a shipment that has a price" do
          before do
            shipment.shipping_rates.first.update_column(:cost, 10)
          end

          it "transitions to payment" do
            order.next!
            order.state.should == "payment"
          end
        end

        context "with a shipment that is free" do
          before do
            shipment.shipping_rates.first.update_column(:cost, 0)
          end

          it "skips payment, transitions to confirm" do
            order.next!
            order.state.should == "confirm"
          end
        end
      end
    end

    context "to payment" do
      before do
        @default_credit_card = FactoryGirl.create(:credit_card)
        order.user = mock_model(Spree::LegacyUser, default_credit_card: @default_credit_card, email: 'spree@example.org')

        order.stub(payment_required?: true)
        order.state = 'delivery'
        order.save!
      end

      it "assigns the user's default credit card" do
        order.next!
        order.reload

        expect(order.state).to eq 'payment'
        expect(order.payments.count).to eq 1
        expect(order.payments.first.source).to eq @default_credit_card
      end
    end

    context "from payment" do
      before do
        order.state = 'payment'
      end

      it "transitions to confirm" do
        order.next!
        assert_state_changed(order, 'payment', 'confirm')
        order.state.should == "confirm"
      end

      # Regression test for #2028
      context "when payment is not required" do
        before do
          order.stub :payment_required? => false
        end

        it "does not call process payments" do
          order.should_not_receive(:process_payments!)
          order.next!
          assert_state_changed(order, 'payment', 'confirm')
          order.state.should == "confirm"
        end
      end
    end
  end

  context "to complete" do
    before do
      order.state = 'confirm'
      order.save!
    end

    context "out of stock" do
      before do
        order.user = FactoryGirl.create(:user)
        order.email = 'spree@example.org'
        order.payments << FactoryGirl.create(:payment)
        order.stub(payment_required?: true)
        order.line_items << FactoryGirl.create(:line_item)
        order.line_items.first.variant.stock_items.each do |si|
          si.set_count_on_hand(0)
          si.update_attributes(:backorderable => false)
        end

        Spree::OrderUpdater.new(order).update
        order.save!
      end

      it "does not allow the order to complete" do
        expect {
          order.complete!
        }.to raise_error Spree::LineItem::InsufficientStock

        expect(order.state).to eq 'confirm'
        expect(order.line_items.first.errors[:quantity]).to be_present
      end
    end

    context "no inventory units" do
      before do
        order.user = FactoryGirl.create(:user)
        order.email = 'spree@example.com'
        order.payments << FactoryGirl.create(:payment)
        order.stub(payment_required?: true)
        order.line_items << FactoryGirl.create(:line_item)

        Spree::OrderUpdater.new(order).update
        order.save!
      end

      it "does not allow order to complete" do
        expect { order.complete! }.to raise_error Spree::LineItem::InsufficientStock

        expect(order.state).to eq 'confirm'
        expect(order.line_items.first.errors[:inventory]).to be_present
      end
    end

    context "exchange order completion" do
      before do
        order.email = 'spree@example.org'
        order.payments << FactoryGirl.create(:payment)
        order.shipments.create!
        order.stub(payment_required?: true)
        order.stub(:ensure_available_shipping_rates).and_return(true)
      end

      context 'when the line items are not available' do
        before do
          order.line_items << FactoryGirl.create(:line_item)
          Spree::OrderUpdater.new(order).update

          order.save!
        end

        context 'when the exchange is for an unreturned item' do
          before do
            order.shipments.first.update_attributes!(created_at: order.created_at - 1.day)
            expect(order.unreturned_exchange?).to eq true
          end

          it 'allows the order to complete' do
            order.complete!

            expect(order).to be_complete
          end
        end

        context 'when the exchange is not for an unreturned item' do
          it 'does not allow the order to completed' do
            expect { order.complete! }.to raise_error  Spree::LineItem::InsufficientStock
          end
        end
      end
    end

    context "default credit card" do
      before do
        order.user = FactoryGirl.create(:user)
        order.email = 'spree@example.org'
        order.payments << FactoryGirl.create(:payment)

        # make sure we will actually capture a payment
        order.stub(payment_required?: true)
        order.stub(ensure_available_shipping_rates: true)
        order.line_items << FactoryGirl.create(:line_item)
        order.line_items.each { |li| li.inventory_units.create! }
        Spree::OrderUpdater.new(order).update

        order.save!
      end

      it "makes the current credit card a user's default credit card" do
        order.complete!
        expect(order.state).to eq 'complete'
        expect(order.user.reload.default_credit_card.try(:id)).to eq(order.credit_cards.first.id)
      end

      it "does not assign a default credit card if temporary_credit_card is set" do
        order.temporary_credit_card = true
        order.complete!
        expect(order.user.reload.default_credit_card).to be_nil
      end
    end

    context "a payment fails during processing" do
      before do
        order.user = FactoryGirl.create(:user)
        order.email = 'spree@example.org'
        payment = FactoryGirl.create(:payment)
        payment.stub(:process!).and_raise(Spree::Core::GatewayError.new('processing failed'))
        order.line_items.each { |li| li.inventory_units.create! }
        order.payments << payment

        # make sure we will actually capture a payment
        order.stub(payment_required?: true)
        order.stub(ensure_available_shipping_rates: true)
        order.line_items << FactoryGirl.create(:line_item)
        order.line_items.each { |li| li.inventory_units.create! }
        Spree::OrderUpdater.new(order).update
      end

      it "transitions to the payment state" do
        expect { order.complete! }.to raise_error StateMachine::InvalidTransition
        expect(order.reload.state).to eq 'payment'
      end
    end
  end

  context "subclassed order" do
    # This causes another test above to fail, but fixing this test should make
    #   the other test pass
    class SubclassedOrder < Spree::Order
      checkout_flow do
        go_to_state :payment
        go_to_state :complete
      end
    end

    skip "should only call default transitions once when checkout_flow is redefined" do
      order = SubclassedOrder.new
      order.stub :payment_required? => true
      order.should_receive(:process_payments!).once
      order.state = "payment"
      order.next!
      assert_state_changed(order, 'payment', 'complete')
      order.state.should == "complete"
    end
  end

  context "re-define checkout flow" do
    before do
      @old_checkout_flow = Spree::Order.checkout_flow
      Spree::Order.class_eval do
        checkout_flow do
          go_to_state :payment
          go_to_state :complete
        end
      end
    end

    after do
      Spree::Order.checkout_flow(&@old_checkout_flow)
    end

    it "should not keep old event transitions when checkout_flow is redefined" do
      Spree::Order.next_event_transitions.should == [{:cart=>:payment}, {:payment=>:complete}]
    end

    it "should not keep old events when checkout_flow is redefined" do
      state_machine = Spree::Order.state_machine
      state_machine.states.any? { |s| s.name == :address }.should be false
      known_states = state_machine.events[:next].branches.map(&:known_states).flatten
      known_states.should_not include(:address)
      known_states.should_not include(:delivery)
      known_states.should_not include(:confirm)
    end
  end

  # Regression test for #3665
  context "with only a complete step" do
    before do
      @old_checkout_flow = Spree::Order.checkout_flow
      Spree::Order.class_eval do
        checkout_flow do
          go_to_state :complete
        end
      end
    end

    after do
      Spree::Order.checkout_flow(&@old_checkout_flow)
    end

    it "does not attempt to process payments" do
      order.stub(:ensure_available_shipping_rates).and_return(true)
      order.stub_chain(:line_items, :present?).and_return(true)
      order.stub_chain(:line_items, :map).and_return([])
      order.should_not_receive(:payment_required?)
      order.should_not_receive(:process_payments!)
      order.next!
      assert_state_changed(order, 'cart', 'complete')
    end

  end

  context "insert checkout step" do
    before do
      @old_checkout_flow = Spree::Order.checkout_flow
      Spree::Order.class_eval do
        remove_transition from: :delivery, to: :confirm
      end
      Spree::Order.class_eval do
        insert_checkout_step :new_step, before: :address
      end
    end

    after do
      Spree::Order.checkout_flow(&@old_checkout_flow)
    end

    it "should maintain removed transitions" do
      transition = Spree::Order.find_transition(:from => :delivery, :to => :confirm)
      transition.should be_nil
    end

    context "before" do
      before do
        Spree::Order.class_eval do
          insert_checkout_step :before_address, before: :address
        end
      end

      specify do
        order = Spree::Order.new
        order.checkout_steps.should == %w(new_step before_address address delivery confirm complete)
      end
    end

    context "after" do
      before do
        Spree::Order.class_eval do
          insert_checkout_step :after_address, after: :address
        end
      end

      specify do
        order = Spree::Order.new
        order.checkout_steps.should == %w(new_step address after_address delivery confirm complete)
      end
    end
  end

  context "remove checkout step" do
    before do
      @old_checkout_flow = Spree::Order.checkout_flow
      Spree::Order.class_eval do
        remove_transition from: :delivery, to: :confirm
      end
      Spree::Order.class_eval do
        remove_checkout_step :address
      end
    end

    after do
      Spree::Order.checkout_flow(&@old_checkout_flow)
    end

    it "should maintain removed transitions" do
      transition = Spree::Order.find_transition(:from => :delivery, :to => :confirm)
      transition.should be_nil
    end

    specify do
      order = Spree::Order.new
      order.checkout_steps.should == %w(delivery confirm complete)
    end
  end

  describe "payment processing" do
    # Turn off transactional fixtures so that we can test that
    # processing state is persisted.
    self.use_transactional_fixtures = false
    before(:all) { DatabaseCleaner.strategy = :truncation }
    after(:all) do
      DatabaseCleaner.clean
      DatabaseCleaner.strategy = :transaction
    end
    let(:order) { OrderWalkthrough.up_to(:payment) }
    let(:creditcard) { create(:credit_card) }
    let!(:payment_method) { create(:credit_card_payment_method, :environment => 'test') }

    it "does not process payment within transaction" do
      # Make sure we are not already in a transaction
      ActiveRecord::Base.connection.open_transactions.should == 0

      Spree::Payment.any_instance.should_receive(:authorize!) do
        ActiveRecord::Base.connection.open_transactions.should == 0
      end

      order.payments.create!({ :amount => order.outstanding_balance, :payment_method => payment_method, :source => creditcard })
      order.complete!
    end
  end

  describe 'update_from_params' do
    let(:permitted_params) { {} }
    let(:params) { {} }
    it 'calls update_atributes without order params' do
      order.should_receive(:update_attributes).with({})
      order.update_from_params( params, permitted_params)
    end

    it 'runs the callbacks' do
      order.should_receive(:run_callbacks).with(:updating_from_params)
      order.update_from_params( params, permitted_params)
    end

    context "passing a credit card" do
      let(:permitted_params) do
        Spree::PermittedAttributes.checkout_attributes +
          [payments_attributes: Spree::PermittedAttributes.payment_attributes]
      end

      let(:credit_card) { create(:credit_card, user_id: order.user_id) }

      let(:params) do
        ActionController::Parameters.new(
          order: { payments_attributes: [{payment_method_id: 1}] },
          existing_card: credit_card.id,
          payment_source: {
            "1" => { name: "Luis Braga",
                     number: "4111 1111 1111 1111",
                     expiry: "06 / 2016",
                     verification_value: "737",
                     cc_type: "" }
          }
        )
      end

      before { order.user_id = 3 }

      it "sets existing card as source for new payment" do
        expect {
          order.update_from_params(params, permitted_params)
        }.to change { Spree::Payment.count }.by(1)

        expect(Spree::Payment.last.source).to eq credit_card
      end

      it "dont let users mess with others users cards" do
        credit_card.update_column :user_id, 5

        expect {
          order.update_from_params(params, permitted_params)
        }.to raise_error
      end
    end

    context 'has params' do
      let(:permitted_params) { [ :good_param ] }
      let(:params) { ActionController::Parameters.new(order: {  bad_param: 'okay' } ) }

      it 'does not let through unpermitted attributes' do
        order.should_receive(:update_attributes).with({})
        order.update_from_params(params, permitted_params)
      end

      context 'has allowed params' do
        let(:params) { ActionController::Parameters.new(order: {  good_param: 'okay' } ) }

        it 'accepts permitted attributes' do
          order.should_receive(:update_attributes).with({"good_param" => 'okay'})
          order.update_from_params(params, permitted_params)
        end
      end

      context 'callbacks halt' do
        before do
          order.should_receive(:update_params_payment_source).and_return false
        end
        it 'does not let through unpermitted attributes' do
          order.should_not_receive(:update_attributes).with({})
          order.update_from_params(params, permitted_params)
        end
      end
    end
  end
end
