require 'spec_helper'

describe Spree::PromotionCode do
  context "#usage_limit_exceeded?" do
    let(:promotable) { double('Promotable') }
    let(:code) { create(:promotion_code) }

    it "should not have its usage limit exceeded with no usage limit" do
      code.usage_limit = 0
      code.usage_limit_exceeded?(promotable).should be false
    end

    it "should have its usage limit exceeded" do
      code.usage_limit = 2
      code.stub(:usage_for_promotion_code_count => 2)
      code.usage_limit_exceeded?(promotable).should be true

      code.stub(:usage_for_promotion_code_count => 3)
      code.usage_limit_exceeded?(promotable).should be true
    end
  end
end