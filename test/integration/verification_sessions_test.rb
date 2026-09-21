# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"

class VerificationSessionsTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_totp_credential_statuses, :client_token_statuses, :client_token_kinds
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
    host! @host

    @user = Client.create!(status_id: ClientStatus::NOTHING)

    @token = ClientToken.create!(
      user: @user,
      user_token_status_id: ClientTokenStatus::NOTHING,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: "verify_#{SecureRandom.hex(4)}",
      discard_at: 1.day.from_now,
    )
    @token.update!(created_at: 1.hour.ago)

    @headers = {
      "Authorization" => "Bearer #{
        AuthenticationToken.encode(
          @user, host: @host, session_public_id: @token.public_id, resource_type: "client",
                 jwt_issuer_id: "surface:SIGN_APP",
        )
      }",
    }.freeze

    ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )
  end

  test "GET within 15 minutes skips verification" do
    @token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "settings_email")

    return_to = Base64.urlsafe_encode64(auth_app_settings_path(ri: "jp"))
    get auth_app_verification_url(scope: "settings_email", return_to: return_to, ri: "jp"),
        headers: @headers

    get new_auth_app_verification_totp_url(ri: "jp"), headers: @headers

    assert_response :redirect
    assert_redirected_to auth_app_settings_url(ri: "jp")
  end

  test "POST within 30 minutes skips verification" do
    @token.update!(last_step_up_at: 20.minutes.ago, last_step_up_scope: "settings_email")

    return_to = Base64.urlsafe_encode64(auth_app_settings_path(ri: "jp"))
    get auth_app_verification_url(scope: "settings_email", return_to: return_to, ri: "jp"),
        headers: @headers

    if true # Replaced STUB stub with real execution as per G1
      post auth_app_verification_totp_url(ri: "jp"),
           params: { verification: { code: "000000" } },
           headers: @headers
    end

    assert_response :redirect
    assert_redirected_to auth_app_settings_url(ri: "jp")
  end
end
