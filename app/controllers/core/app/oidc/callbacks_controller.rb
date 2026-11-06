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

        def oidc_client_id
          RpDeploymentBindingValue.client_id("core-app")
        end
      end
    end
  end
end
