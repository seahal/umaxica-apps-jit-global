# typed: false
# frozen_string_literal: true

module Visa
  module App
    module Oidc
      class SwitchesController < ::Visa::App::AuthorizationBaseController
        include ::OidcAuthorizationContinuation

        AUTHENTICATION_MODE = :open
        OIDC_CONTINUATION_KIND = :switch
        declare_authentication_mode! :open
        before_action :enforce_oauth_authorize_request_size!
      end
    end
  end
end
