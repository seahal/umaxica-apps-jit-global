# typed: false
# frozen_string_literal: true

require "test_helper"

# Limiters on the base surfaces' unauthenticated POST and bearer-token endpoints.
# Each of these guards a guessing oracle -- an OAuth revocation or userinfo call
# that answers differently for a valid and an invalid credential, or a ceremony
# re-entry that answers differently for a known and an unknown address -- so a
# limiter that is declared but never fires is the difference between bounded and
# unbounded probing. Nothing exercised these handlers before.
class BaseEndpointRateLimitTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
  self.fixture_table_names = []

  setup { Rails.configuration.x.rate_limit.fetch(:store).clear }
  teardown { Rails.configuration.x.rate_limit.fetch(:store).clear }

  OAUTH_REVOCATION_QUOTA = 20
  OAUTH_USERINFO_QUOTA = 60
  CEREMONY_REENTRY_QUOTA = 5
  ENTRA_CALLBACK_QUOTA = 10

  test "the app OAuth revocation endpoint bounds revocation probing per source" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    OAUTH_REVOCATION_QUOTA.times do
      post base_app_oauth_revocation_path, params: { token: "probe", client_id: "unknown" }
    end

    assert_not_equal 429, response.status

    post base_app_oauth_revocation_path, params: { token: "probe", client_id: "unknown" }

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end

  {
    "app" => ["PUBLIC_BASE_SERVICE_URL", :base_app_oauth_userinfo_path],
    "com" => ["PUBLIC_BASE_CORPORATE_URL", :base_com_oauth_userinfo_path],
    "org" => ["PUBLIC_BASE_STAFF_URL", :base_org_oauth_userinfo_path],
  }.each do |surface, (env_name, helper)|
    test "the #{surface} OAuth userinfo endpoint bounds bearer-token probing per source" do
      host! ENV.fetch(env_name)

      OAUTH_USERINFO_QUOTA.times do
        get public_send(helper), headers: { "Authorization" => "Bearer probe" }
      end

      assert_not_equal 429, response.status

      get public_send(helper), headers: { "Authorization" => "Bearer probe" }

      assert_response :too_many_requests
      assert_equal "60", response.headers["Retry-After"]
    end
  end

  {
    "app recovery" => ["PUBLIC_BASE_SERVICE_URL", :base_app_identity_recovery_session_path],
    "com recovery" => ["PUBLIC_BASE_CORPORATE_URL", :base_com_identity_recovery_session_path],
    "app withdrawal" => ["PUBLIC_BASE_SERVICE_URL", :base_app_identity_withdrawal_session_path],
    "com withdrawal" => ["PUBLIC_BASE_CORPORATE_URL", :base_com_identity_withdrawal_session_path],
  }.each do |label, (env_name, helper)|
    test "the #{label} re-entry endpoint bounds address probing per source" do
      host! ENV.fetch(env_name)

      CEREMONY_REENTRY_QUOTA.times do
        post public_send(helper, ri: "jp"), params: { address: "probe@example.com" }
      end

      assert_not_equal 429, response.status

      post public_send(helper, ri: "jp"), params: { address: "probe@example.com" }

      assert_response :too_many_requests
      assert_equal "60", response.headers["Retry-After"]
    end
  end

  test "the staff Entra callback bounds replayed callbacks per source" do
    previous_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:entra] = OmniAuth::AuthHash.new(provider: "entra", uid: "probe")
    host!(ENV.fetch("PUBLIC_AUTH_STAFF_URL"))

    ENTRA_CALLBACK_QUOTA.times { get(auth_org_social_entra_callback_path(ri: "jp")) }

    assert_not_equal 429, response.status

    get(auth_org_social_entra_callback_path(ri: "jp"))

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  ensure
    OmniAuth.config.mock_auth.delete(:entra)
    OmniAuth.config.test_mode = previous_test_mode
  end
end
