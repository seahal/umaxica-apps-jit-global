# typed: false
# frozen_string_literal: true

module GroupAvatarMemberships
  class Attach < ApplicationService
    AuthorizationDenied = AvatarOwnerMembershipLockService::AuthorizationDenied

    def initialize(group:, avatar:, actor:, surface:, subject_public_id:, account_public_id:, position: nil)
      super()
      @group = group
      @avatar = avatar
      @actor = actor
      @surface = surface.to_s
      @subject_public_id = subject_public_id.to_s
      @account_public_id = account_public_id.to_s
      @position = position
    end

    def call
      observed_group_owner = AvatarGroupOwnershipPeriod.current.find_by!(avatar_group_id: group.id)
      unless observed_group_owner.owner_surface == surface
        raise AuthorizationDenied, "group owner surface does not match actor surface"
      end

      AvatarOwnerMembershipLockService.call(
        actor: actor,
        surface: surface,
        subject_public_id: subject_public_id,
        owner_collective_public_id: observed_group_owner.owner_collective_public_id,
        permission: "avatar.group.attach",
      ) do
        Avatar.transaction do
          locked_group = AvatarGroup.lock.find(group.id)
          locked_avatar = Avatar.lock.find(avatar.id)
          raise ArgumentError, "group is not active" unless locked_group.active?
          raise ArgumentError, "avatar is not active" unless active_avatar?(locked_avatar)

          authorize_same_owner!(locked_group, locked_avatar, observed_group_owner)

          GroupAvatarMembership.create!(
            avatar_group: locked_group,
            avatar: locked_avatar,
            role: GroupAvatarMembership::ROLE,
            position: position || next_position(locked_group),
            state: "active",
          )
        end
      end
    end

    private

    attr_reader :group, :avatar, :actor, :surface, :subject_public_id, :account_public_id, :position

    def active_avatar?(record)
      record.lifecycle_state&.key == "active" && record.accessible?
    end

    def authorize_same_owner!(locked_group, locked_avatar, observed_group_owner)
      unless %w(app org).include?(surface) &&
          account_public_id.present? && account_public_id == subject_public_id &&
          locked_group.account_surface == surface && locked_group.account_public_id == account_public_id
        raise AuthorizationDenied, "group account scope does not match actor context"
      end

      group_owner = AvatarGroupOwnershipPeriod.current.lock.find_by(avatar_group_id: locked_group.id)
      avatar_owner = AvatarOwnershipPeriod.current
        .where(avatar_ownership_status_id: AvatarOwnershipStatus::ACTIVE)
        .lock
        .find_by(avatar_id: locked_avatar.id)
      raise ArgumentError, "current owner missing" unless group_owner && avatar_owner
      unless [group_owner.owner_surface, group_owner.owner_collective_public_id] ==
          [observed_group_owner.owner_surface, observed_group_owner.owner_collective_public_id]
        raise AuthorizationDenied, "group owner changed while attaching Avatar"
      end
      unless group_owner.owner_surface == surface &&
          [group_owner.owner_surface, group_owner.owner_collective_public_id] ==
              [avatar_owner.owner_surface, avatar_owner.owner_collective_public_id]
        raise ArgumentError, "group and Avatar current owners differ"
      end
    end

    def next_position(locked_group)
      locked_group.group_avatar_memberships.active.maximum(:position).to_i + 1
    end
  end
end
