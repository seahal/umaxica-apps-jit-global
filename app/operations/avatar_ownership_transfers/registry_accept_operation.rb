# typed: false
# frozen_string_literal: true

module AvatarOwnershipTransfers
  class RegistryAcceptOperation < Operation
    DETAIL_DATA = {
      "enterprise_to_enterprise" => {
        detail_class: AvatarEnterpriseToEnterpriseTransferDetail,
        source_surface: "app",
        source_attribute: :source_enterprise_public_id,
        destination_surface: "app",
        destination_attribute: :destination_enterprise_public_id,
        destination_period_class: AvatarEnterpriseOwnershipPeriod,
      },
      "enterprise_to_bureau" => {
        detail_class: AvatarEnterpriseToBureauTransferDetail,
        source_surface: "app",
        source_attribute: :source_enterprise_public_id,
        destination_surface: "org",
        destination_attribute: :destination_bureau_public_id,
        destination_period_class: AvatarBureauOwnershipPeriod,
      },
      "bureau_to_enterprise" => {
        detail_class: AvatarBureauToEnterpriseTransferDetail,
        source_surface: "org",
        source_attribute: :source_bureau_public_id,
        destination_surface: "app",
        destination_attribute: :destination_enterprise_public_id,
        destination_period_class: AvatarEnterpriseOwnershipPeriod,
      },
      "bureau_to_bureau" => {
        detail_class: AvatarBureauToBureauTransferDetail,
        source_surface: "org",
        source_attribute: :source_bureau_public_id,
        destination_surface: "org",
        destination_attribute: :destination_bureau_public_id,
        destination_period_class: AvatarBureauOwnershipPeriod,
      },
    }.freeze

    def initialize(actor:, surface:, subject_public_id:, reservation_public_id:)
      super()
      @actor = actor
      @surface = surface.to_s
      @subject_public_id = subject_public_id.to_s
      @reservation_public_id = reservation_public_id.to_s
    end

    public

    def call
      observed = find_reservation!
      definition = detail_definition(observed)
      detail = definition.fetch(:detail_class).find_by!(transfer_reservation_id: observed.id)
      unless definition.fetch(:destination_surface) == surface
        raise Unauthorized, "reservation destination surface does not match the authenticated surface"
      end

      avatar = Avatar.find(observed.avatar_id)
      result = nil
      expired = false
      with_authorized_owner_membership(
        surface: surface,
        actor: actor,
        subject_public_id: subject_public_id,
        owner_collective_public_id: destination_collective_public_id(detail, definition),
        permission: "avatar.transfer.accept",
      ) do
        result, expired = accept_locked_reservation!(
          avatar: avatar,
          observed: observed,
          detail: detail,
          definition: definition,
        )
      end
      raise Expired, "ownership transfer expired" if expired

      result
    end

    private

    attr_reader :actor, :surface, :subject_public_id, :reservation_public_id

    def find_reservation!
      AvatarTransferReservation.find_by(public_id: reservation_public_id) ||
        raise(ActiveRecord::RecordNotFound, "Avatar transfer reservation not found")
    end

    def detail_definition(reservation)
      DETAIL_DATA.fetch(reservation.operation_kind) do
        raise InvalidTransfer, "unsupported transfer operation kind"
      end
    end

    def source_collective_public_id(detail, definition)
      detail.public_send(definition.fetch(:source_attribute))
    end

    def destination_collective_public_id(detail, definition)
      detail.public_send(definition.fetch(:destination_attribute))
    end

    def assert_owner_current!(avatar, detail, definition)
      owner = current_owner!(avatar, lock: true)
      expected = [definition.fetch(:source_surface), source_collective_public_id(detail, definition)]
      return owner if [owner.owner_surface, owner.owner_collective_public_id] == expected

      raise InvalidTransfer, "Avatar owner changed after transfer request"
    end

    def assert_generation_current!(avatar, detail)
      concrete_owner = concrete_current_owner!(avatar, lock: true)
      return concrete_owner if concrete_owner.id == detail.source_ownership_period_id

      raise InvalidTransfer, "Avatar ownership generation changed after transfer request"
    end

    def assert_transfer_instant!(legacy_period, source_period, transfer_at)
      return if transfer_at > legacy_period.valid_from && transfer_at > source_period.valid_from

      raise InvalidTransfer, "transfer instant must advance ownership history"
    end

    def assert_distinct_owners!(detail, definition)
      source = [definition.fetch(:source_surface), source_collective_public_id(detail, definition)]
      destination = [definition.fetch(:destination_surface), destination_collective_public_id(detail, definition)]
      return unless source == destination

      raise InvalidTransfer, "Avatar is already owned by the destination collective"
    end

    def close_legacy_period!(avatar, transfer_at)
      inactive = AvatarOwnershipStatus.find_or_create_by!(id: AvatarOwnershipStatus::INACTIVE)
      current_owner!(avatar, lock: true).update!(valid_to: transfer_at, avatar_ownership_status: inactive)
    end

    def open_legacy_period!(avatar, detail, definition, transfer_at)
      active = AvatarOwnershipStatus.find_or_create_by!(id: AvatarOwnershipStatus::ACTIVE)
      destination = destination_collective_public_id(detail, definition)
      AvatarOwnershipPeriod.create!(
        avatar: avatar,
        owner_organization_id: destination,
        owner_surface: definition.fetch(:destination_surface),
        owner_collective_public_id: destination,
        avatar_ownership_status: active,
        valid_from: transfer_at,
      )
    end

    def close_concrete_period!(source_period, transfer_at)
      source_period.update!(valid_to: transfer_at)
    end

    def open_concrete_period!(avatar, detail, definition, transfer_at)
      attributes = {
        avatar: avatar,
        valid_from: transfer_at,
        transferred_by_actor_public_id: subject_public_id,
      }
      owner_attribute =
        (definition.fetch(:destination_surface) == "app") ? :enterprise_public_id : :bureau_public_id
      attributes[owner_attribute] = destination_collective_public_id(detail, definition)
      definition.fetch(:destination_period_class).create!(**attributes)
    end

    def assert_same_reservation!(locked, observed)
      attributes = %w(public_id avatar_id operation_kind idempotency_key request_fingerprint)
      return if attributes.all? { |attribute| locked.public_send(attribute) == observed.public_send(attribute) }

      raise InvalidTransfer, "transfer reservation identity changed"
    end

    def assert_same_detail!(locked, observed, definition)
      attributes = [
        definition.fetch(:source_attribute),
        definition.fetch(:destination_attribute),
        :source_ownership_period_id,
        :request_actor_public_id,
        :requested_at,
      ]
      return if attributes.all? { |attribute| locked.public_send(attribute) == observed.public_send(attribute) }

      raise InvalidTransfer, "transfer detail identity changed"
    end

    def accepted_replay(reservation)
      return reservation if reservation.state == "accepted"
      return if reservation.state == "pending"

      raise InvalidTransfer, "ownership transfer is already terminal"
    end

    def accept_locked_reservation!(avatar:, observed:, detail:, definition:)
      AvatarRecord.transaction(requires_new: true) do
        locked_avatar = Avatar.lock.find(avatar.id)
        locked = AvatarTransferReservation.lock.find(observed.id)
        locked_detail = definition.fetch(:detail_class).lock.find_by!(transfer_reservation_id: locked.id)
        assert_same_reservation!(locked, observed)
        assert_same_detail!(locked_detail, detail, definition)
        replay = accepted_replay(locked)
        next [replay, false] if replay

        transfer_at = Avatar.database_now
        if locked.expires_at <= transfer_at
          locked.update!(state: "expired", completed_at: transfer_at)
          next [locked, true]
        end

        legacy_period = assert_owner_current!(locked_avatar, locked_detail, definition)
        source_period = assert_generation_current!(locked_avatar, locked_detail)
        assert_transfer_instant!(legacy_period, source_period, transfer_at)
        assert_distinct_owners!(locked_detail, definition)

        close_legacy_period!(locked_avatar, transfer_at)
        open_legacy_period!(locked_avatar, locked_detail, definition, transfer_at)
        close_concrete_period!(source_period, transfer_at)
        open_concrete_period!(locked_avatar, locked_detail, definition, transfer_at)

        locked_detail.update!(accept_actor_public_id: subject_public_id, accepted_at: transfer_at)
        locked.update!(state: "accepted", completed_at: transfer_at)
        [locked, false]
      end
    end
  end
end
