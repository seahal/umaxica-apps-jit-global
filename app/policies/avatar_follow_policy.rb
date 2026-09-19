# typed: false
# frozen_string_literal: true

class AvatarFollowPolicy < ApplicationPolicy
  def create?
    actor_avatar = user
    target_avatar = record.try(:followed_avatar)
    return false unless actor_avatar.is_a?(Avatar) && target_avatar.is_a?(Avatar)
    return false unless active_avatar?(actor_avatar) && active_avatar?(target_avatar)
    return false if actor_avatar == target_avatar
    return false if actor_avatar.blocked_avatars.exists?(id: target_avatar.id)
    return false if target_avatar.blocked_avatars.exists?(id: actor_avatar.id)

    true
  end

  def destroy?
    actor_avatar = user
    record.present? && actor_avatar.is_a?(Avatar) && record.follower_avatar_id == actor_avatar.id
  end

  private

  def active_avatar?(avatar)
    return false unless avatar.is_a?(Avatar)

    avatar.lifecycle_state&.key == "active" && avatar.accessible?
  end
end
