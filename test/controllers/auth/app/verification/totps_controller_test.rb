# typed: false
# frozen_string_literal: true

require "test_helper"

# Success, Turnstile rejection and malformed input are covered by AuthStepUpAdmissionTest; these
# cases cover credential selection, replay of a consumed window, revocation and method admission.
class Auth::App::Verification::TotpsControllerTest < ActionDispatch::IntegrationTest
  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  self.fixture_table_names = []

  fixtures :client_statuses, :client_totp_credential_statuses

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  test "the page offers a selector that lists only the admitted actor's two active authenticators" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    first = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    second = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    stranger = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    foreign = ClientTotpCredential.create_for_user!(
      user: stranger, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    client = OidcClientRegistry.find!("core-app-jp")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor:, token:, client:, params:, validated_request:,
    )
    entry_ref = issuance.entry_ref
    issuance.ticket
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    admit_auth_ceremony_entry!(
      auth_app_verification_path,
      reference: entry_ref,
      params: { ri: "jp" },
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref:, nonce: issuance.authorization_transaction.login_challenge,
      ),
    )

    assert_response :see_other

    get new_auth_app_verification_totp_path(ri: "jp")

    assert_response :success
    form = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("form")
    selector = form.fetch("credential_selector")

    assert_equal "verification[credential_public_id]", selector.fetch("name")
    assert_equal [first.public_id, second.public_id].sort, selector.fetch("options").map { |o| o.fetch("value") }.sort
    assert_not_includes response.body, foreign.public_id
    assert_not_includes response.body, first.private_key
    assert_not_includes response.body, second.private_key
  end

  test "a wrong six-digit code keeps the ceremony pending and grants nothing" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    client = OidcClientRegistry.find!("core-app-jp")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor:, token:, client:, params:, validated_request:,
    )
    entry_ref = issuance.entry_ref
    transaction = issuance.ticket
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    admit_auth_ceremony_entry!(
      auth_app_verification_path,
      reference: entry_ref,
      params: { ri: "jp" },
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref:, nonce: issuance.authorization_transaction.login_challenge,
      ),
    )

    assert_response :see_other
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    now = ClientTotpCredential.database_now
    valid = ROTP::TOTP.new(credential.private_key).at(now.to_i)
    wrong = format("%06d", (Integer(valid, 10) + 1) % 1_000_000)

    post auth_app_verification_totp_path(ri: "jp"), params: {
      :verification => { code: wrong, credential_public_id: credential.public_id },
      "cf-turnstile-response" => "test-only",
    }

    assert_response :unprocessable_content
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_equal [I18n.t("sign.app.verification.errors.incorrect_code")], props.fetch("errors")
    assert_equal "pending", transaction.reload.status
    assert_nil transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
  end

  test "the correct code of a revoked authenticator is refused" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    client = OidcClientRegistry.find!("core-app-jp")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor:, token:, client:, params:, validated_request:,
    )
    entry_ref = issuance.entry_ref
    transaction = issuance.ticket
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    admit_auth_ceremony_entry!(
      auth_app_verification_path,
      reference: entry_ref,
      params: { ri: "jp" },
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref:, nonce: issuance.authorization_transaction.login_challenge,
      ),
    )

    assert_response :see_other

    assert_response :see_other
    credential.update!(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::REVOKED)
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    now = ClientTotpCredential.database_now

    ClientTotpCredential.stub(:database_now, now) do
      post auth_app_verification_totp_path(ri: "jp"), params: {
        :verification => {
          code: ROTP::TOTP.new(credential.private_key).at(now.to_i), credential_public_id: credential.public_id,
        },
        "cf-turnstile-response" => "test-only",
      }
    end

    assert_response :unprocessable_content
    assert_equal "pending", transaction.reload.status
    assert_nil token.reload.last_step_up_at
  end

  test "a code window verified in one ceremony cannot be replayed in a second ceremony" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    # Two browser sessions each receive an independently OIDC-mediated admission.
    ceremonies =
      2.times.map do
        token = ClientToken.create!(authentication_epoch: 0, user: actor)
        browser = open_session
        browser.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
        browser.https!
        client = OidcClientRegistry.find!("core-app-jp")
        issuance_now = OpBaseAppRecord.database_now
        grant = OpAppGrant.create!(
          authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
          oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: issuance_now - 1.hour, refresh_token_expires_at: issuance_now + 1.hour,
        )
        grant.issue_refresh_token!(expires_at: issuance_now + 1.hour, now: issuance_now)
        params = {
          response_type: "code",
          client_id: client.client_id,
          redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
          scope: grant.oidc_scope,
          state: SecureRandom.urlsafe_base64(32),
          nonce: SecureRandom.urlsafe_base64(32),
          code_challenge: "a" * 43,
          code_challenge_method: "S256",
          prompt: "login",
          claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
        }
        validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
        issuance = OidcStepUpAuthorizationIssuer.call!(
          surface: "app", actor:, token:, client:, params:, validated_request:,
        )
        entry_ref = issuance.entry_ref
        transaction = issuance.ticket
        admit_auth_ceremony_entry!(
          auth_app_verification_path,
          reference: entry_ref,
          params: { ri: "jp" },
          browser: browser,
          base_token: token,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "app", entry_ref:, nonce: issuance.authorization_transaction.login_challenge,
          ),
        )

        assert_equal 303, browser.response.status
        [browser, transaction]
      end
    now = ClientTotpCredential.database_now
    code = ROTP::TOTP.new(credential.private_key).at(now.to_i)
    statuses =
      ceremonies.map do |browser, transaction|
        ClientTotpCredential.stub(:database_now, now) do
          browser.post(
            auth_app_verification_totp_path(ri: "jp"), params: {
              :verification => { code: code, credential_public_id: credential.public_id },
              "cf-turnstile-response" => "test-only",
            },
          )
        end
        [browser.response.status, transaction.reload.status]
      end

    assert_equal [[302, "verified"], [422, "pending"]], statuses
  end

  test "the TOTP endpoints are refused when Base did not admit TOTP for the ceremony" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    email = actor.client_emails.create!(
      address: "totp-method-exclusion-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    client = OidcClientRegistry.find!("core-app-jp")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor:, token:, client:, params:, validated_request:,
    )
    entry_ref = issuance.entry_ref
    transaction = issuance.ticket
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    admit_auth_ceremony_entry!(
      auth_app_verification_path,
      reference: entry_ref,
      params: { ri: "jp" },
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref:, nonce: issuance.authorization_transaction.login_challenge,
      ),
    )

    assert_response :see_other

    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )

    assert_response :see_other

    get new_auth_app_verification_totp_path(ri: "jp")

    assert_response :bad_request
    now = ClientTotpCredential.database_now
    post auth_app_verification_totp_path(ri: "jp"), params: {
      verification: {
        code: ROTP::TOTP.new(credential.private_key).at(now.to_i), credential_public_id: credential.public_id,
      },
    }

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_equal "pending", transaction.reload.status
    assert_nil credential.reload.last_otp_at
  end
end
