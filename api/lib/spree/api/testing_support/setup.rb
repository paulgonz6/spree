module Spree
  module Api
    module TestingSupport
      module Setup
        def sign_in_as_admin!
          let!(:current_api_user) do
            user = stub_model(Spree::LegacyUser)
            allow(user).to receive(:has_spree_role?).with("admin").and_return(true)
            user
          end
        end
      end
    end
  end
end
