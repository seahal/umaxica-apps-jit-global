# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::Identity::EmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @client = clients(:one)
    @passkey = @client.client_passkeys.create!(
      webauthn_id: "app-email-controller-#{SecureRandom.hex(8)}",
      public_key: "public-key-#{SecureRandom.hex(8)}",
      description: "Email controller test passkey",
      uv_verified_at: Time.current,
    )
    @email = ClientEmail.create!(
      user: @client, address: "app-email-destroy-#{SecureRandom.hex(4)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
  end

  test "destroy with fresh step-up removes the email" do
    delete base_app_identity_email_url(@email.public_id, ri: "jp", host: @host),
           headers: client_headers(step_up_scope: "settings_email")

    assert_response :see_other
    assert_equal ClientEmailStatus::DELETED, @email.reload.user_email_status_id
    assert_predicate @email, :binding_released?
  end

  test "destroy without fresh step-up is refused and keeps the email" do
    delete base_app_identity_email_url(@email.public_id, ri: "jp", host: @host),
           headers: client_headers(step_up_scope: nil)

    assert_response :unauthorized
    assert ClientEmail.exists?(@email.id)
  end

  test "destroy with step-up for another scope is refused and keeps the email" do
    delete base_app_identity_email_url(@email.public_id, ri: "jp", host: @host),
           headers: client_headers(step_up_scope: "settings_secret_credential")

    assert_response :unauthorized
    assert ClientEmail.exists?(@email.id)
  end

  private

  def client_headers(step_up_scope:)
    token = ClientToken.create!(
      user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
      root_login_established_at: Time.current, established_authentication_method: "passkey",
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    BaseSelectorAuthority.prepare(surface: :app, principal: @client, session: token)
    if step_up_scope
      _verification, raw_verification = ClientVerification.issue_for_token!(token: token)
      cookies[ClientVerification.cookie_name] = raw_verification
      token.update!(
        last_step_up_at: Time.current, last_step_up_scope: step_up_scope,
        last_step_up_aal: "aal2", last_step_up_method: "passkey",
        last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
        last_step_up_audience: "step_up:app", last_step_up_credential_ref: @passkey.public_id,
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_full_reauthentication: false,
      )
    end
    install_base_browser_rp_credentials!(surface: "app", host: @host, actor: @client, token: token)
    as_user_headers(@client, host: @host, session_public_id: token.public_id).except("Cookie", "HTTP_COOKIE")
  end
end
