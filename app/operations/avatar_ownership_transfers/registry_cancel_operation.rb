# typed: false
# frozen_string_literal: true

module AvatarOwnershipTransfers
  class RegistryCancelOperation < Operation
    DETAIL_DATA = {
      "enterprise_to_enterprise" => {
        detail_class: AvatarEnterpriseToEnterpriseTransferDetail,
        source_surface: "app",
        source_attribute: :source_enterprise_public_id,
      },
      "enterprise_to_bureau" => {
        detail_class: AvatarEnterpriseToBureauTransferDetail,
        source_surface: "app",
        source_attribute: :source_enterprise_public_id,
      },
      "bureau_to_enterprise" => {
        detail_class: AvatarBureauToEnterpriseTransferDetail,
        source_surface: "org",
        source_attribute: :source_bureau_public_id,
      },
      "bureau_to_bureau" => {
        detail_class: AvatarBureauToBureauTransferDetail,
        source_surface: "org",
        source_attribute: :source_bureau_public_id,
      },
    }.freeze

    def initialize(actor:, surface:, subject_public_id:, reservation_public_id:, at: Avatar.database_now,
                   step_up_token: nil, step_up_requirement: nil)
      super()
      @actor = actor
      @surface = surface.to_s
      @subject_public_id = subject_public_id.to_s
      @reservation_public_id = reservation_public_id.to_s
      @at = at
      @step_up_token = step_up_token
      @step_up_requirement = step_up_requirement
    end

    public

    def call
      validate_step_up_context!(
        actor: actor, surface: surface, scope: "avatar_transfer_cancel",
        token: step_up_token, requirement: step_up_requirement,
      )
      observed = find_reservation!
      definition = detail_definition(observed)
      detail = definition.fetch(:detail_class).find_by!(transfer_reservation_id: observed.id)
      unless definition.fetch(:source_surface) == surface
        raise Unauthorized, "reservation source surface does not match the authenticated surface"
      end

      avatar = Avatar.find(observed.avatar_id)
      result = nil
      with_authorized_owner_membership(
        surface: surface,
        actor: actor,
        subject_public_id: subject_public_id,
        owner_collective_public_id: detail.public_send(definition.fetch(:source_attribute)),
        permission: "avatar.transfer.cancel",
      ) do
        result = cancel_locked!(
          observed: observed,
          definition: definition,
          detail: detail,
          avatar: avatar,
        )
      end
      result
    end

    private

    attr_reader :actor, :surface, :subject_public_id, :reservation_public_id, :at,
                :step_up_token, :step_up_requirement

    def cancel_locked!(observed:, definition:, detail:, avatar:)
      result = nil
      AvatarRecord.transaction(requires_new: true) do
        locked_avatar = Avatar.lock.find(avatar.id)
        locked = AvatarTransferReservation.lock.find(observed.id)
        locked_detail = definition.fetch(:detail_class).lock.find_by!(transfer_reservation_id: locked.id)
        assert_same_reservation!(locked, observed)
        assert_same_detail!(locked_detail, detail, definition.fetch(:source_attribute))
        raise InvalidTransfer, "ownership transfer is already terminal" unless locked.state == "pending"

        assert_owner_current!(locked_avatar, definition, detail)
        assert_generation_current!(locked_avatar, detail)
        state = expired?(locked) ? "expired" : "cancelled"
        locked.update!(state:, completed_at: at)
        consume_step_up!(step_up_token, step_up_requirement) if state == "cancelled"
        result = locked
      end
      raise Expired, "ownership transfer expired" if result.state == "expired"

      result
    end

    def assert_owner_current!(avatar, definition, detail)
      owner = current_owner!(avatar, lock: true)
      return if [owner.owner_surface, owner.owner_collective_public_id] ==
        [definition.fetch(:source_surface), detail.public_send(definition.fetch(:source_attribute))]

      raise InvalidTransfer, "Avatar owner changed after transfer request"
    end

    def assert_generation_current!(avatar, detail)
      concrete_owner = concrete_current_owner!(avatar, lock: true)
      return if concrete_owner.id == detail.source_ownership_period_id

      raise InvalidTransfer, "Avatar ownership generation changed after transfer request"
    end

    def expired?(reservation)
      reservation.expires_at <= at
    end

    def find_reservation!
      AvatarTransferReservation.find_by(public_id: reservation_public_id) ||
        raise(ActiveRecord::RecordNotFound, "Avatar transfer reservation not found")
    end

    def detail_definition(reservation)
      DETAIL_DATA.fetch(reservation.operation_kind) do
        raise InvalidTransfer, "unsupported transfer operation kind"
      end
    end

    def assert_same_reservation!(locked, observed)
      attributes = %w(public_id avatar_id operation_kind idempotency_key request_fingerprint)
      return if attributes.all? { |attribute| locked.public_send(attribute) == observed.public_send(attribute) }

      raise InvalidTransfer, "transfer reservation identity changed"
    end

    def assert_same_detail!(locked, observed, source_attribute)
      attributes = [source_attribute, :source_ownership_period_id, :request_actor_public_id, :requested_at]
      return if attributes.all? { |attribute| locked.public_send(attribute) == observed.public_send(attribute) }

      raise InvalidTransfer, "transfer detail identity changed"
    end
  end
end
