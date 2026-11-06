# typed: false
# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

# Restricted Mode cannot initiate, complete, or reuse ordinary step-up authority.
# HTTP cases use the Base admission contract without Auth root credentials.
class Auth::Org::Verification::EmergencyStepUpProhibitionTest < ActionDispatch::IntegrationTest
  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  fixtures :operators, :operator_tokens

  setup do
    @staff = operators(:one)
    @token = OperatorToken.create!(
      authentication_epoch: 0, staff: @staff, root_login_established_at: Time.current,
    )
    @token.update!(authentication_context: nil)
    @passkey = OperatorPasskey.create!(
      staff: @staff, webauthn_id: SecureRandom.uuid, external_id: SecureRandom.uuid,
      public_key: "org-emergency-public-key", sign_count: 0,
      description: "Org step-up passkey", status_id: OperatorPasskeyStatus::ACTIVE,
    )
    @requirement = StepUpRequirement.new(
      scope: OidcAuthorizeRequestResolver::STEP_UP_SCOPE, required_aal: nil,
      step_up_required: true, allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: @staff.public_id,
      resource_ref: nil, tenant_ref: nil,
      session_binding: @token.public_id, token_binding: @token.public_id,
      purpose: "step_up", audience: "step_up:org", require_session_binding: true,
    )
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
  end

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  test "ORG Auth options and real assertion return scoped evidence without a root credential" do
    origin = "https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL")}"
    fake = WebAuthn::FakeClient.new(origin, encoding: :base64url)
    registration = fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
    relying_party = WebAuthn::RelyingParty.new(
      id: URI.parse(origin).host, allowed_origins: [origin], encoding: :base64url,
    )
    credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    passkey = @staff.staff_passkeys.create!(
      webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0,
    )
    client = OidcClientRegistry.find!("core-org-jp")
    now = OpBaseOrgRecord.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: @staff, resource_type: "operator")
    oidc_issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "org", actor: @staff, token: @token, client:, params:, validated_request:,
    )
    entry_ref = oidc_issuance.entry_ref
    transaction = oidc_issuance.ticket
    binding = attach_auth_ceremony_entry!(
      auth_org_verification_path, reference: entry_ref, params: { ri: "jp" },
    )
    binding.confirm_base!(
      base_token: @token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref:, nonce: oidc_issuance.authorization_transaction.login_challenge,
      ),
    )
    record = OperatorStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
    get auth_org_verification_path(ri: "jp", entry_ref: entry_ref), headers: NAVIGATION_HEADERS

    assert_response :see_other
    follow_redirect!

    assert_response :success

    get new_auth_org_verification_passkey_path(ri: "jp")

    assert_response :success
    assert_nil record.reload.passkey_challenge_ref

    panel = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("panel")
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    post panel.fetch("options_url"), params: { "cf-turnstile-response" => "test-only" }, as: :json

    assert_response :success
    assert_equal "required", response.parsed_body.fetch("options").fetch("userVerification")

    assertion = fake.get(challenge: record.reload.passkey_challenge, user_verified: true, sign_count: 2)
    post panel.fetch("verification_url"),
         params: { credential: assertion, challenge_id: record.passkey_challenge_ref }, as: :json

    assert_response :success
    assert_equal "verified", transaction.reload.status
    assert_equal passkey.external_id, transaction.verified_credential_ref
    assert_nil @token.reload.last_step_up_at

    get response.parsed_body.fetch("redirect_url")

    assert_response :success

    form = response.parsed_body.at_css("form")
    post form["action"], params: { authenticity_token: form.at_css('input[name="authenticity_token"]')["value"] }

    assert_response :see_other
    destination = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(destination.query)

    expected_endpoint = URI.parse(OidcIssuer.authorization_endpoint("operator"))

    assert_equal expected_endpoint.host, destination.host
    assert_equal expected_endpoint.path, destination.path
    assert_equal transaction.transaction_id, query.fetch("step_up_ticket_ref")
    assert_equal oidc_issuance.context.public_id, query.fetch("step_up_context_ref")
    assert_match AuthAdmissionBinding::REFERENCE_PATTERN, query.fetch("step_up_result_ref")
    assert_not query.key?("step_up_cancellation_ref")
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "Base refuses admission for an emergency session without creating a ticket" do
    client = OidcClientRegistry.find!("core-org-jp")
    now = OpBaseOrgRecord.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: @staff, resource_type: "operator")
    @token.update!(authentication_context: "standby")

    assert_no_difference ["OperatorStepUpCeremonyTransaction.count", "OperatorStepUpSession.count"] do
      assert_raises(OidcStepUpAuthorizationIssuer::NoActiveGrant) do
        OidcStepUpAuthorizationIssuer.call!(
          surface: "org", actor: @staff, token: @token, client:, params:, validated_request:,
        )
      end
    end
    assert_nil @token.reload.last_step_up_at
    assert_equal "standby", @token.authentication_context
  end

  test "a direct passkey page without admission is refused and grants no emergency freshness" do
    @token.update!(authentication_context: "standby")
    get new_auth_org_verification_passkey_path(ri: "jp")

    assert_response :bad_request
    assert_nil @token.reload.last_step_up_at
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "a direct passkey POST without admission creates no emergency freshness" do
    @token.update!(authentication_context: "standby")
    post auth_org_verification_passkey_path(ri: "jp"), params: {
      verification: { challenge_id: "anything", credential_json: { id: @passkey.webauthn_id }.to_json },
    }

    assert_response :bad_request
    assert_nil @token.reload.last_step_up_at
    assert_nil @token.last_step_up_scope
    assert_equal "standby", @token.authentication_context
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "legacy root freshness cannot satisfy an OIDC step-up requirement before or after emergency mode" do
    now = Time.current
    @token.update!(
      last_step_up_at: now, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_aal: "aal1", last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
      last_step_up_session_public_id: @token.public_id,
    )

    assert_not_predicate StepUpResolver.call(token: @token, requirement: @requirement, now: now), :satisfied?

    @token.update!(authentication_context: "standby")

    assert_not_predicate StepUpResolver.call(token: @token.reload, requirement: @requirement, now: now), :satisfied?
  end

  test "Base refuses verified evidence when the session becomes emergency before finalization" do
    client = OidcClientRegistry.find!("core-org-jp")
    now = OpBaseOrgRecord.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: @staff, resource_type: "operator")
    oidc_issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "org", actor: @staff, token: @token, client:, params:, validated_request:,
    )
    entry_ref = oidc_issuance.entry_ref
    transaction = oidc_issuance.ticket
    binding = attach_auth_ceremony_entry!(
      auth_org_verification_path, reference: entry_ref, params: { ri: "jp" },
    )
    binding.confirm_base!(
      base_token: @token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref:, nonce: oidc_issuance.authorization_transaction.login_challenge,
      ),
    )
    transaction = transaction
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
      verified_at: OperatorStepUpCeremonyTransaction.database_now, verified_credential_ref: @passkey.external_id,
    )
    ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
    )
    @token.update!(authentication_context: "standby")

    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @staff, token: @token.reload, transaction: transaction,
        requirement: @requirement, raw_result: result.code,
      )
    end
    assert_nil @token.reload.last_step_up_at
    assert_equal "verified", transaction.reload.status
    assert_nil transaction.consumed_at
    assert_not_predicate ceremony.reload, :completed?
  end

  test "normal Base admission reaches Auth passkey selection without Auth root credentials" do
    client = OidcClientRegistry.find!("core-org-jp")
    now = OpBaseOrgRecord.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: @staff, resource_type: "operator")
    oidc_issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "org", actor: @staff, token: @token, client:, params:, validated_request:,
    )
    entry_ref = oidc_issuance.entry_ref
    transaction = oidc_issuance.ticket
    binding = attach_auth_ceremony_entry!(
      auth_org_verification_path, reference: entry_ref, params: { ri: "jp" },
    )
    binding.confirm_base!(
      base_token: @token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref:, nonce: oidc_issuance.authorization_transaction.login_challenge,
      ),
    )
    get auth_org_verification_path(ri: "jp", entry_ref: entry_ref), headers: NAVIGATION_HEADERS

    assert_response :see_other
    follow_redirect!

    assert_response :success

    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_equal ["passkey"], props.fetch("methods").map { |method| method.fetch("key") }
    assert_equal "pending", transaction.reload.status
    assert_nil @token.reload.last_step_up_at
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "admitted Auth continuity refuses a session changed to emergency before passkey selection" do
    client = OidcClientRegistry.find!("core-org-jp")
    now = OpBaseOrgRecord.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: @staff, resource_type: "operator")
    oidc_issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "org", actor: @staff, token: @token, client:, params:, validated_request:,
    )
    entry_ref = oidc_issuance.entry_ref
    transaction = oidc_issuance.ticket
    binding = attach_auth_ceremony_entry!(
      auth_org_verification_path, reference: entry_ref, params: { ri: "jp" },
    )
    binding.confirm_base!(
      base_token: @token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref:, nonce: oidc_issuance.authorization_transaction.login_challenge,
      ),
    )
    get auth_org_verification_path(ri: "jp", entry_ref: entry_ref), headers: NAVIGATION_HEADERS

    assert_response :see_other
    follow_redirect!

    assert_response :success

    @token.update!(authentication_context: "standby")
    get new_auth_org_verification_passkey_path(ri: "jp")

    assert_response :bad_request
    assert_equal "pending", transaction.reload.status
    assert_nil transaction.verified_at
    assert_nil @token.reload.last_step_up_at
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end
end
