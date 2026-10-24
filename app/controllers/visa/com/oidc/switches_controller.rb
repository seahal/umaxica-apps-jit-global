# typed: false
# frozen_string_literal: true

module Visa
  module Com
    module Oidc
      class SwitchesController < ::Visa::Com::Oauth::AuthorizationsController
        include ::OidcAuthorizationContinuation

        AUTHENTICATION_MODE = :open
        OIDC_CONTINUATION_KIND = :switch
        declare_authentication_mode! :open
      end
    end
  end
end
