require 'spec_helper'

describe Spree::CartonCapture do
  describe '#total' do
    subject { carton_capture.total }
    let(:carton_capture) { create(:carton_capture) }

    before do
      2.times do
        create(:inventory_unit_capture,
          carton_capture: carton_capture,
          price: 1.1,
          promo_total: 2.2,
          included_tax_total: 3.3,
          additional_tax_total: 4.4,
          order_adjustment_total: 5.5,
        )
      end
    end

    it "sums it's inventory unit captures breakdown totals" do
      expect(subject).to eq 26.4
    end
  end
end
