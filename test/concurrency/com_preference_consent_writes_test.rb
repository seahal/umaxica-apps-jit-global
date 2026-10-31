# frozen_string_literal: true

require "test_helper"
require "timeout"

class ComPreferenceConsentWritesTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "save and reset with the same JWT recheck the generation in both lock orders" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    json_headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    created_ids = Queue.new
    threads = []
    blocker = nil
    probe = nil
    [:save, :reset].each do |first|
      reset!
      host!(host)
      https!
      patch(base_com_api_v0_preferences_theme_path, params: { theme: "light" }.to_json, headers: json_headers)

      assert_response :ok
      token = cookies[PreferenceCookieName.anonymous_jwt]
      claims = PreferenceToken.decode(token, host: host)
      original = ComPreference.find_by!(public_id: claims.fetch("sub"))
      created_ids << original.id
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
      blocker.exec_params("SELECT id FROM com_preferences WHERE id = $1 FOR UPDATE", [original.id])
      results = Queue.new
      second = (first == :save) ? :reset : :save
      [first, second].each_with_index do |operation, index|
        threads << Thread.new do
          browser = open_session
          browser.host!(host)
          browser.https!
          browser.cookies[PreferenceCookieName.anonymous_jwt] = token
          if operation == :save
            browser.patch(
              base_com_api_v0_preferences_theme_path, params: { theme: "dark" }.to_json,
                                                      headers: json_headers,
            )
          else
            browser.delete(base_com_preference_customization_path(ri: "jp"), params: { confirm_reset: "1" })
          end
          issued = PreferenceToken.decode(browser.cookies[PreferenceCookieName.anonymous_jwt], host: host)
          record = ComPreference.find_by(public_id: issued.fetch("sub")) if issued
          created_ids << record.id if record
          results << [operation, browser.response.status, issued]
        rescue StandardError => e
          results << e
        end
        Timeout.timeout(5) do
          loop do
            waiting = probe.exec(<<~SQL.squish).getvalue(0, 0).to_i
              SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()
                AND wait_event_type = 'Lock' AND query LIKE '%com_preferences%' AND query LIKE '%FOR UPDATE%'
            SQL
            break if waiting >= index + 1

            Thread.pass
          end
        end
      end
      blocker.exec("COMMIT")
      outcomes = 2.times.map { Timeout.timeout(8) { results.pop } }
      outcomes.each { |result| raise result if result.is_a?(Exception) }
      ComSettingRecord.connection_pool.with_connection(&:clear_query_cache)
      results_by_operation = outcomes.to_h { |operation, status, issued| [operation, [status, issued]] }
      save_status, save_claims = results_by_operation.fetch(:save)
      reset_status, reset_claims = results_by_operation.fetch(:reset)

      assert_equal 200, save_status
      assert_equal 303, reset_status
      assert_not_equal save_claims.fetch("sub"), reset_claims.fetch("sub")
      assert_equal "dark", save_claims.fetch("preferences").fetch("theme")
      assert_equal "system", reset_claims.fetch("preferences").fetch("theme")
      assert_not_equal original.public_id, reset_claims.fetch("sub")
      if first == :save
        assert_equal original.public_id, save_claims.fetch("sub")
        assert_equal ComPreferenceStatus::ACTIVE, original.reload.status_id
      else
        assert_not_equal original.public_id, save_claims.fetch("sub")
        assert_equal ComPreferenceStatus::RETIRED, original.reload.status_id
      end
      blocker.finish
      probe.finish
      blocker = nil
      probe = nil
    end
  ensure
    blocker&.exec("ROLLBACK") if blocker && blocker.transaction_status != PG::PQTRANS_IDLE
    blocker&.finish
    probe&.finish
    threads&.each { |thread| thread.join(8) }
    ids = []
    ids << created_ids.pop(true) while created_ids.present?
    ComPreferenceChronicle.where(subject_type: "ComPreference", subject_id: ids).delete_all
    ComPreference.where(id: ids).preload(*PreferenceLifecyclePurger::DEPENDENCIES).find_each(&:destroy!)
  end

  test "concurrent choices with one JWT commit separate generations and receipts" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host!(host)
    https!
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch(base_com_api_v0_preferences_cookie_path, params: { consented: true }.to_json, headers: headers)

    assert_response :ok
    token = cookies[PreferenceCookieName.anonymous_jwt]
    binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    original_claims = PreferenceToken.decode(token, host: host)
    original = ComPreference.find_by!(public_id: original_claims.fetch("sub"))
    original_version = ComPreferenceConsentReceipt.find_by!(preference_id: original.id).version
    created_ids = Queue.new
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
    blocker.exec_params("SELECT id FROM com_preferences WHERE id = $1 FOR UPDATE", [original.id])
    results = Queue.new
    threads =
      [true, false].map do |choice|
        Thread.new do
          browser = open_session
          browser.host!(host)
          browser.https!
          browser.cookies[PreferenceCookieName.anonymous_jwt] = token
          browser.cookies[PreferenceBrowserBinding::COOKIE_NAME] = binding
          browser.patch(
            base_com_api_v0_preferences_cookie_path, params: { consented: choice }.to_json,
                                                     headers: headers,
          )
          claims = PreferenceToken.decode(browser.cookies[PreferenceCookieName.anonymous_jwt], host: host)
          record = ComPreference.find_by(public_id: claims.fetch("sub")) if claims
          created_ids << record.id if record
          results << [choice, browser.response.status, claims]
        rescue StandardError => e
          results << e
        end
      end
    Timeout.timeout(5) do
      loop do
        waiting = probe.exec(<<~SQL.squish).getvalue(0, 0).to_i
          SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()
            AND wait_event_type = 'Lock' AND query LIKE '%com_preferences%' AND query LIKE '%FOR UPDATE%'
        SQL
        break if waiting >= 2

        Thread.pass
      end
    end
    blocker.exec("COMMIT")
    outcomes = 2.times.map { Timeout.timeout(8) { results.pop } }
    outcomes.each { |result| raise result if result.is_a?(Exception) }
    ComSettingRecord.connection_pool.with_connection(&:clear_query_cache)
    public_ids = outcomes.map { |_, _, claims| claims.fetch("sub") }

    assert_equal 2, public_ids.uniq.size
    assert_includes public_ids, original.public_id
    outcomes.each do |choice, status, claims|
      assert_equal 200, status
      preference = ComPreference.find_by!(public_id: claims.fetch("sub"))
      consent = ComPreferenceCookie.find_by!(preference_id: preference.id)
      receipt = ComPreferenceConsentReceipt.find_by!(preference_id: preference.id)
      stored_binding = ComPreferenceBrowserBinding.find_by!(preference_id: preference.id)

      assert_equal choice, consent.consented?
      assert_equal choice, consent.functional?
      assert_equal choice, consent.performant?
      assert_equal choice, consent.targetable?
      assert_not_equal original_version, receipt.version
      assert_equal PreferenceBrowserBinding.digest_for(binding), stored_binding.digest
      assert_equal claims.fetch("jti"), preference.jti
    end
  ensure
    blocker&.exec("ROLLBACK") if blocker && blocker.transaction_status != PG::PQTRANS_IDLE
    blocker&.finish
    probe&.finish
    threads&.each { |thread| thread.join(8) }
    ids = []
    ids << original.id if original
    ids << created_ids.pop(true) while created_ids.present?
    ComPreferenceChronicle.where(subject_type: "ComPreference", subject_id: ids).delete_all
    ComPreference.where(id: ids).preload(*PreferenceLifecyclePurger::DEPENDENCIES).find_each(&:destroy!)
  end
end
