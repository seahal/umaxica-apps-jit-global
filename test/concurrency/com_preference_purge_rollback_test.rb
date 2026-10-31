# frozen_string_literal: true

require "test_helper"
require "timeout"

class ComPreferencePurgeRollbackTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "a child deletion failure rolls back earlier deletions and keeps the preference" do
    ComPreferenceStatus.ensure_defaults!
    now = ComPreference.database_now
    preference = ComPreference.create!(
      jti: SecureRandom.uuid, last_issued_at: now - 431.days, last_issued_expires_at: now - 31.days,
    )
    cookie = ComPreferenceCookie.create!(preference: preference)
    receipt = ComPreferenceConsentReceipt.create!(preference: preference, version: SecureRandom.uuid, recorded_at: now)
    binding = ComPreferenceBrowserBinding.create!(preference: preference, digest: SecureRandom.hex(32))
    config = ComPreference.connection_db_config.configuration_hash
    blocker = PG.connect(
      host: config.fetch(:host), port: config.fetch(:port), dbname: config.fetch(:database),
      user: config.fetch(:username), password: config.fetch(:password),
    )
    probe = PG.connect(
      host: config.fetch(:host), port: config.fetch(:port), dbname: config.fetch(:database),
      user: config.fetch(:username), password: config.fetch(:password),
    )
    blocker.exec("BEGIN")
    blocker.exec_params("SELECT id FROM com_preference_browser_bindings WHERE id = $1 FOR UPDATE", [binding.id])
    results = Queue.new
    purger =
      Thread.new do
        ComSettingRecord.connection_pool.with_connection do |connection|
          connection.execute("SET lock_timeout = '2s'")
          results << PreferenceLifecycleJob.perform_now
        ensure
          connection.execute("RESET lock_timeout")
        end
      rescue StandardError => e
        results << e
      end
    Timeout.timeout(5) do
      loop do
        unless results.empty?
          result = results.pop
          raise result if result.is_a?(Exception)

          flunk("Purge completed without the expected lock wait: #{result.inspect}")
        end
        waiting = probe.exec(<<~SQL.squish).getvalue(0, 0)
          SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE datname = current_database()
            AND wait_event_type = 'Lock' AND query LIKE 'DELETE FROM "com_preference_browser_bindings"%')
        SQL
        break if waiting == "t"

        Thread.pass
      end
    end
    error = Timeout.timeout(5) { results.pop }

    assert_kind_of ActiveRecord::LockWaitTimeout, error
    assert_predicate ComPreference.where(id: preference.id), :exists?
    assert_predicate ComPreferenceCookie.where(id: cookie.id), :exists?
    assert_predicate ComPreferenceConsentReceipt.where(id: receipt.id), :exists?
    assert_predicate ComPreferenceBrowserBinding.where(id: binding.id), :exists?
  ensure
    blocker&.exec("ROLLBACK")
    blocker&.finish
    probe&.finish
    purger&.join(5)
    if preference
      ComPreference.where(id: preference.id).preload(*PreferenceLifecyclePurger::DEPENDENCIES).find_each(&:destroy!)
    end
  end
end
