# typed: false
# frozen_string_literal: true

require "test_helper"
require "timeout"
require_relative "../support/avatar_test_factory"

class AvatarTransferReservationTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "a concrete detail completes one transfer reservation" do
    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Transfer reg",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "transfer-registry-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      source_period = enterprise_period_for(avatar, "enterprise_source_1")
      reservation = AvatarTransferReservation.create!(
        avatar: avatar,
        operation_kind: "enterprise_to_bureau",
        idempotency_key: SecureRandom.uuid,
        request_fingerprint: Digest::SHA256.hexdigest("registry-request"),
      )
      detail = AvatarEnterpriseToBureauTransferDetail.create!(
        transfer_reservation: reservation,
        source_enterprise_public_id: "enterprise_source_1",
        source_ownership_period: source_period,
        destination_bureau_public_id: "bureau_destination_1",
        request_actor_public_id: "persona_actor_1",
      )

      AvatarRecord.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")

      assert_equal reservation, detail.transfer_reservation
      assert_equal "enterprise_to_bureau", reservation.operation_kind
      raise ActiveRecord::Rollback
    end
  end

  test "one pending reservation is shared across all transfer directions" do
    error = nil

    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Pending registry",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "pending-registry-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      AvatarTransferReservation.create!(
        avatar: avatar,
        operation_kind: "enterprise_to_enterprise",
        idempotency_key: SecureRandom.uuid,
        request_fingerprint: Digest::SHA256.hexdigest("pending-1"),
      )
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarTransferReservation.create!(
            avatar: avatar,
            operation_kind: "bureau_to_bureau",
            idempotency_key: SecureRandom.uuid,
            request_fingerprint: Digest::SHA256.hexdigest("pending-2"),
          )
        end
      raise ActiveRecord::Rollback
    end

    assert_match(/unique|pending|avatar/i, error.message)
  end

  test "an idempotency key is unique across different Avatars" do
    error = nil
    key = SecureRandom.uuid

    AvatarRecord.transaction do
      first = AvatarTestFactory.create!(
        moniker: "First registry",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "first-registry-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      second = AvatarTestFactory.create!(
        moniker: "Second registry",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "second-registry-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      AvatarTransferReservation.create!(
        avatar: first,
        operation_kind: "enterprise_to_bureau",
        idempotency_key: key,
        request_fingerprint: Digest::SHA256.hexdigest("same-key-1"),
      )
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarTransferReservation.create!(
            avatar: second,
            operation_kind: "bureau_to_enterprise",
            idempotency_key: key,
            request_fingerprint: Digest::SHA256.hexdigest("same-key-2"),
          )
        end
      raise ActiveRecord::Rollback
    end

    assert_match(/unique|idempotency/i, error.message)
  end

  test "a committed reservation must have exactly one matching concrete detail" do
    error = nil

    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Orphan registry",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "orphan-registry-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      AvatarTransferReservation.create!(
        avatar: avatar,
        operation_kind: "enterprise_to_enterprise",
        idempotency_key: SecureRandom.uuid,
        request_fingerprint: Digest::SHA256.hexdigest("orphan"),
      )

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarRecord.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
        end
      raise ActiveRecord::Rollback
    end

    assert_match(/detail|reservation|cardinality/i, error.message)
  end

  test "database rejects a detail whose source ownership period belongs to another Avatar" do
    error = nil

    AvatarRecord.transaction(requires_new: true) do
      first_avatar = AvatarTestFactory.create!(
        moniker: "Reservation",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "reservation-owner-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      second_avatar = AvatarTestFactory.create!(
        moniker: "Foreign source",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "foreign-source-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      foreign_period = enterprise_period_for(second_avatar, "foreign_enterprise")
      reservation = AvatarTransferReservation.create!(
        avatar: first_avatar,
        operation_kind: "enterprise_to_bureau",
        idempotency_key: SecureRandom.uuid,
        request_fingerprint: Digest::SHA256.hexdigest("foreign-source-period"),
      )

      AvatarRecord.connection.execute(<<~SQL.squish)
        INSERT INTO avatar_enterprise_to_bureau_transfer_details
          (transfer_reservation_id, source_enterprise_public_id, destination_bureau_public_id,
           request_actor_public_id, source_ownership_period_id, requested_at, created_at, updated_at)
        VALUES
          (#{reservation.id}, 'foreign_enterprise', 'destination_bureau', 'raw_sql_actor',
           #{foreign_period.id}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarRecord.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
        end
    end

    assert_match(/source|period|avatar|integrity/i, error.message)
  end

  test "same canonical idempotency request returns the existing reservation" do
    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Idempotent",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "idempotent-registry-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      source_period = enterprise_period_for(avatar, "enterprise_source_1")
      attributes = {
        avatar: avatar,
        operation_kind: "enterprise_to_bureau",
        idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a31",
        request_fingerprint: Digest::SHA256.hexdigest("same-request"),
        source_collective_public_id: "enterprise_source_1",
        destination_collective_public_id: "bureau_destination_1",
        request_actor_public_id: "persona_actor_1",
        source_ownership_period_id: source_period.id,
      }

      first = AvatarOwnershipTransfers::ReservationCreator.call(**attributes)
      second = AvatarOwnershipTransfers::ReservationCreator.call(**attributes)

      assert_equal first.id, second.id
      assert_equal 1, AvatarTransferReservation.where(id: first.id).count
      assert_equal 1, AvatarEnterpriseToBureauTransferDetail.where(transfer_reservation_id: first.id).count
      raise ActiveRecord::Rollback
    end
  end

  test "reservation records the requested instant and five-day expiry" do
    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Timed registry",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "timed-registry-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      source_period = enterprise_period_for(avatar, "enterprise_timed")
      requested_at = Time.utc(2026, 10, 1, 12, 30, 0)

      reservation = AvatarOwnershipTransfers::ReservationCreator.call(
        avatar: avatar,
        operation_kind: "enterprise_to_bureau",
        idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a33",
        request_fingerprint: Digest::SHA256.hexdigest("timed-request"),
        source_collective_public_id: "enterprise_timed",
        destination_collective_public_id: "bureau_timed",
        request_actor_public_id: "persona_timed",
        source_ownership_period_id: source_period.id,
        requested_at: requested_at,
      )

      assert_equal requested_at, reservation.requested_at
      assert_equal requested_at + 5.days, reservation.expires_at
      raise ActiveRecord::Rollback
    end
  end

  test "database enforces the five-day reservation validity boundary" do
    avatar = AvatarTestFactory.create!(
      moniker: "Boundary",
      capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
      active_handle: Handle.create!(handle: "boundary-registry-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
    )
    requested_at = Time.utc(2026, 10, 1, 12, 30, 0)

    AvatarRecord.transaction do
      reservation = AvatarTransferReservation.create!(
        avatar: avatar,
        operation_kind: "enterprise_to_bureau",
        idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a34",
        request_fingerprint: Digest::SHA256.hexdigest("boundary-valid"),
        requested_at: requested_at,
        expires_at: requested_at + 5.days,
      )

      assert_equal requested_at + 5.days, reservation.expires_at
      raise ActiveRecord::Rollback
    end

    AvatarRecord.transaction do
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarTransferReservation.create!(
            avatar: avatar,
            operation_kind: "enterprise_to_bureau",
            idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a35",
            request_fingerprint: Digest::SHA256.hexdigest("boundary-invalid"),
            requested_at: requested_at,
            expires_at: requested_at + 5.days + 1.second,
          )
        end
      assert_match(/check|expiry|validity/i, error.message)
      raise ActiveRecord::Rollback
    end
  end

  test "expiration operation terminalizes a pending reservation at its deadline" do
    AvatarRecord.transaction do
      requested_at = Time.utc(2026, 10, 1, 12, 30, 0)
      avatar = AvatarTestFactory.create!(
        moniker: "Expire",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "expire-registry-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      source_period = enterprise_period_for(avatar, "enterprise_expire")
      reservation = AvatarOwnershipTransfers::ReservationCreator.call(
        avatar: avatar,
        operation_kind: "enterprise_to_bureau",
        idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a36",
        request_fingerprint: Digest::SHA256.hexdigest("expire-request"),
        source_collective_public_id: "enterprise_expire",
        destination_collective_public_id: "bureau_expire",
        request_actor_public_id: "persona_expire",
        source_ownership_period_id: source_period.id,
        requested_at: requested_at,
      )

      expired = AvatarOwnershipTransfers::ExpireReservationOperation.call(
        reservation_public_id: reservation.public_id,
        at: requested_at + 5.days,
      )

      assert_equal "expired", expired.state
      assert_equal requested_at + 5.days, expired.completed_at

      replay = AvatarOwnershipTransfers::ExpireReservationOperation.call(
        reservation_public_id: reservation.public_id,
        at: requested_at + 6.days,
      )

      assert_equal expired.id, replay.id
      assert_equal "expired", replay.state
      assert_equal requested_at + 5.days, replay.completed_at
      raise ActiveRecord::Rollback
    end
  end

  test "new reservation expires an old pending reservation before creating" do
    AvatarRecord.transaction do
      requested_at = Time.utc(2026, 10, 1, 12, 30, 0)
      avatar = AvatarTestFactory.create!(
        moniker: "Expire stale",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "expire-before-create-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      source_period = enterprise_period_for(avatar, "enterprise_expire_before_create")
      first = AvatarOwnershipTransfers::ReservationCreator.call(
        avatar: avatar,
        operation_kind: "enterprise_to_bureau",
        idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a37",
        request_fingerprint: Digest::SHA256.hexdigest("expire-before-create-first"),
        source_collective_public_id: "enterprise_expire_before_create",
        destination_collective_public_id: "bureau_expire_before_create",
        request_actor_public_id: "persona_expire_before_create",
        source_ownership_period_id: source_period.id,
        requested_at: requested_at,
      )

      second = AvatarOwnershipTransfers::ReservationCreator.call(
        avatar: avatar,
        operation_kind: "enterprise_to_bureau",
        idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a38",
        request_fingerprint: Digest::SHA256.hexdigest("expire-before-create-second"),
        source_collective_public_id: "enterprise_expire_before_create",
        destination_collective_public_id: "bureau_expire_before_create",
        request_actor_public_id: "persona_expire_before_create_second",
        source_ownership_period_id: source_period.id,
        requested_at: requested_at + 5.days,
      )

      assert_equal "expired", first.reload.state
      assert_equal requested_at + 5.days, first.completed_at
      assert_equal "pending", second.state
      raise ActiveRecord::Rollback
    end
  end

  test "same idempotency key with changed inputs is rejected" do
    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Changed",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "changed-registry-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      attributes = {
        avatar: avatar,
        operation_kind: "enterprise_to_bureau",
        idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a32",
        request_fingerprint: Digest::SHA256.hexdigest("original-request"),
        source_collective_public_id: "enterprise_source_1",
        destination_collective_public_id: "bureau_destination_1",
        request_actor_public_id: "persona_actor_1",
      }
      attributes[:source_ownership_period_id] = enterprise_period_for(avatar, "enterprise_source_1").id

      AvatarOwnershipTransfers::ReservationCreator.call(**attributes)
      error =
        assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
          AvatarOwnershipTransfers::ReservationCreator.call(
            **attributes.merge(request_fingerprint: Digest::SHA256.hexdigest("changed-request")),
          )
        end

      assert_match(/idempotency|different/i, error.message)
      raise ActiveRecord::Rollback
    end
  end

  test "same idempotency key with a changed source ownership generation is rejected" do
    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Generation key",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "generation-key-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      other_avatar = AvatarTestFactory.create!(
        moniker: "Other generation",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "other-generation-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      source_period = enterprise_period_for(avatar, "enterprise_generation_source")
      other_source_period = enterprise_period_for(other_avatar, "enterprise_other_source")
      attributes = {
        avatar: avatar,
        operation_kind: "enterprise_to_bureau",
        idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a42",
        request_fingerprint: Digest::SHA256.hexdigest("generation-request"),
        source_collective_public_id: "enterprise_generation_source",
        destination_collective_public_id: "bureau_generation_destination",
        request_actor_public_id: "persona_generation_actor",
        source_ownership_period_id: source_period.id,
      }

      AvatarOwnershipTransfers::ReservationCreator.call(**attributes)
      error =
        assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
          AvatarOwnershipTransfers::ReservationCreator.call(
            **attributes.merge(source_ownership_period_id: other_source_period.id),
          )
        end

      assert_match(/idempotency|different/i, error.message)
      raise ActiveRecord::Rollback
    end
  end

  test "concurrent same-key requests return one committed reservation" do
    avatar = AvatarTestFactory.create!(
      moniker: "Concurrent",
      capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
      active_handle: Handle.create!(
        handle: "concurrent-registry-#{SecureRandom.hex(4)}",
        cooldown_until: Time.current,
      ),
    )
    source_period = enterprise_period_for(avatar, "enterprise_source_concurrent")
    key = SecureRandom.uuid
    attributes = {
      avatar: avatar,
      operation_kind: "enterprise_to_bureau",
      idempotency_key: key,
      request_fingerprint: Digest::SHA256.hexdigest("concurrent-request"),
      source_collective_public_id: "enterprise_source_concurrent",
      destination_collective_public_id: "bureau_destination_concurrent",
      request_actor_public_id: "persona_actor_concurrent",
      source_ownership_period_id: source_period.id,
    }
    ready = Queue.new
    start = Queue.new
    threads =
      2.times.map do
        Thread.new do
          AvatarRecord.connection_pool.with_connection do |connection|
            backend_pid = connection.select_value("SELECT pg_backend_pid()")
            ready << backend_pid
            start.pop
            AvatarOwnershipTransfers::ReservationCreator.call(**attributes)
          end
        end
      end

    pids = Timeout.timeout(5) { 2.times.map { ready.pop } }
    2.times { start << true }
    results = Timeout.timeout(15) { threads.map(&:value) }

    assert_equal 2, pids.uniq.length
    assert_equal 1, results.map(&:id).uniq.length
    assert_equal 1, AvatarTransferReservation.where(idempotency_key: key).count
    assert_equal 1, AvatarEnterpriseToBureauTransferDetail.joins(:transfer_reservation).where(
      avatar_transfer_reservations: { idempotency_key: key },
    ).count
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
    threads&.each(&:join)
    if avatar
      AvatarRecord.transaction do
        reservation_ids = AvatarTransferReservation.where(avatar_id: avatar.id).select(:id)
        AvatarEnterpriseToEnterpriseTransferDetail.where(transfer_reservation_id: reservation_ids).delete_all
        AvatarEnterpriseToBureauTransferDetail.where(transfer_reservation_id: reservation_ids).delete_all
        AvatarBureauToEnterpriseTransferDetail.where(transfer_reservation_id: reservation_ids).delete_all
        AvatarBureauToBureauTransferDetail.where(transfer_reservation_id: reservation_ids).delete_all
        AvatarTransferReservation.where(avatar_id: avatar.id).delete_all
      end
      # The concrete source period is intentionally retained because closed ownership history
      # is database-protected and cannot be deleted by test cleanup.
    end
  end

  private

  def enterprise_period_for(avatar, public_id)
    AvatarEnterpriseOwnershipPeriod.create!(
      avatar: avatar,
      enterprise_public_id: public_id,
      valid_from: avatar.created_at,
    )
  end
end
