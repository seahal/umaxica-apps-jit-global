# typed: false
# frozen_string_literal: true

class GroupAvatarMembershipPolicy < ApplicationPolicy
  def create?
    user.is_a?(Client) || user.is_a?(Operator) ? authorized_group_change?("avatar.group.attach", require_same_owner: true) : false
  end

  def update?
    record.is_a?(GroupAvatarMembership) && record.active? &&
      authorized_group_change?("avatar.group.manage", require_same_owner: true)
  end

  def destroy?
    record.is_a?(GroupAvatarMembership) && record.active? &&
      authorized_group_change?("avatar.group.detach", require_same_owner: false)
  end

  private

  def authorized_group_change?(permission, require_same_owner:)
    group = record.respond_to?(:avatar_group) ? record.avatar_group : nil
    avatar = record.respond_to?(:avatar) ? record.avatar : nil
    return false unless group.is_a?(AvatarGroup) && group.active?

    surface = Actor.tld&.to_s
    selection = Actor.selection
    account_public_id = selection.account_public_id
    return false unless %w(app org).include?(surface)
    return false unless [Client, Operator].any? { |principal_class| user.is_a?(principal_class) }
    return false unless group.account_surface == surface &&
      group.account_public_id == account_public_id && account_public_id.present?

    group_owner = group.current_ownership_period
    return false unless group_owner && group_owner.owner_surface == surface

    if require_same_owner
      return false unless avatar.is_a?(Avatar) && active_avatar?(avatar)

      avatar_owner = avatar.current_ownership_period
      return false unless avatar_owner
      return false unless [group_owner.owner_surface, group_owner.owner_collective_public_id] ==
        [avatar_owner.owner_surface, avatar_owner.owner_collective_public_id]
    end

    AvatarPermissionResolver.call(
      actor: user,
      surface: surface,
      subject_public_id: account_public_id,
      owner_collective_public_id: group_owner.owner_collective_public_id,
      permission: permission,
    )
  end

  def active_avatar?(avatar)
    avatar.lifecycle_state&.key == "active" && avatar.accessible?
  end
end
