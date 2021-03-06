# encoding: utf-8
#

require 'spec_helper'

describe Spree::Adjustment do

  let(:order) { Spree::Order.new }

  before do
    allow(order).to receive(:update!)
  end

  let(:adjustment) { Spree::Adjustment.create!(label: 'Adjustment', adjustable: order, order: order, amount: 5) }

  describe 'non_tax scope' do
    subject do
      Spree::Adjustment.non_tax.to_a
    end

    let!(:tax_adjustment) { create(:adjustment, order: order, source: create(:tax_rate))                   }
    let!(:non_tax_adjustment_with_source) { create(:adjustment, order: order, source_type: 'Spree::Order', source_id: nil) }
    let!(:non_tax_adjustment_without_source) { create(:adjustment, order: order, source: nil)                                 }

    it 'select non-tax adjustments' do
      expect(subject).to_not include tax_adjustment
      expect(subject).to     include non_tax_adjustment_with_source
      expect(subject).to     include non_tax_adjustment_without_source
    end
  end

  context "adjustment state" do
    let(:adjustment) { create(:adjustment, order: order, state: 'open') }

    context "#closed?" do
      it "is true when adjustment state is closed" do
        adjustment.state = "closed"
        adjustment.should be_closed
      end

      it "is false when adjustment state is open" do
        adjustment.state = "open"
        adjustment.should_not be_closed
      end
    end
  end

  context "#display_amount" do
    before { adjustment.amount = 10.55 }

    context "with display_currency set to true" do
      before { Spree::Config[:display_currency] = true }

      it "shows the currency" do
        adjustment.display_amount.to_s.should == "$10.55 USD"
      end
    end

    context "with display_currency set to false" do
      before { Spree::Config[:display_currency] = false }

      it "does not include the currency" do
        adjustment.display_amount.to_s.should == "$10.55"
      end
    end

    context "with currency set to JPY" do
      context "when adjustable is set to an order" do
        before do
          order.stub(:currency) { 'JPY' }
          adjustment.adjustable = order
        end

        it "displays in JPY" do
          adjustment.display_amount.to_s.should == "¥11"
        end
      end

      context "when adjustable is nil" do
        it "displays in the default currency" do
          adjustment.display_amount.to_s.should == "$10.55"
        end
      end
    end
  end

  context '#currency' do
    it 'returns the globally configured currency' do
      adjustment.currency.should == 'USD'
    end
  end

  context '#update!' do
    subject { adjustment.update! }

    context "when adjustment is closed" do
      before { adjustment.stub :closed? => true }

      it "does not update the adjustment" do
        adjustment.should_not_receive(:update_column)
        subject
      end
    end

    context "when adjustment is open" do
      before { adjustment.stub :closed? => false }

      it "updates the amount" do
        adjustment.stub :adjustable => double("Adjustable")
        adjustment.stub :source => double("Source")
        adjustment.source.should_receive("compute_amount").with(adjustment.adjustable).and_return(5)
        adjustment.should_receive(:update_columns).with(amount: 5, updated_at: kind_of(Time))
        subject
      end

      context "it is a promotion adjustment" do
        subject { @adjustment.update! }

        let(:promotion) { create(:promotion, :with_order_adjustment, code: 'somecode') }
        let(:promotion_code) { promotion.codes.first }
        let(:order1) { create(:order_with_line_items, line_items_count: 1) }

        before do
          promotion.activate(order: order1, promotion_code: promotion_code)
          expect(order1.adjustments.size).to eq 1
          @adjustment = order1.adjustments.first
        end

        context "the promotion is eligible" do
          it "sets the adjustment elgiible to true" do
            subject
            expect(@adjustment.eligible).to eq true
          end
        end

        context "the promotion is not eligible" do
          before { promotion.update_attributes!(starts_at: 1.day.from_now) }

          it "sets the adjustment elgiible to false" do
            subject
            expect(@adjustment.eligible).to eq false
          end
        end
      end
    end

  end

  describe "promotion code presence error" do
    subject do
      adjustment.valid?
      adjustment.errors[:promotion_code]
    end

    context "when the adjustment is not a promotion adjustment" do
      let(:adjustment) { build(:adjustment) }

      it { is_expected.to be_blank }
    end

    context "when the adjustment is a promotion adjustment" do
      let(:adjustment) { build(:adjustment, source: promotion.actions.first) }
      let(:promotion) { create(:promotion, :with_order_adjustment) }

      context "when the promotion does not have a code" do
        it { is_expected.to be_blank }
      end

      context "when the promotion has a code" do
        let!(:promotion_code) { create(:promotion_code, promotion: promotion) }

        it { is_expected.to include("can't be blank") }
      end
    end
  end
end
