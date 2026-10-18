# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Oidc
      # R5-WU10 back-channel logout receiver for the rp_palm_app cell.
      class BackchannelLogoutsController < ActionController::API
        include RpBackchannelLogoutEndpoint

        AUTHENTICATION_MODE = :open
        RP_CELL_CONNECTION = "rp_palm_app"
      end
    end
  end
end
