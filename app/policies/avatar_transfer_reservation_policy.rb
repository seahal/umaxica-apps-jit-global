# typed: false
# frozen_string_literal: true

class AvatarTransferReservationPolicy < ApplicationPolicy
  DETAIL_DATA = AvatarOwnershipTransfers::RegistryAcceptOperation::DETAIL_DATA

  public

  def accept?
    permitted_registry_transition?(permission: "avatar.transfer.accept", role: :destination)
  end

  def cancel?
    permitted_registry_transition?(permission: "avatar.transfer.cancel", role: :source)
  end

  private

  def permitted_registry_transition?(permission:, role:)
    return false unless record.is_a?(AvatarTransferReservation) && record.state == "pending"

    definition = DETAIL_DATA[record.operation_kind]
    return false unless definition
    return false unless definition.fetch(transition_surface_key(role)) == surface

    detail = definition.fetch(:detail_class).find_by(transfer_reservation_id: record.id)
    return false unless detail

    collective_public_id = detail.public_send(definition.fetch(role_attribute(role)))
    AvatarPermissionResolver.call(
      actor: user,
      surface: surface,
      subject_public_id: Actor.selection.account_public_id,
      owner_collective_public_id: collective_public_id,
      permission: permission,
    )
  end

  def transition_surface_key(role)
    (role == :destination) ? :destination_surface : :source_surface
  end

  def role_attribute(role)
    (role == :destination) ? :destination_attribute : :source_attribute
  end

  def surface
    value = Actor.tld&.to_s
    return value if value == "app" && user.is_a?(Client)
    return value if value == "org" && user.is_a?(Operator)

    nil
  end
end
