# typed: false
# frozen_string_literal: true

module Tech
  module Org
    module Sign
      # R5-WU16 matching-session cookie purge for this RP cell.
      class CookiePurgesController < Tech::Org::ApplicationController
        include ::RpCookiePurgeEndpoint

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
      end
    end
  end
end
