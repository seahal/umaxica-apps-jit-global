# typed: false
# frozen_string_literal: true

module Palm
  module App
    module WellKnown
      class JwksController < Palm::App::BareController
        include AuthenticationJwksRendering

        AUTHENTICATION_MODE = :bare
        JWT_KEY_NAMESPACE = "PALM_APP"

        before_action :skip_jwks_session!
      end
    end
  end
end
