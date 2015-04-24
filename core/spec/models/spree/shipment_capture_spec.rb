require 'spec_helper'

describe Spree::ShipmentCapture do
  describe 'creation' do
    it do
      expect {
        create(:shipment_capture)
      }.to_not raise_error
    end
  end
end
