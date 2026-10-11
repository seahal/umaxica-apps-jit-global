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

  test "Avatar without concrete ownership history is deferred while deletion policy is unresolved" do
    AvatarRecord.transaction do
      handle = Handle.create!(handle: "pending-retention-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
      avatar = Avatar.create!(
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: handle,
      )
      avatar.update_columns(purge_eligible_at: 1.hour.ago)

      RetentionPurgeJob.perform_now

      assert Avatar.exists?(avatar.id)
      assert Handle.exists?(handle.id)
      deferral = AvatarPurgeDeferral.find_by!(avatar_id: avatar.id, reason_code: "retention_policy_pending")

      assert_equal 1, deferral.attempt_count

      RetentionPurgeJob.perform_now

      assert Avatar.exists?(avatar.id)
      assert_equal 1, AvatarPurgeDeferral.where(avatar_id: avatar.id, reason_code: "retention_policy_pending").count
      assert_equal 2, deferral.reload.attempt_count
      raise ActiveRecord::Rollback
    end
  end

  test "concurrent ownership deferrals converge on one row" do
    avatar = AvatarTestFactory.create!(
      moniker: "Concurrent hold",
      capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
      active_handle: Handle.create!(
        handle: "concurrent-retention-#{SecureRandom.hex(4)}",
        cooldown_until: Time.current,
      ),
    )
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
    AvatarPurgeDeferral.where(avatar_id: avatar&.id).delete_all if avatar&.id
    avatar&.destroy! if avatar&.persisted? && Avatar.exists?(avatar.id)
  end
end
