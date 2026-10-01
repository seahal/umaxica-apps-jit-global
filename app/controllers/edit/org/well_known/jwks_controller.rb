# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module WellKnown
      class JwksController < BareController
        include AuthenticationJwksRendering

        AUTHENTICATION_MODE = :bare
        JWT_KEY_NAMESPACE = "EDIT_ORG"

        before_action :skip_jwks_session!
      end
    end
  end
end
