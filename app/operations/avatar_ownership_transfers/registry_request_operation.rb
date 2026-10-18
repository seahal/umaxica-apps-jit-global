# typed: false
# frozen_string_literal: true

module AvatarOwnershipTransfers
  class RegistryRequestOperation < Operation
    def initialize(actor:, surface:, subject_public_id:, avatar_public_id:, target_surface:,
                   target_collective_public_id:, idempotency_key:, request_fingerprint:,
                   requested_at: Avatar.database_now)
      super()
      @actor = actor
      @surface = surface.to_s
      @subject_public_id = subject_public_id.to_s
      @avatar_public_id = avatar_public_id.to_s
      @target_surface = target_surface.to_s
      @target_collective_public_id = target_collective_public_id.to_s
      @idempotency_key = idempotency_key.to_s
      @request_fingerprint = request_fingerprint.to_s
      @requested_at = requested_at
    end

    public

    def call
      validate_idempotency_key!
      validate_request_fingerprint!
      replay = replay_existing_reservation
      return replay if replay

      validate_target!
      avatar = find_avatar!(avatar_public_id)
      observed_owner = current_owner!(avatar)
      observed_concrete_owner = concrete_current_owner!(avatar)
      unless observed_owner.owner_surface == surface
        raise Unauthorized, "selected actor is outside the Avatar's current owner surface"
      end

      assert_concrete_owner_matches!(observed_owner, observed_concrete_owner)

      result = nil
      with_authorized_owner_membership(
        surface: surface,
        actor: actor,
        subject_public_id: subject_public_id,
        owner_collective_public_id: observed_owner.owner_collective_public_id,
        permission: "avatar.transfer.request",
      ) do
        AvatarRecord.transaction(requires_new: true) do
          locked_avatar = Avatar.lock.find(avatar.id)
          assert_eligible_avatar!(locked_avatar)
          owner = current_owner!(locked_avatar, lock: true)
          assert_owner_unchanged!(owner, observed_owner)
          concrete_owner = concrete_current_owner!(locked_avatar, lock: true)
          assert_concrete_owner_unchanged!(concrete_owner, observed_concrete_owner)
          if [owner.owner_surface, owner.owner_collective_public_id] ==
              [target_surface, target_collective_public_id]
            raise InvalidTransfer, "Avatar is already owned by the target collective"
          end

          result = ReservationCreator.call(
            avatar: locked_avatar,
            operation_kind: operation_kind,
            idempotency_key: idempotency_key,
            request_fingerprint: request_fingerprint,
            source_collective_public_id: owner.owner_collective_public_id,
            destination_collective_public_id: target_collective_public_id,
            request_actor_public_id: authorized_initiator_public_id,
            source_ownership_period_id: concrete_owner.id,
            requested_at: requested_at,
          )
        end
      end
      result
    end

    private

    attr_reader :actor, :surface, :subject_public_id, :avatar_public_id,
                :target_surface, :target_collective_public_id, :idempotency_key,
                :request_fingerprint, :requested_at

    def authorized_initiator_public_id
      public_id = actor.respond_to?(:public_id) ? actor.public_id.to_s : ""
      return public_id if public_id.present?

      raise InvalidTransfer, "authorized transfer initiator is missing"
    end

    def validate_target!
      raise InvalidTransfer, "unsupported target surface" unless OWNER_DATA.key?(target_surface)
      raise InvalidTransfer, "target collective public id is required" if target_collective_public_id.blank?
      return if collective_exists?(surface: target_surface, public_id: target_collective_public_id)

      raise InvalidTransfer, "target collective not found"
    end

    def validate_idempotency_key!
      return if idempotency_key.match?(ReservationCreator::IDEMPOTENCY_KEY_PATTERN) &&
        idempotency_key == idempotency_key.downcase

      raise InvalidTransfer, "idempotency key must be canonical UUID v4 or v7"
    end

    def validate_request_fingerprint!
      expected = Digest::SHA256.hexdigest(
        [
          "avatar_transfer",
          surface,
          authorized_initiator_public_id,
          subject_public_id,
          avatar_public_id,
          target_surface,
          target_collective_public_id,
        ].join("\0"),
      )
      return if request_fingerprint.bytesize == expected.bytesize &&
        ActiveSupport::SecurityUtils.secure_compare(request_fingerprint, expected)

      raise InvalidTransfer, "request fingerprint does not match transfer inputs"
    end

    def existing_reservation
      AvatarTransferReservation.find_by(idempotency_key: idempotency_key)
    end

    def replay_existing_reservation
      existing = existing_reservation
      return unless existing

      assert_replay_identity!(existing)
      existing
    end

    def assert_replay_identity!(reservation)
      detail = reservation_detail(reservation)
      avatar = Avatar.find_by(id: reservation.avatar_id)
      destination_attribute =
        if operation_kind.end_with?("enterprise")
          :destination_enterprise_public_id
        else
          :destination_bureau_public_id
        end
      same_request = reservation.request_fingerprint == request_fingerprint &&
        reservation.operation_kind == operation_kind &&
        avatar.public_id == avatar_public_id &&
        detail.request_actor_public_id == authorized_initiator_public_id &&
        detail.public_send(destination_attribute) == target_collective_public_id
      return if same_request

      raise InvalidTransfer, "idempotency key is already bound to different transfer inputs"
    end

    def reservation_detail(reservation)
      detail_class =
        ReservationCreator::DETAIL_CLASSES.fetch(reservation.operation_kind) do
          raise InvalidTransfer, "unsupported transfer operation kind"
        end
      detail_class.find_by!(transfer_reservation_id: reservation.id)
    end

    def assert_owner_unchanged!(current, observed)
      return if [current.owner_surface, current.owner_collective_public_id] ==
        [observed.owner_surface, observed.owner_collective_public_id]

      raise InvalidTransfer, "Avatar ownership changed while the transfer request was starting"
    end

    def assert_concrete_owner_matches!(owner, concrete_owner)
      expected_class = concrete_period_class_for(owner.owner_surface)
      expected_column = (owner.owner_surface == "app") ? :enterprise_public_id : :bureau_public_id
      return if concrete_owner.class == expected_class &&
        concrete_owner.public_send(expected_column) == owner.owner_collective_public_id

      raise InvalidTransfer, "Avatar concrete owner does not match its ownership authority"
    end

    def assert_concrete_owner_unchanged!(current, observed)
      return if current.class == observed.class && current.id == observed.id

      raise InvalidTransfer, "Avatar concrete owner changed while the transfer request was starting"
    end

    def operation_kind
      source = (surface == "app") ? "enterprise" : "bureau"
      destination = (target_surface == "app") ? "enterprise" : "bureau"
      "#{source}_to_#{destination}"
    end
  end
end
