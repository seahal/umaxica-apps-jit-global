# typed: false
# frozen_string_literal: true

require "test_helper"

class AppWithdrawalStepUpEnforcerTest < ActionDispatch::IntegrationTest
  fixtures :client_totp_credential_statuses

  setup do
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)

    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! @host
    @client = Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
    @token = ClientToken.create!(
      user: @client,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
      discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    BaseSelectorAuthority.prepare(surface: :app, principal: @client, session: @token)
  end

  test "app withdrawal destructive action requires fresh step-up" do
    create_totp_credential!

    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" },
          headers: authenticated_headers

    assert_response :unauthorized
    assert_equal VerificationBase::STEP_UP_REQUIRED_MESSAGE, response.body
  end

  test "app withdrawal destructive action rejects stale step-up" do
    create_totp_credential!
    mark_token_step_up_satisfied!(at: 1.day.ago)

    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" },
          headers: authenticated_headers

    assert_response :unauthorized
    assert_equal VerificationBase::STEP_UP_REQUIRED_MESSAGE, response.body
  end

  test "app withdrawal destructive action accepts valid token-bound step-up" do
    mark_token_step_up_satisfied!

    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" },
          headers: authenticated_headers

    assert_response :see_other
    assert_redirected_to new_base_app_identity_withdrawal_path(ri: "jp", ack_schedule_purge: "1")
  end

  private

  def create_totp_credential!
    ClientTotpCredential.create!(
      user: @client,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )
  end

  def mark_token_step_up_satisfied!(at: Time.current)
    @token.update_columns(
      last_step_up_at: at,
      last_step_up_scope: "withdrawal",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
      updated_at: Time.current,
    )
  end

  def authenticated_headers
    csrf_token = "test_csrf_token"
    cookies["csrf_token"] = csrf_token
    {
      "Accept" => "text/html",
      "Client-Agent" => "Mozilla/5.0",
      "X-CSRF-Token" => csrf_token,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
      "Authorization" => "Bearer #{access_token}",
    }
  end

  def access_token
    AuthenticationToken.encode(
      @client,
      host: @host,
      session_public_id: @token.public_id,
      resource_type: "client",
      jwt_issuer_id: "surface:BASE_APP",
    )
  end
end
