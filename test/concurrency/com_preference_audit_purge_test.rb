# frozen_string_literal: true

require "test_helper"
require "timeout"

class ComPreferenceAuditPurgeTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    ComPreferenceStatus.ensure_defaults!
    ComPreferenceChronicleLevel.ensure_defaults!
    ComPreferenceChronicleEvent.ensure_defaults!
    now = ComPreference.database_now
    @preference = ComPreference.create!(
      jti: SecureRandom.uuid, last_issued_at: now - 431.days, last_issued_expires_at: now - 31.days,
    )
  end

  teardown do
    next unless @preference

    ComPreferenceChronicle.where(subject_type: "ComPreference", subject_id: @preference.id).delete_all
    ComPreferenceChronicle.where(actor_type: "ComPreference", actor_id: @preference.id).delete_all
    ComPreference.where(id: @preference.id).delete_all
  end

  test "an audit committed before collection keeps its preference" do
    ready = Queue.new
    release = Queue.new
    results = Queue.new
    writer =
      Thread.new do
        ChronicleRecord.transaction do
          create_audit!
          ready << true
          release.pop
        end
      rescue StandardError => e
        ready << e
      end
    signal = Timeout.timeout(5) { ready.pop }
    raise signal if signal.is_a?(Exception)

    purger =
      Thread.new do
        ChronicleRecord.transaction do
          ChronicleRecord.connection_pool.with_connection { |c| c.execute("SET LOCAL lock_timeout = '5s'") }
          results << PreferenceLifecycleJob.perform_now
        end
      rescue StandardError => e
        results << e
      end
    wait_for_advisory_waiter!
    release << true
    result = Timeout.timeout(5) { results.pop }
    raise result if result.is_a?(Exception)

    assert_equal 0, result
    assert_predicate ComPreference.where(id: @preference.id), :exists?
    assert_predicate ComPreferenceChronicle.where(subject_id: @preference.id, subject_type: "ComPreference"), :exists?
  ensure
    release << true if release && writer&.alive?
    writer&.join(5)
    purger&.join(5)
  end

  test "an audit waiting for collection cannot reference the removed preference" do
    results = Queue.new
    writer = nil
    ChronicleRecord.transaction do
      ComPreferenceChronicle.lock_preference_audit_for_purge!
      writer =
        Thread.new do
          create_audit!
          results << :unexpected_success
        rescue StandardError => e
          results << e
        end
      wait_for_advisory_waiter!

      assert_equal 1, PreferenceLifecycleJob.perform_now
    end
    result = Timeout.timeout(5) { results.pop }

    assert_instance_of ActiveRecord::RecordNotFound, result
    assert_not ComPreference.exists?(@preference.id)
    assert_not ComPreferenceChronicle.exists?(subject_id: @preference.id, subject_type: "ComPreference")
  ensure
    writer&.join(5)
  end

  test "a committed actor reference prevents collection while the purge waits" do
    ready = Queue.new
    release = Queue.new
    results = Queue.new
    writer =
      Thread.new do
        ChronicleRecord.transaction do
          ComPreferenceChronicle.create!(
            subject_type: "OtherType", subject_id: @preference.id + 100_000,
            actor_type: "ComPreference", actor_id: @preference.id,
            event_id: ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
            level_id: ComPreferenceChronicleLevel::INFO, occurred_at: Time.current,
          )
          ready << true
          release.pop
        end
      rescue StandardError => e
        ready << e
      end
    signal = Timeout.timeout(5) { ready.pop }
    raise signal if signal.is_a?(Exception)

    purger =
      Thread.new do
        ChronicleRecord.transaction do
          ChronicleRecord.connection_pool.with_connection { |c| c.execute("SET LOCAL lock_timeout = '5s'") }
          results << PreferenceLifecycleJob.perform_now
        end
      rescue StandardError => e
        results << e
      end
    wait_for_advisory_waiter!
    release << true
    result = Timeout.timeout(5) { results.pop }
    raise result if result.is_a?(Exception)

    assert_equal 0, result
    assert_predicate ComPreference.where(id: @preference.id), :exists?
    assert_predicate ComPreferenceChronicle.where(actor_type: "ComPreference", actor_id: @preference.id), :exists?
  ensure
    release << true if release && writer&.alive?
    writer&.join(5)
    purger&.join(5)
  end

  test "an actor reference waiting for collection cannot refer to the removed preference" do
    results = Queue.new
    writer = nil
    ChronicleRecord.transaction do
      ComPreferenceChronicle.lock_preference_audit_for_purge!
      writer =
        Thread.new do
          ComPreferenceChronicle.create!(
            subject_type: "OtherType", subject_id: @preference.id + 100_000,
            actor_type: "ComPreference", actor_id: @preference.id,
            event_id: ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
            level_id: ComPreferenceChronicleLevel::INFO, occurred_at: Time.current,
          )
          results << :unexpected_success
        rescue StandardError => e
          results << e
        end
      wait_for_advisory_waiter!

      assert_equal 1, PreferenceLifecycleJob.perform_now
    end
    result = Timeout.timeout(5) { results.pop }

    assert_instance_of ActiveRecord::RecordNotFound, result
    assert_not ComPreference.exists?(@preference.id)
    assert_not ComPreferenceChronicle.exists?(actor_type: "ComPreference", actor_id: @preference.id)
  ensure
    writer&.join(5)
  end

  private

  def create_audit!
    ComPreferenceChronicle.create!(
      subject_type: "ComPreference", subject_id: @preference.id,
      actor_type: "ComPreference", actor_id: @preference.id,
      event_id: ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
      level_id: ComPreferenceChronicleLevel::INFO, occurred_at: Time.current,
    )
  end

  def wait_for_advisory_waiter!
    config = ComPreferenceChronicle.connection_db_config.configuration_hash
    probe = PG.connect(
      host: config.fetch(:host), port: config.fetch(:port), dbname: config.fetch(:database),
      user: config.fetch(:username), password: config.fetch(:password),
    )
    Timeout.timeout(3) do
      loop do
        waiting = probe.exec(<<~SQL.squish).getvalue(0, 0)
          SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE datname = current_database()
            AND wait_event = 'advisory' AND query LIKE '%pg_advisory_xact_lock%')
        SQL
        break if waiting == "t"

        Thread.pass
      end
    end
  ensure
    probe&.finish
  end
end
