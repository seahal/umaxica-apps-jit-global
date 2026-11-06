# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Verification::SetupsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  fixtures :client_statuses

  test "an admitted bootstrap shows the registration methods and cancellation, never a back link" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
    issuance =
      begin
        admission_issuance = BaseStepUpAdmissionIssuer.call!(
          actor: actor,
          token: token,
          requirement: StepUpRequirement.new(
            scope: "settings_telephone", purpose: "bootstrap", step_up_required: false,
            phishing_resistant_required: false, user_verification_required: false,
            full_reauthentication_required: false, actor_ref: actor.public_id,
            resource_ref: nil, tenant_ref: nil,
            allowed_methods: %i(passkey totp), audience: "step_up:app", session_binding: token.public_id,
            token_binding: token.public_id, require_session_binding: true, ttl: 15.minutes,
          ),
          return_to: "/identity/telephones",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: token,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: admission_issuance.transaction.surface, reference: admission_issuance.reference,
        )
        admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
        admission_binding.attach_auth_session!(
          auth_session: admission_session,
          confirmation_ref: SecureRandom.uuid,
        )
        admission_binding.confirm_base!(
          base_token: token,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: admission_issuance.transaction.surface,
            entry_ref: admission_issuance.reference,
            nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          ),
        )
        admission_auth_host = {
          "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
          "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
          "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
        }.fetch(admission_issuance.transaction.surface)
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        # Rack::Test::CookieJar#merge mutates the jar and has no merge! counterpart.
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_raw_sid)}",
          URI.parse("https://#{admission_auth_host}/"),
        )
        admission_issuance
      end
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    # An admission reference is accepted only on a top-level document navigation.
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference),
        headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }

    assert_response :see_other
    assert_equal new_auth_app_verification_setup_path(ri: "jp"), URI.parse(response.location).request_uri

    get new_auth_app_verification_setup_path(ri: "jp")

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    methods = props.fetch("methods").to_h { |method| [method.fetch("key"), method.fetch("href")] }

    assert_equal %w(email passkey totp), methods.keys.sort
    assert_equal new_auth_app_verification_registration_passkey_path(ri: "jp"), methods.fetch("passkey")
    assert_equal new_auth_app_settings_totp_path(ri: "jp"), methods.fetch("totp")
    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL"), URI.parse(methods.fetch("email")).host
    assert_equal "/identity/emails/registration/new", URI.parse(methods.fetch("email")).path
    assert_not props.key?("back")
    assert_equal(
      { "label" => I18n.t("actions.cancel"),
        "action" => auth_app_verification_cancellation_path(ri: "jp"),
        "method" => "post", },
      props.fetch("cancel"),
    )
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
  end

  test "the setup page is refused without an admitted bootstrap and never redirects to sign-in" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    get new_auth_app_verification_setup_path(ri: "jp")

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_nil response.headers["Location"]
  end

  test "a step-up admission is not accepted by the setup entry" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    email = actor.client_emails.create!(
      address: "step-up-setup-#{SecureRandom.hex(4)}@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
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
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    binding = attach_auth_ceremony_entry!(
      auth_app_verification_path,
      reference: entry_ref,
      params: { ri: "jp" },
    )
    binding.confirm_base!(
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref:, nonce: issuance.authorization_transaction.login_challenge,
      ),
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref:)

    assert_response :bad_request
    assert_equal 0, ClientAuthCeremonySession.where(
      step_up_ceremony_transaction_ref: issuance.ticket.transaction_id,
    ).count
  end

  test "the admitted bootstrap opens the Auth passkey registration ceremony" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor, root_login_established_at: Time.current)
    issuance =
      begin
        admission_issuance = BaseStepUpAdmissionIssuer.call!(
          actor: actor,
          token: token,
          requirement: StepUpRequirement.new(
            scope: "settings_telephone", purpose: "bootstrap", step_up_required: false,
            phishing_resistant_required: false, user_verification_required: false,
            full_reauthentication_required: false, actor_ref: actor.public_id,
            resource_ref: nil, tenant_ref: nil,
            allowed_methods: %i(passkey totp), audience: "step_up:app", session_binding: token.public_id,
            token_binding: token.public_id, require_session_binding: true, ttl: 15.minutes,
          ),
          return_to: "/identity/telephones",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: token,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: admission_issuance.transaction.surface, reference: admission_issuance.reference,
        )
        admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
        admission_binding.attach_auth_session!(
          auth_session: admission_session,
          confirmation_ref: SecureRandom.uuid,
        )
        admission_binding.confirm_base!(
          base_token: token,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: admission_issuance.transaction.surface,
            entry_ref: admission_issuance.reference,
            nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          ),
        )
        admission_auth_host = {
          "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
          "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
          "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
        }.fetch(admission_issuance.transaction.surface)
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        # Rack::Test::CookieJar#merge mutates the jar and has no merge! counterpart.
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_raw_sid)}",
          URI.parse("https://#{admission_auth_host}/"),
        )
        admission_issuance
      end
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))

    # An admission reference is accepted only on a top-level document navigation.
    get(
      new_auth_app_verification_registration_passkey_path(ri: "jp", entry_ref: issuance.reference),
      headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" },
    )

    assert_response :see_other
    assert_equal new_auth_app_verification_registration_passkey_path(ri: "jp"), URI.parse(response.location).request_uri

    get(new_auth_app_verification_registration_passkey_path(ri: "jp"))

    assert_response :success
    assert_not_includes response.body, "jump.umaxica.net"
    assert_not_includes response.body, "/sign"
    assert_equal "pending", issuance.transaction.reload.status

    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    post(
      auth_app_verification_registration_passkey_options_path(ri: "jp"),
      params: { "cf-turnstile-response" => "test-only" }, as: :json,
    )

    assert_response :ok
    options = response.parsed_body.fetch("options")

    assert_equal %w(umaxica.app umaxica.app), [options.dig("user", "name"), options.dig("user", "displayName")]
    assert_equal "required", options.dig("authenticatorSelection", "residentKey")
  ensure
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end
end
