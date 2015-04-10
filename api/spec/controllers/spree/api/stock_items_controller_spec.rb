require 'spec_helper'

module Spree
  describe Api::StockItemsController do
    render_views

    let!(:stock_location) { create(:stock_location_with_items) }
    let!(:stock_item) { stock_location.stock_items.order(:id).first }
    let!(:attributes) { [:id, :count_on_hand, :backorderable,
                         :stock_location_id, :variant_id] }

    before do
      stub_authentication!
    end

    context "as a normal user" do
      it "cannot list stock items for a stock location" do
        api_get :index, stock_location_id: stock_location.to_param
        response.status.should == 404
      end

      it "cannot see a stock item" do
        api_get :show, stock_location_id: stock_location.to_param, id: stock_item.to_param
        response.status.should == 404
      end

      it "cannot create a stock item" do
        variant = create(:variant)
        params = {
          stock_location_id: stock_location.to_param,
          stock_item: {
            variant_id: variant.id,
            count_on_hand: '20'
          }
        }

        api_post :create, params
        response.status.should == 404
      end

      it "cannot update a stock item" do
        api_put :update, stock_location_id: stock_location.to_param, stock_item_id: stock_item.to_param
        response.status.should == 404
      end

      it "cannot destroy a stock item" do
        api_delete :destroy, stock_location_id: stock_location.to_param, stock_item_id: stock_item.to_param
        response.status.should == 404
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      it 'cannot list of stock items' do
        api_get :index, stock_location_id: stock_location.to_param
        json_response['stock_items'].first.should have_attributes(attributes)
        json_response['stock_items'].first['variant']['sku'].should eq 'ABC'
      end

      it 'requires a stock_location_id to be passed as a parameter' do
        api_get :index
        json_response['error'].should =~ /stock_location_id parameter must be provided/
        response.status.should == 422
      end

      it 'can control the page size through a parameter' do
        api_get :index, stock_location_id: stock_location.to_param, per_page: 1
        json_response['count'].should == 1
        json_response['current_page'].should == 1
      end

      it 'can query the results through a paramter' do
        stock_item.update_column(:count_on_hand, 30)
        api_get :index, stock_location_id: stock_location.to_param, q: { count_on_hand_eq: '30' }
        json_response['count'].should == 1
        json_response['stock_items'].first['count_on_hand'].should eq 30
      end

      it 'gets a stock item' do
        api_get :show, stock_location_id: stock_location.to_param, id: stock_item.to_param
        json_response.should have_attributes(attributes)
        json_response['count_on_hand'].should eq stock_item.count_on_hand
      end

      context 'creating a stock item' do
        let!(:variant) do
          variant = create(:variant)
          # Creating a variant also creates stock items.
          # We don't want any to exist (as they would conflict with what we're about to create)
          StockItem.delete_all
          variant
        end
        let(:params) do
          {
            stock_location_id: stock_location.to_param,
            stock_item: {
              variant_id: variant.id,
              count_on_hand: '20'
            }
          }
        end

        subject { api_post :create, params }

        it 'can create a new stock item' do
          subject
          expect(response.status).to eq 201
          expect(json_response).to have_attributes(attributes)
        end

        context 'variant tracks inventory' do
          before do
            expect(variant.track_inventory).to eq true
          end

          it 'creates a stock movement' do
            expect { subject }.to change { Spree::StockMovement.count }.by(1)
            expect(Spree::StockMovement.last.quantity).to eq 20
          end
        end

        context 'variant does not track inventory' do
          before do
            variant.update_attributes(track_inventory: false)
          end

          it 'does not create a stock movement' do
            expect { subject }.not_to change { Spree::StockMovement.count }
          end
        end
      end

      context 'updating a stock item' do
        before do
          expect(stock_item.count_on_hand).to eq 10
        end

        subject { api_put :update, params }

        context 'adjusting count_on_hand' do
          let(:params) do
            {
              id: stock_item.to_param,
              stock_item: {
                count_on_hand: 40,
                backorderable: true
              }
            }
          end

          it 'can update a stock item to add new inventory' do
            subject
            expect(response.status).to eq 200
            expect(json_response['count_on_hand']).to eq 50
            expect(json_response['backorderable']).to eq true
          end

          context 'tracking inventory' do
            before do
              expect(stock_item.should_track_inventory?).to eq true
            end

            it 'creates a stock movement for the adjusted quantity' do
              expect { subject }.to change { Spree::StockMovement.count }.by(1)
              expect(Spree::StockMovement.last.quantity).to eq 40
            end
          end

          context 'not tracking inventory' do
            before do
              stock_item.variant.update_attributes(track_inventory: false)
            end

            it 'does not create a stock movement for the adjusted quantity' do
              expect { subject }.not_to change { Spree::StockMovement.count }
            end
          end
        end

        context 'setting count_on_hand' do
          let(:params) do
            {
              id: stock_item.to_param,
              stock_item: {
                count_on_hand: 40,
                force: true,
              }
            }
          end

          it 'can set a stock item to modify the current inventory' do
            subject
            expect(response.status).to eq 200
            expect(json_response['count_on_hand']).to eq 40
          end

          context 'tracking inventory' do
            before do
              expect(stock_item.should_track_inventory?).to eq true
            end

            it 'creates a stock movement for the adjusted quantity' do
              expect { subject }.to change { Spree::StockMovement.count }.by(1)
              expect(Spree::StockMovement.last.quantity).to eq 30
            end
          end

          context 'not tracking inventory' do
            before do
              stock_item.variant.update_attributes(track_inventory: false)
            end

            it 'does not create a stock movement for the adjusted quantity' do
              expect { subject }.not_to change { Spree::StockMovement.count }
            end
          end
        end
      end

      it 'can delete a stock item' do
        api_delete :destroy, id: stock_item.to_param
        response.status.should == 204
        lambda { Spree::StockItem.find(stock_item.id) }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end

