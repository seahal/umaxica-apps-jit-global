# typed: false
# frozen_string_literal: true

module GroupAvatarMemberships
  class Reorder < ApplicationService
    AuthorizationDenied = AvatarOwnerMembershipLockService::AuthorizationDenied

    def initialize(membership:, position:, actor:, surface:, subject_public_id:, account_public_id:)
      super()
      @membership = membership
      @position = Integer(position)
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
        permission: "avatar.group.manage",
      ) do
        Avatar.transaction do
          current_membership = GroupAvatarMembership.find(membership.id)
          unless current_membership.avatar_group_id == observed_membership.avatar_group_id &&
              current_membership.avatar_id == observed_membership.avatar_id
            raise ArgumentError, "membership ownership changed while reordering"
          end

          group = AvatarGroup.lock.find(current_membership.avatar_group_id)
          avatar = Avatar.lock.find(current_membership.avatar_id)
          locked_membership = GroupAvatarMembership.lock.find(membership.id)
          unless locked_membership.avatar_group_id == group.id && locked_membership.avatar_id == avatar.id
            raise ArgumentError, "membership ownership changed while reordering"
          end
          raise ArgumentError, "membership is not active" unless locked_membership.active?
          raise ArgumentError, "group is not active" unless group.active?
          raise ArgumentError, "position must be non-negative" if position.negative?

          authorize_same_owner!(group, avatar, observed_group_owner)

          locked_membership.update!(position: position)
          locked_membership
        end
      end
    end

    private

    attr_reader :membership, :position, :actor, :surface, :subject_public_id, :account_public_id

    def authorize_same_owner!(group, avatar, observed_group_owner)
      unless %w(app org).include?(surface) && account_public_id.present? &&
          account_public_id == subject_public_id && group.account_surface == surface &&
          group.account_public_id == account_public_id
        raise AuthorizationDenied, "group account scope does not match actor context"
      end

      group_owner = AvatarGroupOwnershipPeriod.current.lock.find_by(avatar_group_id: group.id)
      avatar_owner = AvatarOwnershipPeriod.current
        .where(avatar_ownership_status_id: AvatarOwnershipStatus::ACTIVE)
        .lock
        .find_by(avatar_id: avatar.id)
      raise ArgumentError, "current owner missing" unless group_owner && avatar_owner
      unless [group_owner.owner_surface, group_owner.owner_collective_public_id] ==
          [observed_group_owner.owner_surface, observed_group_owner.owner_collective_public_id]
        raise AuthorizationDenied, "group owner changed while reordering"
      end
      unless group_owner.owner_surface == surface &&
          [group_owner.owner_surface, group_owner.owner_collective_public_id] ==
              [avatar_owner.owner_surface, avatar_owner.owner_collective_public_id]
        raise ArgumentError, "group and Avatar current owners differ"
      end
    end
  end
end
