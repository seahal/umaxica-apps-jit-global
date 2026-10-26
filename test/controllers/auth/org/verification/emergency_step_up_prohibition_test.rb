# typed: false
# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

# Restricted Mode cannot initiate, complete, or reuse ordinary step-up authority.
# HTTP cases use the Base admission contract without Auth root credentials.
class Auth::Org::Verification::EmergencyStepUpProhibitionTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens

  setup do
    @staff = operators(:one)
    @token = operator_tokens(:one)
    @token.update!(authentication_context: nil)
    @passkey = OperatorPasskey.create!(
      staff: @staff, webauthn_id: SecureRandom.uuid, external_id: SecureRandom.uuid,
      public_key: "org-emergency-public-key", sign_count: 0,
      description: "Org step-up passkey", status_id: OperatorPasskeyStatus::ACTIVE,
    )
    @requirement = StepUpRequirement.new(
      scope: "settings_passkey", required_aal: nil, step_up_required: true, allowed_methods: [:passkey],
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
    issuance =
      begin
        admission_issuance = BaseStepUpAdmissionIssuer.call!(
          actor: @staff, token: @token,
          requirement: @requirement, return_to: "/identity/passkeys",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: @token,
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
          base_token: @token,
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
    record = OperatorStepUpSession.find_by!(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id)
    get auth_org_verification_path(ri: "jp", entry_ref: issuance.reference)

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
    assert_equal "verified", issuance.transaction.reload.status
    assert_equal passkey.external_id, issuance.transaction.verified_credential_ref
    assert_nil @token.reload.last_step_up_at

    get response.parsed_body.fetch("redirect_url")

    assert_response :success

    form = response.parsed_body.at_css("form")
    post form["action"], params: { authenticity_token: form.at_css('input[name="authenticity_token"]')["value"] }

    assert_response :see_other
    destination = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(destination.query)

    assert_equal ENV.fetch("PUBLIC_BASE_STAFF_URL"), destination.host
    assert_equal issuance.transaction.transaction_id, query.fetch("transaction_ref")
    assert_match AuthAdmissionBinding::REFERENCE_PATTERN, query.fetch("result_ref")
    assert_not query.key?("result")
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "Base refuses admission for an emergency session without creating a ticket" do
    @token.update!(authentication_context: "standby")

    assert_no_difference ["OperatorStepUpCeremonyTransaction.count", "OperatorStepUpSession.count"] do
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        begin
          admission_issuance = BaseStepUpAdmissionIssuer.call!(
            actor: @staff, token: @token,
            requirement: @requirement, return_to: "/identity/passkeys",
            base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: @token,
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
            base_token: @token,
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

  test "recorded normal freshness cannot satisfy a requirement after an emergency context change" do
    now = Time.current
    @token.update!(
      last_step_up_at: now, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_aal: "aal1", last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
      last_step_up_session_public_id: @token.public_id,
    )

    assert_predicate StepUpResolver.call(token: @token, requirement: @requirement, now: now), :satisfied?

    @token.update!(authentication_context: "standby")

    assert_not_predicate StepUpResolver.call(token: @token.reload, requirement: @requirement, now: now), :satisfied?
  end

  test "Base refuses verified evidence when the session becomes emergency before finalization" do
    issuance =
      begin
        admission_issuance = BaseStepUpAdmissionIssuer.call!(
          actor: @staff, token: @token,
          requirement: @requirement, return_to: "/identity/passkeys",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: @token,
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
          base_token: @token,
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
    transaction = issuance.transaction
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
    issuance =
      begin
        admission_issuance = BaseStepUpAdmissionIssuer.call!(
          actor: @staff, token: @token,
          requirement: @requirement, return_to: "/identity/passkeys",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: @token,
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
          base_token: @token,
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
    get auth_org_verification_path(ri: "jp", entry_ref: issuance.reference)

    assert_response :see_other
    follow_redirect!

    assert_response :success

    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_equal ["passkey"], props.fetch("methods").map { |method| method.fetch("key") }
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil @token.reload.last_step_up_at
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "admitted Auth continuity refuses a session changed to emergency before passkey selection" do
    issuance =
      begin
        admission_issuance = BaseStepUpAdmissionIssuer.call!(
          actor: @staff, token: @token,
          requirement: @requirement, return_to: "/identity/passkeys",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: @token,
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
          base_token: @token,
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
    get auth_org_verification_path(ri: "jp", entry_ref: issuance.reference)

    assert_response :see_other
    follow_redirect!

    assert_response :success

    @token.update!(authentication_context: "standby")
    get new_auth_org_verification_passkey_path(ri: "jp")

    assert_response :bad_request
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil issuance.transaction.verified_at
    assert_nil @token.reload.last_step_up_at
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end
end
