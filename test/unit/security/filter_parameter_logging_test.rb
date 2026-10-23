# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class FilterParameterLoggingTest < ActiveSupport::TestCase
  test "filters birthdate from logged parameters" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter("birthdate" => "2000-02-03")

    assert_equal "[FILTERED]", filtered.fetch("birthdate")
  end

  test "filters short sensitive redirect and oauth parameters" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter(
      "rt" => "redirect-token",
      "pt" => "path-target",
      "code" => "oauth-code",
      "oauth_code" => "oauth-code-alias",
      "authorization_code" => "authorization-code",
      "cf-turnstile-response" => "turnstile-response",
      "turnstile_response" => "turnstile-response-alias",
      "uid" => "provider-user-id",
      "entry_ref" => "opaque-admission-reference",
    )

    assert_equal "[FILTERED]", filtered.fetch("rt")
    assert_equal "[FILTERED]", filtered.fetch("pt")
    assert_equal "[FILTERED]", filtered.fetch("code")
    assert_equal "[FILTERED]", filtered.fetch("oauth_code")
    assert_equal "[FILTERED]", filtered.fetch("authorization_code")
    assert_equal "[FILTERED]", filtered.fetch("cf-turnstile-response")
    assert_equal "[FILTERED]", filtered.fetch("turnstile_response")
    assert_equal "[FILTERED]", filtered.fetch("uid")
    assert_equal "[FILTERED]", filtered.fetch("entry_ref")
  end

  test "does not let short sensitive names hide safe diagnostic fields" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter(
      "code" => "oauth-code",
      "rt" => "redirect-token",
      "pt" => "path-target",
      "der" => "certificate-der",
      "state" => "oauth-state",
      "uid" => "provider-user-id",
      "provider_uid" => "provider-user-id",
      "reason_code" => "phase_regression",
      "status_code" => "409",
      "http_status_code" => "409",
      "guid" => "safe-guid",
      "public_id" => "safe-public-id",
      "provider" => "google",
      "order" => "created_at",
      "sort" => "asc",
      "support" => "safe-support",
      "attempt_count" => 2,
      "event_uuid" => "safe-event-uuid",
    )

    %w(code rt pt der state uid provider_uid).each do |key|
      assert_equal "[FILTERED]", filtered.fetch(key)
    end

    %w(
      reason_code status_code http_status_code guid public_id provider order sort support attempt_count event_uuid
    ).each do |key|
      assert_not_equal "[FILTERED]", filtered.fetch(key)
    end
  end

  test "filters social identity tokens from Active Record inspection and SQL logs" do
    assert_not_includes ClientExternalIdentity.column_names, "token"
    assert_not_includes ClientExternalIdentity.column_names, "refresh_token"
    assert_includes ClientExternalIdentity.filter_attributes.map(&:to_s), "subject"
  end

  test "browser admission proofs and references are filtered from diagnostic parameters" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    fields = %w(
      auth_sid sid base_browser_digest confirmation_ref binding_ref transaction_ref restart_of
      auth_ceremony_session_ref auth_email_otp_generation
    )
    filtered = filter.filter(fields.index_with { |field| "fixture-#{field}" })

    assert_equal fields.index_with("[FILTERED]"), filtered
  end

  test "does not emit oauth credential values in active record sql logs" do
    log_io = StringIO.new
    logger = ActiveSupport::Logger.new(log_io)
    original_rails_logger = Rails.logger
    original_active_record_logger = ActiveRecord::Base.logger

    Rails.logger = logger
    ActiveRecord::Base.logger = logger

    google_token = "google-token-#{SecureRandom.hex(6)}"
    google_refresh = "google-refresh-#{SecureRandom.hex(6)}"
    google_uid = "google-uid-#{SecureRandom.hex(6)}"
    apple_token = "apple-token-#{SecureRandom.hex(6)}"
    apple_refresh = "apple-refresh-#{SecureRandom.hex(6)}"
    apple_uid = "apple-uid-#{SecureRandom.hex(6)}"

    [google_token, apple_token].each do |provider_token|
      assert_raises(ActiveModel::UnknownAttributeError) { ClientExternalIdentity.new(token: provider_token) }
    end
    [google_refresh, apple_refresh].each do |provider_refresh|
      assert_raises(ActiveModel::UnknownAttributeError) { ClientExternalIdentity.new(refresh_token: provider_refresh) }
    end
    ClientExternalIdentity.create!(
      client: Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE),
      provider: "google", issuer: "https://accounts.google.com", subject: google_uid,
      audience: "google-client-id", verification_authority: "omniauth-google-oauth2/1.2.1",
      verified_at: ClientExternalIdentity.database_now,
    )
    ClientExternalIdentity.create!(
      client: Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE),
      provider: "apple", issuer: "https://appleid.apple.com", subject: apple_uid,
      audience: "apple-client-id", verification_authority: "omniauth-apple/1.4.0",
      verified_at: ClientExternalIdentity.database_now,
    )
    log_output = log_io.string

    assert_no_match(/#{Regexp.escape(google_token)}/, log_output)
    assert_no_match(/#{Regexp.escape(google_refresh)}/, log_output)
    assert_no_match(/#{Regexp.escape(google_uid)}/, log_output)
    assert_no_match(/#{Regexp.escape(apple_token)}/, log_output)
    assert_no_match(/#{Regexp.escape(apple_refresh)}/, log_output)
    assert_no_match(/#{Regexp.escape(apple_uid)}/, log_output)
  ensure
    Rails.logger = original_rails_logger
    ActiveRecord::Base.logger = original_active_record_logger
  end
end
