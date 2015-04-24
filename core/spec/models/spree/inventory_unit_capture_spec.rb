require 'spec_helper'

describe Spree::InventoryUnitCapture do
  describe 'creation' do
    it do
      expect {
        create(:inventory_unit_capture)
      }.to_not raise_error
    end
  end
end
