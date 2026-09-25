# typed: false
# frozen_string_literal: true

module GroupAvatarMemberships
  class Detach < ApplicationService
    AuthorizationDenied = AvatarOwnerMembershipLockService::AuthorizationDenied

    def initialize(membership:, actor:, surface:, subject_public_id:, account_public_id:)
      super()
      @membership = membership
      @actor = actor
      @surface = surface.to_s
      @subject_public_id = subject_public_id.to_s
      @account_public_id = account_public_id.to_s
    end

    def call
      observed_membership = GroupAvatarMembership.find(membership.id)
      observed_group_owner = AvatarGroupOwnershipPeriod.current.find_by!(
        avatar_group_id: observed_membership.avatar_group_id,
      )
      unless observed_group_owner.owner_surface == surface
        raise AuthorizationDenied, "group owner surface does not match actor surface"
      end

      AvatarOwnerMembershipLockService.call(
        actor: actor,
        surface: surface,
        subject_public_id: subject_public_id,
        owner_collective_public_id: observed_group_owner.owner_collective_public_id,
        permission: "avatar.group.detach",
      ) do
        Avatar.transaction do
          current_membership = GroupAvatarMembership.find(membership.id)
          unless current_membership.avatar_group_id == observed_membership.avatar_group_id
            raise ArgumentError, "membership group changed while detaching"
          end

          group = AvatarGroup.lock.find(current_membership.avatar_group_id)
          locked_membership = GroupAvatarMembership.lock.find(membership.id)
          unless locked_membership.avatar_group_id == group.id
            raise ArgumentError, "membership group changed while detaching"
          end

          authorize_group_owner!(group, observed_group_owner)
          next locked_membership unless locked_membership.active?

          locked_membership.update!(state: "removed", removed_at: Time.current)
          locked_membership
        end
      end
    end

    private

    attr_reader :membership, :actor, :surface, :subject_public_id, :account_public_id

    def authorize_group_owner!(group, observed_group_owner)
      unless %w(app org).include?(surface) && account_public_id.present? &&
          account_public_id == subject_public_id && group.account_surface == surface &&
          group.account_public_id == account_public_id
        raise AuthorizationDenied, "group account scope does not match actor context"
      end

      owner = AvatarGroupOwnershipPeriod.current.lock.find_by(avatar_group_id: group.id)
      raise ArgumentError, "current group owner missing" unless owner && owner.owner_surface == surface
      return if [owner.owner_surface, owner.owner_collective_public_id] ==
        [observed_group_owner.owner_surface, observed_group_owner.owner_collective_public_id]

      raise AuthorizationDenied, "current group owner changed while detaching"
    end
  end
end
