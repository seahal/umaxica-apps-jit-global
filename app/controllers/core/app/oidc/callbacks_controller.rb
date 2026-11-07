# typed: false
# frozen_string_literal: true

module Core
  module App
    module Oidc
      class CallbacksController < Core::App::ApplicationController
        include ::OidcCallback

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        skip_before_action :set_region, raise: false

        private

        # Core has no Rails dashboard; the shared Home remains the entry for its TanStack Start
        # screens in both signed-in and signed-out states.
        def oidc_rp_default_landing_path
          "/"
        end

        def oidc_client_id
          RpDeploymentBindingValue.client_id("core-app")
        end
      end
    end
  end
end
