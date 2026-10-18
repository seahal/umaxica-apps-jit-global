# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Api
      module V0
        module Avatar
          # Display identity for the com Base Self-RP dashboard (R5-WU14): the selected persona's
          # display name and the selected Avatar image version, resolved by their owner.
          class DashboardIdentitiesController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ActionPolicy::Controller
            include ::ActorSupport
            include ::AvatarAuthorityApiEndpoint

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "com"

            around_action :with_actor_lifecycle
            before_action :authenticate_avatar_caller!
            before_action :set_current_actor
            rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

            public

            def show
              persona = avatar_switcher.find_account(Actor.selection.account_public_id) ||
                raise(ActiveRecord::RecordNotFound, "selected com Persona is not available to this principal")
              display_name = persona.moniker
              raise RuntimeError, "selected com Persona has no display name" if display_name.blank?

              # The com surface has no Avatar capability.
              image_version = nil
              render json: { display_name:, image_version: }
            end
          end
        end
      end
    end
  end
end
