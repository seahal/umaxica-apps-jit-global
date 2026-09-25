# typed: false
# frozen_string_literal: true

module Base
  module App
    class GroupAvatarMembershipsController < Base::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      rescue_from AvatarOwnerMembershipLockService::AuthorizationDenied, with: :forbid_owner_mutation

      before_action :authenticate_client!
      before_action :set_group
      before_action :set_membership, only: %i(update destroy)

      def create
        avatar = Avatar.find_by!(public_id: membership_params.fetch(:avatar_public_id))
        membership = GroupAvatarMembership.new(avatar_group: @group, avatar: avatar)
        authorize!(membership, to: :create?)

        membership = GroupAvatarMemberships::Attach.call(
          group: @group,
          avatar: avatar,
          actor: current_client,
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
          actor: current_client,
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
          actor: current_client,
          surface: "app",
          subject_public_id: Actor.selection.account_public_id,
          account_public_id: Actor.selection.account_public_id,
        )
        head :no_content
      end

      private

      def forbid_owner_mutation
        head :forbidden
      end

      def set_group
        @group = AvatarGroup.includes(:current_ownership_period).find_by!(public_id: params.expect(:group_id))
      end

      def set_membership
        @membership = @group.group_avatar_memberships
          .includes(avatar: %i(current_ownership_period lifecycle_state))
          .find_by!(public_id: params.expect(:id))
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
