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

  test "filters social identity tokens from Active Record inspection and SQL logs" do
    assert_not_includes ClientExternalIdentity.column_names, "token"
    assert_not_includes ClientExternalIdentity.column_names, "refresh_token"
    assert_includes ClientExternalIdentity.filter_attributes.map(&:to_s), "subject"
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
    ClientGoogleIdentity.create!(
      user: clients(:one),
      uid: google_uid,
      token: google_token,
      refresh_token: google_refresh,
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    ClientAppleIdentity.create!(
      user: clients(:one),
      uid: apple_uid,
      token: apple_token,
      refresh_token: apple_refresh,
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
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
