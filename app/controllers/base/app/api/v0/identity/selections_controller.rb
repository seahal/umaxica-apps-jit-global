# typed: false
# frozen_string_literal: true

module Base
  module App
    module Api
      module V0
        module Identity
          # APP selection belongs to the Base RP session. This retired endpoint refuses requests so
          # an APP cell cannot obtain a competing selection from the OP root.
          class SelectionsController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ::AvatarAuthorityApiEndpoint

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "app"

            before_action :authenticate_avatar_caller!

            public

            def show
              render json: { error: "selection_owned_by_base_rp" }, status: :conflict
            end
          end
        end
      end
    end
  end
end
