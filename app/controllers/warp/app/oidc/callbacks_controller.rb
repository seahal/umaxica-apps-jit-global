# typed: false
# frozen_string_literal: true

module Warp
  module App
    module Oidc
      class CallbacksController < Warp::App::ApplicationController
        include ::OidcCallback

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        skip_before_action :set_region, raise: false

        private

        def consume_oidc_pt
          destination = super
          (destination == "/") ? warp_app_dashboard_path(ri: params[:ri]) : destination
        end

        def oidc_client_id
          RpDeploymentBindingValue.client_id("warp-app")
        end
      end
    end
  end
end
