# typed: false
# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class SignOrgVerificationBaseDirectCoverageTest < ActionDispatch::IntegrationTest
  setup do
    @base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    @staff = Operator.create!(status_id: OperatorStatus::ACTIVE)
    @token = OperatorToken.create!(staff: @staff, authentication_context: AuthenticationContextValue::NORMAL_KEY)
    @token.rotate_refresh_token!
    @staff.staff_passkeys.create!(
      webauthn_id: SecureRandom.urlsafe_base64(32), external_id: SecureRandom.uuid,
      public_key: "stored fixture key", status_id: OperatorPasskeyStatus::ACTIVE,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @staff)
    @requirement = StepUpRequirement.new(
      step_up_required: true, scope: "operator_lifecycle", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
      ttl: 15.minutes, purpose: "step_up", audience: "step_up:org", session_binding: @token.public_id,
      token_binding: @token.public_id, require_session_binding: true, actor_ref: @staff.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    @auth_headers = as_staff_headers(@staff, host: @auth_host, session_public_id: @token.public_id)
    @base_headers = as_staff_headers(@staff, host: @base_host, session_public_id: @token.public_id)
    client = OidcClientRegistry.find!("base-org-ww")
    rp = OperatorRpSession.create!(
      operator_token: @token, oidc_client_id: client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.current,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    access = AuthenticationTokenService.encode(
      @staff, host: @base_host, resource_type: "operator", session_public_id: @token.public_id,
              base_session_public_id: @token.public_id, oidc_sid: rp.public_id, oidc_jti: rp.oidc_jti,
              expires_at: 10.minutes.from_now, scopes: %w(openid profile), issuer: OidcIssuer.for_client(client),
              audiences: [client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
              subject: OidcSubject.for(@staff, resource_type: "operator"), client_id: client.client_id,
    )
    cookie = [@base_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(
                rp
                                .issue_refresh_token!,
              )}",].join("; ")
    @base_headers = @base_headers.merge("Cookie" => cookie, "HTTP_COOKIE" => cookie)
  end

  test "a missing Root cannot satisfy an explicit step-up requirement" do
    assert_not_predicate StepUpResolver.call(token: nil, requirement: @requirement), :satisfied?
  end

  test "a legacy verification record does not replace complete Root evidence" do
    verification, = OperatorVerification.issue_for_token!(token: @token)
    original_last_used = verification.last_used_at

    assert_not_predicate StepUpResolver.call(token: @token, requirement: @requirement), :satisfied?
    assert_equal original_last_used, verification.reload.last_used_at
    assert_nil @token.reload.last_step_up_at
  end

  test "a missing verification cookie leaves the protected Base operation pending" do
    get base_org_identity_withdrawal_url(ri: "jp", host: @base_host), headers: @base_headers

    assert_response :redirect
    assert_equal "/verification", URI.parse(response.location).path
    assert_nil @token.reload.last_step_up_at
  end

  test "a forged verification cookie cannot authorize the protected Base operation" do
    cookie = [@base_headers.fetch("Cookie"), "#{OperatorVerification.cookie_name}=forged-verification"].join("; ")
    get base_org_identity_withdrawal_url(ri: "jp", host: @base_host),
        headers: @base_headers.merge("Cookie" => cookie, "HTTP_COOKIE" => cookie)

    assert_response :redirect
    assert_equal "/verification", URI.parse(response.location).path
    assert_nil @token.reload.last_step_up_at
  end

  test "an authentic legacy verification cookie remains non-authoritative and is not stamped as used" do
    verification, raw = OperatorVerification.issue_for_token!(token: @token)
    original_last_used = verification.last_used_at
    cookie = [@base_headers.fetch("Cookie"),
              "#{OperatorVerification.cookie_name}=#{Rack::Utils.escape(raw)}",].join("; ")
    get base_org_identity_withdrawal_url(ri: "jp", host: @base_host),
        headers: @base_headers.merge("Cookie" => cookie, "HTTP_COOKIE" => cookie)

    assert_response :redirect
    assert_equal original_last_used, verification.reload.last_used_at
    assert_nil @token.reload.last_step_up_at
  end

  test "a revoked Root never authorizes the protected Base operation" do
    @token.revoke!
    get base_org_identity_withdrawal_url(ri: "jp", host: @base_host), headers: @base_headers

    assert_response :redirect
    assert_equal "/sign", URI.parse(response.location).path
    assert_nil @token.reload.last_step_up_at
    assert_predicate @token, :revoked?
  end

  test "the protected GET returns to Base verification with its original operation scope" do
    get base_org_identity_withdrawal_url(ri: "jp", host: @base_host), headers: @base_headers

    assert_response :redirect
    target = URI.parse(response.location)
    query = Rack::Utils.parse_query(target.query)

    assert_equal @base_host, target.host
    assert_equal "/verification", target.path
    assert_equal "operator_lifecycle", query.fetch("scope")
    assert_predicate query["pt"], :present?
    assert_nil @token.reload.last_step_up_at
  end

  test "unsatisfied public resolution retains the explicit policy without inventing a freshness expiry" do
    decision = StepUpResolver.call(token: @token, requirement: @requirement)

    assert_not_predicate decision, :satisfied?
    assert_equal "operator_lifecycle", decision.scope
    assert_nil decision.satisfied_at
    assert_nil decision.expires_at
    assert_predicate decision, :usable_token?
  end

  test "a real public passkey ceremony authorizes Base only after result consumption" do
    @token.rotate_refresh_token! unless @token.device_session.current_refresh_token_id
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: "operator_lifecycle", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
      ttl: 15.minutes, purpose: "step_up", audience: "step_up:org", session_binding: @token.public_id,
      token_binding: @token.public_id, require_session_binding: true, actor_ref: @staff.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: @staff, token: @token, requirement: requirement, return_to: "/identity/withdrawal",
      base_browser_nonce: nonce, base_token: @token,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: issuance.reference)
    attached, raw_sid = OperatorAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: @token, browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "org", entry_ref: issuance.reference, nonce: nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "org", expected_intent: "step_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, admitted_sid = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    continuity_cookie = [@auth_headers.fetch("Cookie"), "#{cookie_name}=#{Rack::Utils.escape(admitted_sid)}"].join("; ")
    @auth_headers = @auth_headers.merge("Cookie" => continuity_cookie, "HTTP_COOKIE" => continuity_cookie)
    host!(@auth_host)
    https!
    fake = WebAuthn::FakeClient.new("https://#{@auth_host}", encoding: :base64url)
    registration = WebAuthn::Credential.from_create(fake.create(user_verified: true))
    passkey = @staff.staff_passkeys.create!(
      webauthn_id: registration.id, public_key: registration.public_key, sign_count: 0,
      external_id: SecureRandom.uuid, status_id: OperatorPasskeyStatus::ACTIVE,
    )
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    post(
      auth_org_verification_passkey_options_path(ri: "jp"),
      params: { "cf-turnstile-response" => "test" }, headers: @auth_headers,
    )

    assert_response :success
    options = response.parsed_body
    assertion = fake.get(challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 1)
    post(
      auth_org_verification_passkey_path(ri: "jp"),
      params: { challenge_id: options.fetch("challenge_id"), credential: assertion }, headers: @auth_headers,
    )

    assert_response :success
    assert_equal 1, passkey.reload.sign_count
    assert_nil @token.reload.last_step_up_at
    assert_not OperatorVerification.active.exists?(staff_token_id: @token.id)
    assert_not OperatorChronicle.exists?(actor_id: @staff.id, event_id: OperatorChronicleEvent::STEP_UP_VERIFIED)
    get(auth_org_verification_handoff_path(ri: "jp"), headers: @auth_headers)

    assert_response :success
    form = response.parsed_body.at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    post(form["action"], params: fields, headers: @auth_headers)

    assert_response :see_other
    reference = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("result_ref")
    BaseAuthAdmissionCoordinator.validate_result_browser_binding!(
      transaction: issuance.transaction, surface: "org", base_browser_nonce: nonce, base_token: @token,
    )
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: @staff, token: @token, transaction: issuance.transaction.reload,
      requirement: requirement, result_reference: reference,
    )

    assert_not_nil @token.reload.last_step_up_at
    assert_predicate issuance.transaction.reload, :consumed?
    assert_predicate admitted.reload, :completed?
    decision = StepUpResolver.call(token: @token, requirement: requirement)

    assert_predicate decision, :satisfied?
    assert_equal @token.last_step_up_at + requirement.ttl, decision.expires_at
    get(base_org_identity_withdrawal_url(ri: "jp", host: @base_host), headers: @base_headers)

    assert_response :success
    post(auth_org_verification_passkey_options_path(ri: "jp"), headers: @auth_headers)

    assert_response :bad_request
  ensure
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end
end
