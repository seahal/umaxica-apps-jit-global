# typed: false
# frozen_string_literal: true

module Warp
  module Com
    module Oidc
      # R5-WU10 back-channel logout receiver for the rp_warp_com cell.
      class ClosuresController < ActionController::API
        include RpBackchannelLogoutEndpoint

        # D-118: no browser parent, so FQDN gating and rate limiting are explicit here.
        rate_limit to: 60, within: 1.minute, by: -> { request.remote_ip },
                   store: Rails.configuration.x.rate_limit.fetch(:store), name: "oidc_closures_ip",
                   with: -> { head(:too_many_requests) }

        AUTHENTICATION_MODE = :open
        RP_CELL_CONNECTION = "rp_warp_com"
      end
    end
  end
end
