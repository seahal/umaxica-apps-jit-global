# frozen_string_literal: true

require "test_helper"

class ComPreferenceCommitFailureTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "binding entropy failure rolls back consent and Web Push writes before issuing cookies" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    requests = [
      [base_com_api_v0_preferences_cookie_path, { consented: true }],
      [base_com_api_v0_preferences_web_push_path, { web_push: "enabled" }],
    ]

    requests.each do |path, body|
      reset!
      host!(host)
      https!
      setting_transaction_open = false
      failure =
        lambda do
          setting_transaction_open = ComPreference.lease_connection.transaction_open?
          raise IOError, "entropy source unavailable"
        end
      old_audit_count = ComPreferenceChronicle.count

      PreferenceBrowserBinding.stub(:mint_value, failure) do
        assert_no_difference -> { ComPreference.count } do
          patch(path, params: body.to_json, headers: headers)
        end
      end

      assert_response :service_unavailable
      assert setting_transaction_open
      assert_equal old_audit_count, ComPreferenceChronicle.count
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceBrowserBinding::COOKIE_NAME}="
    end
  end

  test "chronicle commit failure reports the already committed setting without issuing cookies" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host!(host)
    https!
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch(base_com_api_v0_preferences_theme_path, params: { theme: "dark" }.to_json, headers: headers)

    assert_response :ok
    token = cookies[PreferenceCookieName.anonymous_jwt]
    claims = PreferenceToken.decode(token, host: host)
    original = ComPreference.find_by!(public_id: claims.fetch("sub"))
    existing_ids = ComPreference.pluck(:id)
    old_audits = ComPreferenceChronicle.where(subject_type: "ComPreference", subject_id: original.id).count
    connection = ComPreferenceChronicle.lease_connection
    failure = -> { raise ActiveRecord::StatementInvalid, "chronicle commit unavailable" }
    errors = []

    Rails.logger.stub(:error, ->(message) { errors << message }) do
      connection.stub(:commit_db_transaction, failure) do
        delete(base_com_preference_customization_path(ri: "jp"), params: { confirm_reset: "1" })
      end
    end

    assert_response :service_unavailable
    replacement_ids = ComPreference.where.not(id: existing_ids).pluck(:id)

    assert_equal 1, replacement_ids.size
    assert_equal ComPreferenceStatus::RETIRED, original.reload.status_id
    assert_equal old_audits,
                 ComPreferenceChronicle.where(subject_type: "ComPreference", subject_id: original.id).count
    assert errors.any? { |message| message.include?("preference.write.setting_committed_audit_failed") }
    assert_equal token, cookies[PreferenceCookieName.anonymous_jwt]
    [PreferenceCookieName.anonymous_jwt, PreferenceCookieName.anonymous_experience,
     PreferenceIoKeys::Cookies::LANGUAGE, PreferenceBrowserBinding::COOKIE_NAME,].each do |name|
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  ensure
    ids = [original&.id, *replacement_ids].compact
    ComPreferenceChronicle.where(subject_type: "ComPreference", subject_id: ids).delete_all if ids.any?
    ComPreference.where(id: ids).preload(*PreferenceLifecyclePurger::DEPENDENCIES).find_each(&:destroy!) if ids.any?
  end

  test "setting commit failure rolls back a consent change and emits no preference cookies" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host!(host)
    https!
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch(base_com_api_v0_preferences_cookie_path, params: { consented: true }.to_json, headers: headers)

    assert_response :ok
    token = cookies[PreferenceCookieName.anonymous_jwt]
    binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    claims = PreferenceToken.decode(token, host: host)
    original = ComPreference.find_by!(public_id: claims.fetch("sub"))
    original_attributes = original.attributes
    cookie_attributes = ComPreferenceCookie.find_by!(preference_id: original.id).attributes
    receipt_attributes = ComPreferenceConsentReceipt.find_by!(preference_id: original.id).attributes
    binding_attributes = ComPreferenceBrowserBinding.find_by!(preference_id: original.id).attributes
    connection = ComPreference.lease_connection
    failure = -> { raise ActiveRecord::StatementInvalid, "setting commit unavailable" }

    connection.stub(:commit_db_transaction, failure) do
      patch(base_com_api_v0_preferences_cookie_path, params: { consented: false }.to_json, headers: headers)
    end

    assert_response :service_unavailable
    assert_equal original_attributes, original.reload.attributes
    assert_equal cookie_attributes, ComPreferenceCookie.find_by!(preference_id: original.id).attributes
    assert_equal receipt_attributes, ComPreferenceConsentReceipt.find_by!(preference_id: original.id).attributes
    assert_equal binding_attributes, ComPreferenceBrowserBinding.find_by!(preference_id: original.id).attributes
    assert_equal token, cookies[PreferenceCookieName.anonymous_jwt]
    assert_equal binding, cookies[PreferenceBrowserBinding::COOKIE_NAME]
    [PreferenceCookieName.anonymous_jwt, PreferenceCookieName.anonymous_experience,
     PreferenceIoKeys::Cookies::LANGUAGE, PreferenceBrowserBinding::COOKIE_NAME,].each do |name|
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  ensure
    if original
      ComPreferenceChronicle.where(subject_type: "ComPreference", subject_id: original.id).delete_all
      ComPreference.where(id: original.id).preload(*PreferenceLifecyclePurger::DEPENDENCIES).find_each(&:destroy!)
    end
  end

  test "setting commit failure rolls back reset and emits no preference cookies" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host!(host)
    https!
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch(base_com_api_v0_preferences_theme_path, params: { theme: "dark" }.to_json, headers: headers)

    assert_response :ok
    token = cookies[PreferenceCookieName.anonymous_jwt]
    claims = PreferenceToken.decode(token, host: host)
    original = ComPreference.find_by!(public_id: claims.fetch("sub"))
    original_attributes = original.attributes
    old_count = ComPreference.count
    old_audits = ComPreferenceChronicle.where(subject_type: "ComPreference", subject_id: original.id).count
    connection = ComPreference.lease_connection
    failure = -> { raise ActiveRecord::StatementInvalid, "setting commit unavailable" }

    connection.stub(:commit_db_transaction, failure) do
      delete(base_com_preference_customization_path(ri: "jp"), params: { confirm_reset: "1" })
    end

    assert_response :service_unavailable
    assert_equal old_count, ComPreference.count
    assert_equal original_attributes, original.reload.attributes
    assert_equal old_audits,
                 ComPreferenceChronicle.where(subject_type: "ComPreference", subject_id: original.id).count
    assert_equal token, cookies[PreferenceCookieName.anonymous_jwt]
    [PreferenceCookieName.anonymous_jwt, PreferenceCookieName.anonymous_experience,
     PreferenceIoKeys::Cookies::LANGUAGE, PreferenceBrowserBinding::COOKIE_NAME,].each do |name|
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  ensure
    if original
      ComPreferenceChronicle.where(subject_type: "ComPreference", subject_id: original.id).delete_all
      ComPreference.where(id: original.id).preload(*PreferenceLifecyclePurger::DEPENDENCIES).find_each(&:destroy!)
    end
  end
end
