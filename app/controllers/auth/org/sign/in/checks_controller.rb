# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        class ChecksController < ::Auth::Org::ApplicationController
          include SignOrgInCheckControllerSupport

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          prepend_before_action :authenticate_sign_in_sequence_actor!
          ensure_fqdn_gate_first!
          before_action :continue_checkpoint_sequence_without_content!

          def show = super
        end
      end
    end
  end
end
