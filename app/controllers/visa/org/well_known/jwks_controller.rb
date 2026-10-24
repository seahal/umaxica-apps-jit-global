# typed: false
# frozen_string_literal: true

module Visa
  module Org
    module WellKnown
      class JwksController < BareController
        include AuthenticationJwksRendering

        AUTHENTICATION_MODE = :bare
        JWT_KEY_NAMESPACE = "VISA_ORG"

        before_action :skip_jwks_session!
      end
    end
  end
end
