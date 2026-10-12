# typed: false
# frozen_string_literal: true

module AvatarOwnershipTransfers
  class ReservationCreator < ApplicationService
    MAX_IDEMPOTENCY_RACE_RETRIES = 3
    VALID_FOR = 5.days
    IDEMPOTENCY_KEY_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[47][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

    DETAIL_CLASSES = {
      "enterprise_to_enterprise" => AvatarEnterpriseToEnterpriseTransferDetail,
      "enterprise_to_bureau" => AvatarEnterpriseToBureauTransferDetail,
      "bureau_to_enterprise" => AvatarBureauToEnterpriseTransferDetail,
      "bureau_to_bureau" => AvatarBureauToBureauTransferDetail,
    }.freeze

    def initialize(avatar:, operation_kind:, idempotency_key:, request_fingerprint:,
                   source_collective_public_id:, destination_collective_public_id:,
                   request_actor_public_id:, source_ownership_period_id:,
                   requested_at: Avatar.database_now)
      super()
      @avatar = avatar
      @operation_kind = operation_kind.to_s
      @idempotency_key = idempotency_key.to_s
      @request_fingerprint = request_fingerprint.to_s
      @source_collective_public_id = source_collective_public_id.to_s
      @destination_collective_public_id = destination_collective_public_id.to_s
      @request_actor_public_id = request_actor_public_id.to_s
      @source_ownership_period_id = source_ownership_period_id
      @requested_at = requested_at
    end

    public

    def call
      validate_inputs!
      AvatarRecord.connected_to(role: :writing) { call_on_writer }
    end

    private

    def call_on_writer
      attempts = 0

      begin
        AvatarRecord.transaction(requires_new: true) do
          existing = AvatarTransferReservation.lock.find_by(idempotency_key: idempotency_key)
          if existing
            assert_same_request!(existing)
            next existing
          end

          locked_avatar = Avatar.lock.find(avatar.id)
          expire_stale_pending!(locked_avatar)
          reservation = AvatarTransferReservation.create!(
            avatar: locked_avatar,
            operation_kind: operation_kind,
            idempotency_key: idempotency_key,
            request_fingerprint: request_fingerprint,
            state: "pending",
            requested_at: requested_at,
            expires_at: requested_at + VALID_FOR,
          )
          detail_attributes = {
            :transfer_reservation => reservation,
            source_attributes => source_collective_public_id,
            destination_attributes => destination_collective_public_id,
            :request_actor_public_id => request_actor_public_id,
            :source_ownership_period_id => source_ownership_period_id,
            :requested_at => requested_at,
          }
          detail_class.create!(**detail_attributes)
          reservation
        end
      rescue ActiveRecord::RecordNotUnique => e
        raise unless retryable_reservation_constraint?(e)

        attempts += 1
        raise if attempts >= MAX_IDEMPOTENCY_RACE_RETRIES

        retry
      end
    end

    attr_reader :avatar, :operation_kind, :idempotency_key, :request_fingerprint,
                :source_collective_public_id, :destination_collective_public_id,
                :request_actor_public_id, :source_ownership_period_id, :requested_at

    def validate_inputs!
      raise ArgumentError, "avatar is required" unless avatar.is_a?(Avatar)
      raise ArgumentError, "unsupported operation kind" unless detail_class
      raise ArgumentError, "idempotency key must be canonical UUID v4 or v7" unless
        idempotency_key.match?(IDEMPOTENCY_KEY_PATTERN) && idempotency_key == idempotency_key.downcase
      raise ArgumentError, "request fingerprint is required" if request_fingerprint.blank?
      raise ArgumentError, "source collective public id is required" if source_collective_public_id.blank?
      raise ArgumentError, "destination collective public id is required" if destination_collective_public_id.blank?
      raise ArgumentError, "request actor public id is required" if request_actor_public_id.blank?
      raise ArgumentError, "source ownership period is required" if source_ownership_period_id.blank?
      raise ArgumentError, "requested_at is required" if requested_at.blank?
    end

    def detail_class
      DETAIL_CLASSES[operation_kind]
    end

    def source_attributes
      operation_kind.start_with?("enterprise") ? :source_enterprise_public_id : :source_bureau_public_id
    end

    def destination_attributes
      operation_kind.end_with?("enterprise") ? :destination_enterprise_public_id : :destination_bureau_public_id
    end

    def assert_same_request!(existing)
      detail = detail_class.find_by!(transfer_reservation_id: existing.id)
      same_request = existing.avatar_id == avatar.id &&
        existing.operation_kind == operation_kind &&
        existing.request_fingerprint == request_fingerprint &&
        detail.public_send(source_attributes) == source_collective_public_id &&
        detail.public_send(destination_attributes) == destination_collective_public_id &&
        detail.source_ownership_period_id == source_ownership_period_id &&
        detail.request_actor_public_id == request_actor_public_id
      return if same_request

      raise InvalidTransfer, "idempotency key is already bound to different transfer inputs"
    end

    def expire_stale_pending!(locked_avatar)
      pending = AvatarTransferReservation.pending
        .where(avatar_id: locked_avatar.id)
        .lock
        .first
      return unless pending && pending.expires_at <= requested_at

      pending.update!(state: "expired", completed_at: requested_at)
    end

    def retryable_reservation_constraint?(error)
      %w(
        idx_avatar_transfer_reservations_idempotency
        idx_avatar_transfer_reservations_one_pending_avatar
      ).include?(constraint_name(error))
    end

    def constraint_name(error)
      result = error.cause&.result
      result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    end
  end
end
