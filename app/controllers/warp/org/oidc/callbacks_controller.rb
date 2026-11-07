# typed: false
# frozen_string_literal: true

module Warp
  module Org
    module Oidc
      class CallbacksController < Warp::Org::ApplicationController
        include ::OidcCallback

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          RpDeploymentBindingValue.client_id("warp-org")
        end

        def oidc_rp_default_landing_path
          warp_org_dashboard_path(ri: params[:ri])
        end
      end
    end
  end
end
