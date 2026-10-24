# typed: false
# frozen_string_literal: true

module Visa
  module App
    module Oidc
      class ResultsController < ::Visa::App::Oauth::AuthorizationsController
        include ::OidcAuthorizationContinuation

        AUTHENTICATION_MODE = :open
        OIDC_CONTINUATION_KIND = :result
        declare_authentication_mode! :open
      end
    end
  end
end
