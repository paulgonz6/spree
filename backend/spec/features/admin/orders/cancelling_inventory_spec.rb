require 'spec_helper'

describe "Cancelling inventory" do
  stub_authorization!

  let!(:order) do
    create(
      :order_ready_to_ship,
      number: "R100",
      state: "complete",
      line_items_count: 1,
    )
  end

  before(:each) do
    visit spree.admin_path
    click_link "Orders"
    within_row(1) do
      click_link "R100"
    end
  end

  context "when some inventory is cancelable" do
    it "can cancel the inventory" do
      click_link 'Cancel Inventory'

      within_row(1) do
        check 'inventory_unit_ids[]'
      end

      click_button "Cancel Inventory"
      expect(page).to have_content("Inventory canceled")
      expect(page).to have_content("1 x canceled")
    end
  end

  context "when all inventory is not cancelable" do
    before { order.inventory_units.map(&:cancel!) }

    it "does not display the link to cancel inventory" do
      expect(page).not_to have_content("Inventory canceled")
    end
  end
end
