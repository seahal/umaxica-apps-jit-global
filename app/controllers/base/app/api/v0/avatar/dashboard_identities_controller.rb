# typed: false
# frozen_string_literal: true

module Base
  module App
    module Api
      module V0
        module Avatar
          # Display identity for the app Base Self-RP dashboard (R5-WU14): the selected persona's
          # display name and the selected Avatar image version, resolved by their owner.
          class DashboardIdentitiesController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ActionPolicy::Controller
            include ::ActorSupport
            include ::AvatarAuthorityApiEndpoint

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "app"

            around_action :with_actor_lifecycle
            before_action :authenticate_avatar_caller!
            before_action :set_current_actor
            rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

            public

            def show
              persona = avatar_switcher.find_account(Actor.selection.account_public_id) ||
                raise(ActiveRecord::RecordNotFound, "selected app Persona is not available to this principal")
              display_name = persona.moniker
              raise RuntimeError, "selected app Persona has no display name" if display_name.blank?

              avatar = avatar_switcher.selected_avatar || raise(RuntimeError, "selected app context has no Avatar")
              image_version = avatar.image ? avatar.image_cache_key : "default"
              render json: { display_name:, image_version: }
            end
          end
        end
      end
    end
  end
end
