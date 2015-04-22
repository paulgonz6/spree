require 'spec_helper'

RSpec.feature "Promotion Code Invalidation" do
  given!(:promotion) do
    FactoryGirl.create(
      :promotion_with_item_adjustment,
      code: "PROMO",
      per_code_usage_limit: 1,
      adjustment_rate: 5
    )
  end

  background do
    FactoryGirl.create(:product, name: "DL-44")
    FactoryGirl.create(:product, name: "E-11")

    visit spree.root_path
    click_link "DL-44"
    click_button "Add To Cart"

    visit spree.root_path
    click_link "E-11"
    click_button "Add To Cart"
  end

  scenario "adding the promotion to a cart with two applicable items" do
    fill_in "Coupon code", with: "PROMO"
    click_button "Update"

    expect(page).to have_content("The coupon code was successfully applied to your order")

    within("#cart_adjustments") do
      expect(page).to have_content("-$10.00")
    end
  end
end
