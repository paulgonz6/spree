require 'spec_helper'

describe Spree::CartonCapture do
  describe 'creation' do
    it do
      expect {
        create(:carton_capture)
      }.to_not raise_error
    end
  end
end
