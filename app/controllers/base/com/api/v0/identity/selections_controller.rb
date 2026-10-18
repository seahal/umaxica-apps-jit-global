# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Api
      module V0
        module Identity
          # The selected account/organization context recorded on the actor's own OP root, for the
          # com Base Self-RP cell (R5-WU17). The cell never reads the OP store; it asks here.
          class SelectionsController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ::AvatarAuthorityApiEndpoint

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "com"

            before_action :authenticate_avatar_caller!

            public

            def show
              render json: {
                account_public_id: avatar_root.try(:selected_account_public_id),
                collective_public_id: avatar_root.try(:selected_collective_public_id),
                collective_unit_public_id: avatar_root.try(:selected_collective_unit_public_id),
                avatar_public_id: avatar_root.try(:selected_avatar_public_id),
                selected_at: avatar_root.try(:selected_at)&.iso8601(6),
              }
            end
          end
        end
      end
    end
  end
end
