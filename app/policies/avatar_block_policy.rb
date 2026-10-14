# typed: false
# frozen_string_literal: true

class AvatarBlockPolicy < ApplicationPolicy
  def create?
    actor_avatar = user
    target_avatar = record&.blocked_avatar
    actor_avatar.is_a?(Avatar) &&
      target_avatar.is_a?(Avatar) &&
      active_avatar?(actor_avatar) &&
      active_avatar?(target_avatar) &&
      actor_avatar != target_avatar
  end

  def destroy?
    actor_avatar = user
    record.present? && actor_avatar.is_a?(Avatar) && record.blocker_avatar_id == actor_avatar.id
  end

  private

  def active_avatar?(avatar)
    AvatarLifecycleState.exists?(id: avatar.lifecycle_state_id, key: "active") && avatar.accessible?
  end
end
