# typed: false
# frozen_string_literal: true

module Visa
  module Org
    module Oidc
      class CancellationsController < ::Visa::Org::Oauth::AuthorizationsController
        include ::OidcAuthorizationContinuation

        AUTHENTICATION_MODE = :open
        OIDC_CONTINUATION_KIND = :cancellation
        declare_authentication_mode! :open
      end
    end
  end
end
