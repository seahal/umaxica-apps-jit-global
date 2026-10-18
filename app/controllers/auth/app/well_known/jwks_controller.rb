# typed: false
# frozen_string_literal: true

module Auth
  module App
    module WellKnown
      class JwksController < BareController
        include AuthenticationJwksRendering

        AUTHENTICATION_MODE = :bare
        JWT_KEY_NAMESPACE = "AUTH_APP"

        before_action :skip_jwks_session!
      end
    end
  end
end
