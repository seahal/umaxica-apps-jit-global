# typed: false
# frozen_string_literal: true

module Visa
  module App
    module Oidc
      class CancellationsController < ::Visa::App::Oauth::AuthorizationsController
        include ::OidcAuthorizationContinuation

        AUTHENTICATION_MODE = :open
        OIDC_CONTINUATION_KIND = :cancellation
        declare_authentication_mode! :open
      end
    end
  end
end
