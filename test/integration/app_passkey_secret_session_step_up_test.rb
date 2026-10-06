# frozen_string_literal: true

require "test_helper"

class AppPasskeySecretSessionStepUpTest < ActionDispatch::IntegrationTest
  include BaseBrowserRpTestHelper

  setup do
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  test "a Secret session cannot start Base passkey registration without an independent Step-Up" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(
      user: actor, established_authentication_method: "secret", root_login_established_at: ClientToken.database_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
    base = open_session
    base.host!(base_host)
    base.https!
    install_base_browser_rp_credentials!(
      surface: "app", host: base_host, actor: actor, token: token, cookie_jar: base.cookies,
    )
    headers = {
      "Host" => base_host, "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
    }

    assert_no_difference("ClientStepUpCeremonyTransaction.count") do
      base.get(new_base_app_identity_passkey_path(ri: "jp"), headers: headers)
    end

    assert_equal 400, base.response.status
    assert_nil base.response.headers["Location"]
    assert_equal 0, actor.client_passkeys.count
    assert_nil token.reload.last_step_up_at
  end

  test "a Secret-origin session with a valid other-method Step-Up reaches the admitted Auth registration" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    passkey = actor.client_passkeys.create!(webauthn_id: "secret-session-step-up-passkey", public_key: "public-key")
    token = ClientToken.create!(
      user: actor, established_authentication_method: "secret", root_login_established_at: ClientToken.database_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_passkey",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: passkey.public_id, last_step_up_full_reauthentication: false,
    )
    base = open_session
    base.host!(base_host)
    base.https!
    install_base_browser_rp_credentials!(
      surface: "app", host: base_host, actor: actor, token: token, cookie_jar: base.cookies,
    )
    headers = {
      "Host" => base_host, "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
    }

    base.get(new_base_app_identity_passkey_path(ri: "jp"), headers: headers)

    assert_equal 303, base.response.status, base.response.body
    registration_uri = URI.parse(base.response.location)
    assert_equal auth_host, registration_uri.host
    assert_equal new_auth_app_verification_registration_passkey_path,
                 registration_uri.path
    assert_match BaseAuthAdmissionCoordinator::ADMISSION_REFERENCE_PATTERN,
                 Rack::Utils.parse_query(registration_uri.query).fetch("entry_ref")
    assert_equal 1, actor.client_passkeys.count
    assert_equal "passkey", token.reload.last_step_up_method
  end
end
