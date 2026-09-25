# typed: false
# frozen_string_literal: true

class AvatarGroupPolicy < ApplicationPolicy
  def index?
    selected_owner_permission?("avatar.group.manage")
  end

  def show?
    same_selected_account? && owner_permission?(record, "avatar.group.manage")
  end

  def create?
    selected_owner_permission?("avatar.group.manage")
  end

  def update?
    same_selected_account? && record.active? && owner_permission?(record, "avatar.group.manage")
  end

  def destroy?
    same_selected_account? && record.active? && owner_permission?(record, "avatar.group.manage")
  end

  relation_scope do |relation|
    surface = group_surface
    selection = Actor.selection
    account_public_id = selection.account_public_id
    collective_public_id = selection.collective_public_id
    next relation.none unless selected_owner_permission?("avatar.group.manage")

    relation
      .joins(:current_ownership_period)
      .where(
        account_surface: surface,
        account_public_id: account_public_id,
        avatar_group_ownership_periods: {
          owner_surface: surface,
          owner_collective_public_id: collective_public_id,
        },
      )
  end

  private

  def same_selected_account?
    surface = group_surface
    selection = Actor.selection
    record.is_a?(AvatarGroup) &&
      record.account_surface == surface &&
      record.account_public_id == selection.account_public_id
  end

  def selected_owner_permission?(permission)
    selection = Actor.selection
    return false unless selection.account_public_id.present? && selection.collective_public_id.present?

    permission_for(surface: group_surface, collective_public_id: selection.collective_public_id, permission: permission)
  end

  def owner_permission?(group, permission)
    return false unless group.is_a?(AvatarGroup)

    owner = group.current_ownership_period
    return false unless owner && owner.owner_surface == group_surface

    permission_for(
      surface: owner.owner_surface,
      collective_public_id: owner.owner_collective_public_id,
      permission: permission,
    )
  end

  def permission_for(surface:, collective_public_id:, permission:)
    surface = surface.to_s
    return false unless %w(app org).include?(surface)

    AvatarPermissionResolver.call(
      actor: user,
      surface: surface,
      subject_public_id: Actor.selection.account_public_id,
      owner_collective_public_id: collective_public_id,
      permission: permission,
    )
  end

  def group_surface
    surface = Actor.tld&.to_s
    return surface if surface == "app" && user.is_a?(Client)
    return surface if surface == "org" && user.is_a?(Operator)

    nil
  end
end
