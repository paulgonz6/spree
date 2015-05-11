require 'spec_helper'

describe Spree::OrderCapturing do
  describe '#capture_payments' do
    subject { Spree::OrderCapturing.new(order).capture_payments }

    let(:order) { create(:completed_order_with_pending_payment) }

    context 'the order has already been paid for' do
      before { Spree::OrderCapturing.new(order).capture_payments }

      it 'does not process payments' do
        expect_any_instance_of(Spree::Payment).not_to receive(:capture!)
        subject
      end
    end

    it 'processes payments for the order' do
      expect(order.paid?).to eq false
      subject
      expect(order.reload.paid?).to eq true
    end
  end
end
