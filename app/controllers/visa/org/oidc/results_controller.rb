# typed: false
# frozen_string_literal: true

module Visa
  module Org
    module Oidc
      class ResultsController < ::Visa::Org::AuthorizationBaseController
        include ::OidcAuthorizationContinuation

        AUTHENTICATION_MODE = :open
        OIDC_CONTINUATION_KIND = :result
        declare_authentication_mode! :open
        before_action :enforce_oauth_authorize_request_size!
      end
    end
  end
end
