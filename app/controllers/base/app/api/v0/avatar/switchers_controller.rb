# typed: false
# frozen_string_literal: true

module Base
  module App
    module Api
      module V0
        module Avatar
          # Server-validated context switch for the app Base Self-RP (R5-WU14). Candidate
          # resolution and persistence onto the actor's own root stay in BaseSwitcherAuthority.
          class SwitchersController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ActionPolicy::Controller
            include ::ActorSupport
            include ::AvatarAuthorityApiEndpoint

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "app"

            authorize :user, through: :avatar_actor
            around_action :with_actor_lifecycle
            before_action :authenticate_avatar_caller!
            before_action :set_current_actor
            rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
            rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
            rescue_from ActionController::ParameterMissing, with: :render_bad_request

            public

            def show
              authorize!(avatar_actor, to: :show?)
              render json: BaseSwitcherAuthority.current(surface: :app, principal: avatar_actor, session: avatar_root)
            end

            def update
              authorize!(avatar_actor, to: :update?)
              BaseSwitcherAuthority.switch(
                surface: :app, principal: avatar_actor, session: avatar_root,
                params: switcher_params,
              )
              render json: { status: "switched" }
            rescue BaseSwitcherAuthority::InvalidSwitch => e
              render json: { status: "invalid_switch", error: e.message }, status: :unprocessable_content
            end

            private

            def switcher_params
              keys = %i(
                account_public_id organization_public_id organization_unit_public_id
                collective_public_id collective_unit_public_id avatar_public_id
              )
              params.slice(*keys).permit(*keys).to_h.symbolize_keys
            end
          end
        end
      end
    end
  end
end
