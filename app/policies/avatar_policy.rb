# typed: false
# frozen_string_literal: true

class AvatarPolicy < ApplicationPolicy
  def index?
    permission_for_selected_collective?("avatar.view")
  end

  def show?
    permission_for_avatar?("avatar.view")
  end

  def create?
    permission_for_selected_collective?("avatar.update")
  end

  def update?
    permission_for_avatar?("avatar.update")
  end

  relation_scope do |relation|
    surface = avatar_surface
    collective_public_id = Actor.selection.collective_public_id
    next relation.none unless permission_for_selected_collective?("avatar.view")

    relation
      .joins(:current_ownership_period, :lifecycle_state)
      .where(
        avatar_ownership_periods: {
          owner_surface: surface,
          owner_collective_public_id: collective_public_id,
        },
        avatar_lifecycle_states: { key: "active" },
      )
      .where("avatars.discard_at > ?", Time.current)
  end

  private

  def permission_for_avatar?(permission)
    return false unless user && record.is_a?(Avatar)

    ownership = record.current_ownership_period
    return false unless ownership

    surface = avatar_surface
    return false unless ownership.owner_surface == surface
    return false unless record.lifecycle_state&.key == "active" && record.accessible?

    AvatarPermissionResolver.call(
      actor: user,
      surface: surface,
      subject_public_id: Actor.selection.account_public_id,
      owner_collective_public_id: ownership.owner_collective_public_id,
      permission: permission,
    )
  end

  def permission_for_selected_collective?(permission)
    surface = avatar_surface
    collective_public_id = Actor.selection.collective_public_id
    return false if collective_public_id.blank?

    AvatarPermissionResolver.call(
      actor: user,
      surface: surface,
      subject_public_id: Actor.selection.account_public_id,
      owner_collective_public_id: collective_public_id,
      permission: permission,
    )
  end

  def avatar_surface
    surface = Actor.tld&.to_s
    return surface if surface == "app" && user.is_a?(Client)
    return surface if surface == "org" && user.is_a?(Operator)

    nil
  end
end
