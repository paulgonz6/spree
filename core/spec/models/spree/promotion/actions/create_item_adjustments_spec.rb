require 'spec_helper'

module Spree
  class Promotion
    module Actions
      describe CreateItemAdjustments do
        let(:order) { create(:order) }
        let(:promotion) { create(:promotion) }
        let(:action) { CreateItemAdjustments.new }
        let!(:line_item) { create(:line_item, :order => order) }
        let(:payload) { { order: order, promotion: promotion } }

        before do
          allow(action).to receive(:promotion).and_return(promotion)
          promotion.promotion_actions = [action]
        end

        context "#perform" do
          # Regression test for #3966
          context "when calculator computes 0" do
            before do
              action.stub :compute_amount => 0
            end

            it "does not create an adjustment when calculator returns 0" do
              action.perform(payload)
              action.adjustments.should be_empty
            end
          end

          context "when calculator returns a non-zero value" do
            before do
              promotion.promotion_actions = [action]
              action.stub :compute_amount => 10
            end

            it "creates adjustment with item as adjustable" do
              action.perform(payload)
              action.adjustments.count.should == 1
              line_item.reload.adjustments.should == action.adjustments
            end

            it "creates adjustment with self as source" do
              action.perform(payload)
              expect(line_item.reload.adjustments.first.source).to eq action
            end

            it "does not perform twice on the same item" do
              2.times { action.perform(payload) }
              action.adjustments.count.should == 1
            end

            context "with products rules" do
              let(:rule) { double Spree::Promotion::Rules::Product }

              before { promotion.stub(:eligible_rules) { [rule] } }

              context "when the rule is actionable" do
                before { rule.stub(:actionable?).and_return(true) }

                it "creates an adjustment" do
                  expect {
                    expect {
                      action.perform(payload)
                    }.to change { action.adjustments.count }.by(1)
                  }.to change { line_item.adjustments.count }.by(1)

                  expect(action.adjustments.last).to eq line_item.adjustments.last
                end
              end

              context "when the rule is not actionable" do
                before { rule.stub(:actionable?).and_return(false) }

                it "does not create an adjustment" do
                  expect {
                    expect {
                      action.perform(payload)
                    }.to_not change { action.adjustments.count }
                  }.to_not change { line_item.adjustments.count }
                end
              end
            end

            context "when a promotion code is used" do
              let(:promotion_code) { create(:promotion_code) }
              let(:promotion) { promotion_code.promotion }
              let(:payload) { { order: order, promotion: promotion, promotion_code: promotion_code } }

              it "should connect the adjustment to the promotion_code" do
                expect {
                  action.perform(payload)
                }.to change { line_item.adjustments.count }.by(1)
                expect(line_item.adjustments.last.promotion_code).to eq promotion_code
              end
            end
          end
        end

        context "#compute_amount" do
          before { promotion.promotion_actions = [action] }

          it "calls compute on the calculator" do
            action.calculator.should_receive(:compute).with(line_item)
            action.compute_amount(line_item)
          end

          context "calculator returns amount greater than item total" do
            before do
              action.calculator.should_receive(:compute).with(line_item).and_return(300)
              line_item.stub(amount: 100)
            end

            it "does not exceed it" do
              action.compute_amount(line_item).should eql(-100)
            end
          end
        end

        context "#destroy" do
          let!(:action) { promotion.actions.first }
          let(:other_action) { other_promotion.actions.first }
          let(:promotion) { create(:promotion, :with_line_item_adjustment) }
          let(:other_promotion) { create(:promotion, :with_line_item_adjustment) }

          it "destroys adjustments for incompleted orders" do
            order = Order.create
            action.adjustments.create!(label: "Check", amount: 0, order: order, adjustable: order)

            expect {
              action.destroy
            }.to change { Adjustment.count }.by(-1)
          end

          it "nullifies adjustments for completed orders" do
            order = Order.create(completed_at: Time.now)
            adjustment = action.adjustments.create!(label: "Check", amount: 0, order: order, adjustable: order)

            expect {
              action.destroy
            }.to change { adjustment.reload.source_id }.from(action.id).to nil
          end

          it "doesnt mess with unrelated adjustments" do
            other_action.adjustments.create!(label: "Check", amount: 0, order: order, adjustable: order)

            expect {
              action.destroy
            }.not_to change { other_action.adjustments.count }
          end
        end
      end
    end
  end
end
