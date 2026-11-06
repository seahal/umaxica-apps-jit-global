# typed: false
# frozen_string_literal: true

module Base
  module App
    module Oidc
      class CallbacksController < Base::App::ApplicationController
        include ::OidcCallback

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        skip_before_action :set_region, raise: false

        private

        def consume_oidc_pt
          destination = super
          (destination == "/") ? base_app_dashboard_path(ri: params[:ri]) : destination
        end

        def oidc_client_id
          "base-app-ww"
        end
      end
    end
  end
end
