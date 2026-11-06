# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Oidc
      class CallbacksController < Palm::App::ApplicationController
        include ::OidcCallback

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          RpDeploymentBindingValue.client_id("palm-app")
        end
      end
    end
  end
end
