# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module In
        class ChecksController < ::Auth::App::ApplicationController
          include SignAppInCheckControllerSupport

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          prepend_before_action :authenticate_sign_in_sequence_actor!
          ensure_fqdn_gate_first!
          # Restores the inherited default no-store ahead of the gate (DefaultNoStore).
          prepend_before_action :apply_default_no_store
          before_action :continue_checkpoint_sequence_without_content!

          def show = super
        end
      end
    end
  end
end
