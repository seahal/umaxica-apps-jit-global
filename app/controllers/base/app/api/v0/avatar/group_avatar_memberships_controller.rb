# typed: false
# frozen_string_literal: true

module Base
  module App
    module Api
      module V0
        module Avatar
          # Avatar owner endpoint for the app Base Self-RP (R5-WU14), moved from the former in-process
          # page with the same policy, relation scope and GroupManagement/GroupAvatarMemberships rules.
          class GroupAvatarMembershipsController < ActionController::API
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
            before_action :verify_avatar_persona!
            rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
            rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
            rescue_from ActionController::ParameterMissing, with: :render_bad_request

            rescue_from AvatarOwnerMembershipLockService::AuthorizationDenied, with: :forbid_owner_mutation

            before_action :set_group
            before_action :set_membership, only: %i(update destroy)

            public

            def create
              avatar = ::Avatar.find_by!(public_id: membership_params.fetch(:avatar_public_id))
              membership = GroupAvatarMembership.new(avatar_group: @group, avatar: avatar)
              authorize!(membership, to: :create?)

              membership = GroupAvatarMemberships::Attach.call(
                group: @group,
                avatar: avatar,
                actor: avatar_actor,
                surface: "app",
                subject_public_id: Actor.selection.account_public_id,
                account_public_id: Actor.selection.account_public_id,
                position: membership_params[:position],
              )
              render json: { membership: serialize_membership(membership) }, status: :created
            end

            def update
              authorize!(@membership, to: :update?)
              membership = GroupAvatarMemberships::Reorder.call(
                membership: @membership,
                position: membership_params.fetch(:position),
                actor: avatar_actor,
                surface: "app",
                subject_public_id: Actor.selection.account_public_id,
                account_public_id: Actor.selection.account_public_id,
              )
              render json: { membership: serialize_membership(membership) }
            end

            def destroy
              authorize!(@membership, to: :destroy?)
              GroupAvatarMemberships::Detach.call(
                membership: @membership,
                actor: avatar_actor,
                surface: "app",
                subject_public_id: Actor.selection.account_public_id,
                account_public_id: Actor.selection.account_public_id,
              )
              head :no_content
            end

            private

            def forbid_owner_mutation = render_owner_denied

            def set_group
              @group = ::AvatarGroup.find_by!(public_id: params.expect(:group_ref))
            end

            def set_membership
              @membership = @group.group_avatar_memberships
                .includes(avatar: %i(current_ownership_period lifecycle_state))
                .find_by!(public_id: params.expect(:ref))
            end

            def membership_params
              params.expect(membership: %i(avatar_public_id position))
            end

            def serialize_membership(membership)
              {
                public_id: membership.public_id,
                group_public_id: membership.avatar_group.public_id,
                avatar_public_id: membership.avatar.public_id,
                role: membership.role,
                position: membership.position,
                state: membership.state,
              }
            end
          end
        end
      end
    end
  end
end
