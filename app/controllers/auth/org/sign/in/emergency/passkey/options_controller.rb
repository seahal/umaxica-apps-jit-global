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

              prepend_before_action :require_sign_in_ceremony_admission!
              ensure_fqdn_gate_first!
              prepend_before_action :apply_default_no_store

              def create = options
            end
          end
        end
      end
    end
  end
end
