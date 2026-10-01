# typed: false
# frozen_string_literal: true

module Warp
  module App
    module WellKnown
      class JwksController < Warp::App::BareController
        include AuthenticationJwksRendering

        AUTHENTICATION_MODE = :bare
        JWT_KEY_NAMESPACE = "WARP_APP"

        before_action :skip_jwks_session!
      end
    end
  end
end
