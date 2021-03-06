require 'spec_helper'

module Spree
  describe Api::VariantsController do
    render_views

    let!(:product) { create(:product) }
    let!(:variant) do
      variant = product.master
      variant.option_values << create(:option_value)
      variant
    end

    let!(:base_attributes) { Api::ApiHelpers.variant_attributes }
    let!(:show_attributes) { base_attributes.dup.push(:in_stock, :display_price) }
    let!(:new_attributes) { base_attributes }

    before do
      stub_authentication!
    end

    describe "#index" do

      it "can see a paginated list of variants" do
        api_get :index
        first_variant = json_response["variants"].first
        first_variant.should have_attributes(show_attributes)
        first_variant["stock_items"].should be_present
        json_response["count"].should == 1
        json_response["current_page"].should == 1
        json_response["pages"].should == 1
      end

      it 'can control the page size through a parameter' do
        create(:variant)
        api_get :index, :per_page => 1
        json_response['count'].should == 1
        json_response['current_page'].should == 1
        json_response['pages'].should == 3
      end

      it 'can query the results through a paramter' do
        expected_result = create(:variant, :sku => 'FOOBAR')
        api_get :index, :q => { :sku_cont => 'FOO' }
        json_response['count'].should == 1
        json_response['variants'].first['sku'].should eq expected_result.sku
      end

      it "variants returned contain option values data" do
        api_get :index
        option_values = json_response["variants"].last["option_values"]
        option_values.first.should have_attributes([:name,
                                                   :presentation,
                                                   :option_type_name,
                                                   :option_type_id])
      end

      it "variants returned contain images data" do
        variant.images.create!(:attachment => image("thinking-cat.jpg"))

        api_get :index

        json_response["variants"].last.should have_attributes([:images])
        json_response['variants'].first['images'].first.should have_attributes([:attachment_file_name,
                                                                                 :attachment_width,
                                                                                 :attachment_height,
                                                                                 :attachment_content_type,
                                                                                 :mini_url,
                                                                                 :small_url,
                                                                                 :product_url,
                                                                                 :large_url])

      end

      # Regression test for #2141
      context "a deleted variant" do
        before do
          variant.update_column(:deleted_at, Time.now)
        end

        it "is not returned in the results" do
          api_get :index
          json_response["variants"].count.should == 0
        end

        it "is not returned even when show_deleted is passed" do
          api_get :index, :show_deleted => true
          json_response["variants"].count.should == 0
        end
      end

      context "stock filtering" do
        subject { api_get :index, in_stock_only: true }

        context "variant is out of stock" do
          before do
            variant.stock_items.update_all(count_on_hand: 0)
          end

          it "is not returned in the results" do
            subject
            expect(json_response["variants"].count).to eq 0
          end
        end

        context "variant is in stock" do
          before do
            variant.stock_items.update_all(count_on_hand: 10)
          end

          it "is returned in the results" do
            subject
            expect(json_response["variants"].count).to eq 1
          end
        end
      end

      context "pagination" do
        it "can select the next page of variants" do
          second_variant = create(:variant)
          api_get :index, :page => 2, :per_page => 1
          json_response["variants"].first.should have_attributes(show_attributes)
          json_response["total_count"].should == 3
          json_response["current_page"].should == 2
          json_response["pages"].should == 3
        end
      end

      context "stock item filter" do
        let(:stock_location) { variant.stock_locations.first }
        let!(:inactive_stock_location) { create(:stock_location, propagate_all_variants: true, name: "My special stock location", active: false) }

        it "only returns stock items for active stock locations" do
          api_get :index
          variant = json_response['variants'].first
          stock_items = variant['stock_items'].map { |si| si['stock_location_name'] }

          expect(stock_items).to include stock_location.name
          expect(stock_items).not_to include inactive_stock_location.name
        end
      end
    end

    describe "#show" do

      it "can see a single variant" do
        api_get :show, :id => variant.to_param
        json_response.should have_attributes(show_attributes)
        json_response["stock_items"].should be_present
        option_values = json_response["option_values"]
        option_values.first.should have_attributes([:name,
                                                   :presentation,
                                                   :option_type_name,
                                                   :option_type_id])
      end

      it "can see a single variant with images" do
        variant.images.create!(:attachment => image("thinking-cat.jpg"))

        api_get :show, :id => variant.to_param

        json_response.should have_attributes(show_attributes + [:images])
        option_values = json_response["option_values"]
        option_values.first.should have_attributes([:name,
                                                   :presentation,
                                                   :option_type_name,
                                                   :option_type_id])
      end
    end

    it "can learn how to create a new variant" do
      api_get :new
      json_response["attributes"].should == new_attributes.map(&:to_s)
      json_response["required_attributes"].should be_empty
    end

    it "cannot create a new variant if not an admin" do
      api_post :create, :variant => { :sku => "12345" }
      assert_unauthorized!
    end

    it "cannot update a variant" do
      api_put :update, :id => variant.to_param, :variant => { :sku => "12345" }
      assert_not_found!
    end

    it "cannot delete a variant" do
      api_delete :destroy, :id => variant.to_param
      assert_not_found!
      lambda { variant.reload }.should_not raise_error
    end

    context "as an admin" do
      sign_in_as_admin!
      let(:resource_scoping) { { :product_id => variant.product.to_param } }

      # Test for #2141
      context "deleted variants" do
        before do
          variant.update_column(:deleted_at, Time.now)
        end

        it "are visible by admin" do
          api_get :index, :show_deleted => 1
          json_response["variants"].count.should == 1
        end
      end

      it "can create a new variant" do
        api_post :create, :variant => { :sku => "12345" }
        json_response.should have_attributes(new_attributes)
        response.status.should == 201
        json_response["sku"].should == "12345"

        variant.product.variants.count.should == 1
      end

      it "can update a variant" do
        api_put :update, :id => variant.to_param, :variant => { :sku => "12345" }
        response.status.should == 200
      end

      it "can delete a variant" do
        api_delete :destroy, :id => variant.to_param
        response.status.should == 204
        lambda { Spree::Variant.find(variant.id) }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end

  end
end
