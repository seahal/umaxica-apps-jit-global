# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarConcreteOwnershipPeriodTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "a newly committed Avatar requires one concrete ownership period" do
    database = AvatarRecord.connection_db_config.configuration_hash
    capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    lifecycle_state = AvatarLifecycleState.find_by!(key: "active")
    handle = Handle.create!(
      handle: "ownerless-commit-#{SecureRandom.hex(4)}",
      cooldown_until: Time.current,
    )
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

    observer =
      PG.connect(
        host: database.fetch(:host),
        port: database.fetch(:port),
        user: database.fetch(:username),
        password: database.fetch(:password),
        dbname: database.fetch(:database),
        connect_timeout: 3,
      )

    assert_equal 0, observer.exec_params("SELECT 1 FROM avatars WHERE public_id = $1", [public_id]).ntuples
  ensure
    observer&.close
  end

  test "an enterprise period stores a concrete organization reference" do
    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        create_concrete_owner: false,
        moniker: "Enterprise owner",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "concrete-enterprise-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      period = AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_concrete_1",
        valid_from: avatar.created_at,
      )

      assert_equal avatar.id, period.avatar_id
      assert_equal "enterprise_concrete_1", period.enterprise_public_id
      assert_predicate period, :current?

      raise ActiveRecord::Rollback
    end
  end

  test "cross-family ownership periods cannot overlap for one avatar" do
    error = nil

    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        create_concrete_owner: false,
        moniker: "Cross family",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "concrete-overlap-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      first_end = avatar.created_at + 1.hour
      AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_overlap_1",
        valid_from: avatar.created_at,
        valid_to: first_end,
      )
      AvatarBureauOwnershipPeriod.create!(
        avatar: avatar,
        bureau_public_id: "bureau_overlap_1",
        valid_from: avatar.created_at + 30.minutes,
      )

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarRecord.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
        end
      raise ActiveRecord::Rollback
    end

    assert_match(/overlap|ownership/i, error.message)
  end

  test "an adjacent enterprise to bureau ownership chain is accepted" do
    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        create_concrete_owner: false,
        moniker: "Adjacent owners",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "concrete-adjacent-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      transfer_at = avatar.created_at + 1.hour
      enterprise = AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_adjacent_1",
        valid_from: avatar.created_at,
        valid_to: transfer_at,
      )
      bureau = AvatarBureauOwnershipPeriod.create!(
        avatar: avatar,
        bureau_public_id: "bureau_adjacent_1",
        valid_from: transfer_at,
      )

      AvatarRecord.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")

      assert_equal transfer_at, enterprise.valid_to
      assert_predicate bureau, :current?

      raise ActiveRecord::Rollback
    end
  end

  test "a committed adjacent chain is visible after a real independent commit" do
    avatar = committed_avatar("committed-adjacent")
    enterprise = avatar.enterprise_ownership_periods.current.first
    transfer_at = database_boundary(avatar.created_at) + 1.hour
    connection = open_avatar_connection

    connection.exec("BEGIN")
    connection.exec_params(
      "UPDATE avatar_enterprise_ownership_periods SET valid_to = $1 WHERE id = $2",
      [transfer_at, enterprise.id],
    )
    connection.exec_params(
      "INSERT INTO avatar_bureau_ownership_periods " \
      "(avatar_id, bureau_public_id, valid_from, valid_to, created_at, updated_at) " \
      "VALUES ($1, $2, $3, 'infinity', $4, $4)",
      [avatar.id, "bureau-committed-#{SecureRandom.hex(4)}", transfer_at, Time.current],
    )
    connection.exec("COMMIT")

    assert_equal 2, concrete_period_count(avatar)
    assert_equal 1, avatar.bureau_ownership_periods.current.count
    assert_in_delta transfer_at.to_f, avatar.enterprise_ownership_periods.first.reload.valid_to.to_f, 0.001
  ensure
    connection&.close
  end

  test "a real commit rejects a gap and leaves the prior current period intact" do
    avatar = committed_avatar("committed-gap")
    enterprise = avatar.enterprise_ownership_periods.current.first
    transfer_at = database_boundary(avatar.created_at) + 1.hour
    connection = open_avatar_connection

    connection.exec("BEGIN")
    connection.exec_params(
      "UPDATE avatar_enterprise_ownership_periods SET valid_to = $1 WHERE id = $2",
      [transfer_at, enterprise.id],
    )
    connection.exec_params(
      "INSERT INTO avatar_bureau_ownership_periods " \
      "(avatar_id, bureau_public_id, valid_from, valid_to, created_at, updated_at) " \
      "VALUES ($1, $2, $3, 'infinity', $4, $4)",
      [avatar.id, "bureau-gap-#{SecureRandom.hex(4)}", transfer_at + 1.hour, Time.current],
    )

    error = assert_raises(PG::Error) { connection.exec("COMMIT") }
    assert_equal "23514", error.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
    connection.exec("ROLLBACK") unless connection.transaction_status == PG::PQTRANS_IDLE

    assert_equal Float::INFINITY, enterprise.reload.valid_to
    assert_equal 0, avatar.bureau_ownership_periods.count
  ensure
    connection&.close
  end

  test "a real commit rejects cross-family overlap through raw SQL" do
    avatar = committed_avatar("committed-overlap")
    connection = open_avatar_connection

    connection.exec("BEGIN")
    connection.exec_params(
      "INSERT INTO avatar_bureau_ownership_periods " \
      "(avatar_id, bureau_public_id, valid_from, valid_to, created_at, updated_at) " \
      "VALUES ($1, $2, $3, 'infinity', $4, $4)",
      [avatar.id, "bureau-overlap-#{SecureRandom.hex(4)}", avatar.created_at + 30.minutes, Time.current],
    )

    error = assert_raises(PG::Error) { connection.exec("COMMIT") }
    assert_includes %w(23P01 23514), error.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
    connection.exec("ROLLBACK") unless connection.transaction_status == PG::PQTRANS_IDLE

    assert_equal 0, avatar.bureau_ownership_periods.count
    assert_equal 1, avatar.enterprise_ownership_periods.current.count
  ensure
    connection&.close
  end

  test "independent ownership writers serialize safely at each PostgreSQL isolation level" do
    ["READ COMMITTED", "REPEATABLE READ", "SERIALIZABLE"].each do |isolation|
      assert_concurrent_owner_change(isolation)
    end
  end

  test "direct SQL cannot change the concrete owner identity" do
    error = nil

    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        create_concrete_owner: false,
        moniker: "Immutable owner",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "concrete-immutable-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      period = AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_immutable_1",
        valid_from: avatar.created_at,
      )

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarRecord.connection.execute(
            "UPDATE avatar_enterprise_ownership_periods " \
            "SET enterprise_public_id = 'enterprise_immutable_2' WHERE id = #{period.id}",
          )
        end
      raise ActiveRecord::Rollback
    end

    assert_match(/immutable|ownership/i, error.message)
  end

  test "direct SQL cannot delete concrete ownership history" do
    error = nil

    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        create_concrete_owner: false,
        moniker: "Delete history",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "concrete-delete-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      period = AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_delete_1",
        valid_from: avatar.created_at,
      )

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarRecord.connection.execute(
            "DELETE FROM avatar_enterprise_ownership_periods WHERE id = #{period.id}",
          )
        end
      raise ActiveRecord::Rollback
    end

    assert_match(/immutable|history/i, error.message)
  end

  test "direct SQL cannot truncate concrete ownership history" do
    error = nil

    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        create_concrete_owner: false,
        moniker: "Truncate history",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "concrete-truncate-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_truncate_1",
        valid_from: avatar.created_at,
      )

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarRecord.connection.execute("TRUNCATE avatar_enterprise_ownership_periods")
        end
      raise ActiveRecord::Rollback
    end

    assert_match(/truncate|history/i, error.message)
  end

  test "a transfer may close the current period when it creates the adjacent next period" do
    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        create_concrete_owner: false,
        moniker: "Close current",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "concrete-close-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      period = AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_close_1",
        valid_from: avatar.created_at,
      )
      transfer_at = avatar.created_at + 1.hour

      AvatarRecord.connection.execute(
        "UPDATE avatar_enterprise_ownership_periods " \
        "SET valid_to = '#{transfer_at.iso8601(6)}' WHERE id = #{period.id}",
      )
      AvatarBureauOwnershipPeriod.create!(
        avatar: avatar,
        bureau_public_id: "bureau_close_1",
        valid_from: transfer_at,
      )
      AvatarRecord.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")

      assert_equal transfer_at, period.reload.valid_to
      raise ActiveRecord::Rollback
    end
  end

  test "a transfer cannot change the owner while closing the current period" do
    error = nil

    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        create_concrete_owner: false,
        moniker: "Owner close",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "concrete-owner-close-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      period = AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_owner_close_1",
        valid_from: avatar.created_at,
      )
      transfer_at = avatar.created_at + 1.hour

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarRecord.connection.execute(
            "UPDATE avatar_enterprise_ownership_periods " \
            "SET enterprise_public_id = 'enterprise_owner_close_2', " \
            "valid_to = '#{transfer_at.iso8601(6)}' WHERE id = #{period.id}",
          )
        end
      raise ActiveRecord::Rollback
    end

    assert_match(/immutable|ownership/i, error.message)
  end

  test "enterprise ownership rejects a nonfinite start even when Avatar creation matches" do
    error = nil

    AvatarRecord.transaction do
      avatar = Avatar.create!(
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "finite-enterprise-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      # Matching a corrupted creation timestamp must not make a nonfinite period valid.
      avatar.update_columns(created_at: -Float::INFINITY)

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarEnterpriseOwnershipPeriod.insert_all!(
            [{
              avatar_id: avatar.id,
              enterprise_public_id: "enterprise_finite_start",
              valid_from: -Float::INFINITY,
              valid_to: Float::INFINITY,
              created_at: Time.current,
              updated_at: Time.current,
            }],
          )
        end
      raise ActiveRecord::Rollback
    end

    assert_equal "23514", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
    assert_equal "chk_avatar_enterprise_ownership_periods_finite_start",
                 error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
  end

  test "bureau ownership rejects a nonfinite start even when Avatar creation matches" do
    error = nil

    AvatarRecord.transaction do
      avatar = Avatar.create!(
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "finite-bureau-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      # Matching a corrupted creation timestamp must not make a nonfinite period valid.
      avatar.update_columns(created_at: -Float::INFINITY)

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarBureauOwnershipPeriod.insert_all!(
            [{
              avatar_id: avatar.id,
              bureau_public_id: "bureau_finite_start",
              valid_from: -Float::INFINITY,
              valid_to: Float::INFINITY,
              created_at: Time.current,
              updated_at: Time.current,
            }],
          )
        end
      raise ActiveRecord::Rollback
    end

    assert_equal "23514", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
    assert_equal "chk_avatar_bureau_ownership_periods_finite_start",
                 error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
  end

  private

  def committed_avatar(prefix)
    AvatarTestFactory.create!(
      moniker: "p7-#{SecureRandom.hex(5)}",
      capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
      active_handle: Handle.create!(
        handle: "#{prefix}-#{SecureRandom.hex(4)}",
        cooldown_until: Time.current,
      ),
    )
  end

  def concrete_period_count(avatar)
    avatar.enterprise_ownership_periods.count + avatar.bureau_ownership_periods.count
  end

  def database_boundary(time)
    time.change(usec: 0)
  end

  def open_avatar_connection
    database = AvatarRecord.connection_db_config.configuration_hash
    connection = PG.connect(
      host: database.fetch(:host),
      port: database.fetch(:port),
      user: database.fetch(:username),
      password: database.fetch(:password),
      dbname: database.fetch(:database),
      connect_timeout: 3,
    )
    actual_database = connection.exec("SELECT current_database()").getvalue(0, 0)
    expected_database = database.fetch(:database).to_s
    raise RuntimeError, "raw COMMIT connection target mismatch" unless actual_database == expected_database

    connection
  end

  def assert_concurrent_owner_change(isolation)
    ActiveRecord::Base.connection_handler.clear_active_connections!
    avatar = committed_avatar("concurrent-#{isolation.downcase.tr(" ", "-")}")
    enterprise = avatar.enterprise_ownership_periods.current.first
    transfer_at = database_boundary(avatar.created_at) + 1.hour
    ActiveRecord::Base.connection_handler.clear_active_connections!
    ready = Queue.new
    start = Queue.new

    first = start_owner_writer(
      avatar: avatar,
      enterprise: enterprise,
      transfer_at: transfer_at,
      isolation: isolation,
      ready: ready,
      start: start,
      label: "first",
    )
    second = start_owner_writer(
      avatar: avatar,
      enterprise: enterprise,
      transfer_at: transfer_at,
      isolation: isolation,
      ready: ready,
      start: start,
      label: "second",
    )

    release_concurrent_writers(ready, start)
    results = Timeout.timeout(15) { [first.value, second.value] }

    assert_equal 1, results.count(:committed), "#{isolation} must commit one owner change: #{results.inspect}"
    failures = results.reject { |result| result == :committed }

    assert_equal 1, failures.length
    assert_includes %w(40001 45000 23514 23P01), failures.first[1]
    assert_equal 2, concrete_period_count(avatar)
    assert_equal 1, avatar.bureau_ownership_periods.current.count
  ensure
    [first, second].compact.each do |thread|
      thread.kill if thread.alive?
      thread.join
    end
  end

  def start_owner_writer(avatar:, enterprise:, transfer_at:, isolation:, ready:, start:, label:)
    Thread.new do
      AvatarRecord.connection_pool.with_connection do |active_connection|
        connection = active_connection.raw_connection
        ready_sent = false
        begin
          expected_database = AvatarRecord.connection_db_config.database.to_s
          actual_database = connection.exec("SELECT current_database()").getvalue(0, 0)
          raise RuntimeError, "pooled writer connection target mismatch" unless actual_database == expected_database

          ready << connection.exec("SELECT pg_backend_pid()").getvalue(0, 0)
          ready_sent = true
          start.pop
          connection.exec("BEGIN")
          connection.exec("SET TRANSACTION ISOLATION LEVEL #{isolation}")
          write_adjacent_period(connection, avatar, enterprise, transfer_at, label)
          connection.exec("COMMIT")
          :committed
        rescue PG::Error => e
          rollback_raw_connection(connection)
          ready << true unless ready_sent
          [:failed, e.result.error_field(PG::Result::PG_DIAG_SQLSTATE), e.message.lines.first.to_s.strip]
        rescue StandardError => e
          rollback_raw_connection(connection)
          ready << true unless ready_sent
          [:error, e.class.name]
        end
      end
    end
  end

  def release_concurrent_writers(ready, start)
    backend_pids = Timeout.timeout(10) { 2.times.map { ready.pop } }

    assert_equal 2, backend_pids.uniq.length
    2.times { start << true }
  end

  def write_adjacent_period(connection, avatar, enterprise, transfer_at, label)
    connection.exec_params(
      "UPDATE avatar_enterprise_ownership_periods SET valid_to = $1 WHERE id = $2",
      [transfer_at, enterprise.id],
    )
    connection.exec_params(
      "INSERT INTO avatar_bureau_ownership_periods " \
      "(avatar_id, bureau_public_id, valid_from, valid_to, created_at, updated_at) " \
      "VALUES ($1, $2, $3, 'infinity', $4, $4)",
      [avatar.id, "bureau-concurrent-#{label}-#{SecureRandom.hex(4)}", transfer_at, Time.current],
    )
  end

  def rollback_raw_connection(connection)
    return unless connection && connection.transaction_status != PG::PQTRANS_IDLE

    connection.exec("ROLLBACK")
  end
end
