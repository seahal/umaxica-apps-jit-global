# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarRetentionPurgeTest < ActiveJob::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "ownership history defers Avatar purge idempotently" do
    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        create_concrete_owner: false,
        moniker: "Retain ownership",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "retain-ownership-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      period = AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_retention_1",
        valid_from: avatar.created_at,
      )
      AvatarRecord.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
      avatar.update_columns(purge_eligible_at: 1.hour.ago)

      RetentionPurgeJob.perform_now

      assert Avatar.exists?(avatar.id)
      assert AvatarEnterpriseOwnershipPeriod.exists?(period.id)
      deferral = AvatarPurgeDeferral.find_by(avatar_id: avatar.id, reason_code: "ownership_history")

      assert_not_nil deferral
      assert_equal 1, deferral.attempt_count

      RetentionPurgeJob.perform_now

      assert_equal 1, AvatarPurgeDeferral.where(avatar_id: avatar.id, reason_code: "ownership_history").count
      assert_equal 2, deferral.reload.attempt_count
      raise ActiveRecord::Rollback
    end
  end

  test "a newly created Avatar without concrete ownership is rejected before retention" do
    handle = Handle.create!(handle: "pending-retention-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    lifecycle_state = AvatarLifecycleState.find_by!(key: "active")
    public_id = PublicId.generate
    timestamp = Time.current
    raw_connection = AvatarRecord.connection.raw_connection
    raw_connection.exec("BEGIN")
    raw_connection.exec_params(
      "INSERT INTO avatars (public_id, active_handle_id, capability_id, lifecycle_state_id, created_at, updated_at) " \
      "VALUES ($1, $2, $3, $4, $5, $5)",
      [public_id, handle.id, capability.id, lifecycle_state.id, timestamp],
    )
    error = assert_raises(PG::CheckViolation) { raw_connection.exec("COMMIT") }
    raw_connection.exec("ROLLBACK") unless raw_connection.transaction_status == PG::PQTRANS_IDLE

    assert_equal "23514", error.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
    assert_equal "avatar_initial_concrete_owner_required",
                 error.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    assert_not Avatar.exists?(active_handle_id: handle.id)
  end

  test "concurrent ownership deferrals converge on one row" do
    organization = Enterprise.create!(name: "Retention race owner", title: "RetOwner")
    avatar = nil
    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        create_concrete_owner: false,
        moniker: "Concurrent hold",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "concurrent-retention-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: organization.public_id,
        valid_from: avatar.created_at,
      )
    end

    assert_equal 1, avatar.enterprise_ownership_periods.current.count
    ready = Queue.new
    release = Queue.new
    outcomes = Queue.new
    threads =
      2.times.map do
        Thread.new do
          AvatarRecord.connection_pool.with_connection do
            ready << true
            release.pop
            outcomes << AvatarPurgeDeferral.record!(
              avatar: avatar,
              reason_code: "ownership_history",
            ).id
          end
        rescue StandardError => e
          outcomes << e
        end
      end

    2.times { ready.pop }
    2.times { release << true }
    threads.each(&:value)
    results = 2.times.map { outcomes.pop }

    assert(results.all? { |result| result.is_a?(Integer) })
    assert_equal 1, results.uniq.size
    assert_equal 1, AvatarPurgeDeferral.where(avatar_id: avatar.id, reason_code: "ownership_history").count
    assert_equal 2, AvatarPurgeDeferral.find(results.first).attempt_count
  ensure
    threads&.each { |thread| thread.join if thread.alive? }
    # The owned worker lifecycle removes committed deferrals and history together.
  end
end
