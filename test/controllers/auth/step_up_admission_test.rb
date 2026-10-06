# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class AuthStepUpAdmissionTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  fixtures :clients, :client_statuses, :visitor_statuses

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  test "verification pages refuse missing admission on every supported surface" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get new_auth_app_verification_passkey_path(ri: "jp")

    assert_response :bad_request
    get new_auth_app_verification_totp_path(ri: "jp")

    assert_response :bad_request
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    get new_auth_com_verification_passkey_path(ri: "jp")

    assert_response :bad_request
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    get new_auth_org_verification_passkey_path(ri: "jp")

    assert_response :bad_request
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  [["Turnstile rejection", false], ["malformed TOTP", true]].each do |failure, turnstile_success|
    test "APP #{failure} retains the pending ceremony without granting authority" do
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      credential = ClientTotpCredential.create_for_user!(
        user: actor, private_key: ROTP::Base32.random_base32,
        user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      )

      assert_nil credential.last_otp_at

      token = ClientToken.create!(user: actor)
      issuance = issue_confirmed_base_step_up_admission!(
        actor: actor, token: token,
        requirement: StepUpRequirement.new(
          step_up_required: true, scope: "settings_birthdate", allowed_methods: [:totp],
          phishing_resistant_required: false, user_verification_required: false,
          full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
          resource_ref: nil, tenant_ref: nil, purpose: "step_up",
          audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
          require_session_binding: true,
        ), return_to: "/identity/birthdate",
      )
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      get auth_app_verification_path(ri: "jp", entry_ref: issuance.reference)
      csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }
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
      assert_equal "pending", issuance.transaction.reload.status
      assert_nil issuance.transaction.verified_at
      assert_nil issuance.transaction.verified_credential_ref
      assert_nil credential.reload.last_otp_at
      assert_nil token.reload.last_step_up_at
      assert_nil cookies[AuthenticationCookieName.access]
      assert_nil cookies[AuthenticationCookieName.refresh]
    end
  end

  test "bootstrap registration and credential-change continuity cannot enter ordinary step-up endpoints" do
    %w(bootstrap credential_registration credential_change).each do |purpose|
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(user: actor)
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
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(user: actor)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: [:totp],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get auth_app_verification_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }
    get new_auth_app_verification_totp_path(ri: "jp")

    assert_response :success
    assert_equal "pending", issuance.transaction.reload.status
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
    assert_equal "verified", issuance.transaction.reload.status
    assert_equal "totp", issuance.transaction.method
    assert_equal credential.public_id, issuance.transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "Email OTP GET is read-only and issuance POST uses the admitted DB transaction without root cookies" do
    actor = clients(:one)
    email = actor.client_emails.create!(
      address: "admitted-email@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    token = ClientToken.create!(user: actor)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: [:email_otp],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id)
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get auth_app_verification_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }
    get new_auth_app_verification_email_path(ri: "jp")

    assert_response :success
    assert_equal 0, record.reload.email_code_generation
    form = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("form")
    post form.fetch("action"), params: { authenticity_token: form.fetch("csrf_token") }

    assert_redirected_to edit_auth_app_verification_email_path(issuance.transaction.transaction_id, ri: "jp")
    assert_equal 1, record.reload.email_code_generation
    assert_equal email.public_id, record.email_credential_ref
    assert_equal "pending", record.email_delivery_state
    get response.location

    assert_response :success
    assert_equal 1, record.reload.email_code_generation
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]

    post auth_app_verification_email_redelivery_path(issuance.transaction.transaction_id, ri: "jp"),
         params: { authenticity_token: csrf }

    assert_response :unprocessable_content
    assert_equal 1, record.reload.email_code_generation
    assert_equal "pending", issuance.transaction.reload.status
    patch auth_app_verification_email_path(SecureRandom.uuid, ri: "jp"),
          params: { verification: { code: "000000" }, authenticity_token: csrf }

    assert_response :bad_request
    assert_equal 0, email.reload.step_up_otp_failures

    post auth_app_verification_cancellation_path(ri: "jp"),
         params: { authenticity_token: csrf, return_to: "/identity/birthdate" }

    assert_response :see_other
    cancellation = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL"), cancellation.host
    assert_equal base_app_verification_cancellation_path, cancellation.path
    assert_equal issuance.transaction.transaction_id,
                 Rack::Utils.parse_nested_query(cancellation.query).fetch("transaction_ref")
    assert_equal "pending", issuance.transaction.reload.status
    assert_predicate ClientAuthCeremonySession.find_by!(
      step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
    ), :active?
    assert_nil token.reload.last_step_up_at
    post auth_app_verification_cancellation_path(ri: "jp"), params: { authenticity_token: csrf }

    assert_response :see_other
    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL"), URI.parse(response.location).host
    assert_equal base_app_verification_cancellation_path, URI.parse(response.location).path
  end

  test "COM Email OTP admission uses only the Visitor transaction and verified credential" do
    actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
    email = actor.visitor_emails.create!(
      address: "admitted-com-email@example.com", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    token = VisitorToken.create!(visitor: actor)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: [:email_otp],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:com", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    record = VisitorStepUpSession.find_by!(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id)
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    get auth_com_verification_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_com_verification_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }
    get new_auth_com_verification_email_path(ri: "jp")

    assert_response :success
    assert_equal 0, record.reload.email_code_generation
    form = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("form")
    post form.fetch("action"), params: { authenticity_token: form.fetch("csrf_token") }

    assert_redirected_to edit_auth_com_verification_email_path(issuance.transaction.transaction_id, ri: "jp")
    assert_equal email.public_id, record.reload.email_credential_ref
    assert_equal 1, record.email_code_generation
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
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
    token = ClientToken.create!(user: actor)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id)
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get auth_app_verification_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }
    get new_auth_app_verification_passkey_path(ri: "jp")

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
    assert_equal "required", response.parsed_body.fetch("options").fetch("userVerification")
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at

    assertion = fake.get(challenge: record.passkey_challenge, user_present: true, user_verified: true, sign_count: 2)
    post panel.fetch("verification_url"),
         params: { credential: assertion, challenge_id: record.passkey_challenge_ref },
         headers: { "X-CSRF-Token" => csrf }, as: :json

    assert_response :success
    assert_equal "ok", response.parsed_body.fetch("status")
    assert_equal "verified", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
    get response.parsed_body.fetch("redirect_url")

    assert_response :success
    form = response.parsed_body.at_css("form")
    post form["action"], params: { authenticity_token: form.at_css('input[name="authenticity_token"]')["value"] }

    assert_response :see_other
    completion = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL"), completion.host
    assert_equal base_app_verification_completion_path, completion.path
    query = Rack::Utils.parse_nested_query(completion.query)

    assert_equal issuance.transaction.transaction_id, query.fetch("transaction_ref")
    assert_match BaseAuthAdmissionCoordinator::ADMISSION_REFERENCE_PATTERN, query.fetch("result_ref")
    assert_not_includes response.location, "jump.umaxica.net"
    assert_not_includes response.location, "/sign"
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "Auth accepts step-up through a nonconsuming GET and CSRF POST without an Auth root credential" do
    actor = clients(:one)
    actor.client_passkeys.create!(webauthn_id: "admission-passkey", public_key: "public-key")
    token = ClientToken.create!(user: actor)
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ),
      return_to: "/identity/birthdate",
    )
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    assert_no_difference("ClientAuthCeremonySession.count") do
      get auth_app_verification_path(ri: "jp", entry_ref: issuance.reference)
    end
    assert_response :success
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_path(ri: "jp"),
         params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_redirected_to auth_app_verification_path(ri: "jp")
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
    get response.location

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_equal ["passkey"], props.fetch("methods").map { |method| method.fetch("key") }
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at

    other_browser = open_session
    other_browser.get(auth_app_verification_url(ri: "jp", host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL")))

    assert_equal 400, other_browser.response.status
    post auth_app_verification_path(ri: "jp"),
         params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_equal auth_app_verification_path(ri: "jp"), URI.parse(response.location).request_uri
  end
end
