require 'spec_helper'

module Spree
  module Admin
    describe PaymentsController do
      before do
        controller.stub :spree_current_user => user
      end

      let(:user) { create(:admin_user) }
      let(:order) { create(:order) }

      context "with a valid credit card" do
        let(:order) { create(:order_with_line_items, :state => "payment") }
        let(:payment_method) { create(:credit_card_payment_method, :display_on => "back_end") }

        before do
          attributes = {
            :order_id => order.number,
            :card => "new",
            :payment => {
              :amount => order.total,
              :payment_method_id => payment_method.id.to_s,
              :source_attributes => {
                :name => "Test User",
                :number => "4111 1111 1111 1111",
                :expiry => "09 / #{Time.now.year + 1}",
                :verification_value => "123"
              }
            }
          }
          spree_post :create, attributes
        end

        it "should create payments correctly" do
          order.payments.count.should == 1
          expect(order.payments.last.state).to eq 'checkout'
          expect(response).to redirect_to(spree.admin_order_payments_path(order))
          expect(order.reload.state).to eq('confirm')
        end
      end

      # Regression test for #3233
      context "with a backend payment method" do
        before do
          @payment_method = create(:check_payment_method, :display_on => "back_end")
        end

        it "loads backend payment methods" do
          spree_get :new, :order_id => order.number
          response.status.should == 200
          assigns[:payment_methods].should include(@payment_method)
        end
      end

      context "order has billing address" do
        before do
          order.bill_address = create(:address)
          order.save!
        end

        context "order does not have payments" do
          it "redirect to new payments page" do
            spree_get :index, { amount: 100, order_id: order.number }
            response.should redirect_to(spree.new_admin_order_payment_path(order))
          end
        end

        context "order has payments" do
          before do
            order.payments << create(:payment, amount: order.total, order: order, state: 'completed')
          end

          it "shows the payments page" do
            spree_get :index, { amount: 100, order_id: order.number }
            expect(response.code).to eq "200"
          end
        end

      end

      context "order does not have a billing address" do
        before do
          order.bill_address = nil
          order.save
        end

        it "should redirect to the customer details page" do
          spree_get :index, { amount: 100, order_id: order.number }
          expect(response).to redirect_to(spree.edit_admin_order_customer_path(order))
        end
      end

      describe 'fire' do
        describe 'authorization' do
          let(:payment) { create(:payment, state: 'checkout') }
          let(:order) { payment.order }

          context 'the user is authorized' do
            class CaptureAllowedAbility
              include CanCan::Ability

              def initialize(user)
                can :capture, Spree::Payment
              end
            end

            before do
              Spree::Ability.register_ability(CaptureAllowedAbility)
            end

            it 'allows the action' do
              expect {
                spree_post(:fire, id: payment.to_param, e: 'capture', order_id: order.to_param)
              }.to change { payment.reload.state }.from('checkout').to('completed')
            end
          end

          context 'the user is not authorized' do
            class CaptureNotAllowedAbility
              include CanCan::Ability

              def initialize(user)
                cannot :capture, Spree::Payment
              end
            end

            before do
              Spree::Ability.register_ability(CaptureNotAllowedAbility)
            end

            it 'does not allow the action' do
              expect {
                spree_post(:fire, id: payment.to_param, e: 'capture', order_id: order.to_param)
              }.to_not change { payment.reload.state }
              expect(flash[:error]).to eq('Authorization Failure')
            end
          end
        end
      end

    end
  end
end
