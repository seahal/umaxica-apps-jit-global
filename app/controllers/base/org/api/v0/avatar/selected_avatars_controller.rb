# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Api
      module V0
        module Avatar
          # The org actor's selected Avatar (R5-WU14): read, rename and destroy authorization, moved
          # from the former in-process page with the same ownership-period and membership lock.
          class SelectedAvatarsController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ActionPolicy::Controller
            include ::ActorSupport
            include ::AvatarAuthorityApiEndpoint

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "org"

            authorize :user, through: :avatar_actor
            around_action :with_actor_lifecycle
            before_action :authenticate_avatar_caller!
            before_action :set_current_actor
            rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
            rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
            rescue_from ActionController::ParameterMissing, with: :render_bad_request
            before_action :verify_avatar_persona!
            rescue_from AvatarOwnerMembershipLockService::AuthorizationDenied, with: :render_owner_denied

            public

            def show
              avatar = selected_avatar
              authorize!(avatar || ::Avatar, to: avatar ? :show? : :index?)
              render json: { avatar: avatar && { public_id: avatar.public_id, moniker: avatar.moniker } }
            end

            def update
              avatar = selected_avatar!
              authorize!(avatar, to: :update?)
              observed = avatar.current_ownership_period || raise(ActiveRecord::RecordNotFound)
              raise AvatarOwnerMembershipLockService::AuthorizationDenied unless observed.owner_surface == "org"

              moniker = params.fetch(:avatar, {}).permit(:moniker)[:moniker]
              result =
                AvatarOwnerMembershipLockService.call(
                  actor: avatar_actor, surface: "org", subject_public_id: Actor.selection.account_public_id,
                  owner_collective_public_id: observed.owner_collective_public_id, permission: "avatar.update",
                ) do
                  ::Avatar.transaction do
                    current = AvatarOwnershipPeriodSource.current_for(avatar, lock: true)
                    unless [current.owner_surface, current.owner_collective_public_id] ==
                        [observed.owner_surface, observed.owner_collective_public_id]
                      raise AvatarOwnerMembershipLockService::AuthorizationDenied, "Avatar owner changed"
                    end

                    AvatarMonikerWriterOperation.call(avatar:, moniker:, expected_current: :present)
                  end
                end
              return render(json: { avatar: { public_id: avatar.public_id } }) if result.success?

              errors = result.errors.transform_keys { |key| "avatar.#{key}" }.transform_values(&:first)
              render json: { errors: }, status: :unprocessable_content
            end

            def destroy
              authorize!(selected_avatar!, to: :destroy?)
              head :no_content
            end

            private

            def selected_avatar
              public_id = Actor.selection.avatar_public_id
              return if public_id.blank?

              avatar_switcher.find_avatar(public_id) || raise(ActiveRecord::RecordNotFound)
            end

            def selected_avatar! = selected_avatar || raise(ActiveRecord::RecordNotFound)
          end
        end
      end
    end
  end
end
