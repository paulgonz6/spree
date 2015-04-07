require 'spec_helper'

module Spree
  module Admin
    describe StockItemsController do
      stub_authorization!

      context "formats" do
        let!(:stock_item) { create(:variant).stock_items.first }

        it "destroy stock item via js" do
          expect {
            spree_delete :destroy, format: :js, id: stock_item
          }.to change{ StockItem.count }.by(-1)
        end
      end

      context "create" do
        let!(:variant) { create(:variant) }
        let!(:stock_location) { variant.stock_locations.first }
        let(:stock_item) { variant.stock_items.first }

        before { request.env["HTTP_REFERER"] = "product_admin_page" }

        subject do
          spree_post :create, { variant_id: variant, stock_location_id: stock_location, stock_movement: { quantity: 1, stock_item_id: stock_item.id } }
        end

        it "creates a stock movement with originator" do
          expect { subject }.to change { Spree::StockMovement.count }.by(1)
          stock_movement = Spree::StockMovement.last
          expect(stock_movement.originator_type).to eq "Spree::LegacyUser"
        end
      end
    end
  end
end
