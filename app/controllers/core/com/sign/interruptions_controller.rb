# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Sign
      class InterruptionsController < Core::Com::ApplicationController
        include ::OidcRpSignInterruption

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        # The page never redirects on its own (D-153), not even to add a region.
        skip_before_action :set_region, raise: false
        helper_method :interruption_sign_path
      end
    end
  end
end
