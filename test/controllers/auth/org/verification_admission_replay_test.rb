# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::VerificationAdmissionReplayTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  test "the same browser repeats a redeemed Step-Up admission only within its original ten second window" do
    OperatorStatus.ensure_defaults!
    OperatorVisibility.ensure_defaults!
    OperatorMfaStatus.ensure_defaults!
    OperatorTokenStatus.ensure_defaults!
    OperatorTokenKind.ensure_defaults!
    OperatorTokenBindingMethod.ensure_defaults!
    OperatorTokenDbscStatus.ensure_defaults!

    actor = Operator.create!(
      security_mode_id: OperatorSecurityMode::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
      mfa_status_id: OperatorMfaStatus::UNCONFIGURED,
    )
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: actor,
      root_login_established_at: Time.current,
    )
    OperatorPasskey.create!(
      staff: actor, webauthn_id: SecureRandom.uuid, external_id: SecureRandom.uuid,
      public_key: "admission-replay-public-key", sign_count: 0,
      description: "Admission replay passkey", status_id: OperatorPasskeyStatus::ACTIVE,
    )
    client = OidcClientRegistry.find!("core-org-jp")
    now = OpBaseOrgRecord.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token, oidc_client_id: client.client_id,
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
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "operator")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "org", actor:, token:, client:, params:, validated_request:,
    )
    entry_ref = issuance.entry_ref
    transaction = issuance.ticket
    binding = OperatorAuthAdmissionBinding.find_by!(entry_ref:)
    auth_session, raw_auth_sid = binding.class.auth_admission_session_class.issue!
    binding.attach_auth_session!(auth_session:, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref:, nonce: issuance.authorization_transaction.login_challenge,
      ),
    )

    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    https!
    auth_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    store_raw_cookies(
      cookies,
      "#{auth_cookie_name}=#{Rack::Utils.escape(raw_auth_sid)}",
      URI.parse("https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL")}/"),
    )

    get auth_org_verification_path(ri: "jp", entry_ref:), headers: NAVIGATION_HEADERS

    assert_response :see_other
    assert_equal auth_org_verification_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_predicate binding.reload, :redeemed?
    admitted_session_id = binding.admitted_auth_ceremony_session_id
    session_count = OperatorAuthCeremonySession.where(
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    ).count

    assert_equal 1, session_count

    get auth_org_verification_path(ri: "jp", entry_ref:), headers: NAVIGATION_HEADERS

    assert_response :see_other
    assert_equal auth_org_verification_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_not response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)
    assert_equal admitted_session_id, binding.reload.admitted_auth_ceremony_session_id
    assert_equal session_count, OperatorAuthCeremonySession.where(
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    ).count

    foreign = open_session
    foreign.host!(ENV.fetch("PUBLIC_AUTH_STAFF_URL"))
    foreign.https!
    foreign.get(
      auth_org_verification_path(ri: "jp", entry_ref:),
      headers: NAVIGATION_HEADERS,
    )

    assert_equal 409, foreign.response.status
    assert_not foreign.response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)
    assert_equal admitted_session_id, binding.reload.admitted_auth_ceremony_session_id

    [9, 10, 11].each do |seconds|
      OperatorAuthAdmissionBinding.stub(:database_now, binding.created_at + seconds.seconds) do
        get auth_org_verification_path(ri: "jp", entry_ref:), headers: NAVIGATION_HEADERS
      end

      assert_equal((seconds == 9) ? 303 : 400, response.status)
      assert_not response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)
      assert_equal admitted_session_id, binding.reload.admitted_auth_ceremony_session_id
      assert_equal session_count, OperatorAuthCeremonySession.where(
        step_up_ceremony_transaction_ref: transaction.transaction_id,
      ).count
    end

    assert_nil token.reload.last_step_up_at
  end
end
