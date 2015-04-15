require "spec_helper"

module Spree::Promotion::Actions
  RSpec.describe CreateQuantityAdjustments do
    let(:action) { CreateQuantityAdjustments.create!(calculator: calculator, promotion: promotion) }

    let(:payload) { Hash[order: order, promotion: promotion] }
    let(:order) { FactoryGirl.create :order }
    let(:promotion) { FactoryGirl.create :promotion }

    let(:calculator) { FactoryGirl.create :calculator, preferred_amount: 5 }

    describe "#perform" do
      subject { action.perform(payload) }

      let!(:item_a) { FactoryGirl.create :line_item, order: order, quantity: quantity }

      context "with a quantity group of 2" do
        before { action.preferred_group_size = 2 }
        context "and an item with a quantity of 0" do
          let(:quantity) { 0 }
          it { is_expected.to be_falsy }
          it "does not create any adjustments" do
            expect { subject }.not_to change{ action.adjustments.count }
          end
        end
        context "and an item with a quantity of 1" do
          let(:quantity) { 1 }
          it { is_expected.to be_falsy }
          it "does not create any adjustments" do
            expect { subject }.not_to change{ action.adjustments.count }
          end
        end
        context "and an item with a quantity of 2" do
          let(:quantity) { 2 }
          it { is_expected.to be_truthy }
          it "creates a discount of $10" do
            expect {
              subject
            }.to change{ action.adjustments.sum(:amount) }.by(-10)
          end
        end
        context "and an item with a quantity of 3" do
          let(:quantity) { 3 }
          it { is_expected.to be_truthy }
          it "creates a discount of $10" do
            expect {
              subject
            }.to change{ action.adjustments.sum(:amount) }.by(-10)
          end
        end
        context "and an item with a quantity of 4" do
          let(:quantity) { 4 }
          it { is_expected.to be_truthy }
          it "creates a discount of $20" do
            expect {
              subject
            }.to change{ action.adjustments.sum(:amount) }.by(-20)
          end
        end
      end

      context "with a quantity group of 3" do
        let(:quantity) { 2 }
        before do
          action.preferred_group_size = 3

          FactoryGirl.create_list :line_item, 2, order: order, quantity: 1
        end
        context "and 2x item A, 1x item B and 1x item C" do
          it { is_expected.to be_truthy }
          it "creates a total discount of $15" do
            expect {
              subject
            }.to change{ action.adjustments.sum(:amount) }.by(-15)
          end
        end
      end

      context "with multiple orders using the same action" do
        let(:quantity) { 2 }

        before do
          action.preferred_group_size = 2

          other_order = FactoryGirl.create :order
          FactoryGirl.create :line_item, order: other_order, quantity: 3

          action.perform({ order: other_order, promotion: promotion })
        end

        it { is_expected.to be_truthy }
        it "creates a discount of $10" do
          expect {
            subject
          }.to change{ action.adjustments.sum(:amount) }.by(-10)
        end
      end
    end
  end
end
