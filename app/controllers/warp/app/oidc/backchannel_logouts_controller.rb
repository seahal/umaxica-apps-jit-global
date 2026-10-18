# typed: false
# frozen_string_literal: true

module Warp
  module App
    module Oidc
      # R5-WU10 back-channel logout receiver for the rp_warp_app cell.
      class BackchannelLogoutsController < ActionController::API
        include RpBackchannelLogoutEndpoint

        AUTHENTICATION_MODE = :open
        RP_CELL_CONNECTION = "rp_warp_app"
      end
    end
  end
end
