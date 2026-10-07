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

  test "additional TOTP registration starts with a read-only Base form and purpose-bound POST" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: ClientToken.database_now)
    passkey = actor.client_passkeys.create!(webauthn_id: SecureRandom.hex(32), public_key: "public-key")
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp",
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
    headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    assert_no_difference("ClientAuthAdmissionBinding.count") do
      base.get(new_base_app_identity_totp_path(ri: "jp"), headers: headers)
    end

    assert_equal 200, base.response.status
    csrf = base.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    assert_difference("ClientAuthAdmissionBinding.count", 1) do
      base.post(base_app_identity_totps_path(ri: "jp"), params: { authenticity_token: csrf }, headers: headers)
    end

    assert_equal 303, base.response.status, base.response.body
    entry_uri = URI.parse(base.response.location)

    assert_equal [ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), new_auth_app_settings_totp_path],
                 [entry_uri.host, entry_uri.path]
    reference = Rack::Utils.parse_query(entry_uri.query).fetch("entry_ref")
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: reference)

    assert_equal ["credential_registration_handoff", ["totp"], token.id, 0],
                 [binding.purpose, binding.step_up_ceremony_transaction.allowed_methods_array,
                  binding.base_token_id, actor.client_totp_credentials.count,]
    auth = open_session
    auth.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    auth.https!
    auth.get(entry_uri.to_s)

    assert_equal [200, "/ceremony_bindings", nil],
                 [auth.response.status, URI.parse(auth.response.parsed_body.at_css("form")["action"]).path,
                  binding.reload.auth_ceremony_session_id,]
    csrf = auth.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    auth_headers = {
      "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
    }
    auth.post(
      "/ceremony_bindings", params: { entry_ref: reference, authenticity_token: csrf, ri: "jp" },
                            headers: auth_headers,
    )

    assert_equal 303, auth.response.status
    confirmation_url = auth.response.location
    root_headers = as_user_headers(actor, host: base_host, session_public_id: token.public_id)
    base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = root_headers.fetch("Authorization").delete_prefix("Bearer ")
    base.get(confirmation_url)

    assert_equal 200, base.response.status
    assert_nil binding.reload.base_confirmed_at
    csrf = base.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base.post(confirmation_url, params: { authenticity_token: csrf, ri: "jp" }, headers: headers)

    assert_equal [303, true, new_auth_app_settings_totp_path],
                 [base.response.status, binding.reload.confirmed?, URI.parse(base.response.location).path]
    auth.get(base.response.location)

    assert_equal 200, auth.response.status
    csrf = auth.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    assert_no_difference("IdentityTotpCeremonyCandidate.count") do
      auth.post(
        auth_app_settings_totps_path(ri: "jp"),
        params: { entry_ref: reference, authenticity_token: csrf }, headers: auth_headers,
      )
    end

    assert_equal 303, auth.response.status
    assert_predicate binding.reload, :redeemed?
    assert_equal new_auth_app_settings_totp_url(
      ri: "jp", host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), protocol: "https",
    ), auth.response.location
    assert_not_includes auth.response.location, "entry_ref"
    assert_equal 0, actor.client_totp_credentials.count
    foreign_base = open_session
    foreign_base.host!(base_host)
    foreign_base.https!
    install_base_browser_rp_credentials!(
      surface: "app", host: base_host, actor: actor, token: token, cookie_jar: foreign_base.cookies,
    )
    count = ClientAuthAdmissionBinding.count
    foreign_base.get(new_base_app_identity_totp_path(ri: "jp"), params: { restart_of: reference }, headers: headers)

    assert_equal [400, nil, count, nil],
                 [foreign_base.response.status, foreign_base.response.location, ClientAuthAdmissionBinding.count,
                  binding.reload.retired_at,]
    base.get(new_base_app_identity_passkey_path(ri: "jp"), params: { restart_of: reference }, headers: headers)

    assert_equal [400, nil, nil],
                 [base.response.status, base.response.location, binding.reload.retired_at]
    base.get(new_base_app_identity_totp_path(ri: "jp"), params: { restart_of: reference }, headers: headers)

    assert_equal 200, base.response.status
    restart_field = base.response.parsed_body.at_css('input[name="restart_of"]')

    assert_equal reference, restart_field&.[]("value")
    assert_equal I18n.t("actions.cancel_and_start"), base.response.parsed_body.at_css('button[type="submit"]').text
    csrf = base.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    previous_parent = binding.step_up_ceremony_transaction
    base.post(
      base_app_identity_totps_path(ri: "jp"),
      params: { authenticity_token: csrf, restart_of: restart_field["value"] }, headers: headers,
    )

    assert_equal 303, base.response.status
    replacement_ref = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("entry_ref")

    assert_not_equal reference, replacement_ref
    assert_equal "canceled", previous_parent.reload.status
    assert_equal ["pending", 0],
                 [ClientAuthAdmissionBinding.find_by!(entry_ref: replacement_ref).step_up_ceremony_transaction.status,
                  actor.client_totp_credentials.count,]
  ensure
    ActionController::Base.allow_forgery_protection = protection
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

    assert_equal 200, base.response.status
    csrf = base.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    assert_no_difference("ClientStepUpCeremonyTransaction.count") do
      base.post(base_app_identity_passkeys_path(ri: "jp"), params: { authenticity_token: csrf }, headers: headers)
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

    assert_no_difference("ClientAuthAdmissionBinding.count") do
      base.get(new_base_app_identity_passkey_path(ri: "jp"), headers: headers)
    end

    assert_equal 200, base.response.status
    csrf = base.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base.post(base_app_identity_passkeys_path(ri: "jp"), params: { authenticity_token: csrf }, headers: headers)

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
