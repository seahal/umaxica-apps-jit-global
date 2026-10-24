# typed: false
# frozen_string_literal: true

module Visa
  module App
    module Oidc
      class SwitchesController < ::Visa::App::Oauth::AuthorizationsController
        include ::OidcAuthorizationContinuation

        AUTHENTICATION_MODE = :open
        OIDC_CONTINUATION_KIND = :switch
        declare_authentication_mode! :open
      end
    end
  end
end
