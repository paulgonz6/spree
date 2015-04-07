require 'spec_helper'

describe Spree::Admin::OrderInventoriesController do

  describe "#cancel" do
    subject { spree_post :cancel, id: order.number, inventory_unit_ids: inventory_units.map(&:id) }

    let(:order) { order = create(:order_ready_to_ship, :number => "R100", :state => "complete") }
    let(:referer) { "order_admin_page" }

    context "no inventory unit ids are provided" do
      let(:inventory_units) { [] }

      it "redirects back" do
        subject
        response.should redirect_to(spree.admin_order_inventory_path(order))
      end

      it "sets an error message" do
        subject
        expect(flash[:error]).to eq Spree.t(:no_inventory_selected)
      end
    end

    context "unable to find all the inventory" do
      let(:inventory_units) { [Spree::InventoryUnit.new(id: Spree::InventoryUnit.last.id + 1)] }

      it "redirects back" do
        subject
        response.should redirect_to(spree.admin_order_inventory_path(order))
      end

      it "sets an error message" do
        subject
        expect(flash[:error]).to eq Spree.t(:unable_to_find_all_inventory_units)
      end
    end

    context "successfully cancels inventory" do
      let(:inventory_units) { order.inventory_units.not_canceled }

      it "redirects to admin order edit" do
        subject
        response.should redirect_to(spree.edit_admin_order_path(order))
      end

      it "sets an success message" do
        subject
        expect(flash[:success]).to eq Spree.t(:inventory_canceled)
      end

      it "creates a unit cancel" do
        expect { subject }.to change { Spree::UnitCancel.count }.by(order.inventory_units.not_canceled.size)
      end

      it "cancels the inventory" do
        subject
        expect(order.inventory_units.map(&:state).uniq).to match_array(['canceled'])
      end
    end
  end
end
