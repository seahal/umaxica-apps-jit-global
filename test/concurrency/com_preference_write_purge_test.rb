# frozen_string_literal: true

require "test_helper"
require "timeout"

class ComPreferenceWritePurgeTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  self.fixture_table_names = []

  SNAPSHOT = {
    "theme" => "system",
    "language" => "ja",
    "timezone" => "Asia/Tokyo",
    "currency" => "jpy",
    "date_format" => "iso",
    "time_format" => "24",
    "motion" => "standard",
    "density" => "standard",
    "page_size" => "infinity",
  }.freeze

  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    @created_ids = Queue.new
    ComPreferenceStatus.ensure_defaults!
    now = ComPreference.database_now
    @old = ComPreference.create!(
      jti: SecureRandom.uuid, last_issued_at: now - 431.days, last_issued_expires_at: now - 31.days,
    )
    @token = PreferenceToken.encode(
      SNAPSHOT, host: @host, preference_type: "ComPreference", issued_at: Time.current,
                public_id: @old.public_id, jti: @old.jti,
    )
  end

  teardown do
    ids = []
    ids << @old.id if @old
    ids << @created_ids.pop(true) until @created_ids.empty?
    ComPreferenceChronicle.where(subject_type: "ComPreference", subject_id: ids).delete_all
    ComPreference.where(id: ids).preload(*PreferenceLifecyclePurger::DEPENDENCIES).find_each(&:destroy!)
  end

  %i(save reset).each do |operation|
    test "#{operation} before collection creates a new preference and collection retires the expired row" do
      ready = Queue.new
      release = Queue.new
      results = Queue.new
      writer =
        Thread.new do
          ChronicleRecord.transaction do
            set_lock_timeout!
            result = perform_write(operation)
            ready << result
            release.pop
          end
        rescue StandardError => e
          ready << e
        end
      response = Timeout.timeout(5) { ready.pop }
      raise response if response.is_a?(Exception)

      purger =
        Thread.new do
          ChronicleRecord.transaction do
            set_lock_timeout!
            results << PreferenceLifecycleJob.perform_now
          end
        rescue StandardError => e
          results << e
        end
      wait_for_advisory_waiter!
      release << true
      result = Timeout.timeout(5) { results.pop }
      raise result if result.is_a?(Exception)

      assert_equal 1, result
      assert_write_result(response, operation)
      assert_not ComPreference.exists?(@old.id)
    ensure
      release << true if release && writer&.alive?
      writer&.join(5)
      purger&.join(5)
    end

    test "collection before #{operation} leaves the new preference independent of the removed row" do
      results = Queue.new
      writer = nil
      ChronicleRecord.transaction do
        ComPreferenceChronicle.lock_preference_audit_for_purge!
        writer =
          Thread.new do
            ChronicleRecord.transaction do
              set_lock_timeout!
              results << perform_write(operation)
            end
          rescue StandardError => e
            results << e
          end
        wait_for_advisory_waiter!

        assert_equal 1, PreferenceLifecycleJob.perform_now
      end
      response = Timeout.timeout(5) { results.pop }
      raise response if response.is_a?(Exception)

      assert_write_result(response, operation)
      assert_not ComPreference.exists?(@old.id)
    ensure
      writer&.join(5)
    end
  end

  private

  def perform_write(operation)
    browser = open_session
    browser.host!(@host)
    browser.https!
    browser.cookies[PreferenceCookieName.anonymous_jwt] = @token
    headers = { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" }
    if operation == :save
      browser.patch(
        base_com_api_v0_preferences_theme_path,
        params: { theme: "dark" }.to_json,
        headers: headers.merge("Accept" => "application/json", "Content-Type" => "application/json"),
      )
    else
      browser.delete(
        base_com_preference_customization_path(ri: "jp"),
        params: { confirm_reset: "1" }, headers: headers,
      )
    end
    issued = PreferenceToken.decode(browser.cookies[PreferenceCookieName.anonymous_jwt], host: @host)
    if issued
      created = ComPreference.find_by(public_id: issued.fetch("sub"))
      @created_ids << created.id if created
    end
    [browser.response.status, issued]
  end

  def assert_write_result(response, operation)
    status, issued = response

    assert_equal((operation == :save) ? 200 : 303, status)
    assert_predicate issued, :present?
    assert_not_equal @old.public_id, issued.fetch("sub")
    assert_equal((operation == :save) ? "dark" : "system", issued.fetch("preferences").fetch("theme"))
    assert_predicate ComPreference.where(public_id: issued.fetch("sub")), :exists?
  end

  def set_lock_timeout!
    ChronicleRecord.connection_pool.with_connection { |connection| connection.execute("SET LOCAL lock_timeout = '5s'") }
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
