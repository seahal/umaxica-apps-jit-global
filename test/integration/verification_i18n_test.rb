# typed: false
# frozen_string_literal: true

require "test_helper"

class VerificationI18nTest < ActionDispatch::IntegrationTest
  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  self.fixture_table_names = []

  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    actor.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid,
      external_id: SecureRandom.uuid,
      public_key: "verification-i18n-public-key",
      sign_count: 0,
      description: "Verification I18n passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    token = ClientToken.create!(
      authentication_epoch: 0,
      user: actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    client = OidcClientRegistry.find!("core-app-jp")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch,
      client_token: token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour,
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = step_up_authorization_params(client:, grant:)
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor:, token:, client:, params:, validated_request:,
    )
    admission = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.entry_ref)
    auth_session, raw_sid = admission.class.auth_admission_session_class.issue!
    admission.attach_auth_session!(auth_session:, confirmation_ref: SecureRandom.uuid)
    admission.confirm_base!(
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.entry_ref,
        nonce: issuance.authorization_transaction.login_challenge,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.entry_ref, surface: "app", expected_intent: "step_up", binding: admission,
      raw_auth_sid: raw_sid,
    )
    admitted_session, admitted_sid = admission.class.auth_admission_session_class.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: issuance.ticket.transaction_id,
    )
    admission.redeem!(auth_session: auth_session, admitted_auth_session: admitted_session)
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    cookies[cookie_name] = admitted_sid
    current_session = ClientAuthCeremonySession.find_active_by_raw_sid(admitted_sid)

    assert_predicate current_session, :admitted?
    assert_equal "step_up_handoff", current_session.admission_purpose
    BaseAuthAdmissionCoordinator.resolve_step_up_admission!(
      payload: {
        "purpose" => current_session.admission_purpose,
        "surface" => "app",
        "actor_type" => BaseAuthAdmissionCoordinator::SURFACE_ACTOR.fetch("app"),
        "subject_ref" => issuance.ticket.transaction_id,
      },
      surface: "app", expected_intent: "step_up",
    )
    get auth_app_verification_path(ri: "jp"), headers: NAVIGATION_HEADERS

    assert_response :success, response.body
  end

  test "verification view displays translated strings in Japanese" do
    assert_response :success
    assert_equal I18n.t("sign.app.verification.index.title", locale: :ja), inertia_props.fetch("title")
    assert_equal I18n.t("sign.app.verification.new.title", locale: :ja), inertia_props.fetch("section_title")
  end

  test "verification view displays translated strings in English" do
    get auth_app_verification_path(ri: "us", lx: "en"), headers: NAVIGATION_HEADERS

    assert_response :success
    assert_equal I18n.t("sign.app.verification.index.title", locale: :en), inertia_props.fetch("title")
    assert_equal I18n.t("sign.app.verification.new.title", locale: :en), inertia_props.fetch("section_title")
  end

  private

  def step_up_authorization_params(client:, grant:)
    verifier = SecureRandom.urlsafe_base64(48)
    {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
  end
end
