# typed: false
# frozen_string_literal: true

require "test_helper"

class AcceptanceWu29RootLoginSentryTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    @previous_availability = Flipper.enabled?(@feature)
  end

  teardown do
    @previous_availability ? Flipper.enable(@feature) : Flipper.disable(@feature)
  end

  test "A29-5: Sign In becoming blocked refuses root commit without a session, login audit, or consumed ceremony" do
    Flipper.enable(@feature)
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    browser = open_session
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    browser.host!(visa_host)
    browser.https!
    client = OidcClientRegistry.find!("core-app-jp")
    authorization_params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      code_challenge: SecureRandom.urlsafe_base64(32),
      code_challenge_method: "S256",
      scope: "openid profile",
      state: SecureRandom.urlsafe_base64(24),
      nonce: SecureRandom.urlsafe_base64(24),
    }

    browser.get("/oauth/authorize", params: authorization_params)

    assert_equal 303, browser.response.status
    transaction = ClientOidcAuthorizationTransaction.order(:id).last
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: transaction.id)
    flow_now = ClientSignInFlow.database_now
    sign_in_flow = ClientSignInFlow.create!(
      principal: actor,
      state_id: ClientSignInFlowState::SELECTOR_PENDING,
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: flow_now,
      expires_at: flow_now + 15.minutes,
      authentication_method: "secret",
      authentication_event_at: flow_now,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    transaction.update!(secret_sign_in_flow: sign_in_flow)
    base_nonce = browser.session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY)
    ceremony, raw_auth_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: ceremony, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: binding.entry_ref, nonce: base_nonce,
      ),
    )
    expected_intent = AuthEntryIntentResolver.call(
      prompt: transaction.oidc_prompt, entry_intent: binding.entry_intent,
    )
    payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: binding.entry_ref,
      surface: "app",
      expected_intent: expected_intent,
      binding: binding,
      raw_auth_sid: raw_auth_sid,
    )
    remaining_curfew = binding.curfew_at - ClientAuthCeremonySession.database_now
    admitted_ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: payload.fetch("purpose"),
      previous_raw_sid: raw_auth_sid,
      authorization_transaction_ref: transaction.transaction_id,
      ttl: [ClientAuthCeremonySession::DEFAULT_TTL, remaining_curfew].min,
    )
    binding.redeem!(auth_session: ceremony, admitted_auth_session: admitted_ceremony)
    admitted_ceremony.record_authentication_evidence!(method: "secret")
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "app",
      login_challenge: transaction.login_challenge,
      actor: actor,
      session_ref: admitted_ceremony.sid_digest,
      auth_method: "passcode",
      authentication_event_at: Time.current,
      ceremony_session_ref: admitted_ceremony.id.to_s,
    )
    token_count = ClientToken.where(user_id: actor.id).count
    flow_before = sign_in_flow.reload.attributes
    login_audit_count = ClientChronicle.where(
      subject_type: "Client", subject_id: actor.id, event_id: ClientChronicleEvent::LOGGED_IN,
    ).count
    halted_audit_count = ClientChronicle.where(
      subject_type: "Client", subject_id: actor.id, event_id: ClientChronicleEvent::SIGN_FLOW_HALTED,
    ).count
    Flipper.disable(@feature)

    browser.get(
      "/oidc/result",
      params: { result_ref: result.reference, transaction_ref: transaction.transaction_id },
      headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" },
    )

    assert_equal [400, "invalid_request", "login_failed"],
                 [browser.response.status, browser.response.parsed_body.fetch("error"),
                  browser.response.parsed_body.fetch("error_description"),]
    assert_equal token_count, ClientToken.where(user_id: actor.id).count
    assert_nil browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal login_audit_count,
                 ClientChronicle.where(
                   subject_type: "Client", subject_id: actor.id, event_id: ClientChronicleEvent::LOGGED_IN,
                 ).count
    assert_equal ["authenticated", nil], [transaction.reload.status, transaction.base_finalized_at]
    assert_equal flow_before, sign_in_flow.reload.attributes
    assert_equal "SELECTOR_PENDING", sign_in_flow.state_name_for(sign_in_flow.state_id)
    assert_equal halted_audit_count,
                 ClientChronicle.where(
                   subject_type: "Client", subject_id: actor.id, event_id: ClientChronicleEvent::SIGN_FLOW_HALTED,
                 ).count
    assert_predicate admitted_ceremony.reload, :active?
  end
end
