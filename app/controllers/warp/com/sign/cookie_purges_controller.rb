# typed: false
# frozen_string_literal: true

module Warp
  module Com
    module Sign
      # R5-WU16 matching-session cookie purge for this RP cell.
      class CookiePurgesController < Warp::Com::ApplicationController
        include ::RpCookiePurgeEndpoint

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
      end
    end
  end
end
