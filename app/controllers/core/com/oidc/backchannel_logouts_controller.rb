# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Oidc
      # R5-WU10 back-channel logout receiver for the rp_core_com cell.
      class BackchannelLogoutsController < ActionController::API
        include RpBackchannelLogoutEndpoint

        AUTHENTICATION_MODE = :open
        RP_CELL_CONNECTION = "rp_core_com"
      end
    end
  end
end
