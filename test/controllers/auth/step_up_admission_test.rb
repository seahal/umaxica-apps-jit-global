# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class AuthStepUpAdmissionTest < ActionDispatch::IntegrationTest
  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  self.fixture_table_names = []

  fixtures :clients, :client_statuses

  setup do
    TurnstileVerifierStub.reset!
  end

  teardown do
    TurnstileVerifierStub.reset!
  end

  test "verification pages refuse missing admission on every supported surface" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get new_auth_app_verification_passkey_path(ri: "jp")

    assert_response :bad_request
    get new_auth_app_verification_totp_path(ri: "jp")

    assert_response :bad_request
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    get new_auth_org_verification_passkey_path(ri: "jp")

    assert_response :bad_request
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  [["Turnstile rejection", false], ["malformed TOTP", true]].each do |failure, turnstile_success|
    test "APP #{failure} retains the pending ceremony without granting authority" do
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      credential = ClientTotpCredential.create_for_user!(
        user: actor, private_key: ROTP::Base32.random_base32,
        user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      )

      assert_nil credential.last_otp_at

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
      admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: "app", reference: issuance.entry_ref,
      )
      admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
      admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
      admission_binding.confirm_base!(
        base_token: token,
        browser_digest: AuthAdmissionBinding.browser_digest(
          surface: "app", entry_ref: issuance.entry_ref,
          nonce: issuance.authorization_transaction.login_challenge,
        ),
      )
      admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      store_raw_cookies(
        cookies,
        "#{admission_cookie_name}=#{Rack::Utils.escape(admission_raw_sid)}",
        URI.parse("https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}/"),
      )
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      # The relay chain D-100 accepts: entry GET relays to /ceremony_bindings, the Base confirmation
      # receiver redeems it, and the clean verification URL renders the method entry page.
      get auth_app_verification_path(ri: "jp", entry_ref: issuance.entry_ref), headers: NAVIGATION_HEADERS
      3.times do
        break unless response.status == 303

        location = URI.parse(response.headers["Location"])
        get location.path, params: Rack::Utils.parse_nested_query(location.query)
      end

      assert_response :ok
      get new_auth_app_verification_totp_path(ri: "jp")
      form = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("form")
      TurnstileVerifierStub.enabled = true
      TurnstileVerifierStub.response = { "success" => turnstile_success }
      code = turnstile_success ? "invalid" : ROTP::TOTP.new(credential.private_key).now
      post form.fetch("action"), params: {
        :verification => { code: code, credential_public_id: credential.public_id },
        :authenticity_token => form.fetch("csrf_token"),
        "cf-turnstile-response" => "test-only",
      }

      assert_response :unprocessable_content
      props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

      assert_not_empty props.fetch("errors")
      assert_equal "pending", issuance.ticket.reload.status
      assert_nil issuance.ticket.verified_at
      assert_nil issuance.ticket.verified_credential_ref
      assert_nil credential.reload.last_otp_at
      assert_nil token.reload.last_step_up_at
      assert_nil cookies[AuthenticationCookieName.access]
      assert_nil cookies[AuthenticationCookieName.refresh]
    end
  end

  test "bootstrap registration and credential-change continuity cannot enter ordinary step-up endpoints" do
    %w(bootstrap credential_registration credential_change).each do |purpose|
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(authentication_epoch: 0, user: actor)
      transaction = ClientStepUpCeremonyTransaction.create_transaction!(
        actor_ref: actor.public_id, session_ref: token.public_id, purpose: purpose,
        required_scope: "settings_totp", required_aal: "none", allowed_methods: %w(passkey totp),
      )
      record = ClientStepUpSession.create!(
        user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
        step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
      )
      # Fixture uses only the production continuity API, never an Auth root token or login cookie.
      ceremony, sid = ClientAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "#{purpose}_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      )
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      cookies[JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"] = sid
      [auth_app_verification_path(ri: "jp"), new_auth_app_verification_passkey_path(ri: "jp"),
       new_auth_app_verification_totp_path(ri: "jp"), auth_app_verification_handoff_path(ri: "jp"),].each do |path|
        get path

        assert_response :bad_request
      end
      assert_equal "pending", transaction.reload.status
      assert_nil record.reload.passkey_challenge_ref
      assert_equal 0, record.attempt_count
      assert ceremony.reload.active?(now: ClientAuthCeremonySession.database_now)
      assert_nil token.reload.last_step_up_at
      assert_nil cookies[AuthenticationCookieName.access]
      assert_nil cookies[AuthenticationCookieName.refresh]
    end
  end

  test "APP TOTP verifies the admitted credential without an Auth login or Base freshness" do
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
    admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: "app", reference: issuance.entry_ref,
    )
    admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
    admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
    admission_binding.confirm_base!(
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.entry_ref,
        nonce: issuance.authorization_transaction.login_challenge,
      ),
    )
    admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    store_raw_cookies(
      cookies,
      "#{admission_cookie_name}=#{Rack::Utils.escape(admission_raw_sid)}",
      URI.parse("https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}/"),
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get auth_app_verification_path(ri: "jp", entry_ref: issuance.entry_ref), headers: NAVIGATION_HEADERS
    3.times do
      break unless response.status == 303

      location = URI.parse(response.headers["Location"])
      get location.path, params: Rack::Utils.parse_nested_query(location.query)
    end
    get new_auth_app_verification_totp_path(ri: "jp")

    assert_response :success
    assert_equal "pending", issuance.ticket.reload.status
    form = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("form")
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    now = ClientTotpCredential.database_now
    ClientTotpCredential.stub(:database_now, now) do
      post form.fetch("action"), params: {
        :verification => { code: ROTP::TOTP.new(credential.private_key).at(now.to_i),
                           credential_public_id: credential.public_id, },
        :authenticity_token => form.fetch("csrf_token"),
        "cf-turnstile-response" => "test-only",
      }
    end

    assert_redirected_to auth_app_verification_handoff_path(ri: "jp")
    assert_equal "verified", issuance.ticket.reload.status
    assert_equal "totp", issuance.ticket.method
    assert_equal credential.public_id, issuance.ticket.verified_credential_ref
    assert_nil token.reload.last_step_up_at
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "APP OP-mediated completion binds the Auth ticket result without changing the root login" do
    actor = clients(:one)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    root = ClientToken.create!(authentication_epoch: 0, user: actor)
    client = OidcClientRegistry.find!("core-app-jp")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: root.authentication_epoch,
      client_token: root,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 20.seconds,
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    redirect_uri = client.redirect_uris_by_realm.fetch("client").first
    verifier = SecureRandom.urlsafe_base64(32)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri:,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor:, token: root, client:, params:, validated_request:,
    )
    context = issuance.context.reload
    authorization = issuance.authorization_transaction.reload
    ticket = issuance.ticket.reload
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.entry_ref)
    auth_session, raw_auth_sid = binding.class.auth_admission_session_class.issue!
    binding.attach_auth_session!(auth_session:, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: root,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.entry_ref, nonce: authorization.login_challenge,
      ),
    )
    root_before = root.attributes.slice(
      "refresh_token_digest", "refresh_token_generation", "root_login_established_at", "last_step_up_at",
    )
    root_count = ClientToken.where(user_id: actor.id).count
    device_before = root.device_session_record!.attributes.slice("current_refresh_token_id", "revoked_at")
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    cookies[JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"] = raw_auth_sid
    get auth_app_verification_path(ri: "jp", entry_ref: issuance.entry_ref), headers: NAVIGATION_HEADERS
    3.times do
      break unless response.status == 303

      location = URI.parse(response.headers["Location"])
      get location.path, params: Rack::Utils.parse_nested_query(location.query)
    end
    binding.reload
    ceremony = binding.class.auth_admission_session_class.find(binding.admitted_auth_ceremony_session_id)
    get new_auth_app_verification_totp_path(ri: "jp")

    assert_response :success
    form = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("form")
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    verification_time = ClientTotpCredential.database_now
    ClientTotpCredential.stub(:database_now, verification_time) do
      post form.fetch("action"), params: {
        "verification" => {
          "code" => ROTP::TOTP.new(credential.private_key).at(verification_time.to_i),
          "credential_public_id" => credential.public_id,
        },
        "authenticity_token" => form.fetch("csrf_token"),
        "cf-turnstile-response" => "test-only",
      }
    end

    assert_redirected_to auth_app_verification_handoff_path(ri: "jp")
    assert_equal "verified", ticket.reload.status
    assert_equal AuthCeremonySession::STATUS_ADMITTED, ceremony.reload.status_id
    assert_not_predicate ceremony, :authentication_evidence_recorded?
    get auth_app_verification_handoff_path(ri: "jp")

    assert_response :success
    handoff_form = response.parsed_body.at_css("form")
    post handoff_form["action"], params: {
      authenticity_token: handoff_form.at_css('input[name="authenticity_token"]')["value"],
    }

    assert_response :see_other
    callback = URI.parse(response.location)
    visa_host = callback.host
    visa_access =
      AuthenticationToken.encode(
        actor, host: visa_host, session_public_id: root.public_id, resource_type: "client",
               jwt_issuer_id: "surface:VISA_APP",
      )
    store_raw_cookies(
      cookies, "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(visa_access)}",
      URI.parse("https://#{visa_host}/"),
    )
    host! visa_host
    get callback.path, params: Rack::Utils.parse_nested_query(callback.query), headers: NAVIGATION_HEADERS

    assert_response :success
    continuation_form = response.parsed_body.at_css("form")
    continuation_params =
      continuation_form.css('input[type="hidden"]').to_h do |input|
        [input["name"], input["value"]]
      end
    post continuation_form["action"], params: continuation_params, headers: {
      "Origin" => "https://#{visa_host}",
      "Sec-Fetch-Site" => "same-origin",
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
    }

    assert_response :see_other
    assert_equal AuthCeremonySession::STATUS_COMPLETED, ceremony.reload.status_id
    assert_equal "authenticated", authorization.reload.status_name
    assert_equal actor.public_id, authorization.actor_ref
    assert_equal root.public_id, authorization.session_ref
    assert_equal "totp", authorization.auth_method
    assert_equal OidcAuthorizeRequestResolver::STEP_UP_ACR, authorization.acr
    assert_equal verification_time.to_i, authorization.authenticated_at.to_i
    assert_equal ClientStepUpContextState::PENDING, context.reload.state_id
    assert_equal "consumed", ticket.reload.status
    assert_equal root_before, root.reload.attributes.slice(*root_before.keys)
    assert_equal device_before, root.device_session_record!.attributes.slice(*device_before.keys)
    assert_equal root_count, ClientToken.where(user_id: actor.id).count
    assert_nil root.reload.last_step_up_at
    assert_empty ClientStepUpCommit.where(context_ref: context.public_id)
    assert_empty ClientStepUpAuditOutbox.where(context_ref: context.public_id)
    assert_equal visa_access, cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "Email OTP GET is read-only and issuance POST uses the admitted DB transaction without root cookies" do
    actor = clients(:one)
    email = actor.client_emails.create!(
      address: "admitted-email@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
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
    admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: "app", reference: issuance.entry_ref,
    )
    admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
    admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
    admission_binding.confirm_base!(
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.entry_ref,
        nonce: issuance.authorization_transaction.login_challenge,
      ),
    )
    admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    store_raw_cookies(
      cookies,
      "#{admission_cookie_name}=#{Rack::Utils.escape(admission_raw_sid)}",
      URI.parse("https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}/"),
    )
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: issuance.ticket.transaction_id)
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get auth_app_verification_path(ri: "jp", entry_ref: issuance.entry_ref), headers: NAVIGATION_HEADERS
    3.times do
      break unless response.status == 303

      location = URI.parse(response.headers["Location"])
      get location.path, params: Rack::Utils.parse_nested_query(location.query)
    end
    get new_auth_app_verification_email_path(ri: "jp")
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')&.attr("content")

    assert_response :success
    assert_equal 0, record.reload.email_code_generation
    form = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("form")
    post form.fetch("action"), params: { authenticity_token: form.fetch("csrf_token") }

    assert_redirected_to edit_auth_app_verification_email_path(issuance.ticket.transaction_id, ri: "jp")
    assert_equal 1, record.reload.email_code_generation
    assert_equal email.public_id, record.email_credential_ref
    assert_equal "pending", record.email_delivery_state
    get response.location

    assert_response :success
    assert_equal 1, record.reload.email_code_generation
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]

    post auth_app_verification_email_redelivery_path(issuance.ticket.transaction_id, ri: "jp"),
         params: { authenticity_token: csrf }

    assert_response :unprocessable_content
    assert_equal 1, record.reload.email_code_generation
    assert_equal "pending", issuance.ticket.reload.status
    patch auth_app_verification_email_path(SecureRandom.uuid, ri: "jp"),
          params: { verification: { code: "000000" }, authenticity_token: csrf }

    assert_response :bad_request
    assert_equal 0, email.reload.step_up_otp_failures

    post auth_app_verification_cancellation_path(ri: "jp"),
         params: { authenticity_token: csrf, return_to: "/identity/birthdate" }

    assert_response :see_other
    cancellation = URI.parse(response.location)

    oidc_authorization_endpoint = URI.parse(OidcIssuer.authorization_endpoint("client"))
    cancellation_query = Rack::Utils.parse_nested_query(cancellation.query)

    assert_equal oidc_authorization_endpoint.host, cancellation.host
    assert_equal oidc_authorization_endpoint.path, cancellation.path
    assert_match AuthAdmissionBinding::REFERENCE_PATTERN, cancellation_query.fetch("step_up_cancellation_ref")
    assert_equal issuance.ticket.transaction_id, cancellation_query.fetch("step_up_ticket_ref")
    assert_equal issuance.context.public_id, cancellation_query.fetch("step_up_context_ref")
    assert_equal "pending", issuance.ticket.reload.status
    assert_predicate ClientAuthCeremonySession.find_by!(
      step_up_ceremony_transaction_ref: issuance.ticket.transaction_id,
    ), :active?
    assert_nil token.reload.last_step_up_at
    post auth_app_verification_cancellation_path(ri: "jp"), params: { authenticity_token: csrf }

    assert_response :see_other
    repeated_cancellation = URI.parse(response.location)

    assert_equal oidc_authorization_endpoint.host, repeated_cancellation.host
    assert_equal oidc_authorization_endpoint.path, repeated_cancellation.path
  end

  test "Passkey GET creates no challenge and options POST binds the admitted transaction" do
    actor = clients(:one)
    origin = "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}"
    fake = WebAuthn::FakeClient.new(origin, encoding: :base64url)
    registration = fake.create(
      challenge: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false), user_verified: true,
    )
    relying_party = WebAuthn::RelyingParty.new(
      id: URI.parse(origin).host, allowed_origins: [origin], encoding: :base64url,
    )
    credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    actor.client_passkeys.create!(webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0)
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
    admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: "app", reference: issuance.entry_ref,
    )
    admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
    admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
    admission_binding.confirm_base!(
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.entry_ref,
        nonce: issuance.authorization_transaction.login_challenge,
      ),
    )
    admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    store_raw_cookies(
      cookies,
      "#{admission_cookie_name}=#{Rack::Utils.escape(admission_raw_sid)}",
      URI.parse("https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}/"),
    )
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: issuance.ticket.transaction_id)
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get auth_app_verification_path(ri: "jp", entry_ref: issuance.entry_ref), headers: NAVIGATION_HEADERS
    3.times do
      break unless response.status == 303

      location = URI.parse(response.headers["Location"])
      get location.path, params: Rack::Utils.parse_nested_query(location.query)
    end
    get new_auth_app_verification_passkey_path(ri: "jp")
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')&.attr("content")

    assert_response :success
    assert_nil record.reload.passkey_challenge_ref
    panel = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("panel")

    assert_equal auth_app_verification_passkey_options_path(ri: "jp"), panel.fetch("options_url")
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    post panel.fetch("options_url"), params: { "cf-turnstile-response" => "test-only" },
                                     headers: { "X-CSRF-Token" => csrf }, as: :json

    assert_response :success
    assert_equal record.reload.passkey_challenge_ref, response.parsed_body.fetch("challenge_id")
    assert_match(/\A[A-Za-z0-9_-]{21}\z/, record.passkey_challenge_ref)
    assert_equal "required", response.parsed_body.fetch("options").fetch("userVerification")
    assert_equal "pending", issuance.ticket.reload.status
    assert_nil token.reload.last_step_up_at

    assertion = fake.get(challenge: record.passkey_challenge, user_present: true, user_verified: true, sign_count: 2)
    post panel.fetch("verification_url"),
         params: { credential: assertion, challenge_id: record.passkey_challenge_ref },
         headers: { "X-CSRF-Token" => csrf }, as: :json

    assert_response :success
    assert_equal "ok", response.parsed_body.fetch("status")
    assert_equal "verified", issuance.ticket.reload.status
    assert_nil token.reload.last_step_up_at
    get response.parsed_body.fetch("redirect_url")

    assert_response :success
    form = response.parsed_body.at_css("form")
    post form["action"], params: { authenticity_token: form.at_css('input[name="authenticity_token"]')["value"] }

    assert_response :see_other
    completion = URI.parse(response.location)
    oidc_authorization_endpoint = URI.parse(OidcIssuer.authorization_endpoint("client"))
    query = Rack::Utils.parse_nested_query(completion.query)

    assert_equal oidc_authorization_endpoint.host, completion.host
    assert_equal oidc_authorization_endpoint.path, completion.path
    assert_match AuthAdmissionBinding::REFERENCE_PATTERN, query.fetch("step_up_result_ref")
    assert_equal issuance.ticket.transaction_id, query.fetch("step_up_ticket_ref")
    assert_equal issuance.context.public_id, query.fetch("step_up_context_ref")
    assert_not_includes response.location, "jump.umaxica.net"
    assert_not_includes response.location, "/sign"
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "Auth completes the step-up entry relay without an Auth root credential" do
    actor = clients(:one)
    actor.client_passkeys.create!(webauthn_id: "admission-passkey", public_key: "public-key")
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
    admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: "app", reference: issuance.entry_ref,
    )
    admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
    admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
    admission_binding.confirm_base!(
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.entry_ref,
        nonce: issuance.authorization_transaction.login_challenge,
      ),
    )
    admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    store_raw_cookies(
      cookies,
      "#{admission_cookie_name}=#{Rack::Utils.escape(admission_raw_sid)}",
      URI.parse("https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}/"),
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    # D-53 B: the entry relay replaces the attach session with an admitted ceremony row exactly once.
    assert_difference -> { ClientAuthCeremonySession.count }, 1 do
      get auth_app_verification_path(ri: "jp", entry_ref: issuance.entry_ref), headers: NAVIGATION_HEADERS
      5.times do
        break unless response.status == 303

        get response.headers["Location"]
      end
    end
    assert_response :ok
    get auth_app_verification_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_equal %w(passkey totp), props.fetch("methods").map { |method| method.fetch("key") }
    assert_equal "pending", issuance.ticket.reload.status
    assert_nil token.reload.last_step_up_at

    other_browser = open_session
    other_browser.get(auth_app_verification_url(ri: "jp", host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL")))

    assert_equal 400, other_browser.response.status
    get auth_app_verification_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_equal %w(passkey totp), props.fetch("methods").map { |method| method.fetch("key") }
  end
end
