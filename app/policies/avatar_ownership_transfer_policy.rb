# typed: false
# frozen_string_literal: true

class AvatarOwnershipTransferPolicy < ApplicationPolicy
  def create?
    return false unless record == AvatarOwnershipTransfer

    avatar = selected_avatar
    owner = avatar&.current_ownership_period
    return false unless owner && owner.owner_surface == surface

    permitted?(owner.owner_collective_public_id, "avatar.transfer.request")
  end

  def accept?
    record.is_a?(AvatarOwnershipTransfer) && record.state == "pending" &&
      record.to_owner_surface == surface &&
      permitted?(record.to_owner_collective_public_id, "avatar.transfer.accept")
  end

  def cancel?
    record.is_a?(AvatarOwnershipTransfer) && record.state == "pending" &&
      record.from_owner_surface == surface &&
      permitted?(record.from_owner_collective_public_id, "avatar.transfer.cancel")
  end

  private

  def selected_avatar
    public_id = Actor.selection.avatar_public_id
    return if public_id.blank?

    Avatar.find_by(public_id: public_id)
  end

  def permitted?(owner_collective_public_id, permission)
    return false unless %w(app org).include?(surface)

    AvatarPermissionResolver.call(
      actor: user,
      surface: surface,
      subject_public_id: Actor.selection.account_public_id,
      owner_collective_public_id: owner_collective_public_id,
      permission: permission,
    )
  end

  def surface
    value = Actor.tld&.to_s
    return value if value == "app" && user.is_a?(Client)
    return value if value == "org" && user.is_a?(Operator)

    nil
  end
end
