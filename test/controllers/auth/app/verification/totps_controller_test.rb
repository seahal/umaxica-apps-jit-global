# typed: false
# frozen_string_literal: true

require "test_helper"

# Success, Turnstile rejection and malformed input are covered by AuthStepUpAdmissionTest; these
# cases cover credential selection, replay of a consumed window, revocation and method admission.
class Auth::App::Verification::TotpsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  fixtures :client_statuses, :client_totp_credential_statuses

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  test "the page offers a selector that lists only the admitted actor's two active authenticators" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    first = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    second = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    stranger = Client.create!(status_id: ClientStatus::ACTIVE)
    foreign = ClientTotpCredential.create_for_user!(
      user: stranger, private_key: ROTP::Base32.random_base32,
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
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }

    get new_auth_app_verification_totp_path(ri: "jp")

    assert_response :success
    form = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("form")
    selector = form.fetch("credential_selector")

    assert_equal "verification[credential_public_id]", selector.fetch("name")
    assert_equal [first.public_id, second.public_id].sort, selector.fetch("options").map { |o| o.fetch("value") }.sort
    assert_not_includes response.body, foreign.public_id
    assert_not_includes response.body, first.private_key
    assert_not_includes response.body, second.private_key
  end

  test "a wrong six-digit code keeps the ceremony pending and grants nothing" do
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
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    now = ClientTotpCredential.database_now
    valid = ROTP::TOTP.new(credential.private_key).at(now.to_i)
    wrong = format("%06d", (Integer(valid, 10) + 1) % 1_000_000)

    post auth_app_verification_totp_path(ri: "jp"), params: {
      :verification => { code: wrong, credential_public_id: credential.public_id },
      "cf-turnstile-response" => "test-only",
    }

    assert_response :unprocessable_content
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_equal [I18n.t("sign.app.verification.errors.incorrect_code")], props.fetch("errors")
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil issuance.transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
  end

  test "the correct code of a revoked authenticator is refused" do
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
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }
    credential.update!(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::REVOKED)
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    now = ClientTotpCredential.database_now

    ClientTotpCredential.stub(:database_now, now) do
      post auth_app_verification_totp_path(ri: "jp"), params: {
        :verification => {
          code: ROTP::TOTP.new(credential.private_key).at(now.to_i), credential_public_id: credential.public_id,
        },
        "cf-turnstile-response" => "test-only",
      }
    end

    assert_response :unprocessable_content
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
  end

  test "a code window verified in one ceremony cannot be replayed in a second ceremony" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    # Two browsers, each with its own admitted ceremony for the same actor.
    ceremonies =
      2.times.map do
        token = ClientToken.create!(user: actor)
        issuance = BaseStepUpAdmissionIssuer.call!(
          actor: actor, token: token,
          requirement: StepUpRequirement.new(
            scope: "settings_birthdate", allowed_methods: [:totp], purpose: "step_up",
            audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
            require_session_binding: true,
          ), return_to: "/identity/birthdate",
        )
        browser = open_session
        browser.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
        browser.post(auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference })
        [browser, issuance.transaction]
      end
    now = ClientTotpCredential.database_now
    code = ROTP::TOTP.new(credential.private_key).at(now.to_i)
    statuses =
      ceremonies.map do |browser, transaction|
        ClientTotpCredential.stub(:database_now, now) do
          browser.post(
            auth_app_verification_totp_path(ri: "jp"), params: {
              :verification => { code: code, credential_public_id: credential.public_id },
              "cf-turnstile-response" => "test-only",
            },
          )
        end
        [browser.response.status, transaction.reload.status]
      end

    assert_equal [[302, "verified"], [422, "pending"]], statuses
  end

  test "the TOTP endpoints are refused when Base did not admit TOTP for the ceremony" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
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
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: issuance.reference }

    get new_auth_app_verification_totp_path(ri: "jp")

    assert_response :bad_request
    now = ClientTotpCredential.database_now
    post auth_app_verification_totp_path(ri: "jp"), params: {
      verification: {
        code: ROTP::TOTP.new(credential.private_key).at(now.to_i), credential_public_id: credential.public_id,
      },
    }

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil credential.reload.last_otp_at
  end
end
