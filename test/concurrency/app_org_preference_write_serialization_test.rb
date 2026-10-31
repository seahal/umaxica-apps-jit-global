# frozen_string_literal: true

require "test_helper"
require "timeout"

class AppOrgPreferenceWriteSerializationTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "concurrent APP and ORG saves serialize one JWT generation without mixing snapshots" do
    ["app", "org"].each do |realm|
      config =
        case realm
        when "app"
          {
            host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), preference_class: AppPreference,
            table: "app_preferences", prefix: "App",
            theme_path: base_app_api_v0_preferences_theme_path,
            language_path: base_app_api_v0_preferences_language_path,
          }
        when "org"
          {
            host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), preference_class: OrgPreference,
            table: "org_preferences", prefix: "Org",
            theme_path: base_org_api_v0_preferences_theme_path,
            language_path: base_org_api_v0_preferences_language_path,
          }
        else
          raise ArgumentError, "unsupported realm: #{realm.inspect}"
        end
      preference_class = config.fetch(:preference_class)
      host = config.fetch(:host)
      json_headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
      created_ids = Queue.new
      threads = []
      blocker = nil
      probe = nil

      begin
        host!(host)
        https!
        patch(config.fetch(:theme_path), params: { theme: "system" }.to_json, headers: json_headers)

        assert_response :ok

        initial_token = cookies[PreferenceCookieName.anonymous_jwt]
        initial_claims = PreferenceToken.decode(initial_token, host:)
        original = preference_class.find_by!(public_id: initial_claims.fetch("sub"))
        created_ids << original.id
        connection = preference_class.connection_db_config.configuration_hash
        blocker = PG.connect(
          host: connection.fetch(:host), port: connection.fetch(:port), dbname: connection.fetch(:database),
          user: connection.fetch(:username), password: connection.fetch(:password),
        )
        probe = PG.connect(
          host: connection.fetch(:host), port: connection.fetch(:port), dbname: connection.fetch(:database),
          user: connection.fetch(:username), password: connection.fetch(:password),
        )
        blocker.exec("BEGIN")
        blocker.exec_params(
          "SELECT id FROM #{config.fetch(:table)} WHERE id = $1 FOR UPDATE", [original.id],
        )

        results = Queue.new
        [
          [:theme, config.fetch(:theme_path), { theme: "dark" }],
          [:language, config.fetch(:language_path), { language: "en" }],
        ].each do |field, path, submitted|
          threads << Thread.new do
            browser = open_session
            browser.host!(host)
            browser.https!
            browser.cookies[PreferenceCookieName.anonymous_jwt] = initial_token
            browser.patch(path, params: submitted.to_json, headers: json_headers)
            claims = PreferenceToken.decode(browser.cookies[PreferenceCookieName.anonymous_jwt], host:)
            row = preference_class.find_by(public_id: claims.fetch("sub")) if claims
            created_ids << row.id if row
            results << [field, browser.response.status, claims]
          rescue StandardError => e
            results << e
          end
        end

        Timeout.timeout(5) do
          loop do
            waiting = probe.exec_params(<<~SQL.squish, [config.fetch(:table)]).getvalue(0, 0).to_i
              SELECT count(*) FROM pg_stat_activity
              WHERE datname = current_database()
                AND wait_event_type = 'Lock'
                AND query LIKE ('%' || $1 || '%')
                AND query LIKE '%FOR UPDATE%'
            SQL
            break if waiting >= 2

            Thread.pass
          end
        end

        blocker.exec("COMMIT")
        outcomes = 2.times.map { Timeout.timeout(8) { results.pop } }
        outcomes.each { |outcome| raise outcome if outcome.is_a?(Exception) }
        preference_class.connection_pool.with_connection(&:clear_query_cache)

        assert_equal [:language, :theme].sort, outcomes.map(&:first).sort
        assert_equal [200, 200], outcomes.map { |outcome| outcome.fetch(1) }.sort

        claims = outcomes.map(&:last)
        assert_equal 2, claims.map { |payload| payload.fetch("sub") }.uniq.size
        assert_includes claims.map { |payload| payload.fetch("sub") }, original.public_id
        actual_snapshots = claims.map { |payload| payload.fetch("preferences").slice("theme", "language") }
        expected_snapshots = [
          { "theme" => "dark", "language" => "ja" },
          { "theme" => "system", "language" => "en" },
        ]
        assert_equal expected_snapshots.sort_by { |snapshot| snapshot.fetch("theme") },
                     actual_snapshots.sort_by { |snapshot| snapshot.fetch("theme") }

        claims.each do |payload|
          row = preference_class.find_by!(public_id: payload.fetch("sub"))
          assert_equal preference_class::ACTIVE_STATUS_ID, row.status_id
          persisted_snapshot = PreferenceWriteBoundary::ANONYMOUS_DISPLAY_TYPES.each_with_object({}) do |type, values|
            record = PreferenceClassRegistry.record_class(config.fetch(:prefix), type)
              .find_by!(preference_id: row.id)
            option = PreferenceClassRegistry.option_class(config.fetch(:prefix), type).find(record.option_id)
            values[type.to_s] = option.name
          end
          assert_equal payload.fetch("preferences"), persisted_snapshot
        end
      ensure
        blocker&.exec("ROLLBACK") if blocker && blocker.transaction_status != PG::PQTRANS_IDLE
        blocker&.finish
        probe&.finish
        threads.each { |thread| thread.join(8) }
        ids = []
        ids << created_ids.pop(true) while created_ids.present?
        preference_class.where(id: ids).find_each(&:destroy!) if ids.any?
      end
    end
  end
end
