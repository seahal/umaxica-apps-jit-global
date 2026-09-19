# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        class ChecksController < ::Auth::Org::ApplicationController
          include SignOrgInCheckControllerSupport

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_operator!
          before_action :continue_checkpoint_sequence_without_content!

          # TODO: Action Policy authorization is not yet enforced here.

          # This sign-in ceremony step gates with allowed_to?, which does not satisfy

          # verify_authorized, so its render path is expected to raise UnauthorizedAction.

          # Audit the sign-in sequence boundary before choosing the authorize! rule.

          def show = super
        end
      end
    end
  end
end
