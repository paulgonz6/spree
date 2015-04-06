require 'spec_helper'

describe "Cancelling inventory" do
  stub_authorization!

  let!(:order) { order = create(:order_ready_to_ship, :number => "R100", :state => "complete") }

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
      page.should have_content("Inventory canceled")
      expect(order.inventory_units.canceled.size).to eq 1
    end
  end

  context "when all inventory is not cancelable" do
    before { order.inventory_units.map(&:cancel!) }

    it "does not display the link to cancel inventory" do
      page.should_not have_content("Inventory canceled")
    end
  end
end
