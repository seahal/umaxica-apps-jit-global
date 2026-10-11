# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        module Emergency
          module Passkey
            # POST /sign/in/emergency/passkey/options
            class OptionsController < ::Auth::Org::ApplicationController
              include ::SignOrgEmergencyPasskeyCeremony
              include ::AuthenticationModeSwitchGuard

              AUTHENTICATION_MODE = :guest

              def create = options
            end
          end
        end
      end
    end
  end
end
