require 'spec_helper'

describe Spree::Admin::PromotionsController do
  stub_authorization!

  let!(:promotion1) { create(:promotion, name: "name1", code: "code1", path: "path1") }
  let!(:promotion2) { create(:promotion, name: "name2", code: "code2", path: "path2") }
  let!(:category) { create :promotion_category }

  describe "#index" do

    it "succeeds" do
      spree_get :index
      expect(assigns[:promotions]).to match_array [promotion2, promotion1]
    end

    it "assigns promotion categories" do
      spree_get :index
      expect(assigns[:promotion_categories]).to match_array [category]
    end

    context "search" do
      it "pages results" do
        spree_get :index, per_page: '1'
        expect(assigns[:promotions]).to eq [promotion2]
      end

      it "filters by name" do
        spree_get :index, q: {name_cont: promotion1.name}
        expect(assigns[:promotions].map(&:id)).to eq [promotion1.id]
      end

      it "filters by code" do
        spree_get :index, q: {codes_value_cont: promotion1.codes.first.value }
        expect(assigns[:promotions].map(&:id)).to eq [promotion1.id]
      end

      it "filters by path" do
        spree_get :index, q: {path_cont: promotion1.path}
        expect(assigns[:promotions].map(&:id)).to eq [promotion1.id]
      end
    end
  end

  describe "#update" do
    let(:params) { {id: promotion.id, promotion: {name: 'some promo'}} }
    let(:promotion) { create(:promotion, code: 'abc123') }

    before { promotion.codes.first.update!(usage_limit: 100) }

    context "when bulk limit is provided" do
      let(:params) { super().merge(bulk_limit: 1) }

      it "updates the usage limit on all the codes" do
        spree_post :update, params
        expect(promotion.codes.map(&:usage_limit).uniq).to eq [1]
      end
    end

    context "when bulk limit is not provided" do
      it "does not update the codes' usage limits" do
        spree_post :update, params
        expect(promotion.codes.map(&:usage_limit).uniq).to eq [100]
      end
    end
  end

  describe "#create" do
    let(:params) { {promotion: {name: 'some promo'}} }

    it "succeeds" do
      expect {
        spree_post :create, params
      }.to change { Spree::Promotion.count }.by(1)
    end

    context "with one promo codes" do
      let(:params) do
        super().merge(bulk_base: 'abc', bulk_number: 1)
      end

      it "succeeds and creates one code" do
        expect {
          expect {
            spree_post :create, params
          }.to change { Spree::Promotion.count }.by(1)
        }.to change { Spree::PromotionCode.count }.by(1)

        expect(assigns(:promotion).codes.first.value).to eq ('abc')
      end

      context "with usage limit set per code" do
        let(:params) { super().merge(bulk_limit: 10) }

        it "sets the usage limit on the code" do
          spree_post :create, params
          expect(assigns(:promotion).codes.first.usage_limit).to eq 10
        end
      end
    end

    context "with multiple promo codes" do
      let(:params) do
        super().merge(bulk_base: 'abc', bulk_number: 2)
      end

      it "succeeds and creates multiple codes" do
        expect {
          expect {
            spree_post :create, params
          }.to change { Spree::Promotion.count }.by(1)
        }.to change { Spree::PromotionCode.count }.by(2)

        expect(assigns(:promotion).codes.map(&:value)).to all(match(/\Aabc_/))
      end

      context "with usage limit set per code" do
        let(:params) { super().merge(bulk_limit: 10) }

        it "sets the usage limit on the code" do
          spree_post :create, params
          expect(assigns(:promotion).codes.map(&:usage_limit)).to all(eq(10))
        end
      end
    end
  end

end
