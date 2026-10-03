# frozen_string_literal: true

require "test_helper"
require "support/webauthn_fake_client_helper"

class AuthStepUpAdmissionTest < ActionDispatch::IntegrationTest
  include WebauthnFakeClientHelper

  fixtures :clients, :client_statuses, :visitor_statuses

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  test "APP TOTP verifies the admitted credential without an Auth login or Base freshness" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(user: actor)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:totp], purpose: "step_up",
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
    form = inertia_props.fetch("form")
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    now = ClientTotpCredential.database_now
    ClientTotpCredential.stub(:database_now, now) do
      post form.fetch("action"), params: {
        verification: { code: ROTP::TOTP.new(credential.private_key).at(now.to_i), credential_public_id: credential.public_id },
        authenticity_token: form.fetch("csrf_token"), "cf-turnstile-response" => "test-only",
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
    token = ClientToken.create!(user: actor)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:email_otp], purpose: "step_up",
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
    form = inertia_props.fetch("form")
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
    assert_equal "canceled", issuance.transaction.reload.status
    assert_predicate ClientAuthCeremonySession.find_by!(
      step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
    ), :cancelled?
    assert_nil token.reload.last_step_up_at
    post auth_app_verification_cancellation_path(ri: "jp"), params: { authenticity_token: csrf }

    assert_response :bad_request
  end

  test "COM Email OTP admission uses only the Visitor transaction and verified credential" do
    actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
    email = actor.visitor_emails.create!(
      address: "admitted-com-email@example.com", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    token = VisitorToken.create!(visitor: actor)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:email_otp], purpose: "step_up",
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
    form = inertia_props.fetch("form")
    post form.fetch("action"), params: { authenticity_token: form.fetch("csrf_token") }

    assert_redirected_to edit_auth_com_verification_email_path(issuance.transaction.transaction_id, ri: "jp")
    assert_equal email.public_id, record.reload.email_credential_ref
    assert_equal 1, record.email_code_generation
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "Passkey GET creates no challenge and options POST binds the admitted transaction" do
    actor = clients(:one)
    fake = webauthn_fake_client(origin: "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}")
    actor.client_passkeys.create!(fake_credential_record_attrs(fake))
    token = ClientToken.create!(user: actor)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up",
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
    panel = inertia_props.fetch("panel")

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

    assertion = fake_assertion(fake, challenge: record.passkey_challenge, sign_count: 2)
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

    assert_response :success
    result_form = response.parsed_body.at_css("form")

    assert_equal issuance.transaction.transaction_id, result_form.at_css('input[name="transaction_ref"]')["value"]
    assert_not_empty result_form.at_css('input[name="result"]')["value"]
    assert_nil cookies[AuthenticationCookieName.access]
    assert_nil cookies[AuthenticationCookieName.refresh]
  end

  test "Auth accepts step-up through a nonconsuming GET and CSRF POST without an Auth root credential" do
    actor = clients(:one)
    actor.client_passkeys.create!(webauthn_id: "admission-passkey", public_key: "public-key")
    token = ClientToken.create!(user: actor)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up",
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
    assert_equal ["passkey"], inertia_props.fetch("methods").map { |method| method.fetch("key") }
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at

    other_browser = open_session
    other_browser.get(auth_app_verification_url(ri: "jp", host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL")))

    assert_equal 400, other_browser.response.status
    post auth_app_verification_path(ri: "jp"),
         params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :bad_request
  end
end
