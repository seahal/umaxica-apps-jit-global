# typed: false
# frozen_string_literal: true

module Warp
  module Org
    module WellKnown
      class JwksController < Warp::Org::BareController
        include AuthenticationJwksRendering

        AUTHENTICATION_MODE = :bare
        JWT_KEY_NAMESPACE = "WARP_ORG"

        before_action :skip_jwks_session!
      end
    end
  end
end
