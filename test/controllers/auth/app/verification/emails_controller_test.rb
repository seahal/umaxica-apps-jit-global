# typed: false
# frozen_string_literal: true

require "test_helper"

# Admission, read-only GET and code issuance are covered by AuthStepUpAdmissionTest; these cases
# cover code submission over HTTP and method admission.
class Auth::App::Verification::EmailsControllerTest < ActionDispatch::IntegrationTest
  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  self.fixture_table_names = []

  fixtures :client_statuses, :client_totp_credential_statuses

  test "the delivered code records email evidence and hands off without granting freshness" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    email = actor.client_emails.create!(
      address: "email-step-up-#{SecureRandom.hex(4)}@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
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
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
    # The delivered code is seeded through the ticket's own API; delivery itself is covered by the
    # issuer and delivery-recorder tests.
    generation = record.issue_bound_email_code!(
      transaction: transaction, credential_ref: email.public_id, code: "012345",
    )
    record.mark_bound_email_delivery!(transaction: transaction, generation: generation, success: true)

    patch auth_app_verification_email_path(transaction.transaction_id, ri: "jp"),
          params: { verification: { code: "012345" } }

    assert_redirected_to auth_app_verification_handoff_path(ri: "jp")
    transaction.reload

    assert_equal "verified", transaction.status
    assert_equal "email_otp", transaction.method
    assert_equal "none", transaction.aal
    assert_equal email.public_id, transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]

    get auth_app_verification_handoff_path(ri: "jp")

    assert_response :success
    assert_equal "strict-origin", response.headers["Referrer-Policy"]
    assert_select 'meta[name="referrer"][content="strict-origin"]'
    form = response.parsed_body.at_css("form")

    assert_equal auth_app_verification_handoff_path(ri: "jp"), form["action"]
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    post form["action"], params: fields

    assert_response :see_other
    expected_endpoint = URI.parse(OidcIssuer.authorization_endpoint("client"))

    assert_equal expected_endpoint.host, URI.parse(response.location).host
    assert_equal expected_endpoint.path, URI.parse(response.location).path
    assert_nil token.reload.last_step_up_at
  end

  # Partitions of the submitted code: a wrong six-digit code, and codes that are not six digits
  # (missing, empty, zero, five digits, seven digits, NUL-bearing).
  test "a wrong or malformed code re-renders the entry page and keeps the ceremony pending" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    email = actor.client_emails.create!(
      address: "email-step-up-#{SecureRandom.hex(4)}@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
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
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
    # The delivered code is seeded through the ticket's own API; delivery itself is covered by the
    # issuer and delivery-recorder tests.
    generation = record.issue_bound_email_code!(
      transaction: transaction, credential_ref: email.public_id, code: "012345",
    )
    record.mark_bound_email_delivery!(transaction: transaction, generation: generation, success: true)

    [
      { verification: { code: "999999" } }, {}, { verification: { code: "" } }, { verification: { code: "0" } },
      { verification: { code: "01234" } }, { verification: { code: "0123456" } },
      { verification: { code: "0123\u00005" } },
    ].each do |submitted_params|
      patch auth_app_verification_email_path(transaction.transaction_id, ri: "jp"), params: submitted_params

      assert_response :unprocessable_content, submitted_params.inspect
      assert_equal "pending", transaction.reload.status, submitted_params.inspect
    end
    assert_nil transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
  end

  test "the email endpoints are refused when Base did not admit email for the ceremony" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    ClientTotpCredential.create_for_user!(
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
    email = actor.client_emails.create!(
      address: "email-step-up-#{SecureRandom.hex(4)}@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!

    assert_response :see_other

    get new_auth_app_verification_email_path(ri: "jp")

    assert_response :bad_request
    post auth_app_verification_emails_path(ri: "jp")

    assert_response :bad_request
    get edit_auth_app_verification_email_path(transaction.transaction_id, ri: "jp")

    assert_response :bad_request
    patch auth_app_verification_email_path(transaction.transaction_id, ri: "jp"),
          params: { verification: { code: "012345" } }

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_equal "pending", transaction.reload.status
    assert_equal 0, email.reload.step_up_otp_failures
  end
end
