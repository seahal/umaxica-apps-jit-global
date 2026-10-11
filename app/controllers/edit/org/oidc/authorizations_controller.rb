# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module Oidc
      class AuthorizationsController < Edit::Org::ApplicationController
        AUTHENTICATION_MODE = :open

        skip_before_action :set_region, raise: false

        public

        def show
          url = initiate_oidc_session!(screen_hint: "signup")
          redirect_to_oidc_authorization_url(url)
        end
      end
    end
  end
end
