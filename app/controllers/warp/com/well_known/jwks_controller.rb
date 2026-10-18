# typed: false
# frozen_string_literal: true

module Warp
  module Com
    module WellKnown
      class JwksController < Warp::Com::BareController
        include AuthenticationJwksRendering

        AUTHENTICATION_MODE = :bare
        JWT_KEY_NAMESPACE = "WARP_COM"

        before_action :skip_jwks_session!
      end
    end
  end
end
