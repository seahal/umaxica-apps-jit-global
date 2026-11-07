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

        def oidc_client_id
          "base-app-ww"
        end

        def oidc_rp_default_landing_path
          base_app_dashboard_path(ri: params[:ri])
        end
      end
    end
  end
end
