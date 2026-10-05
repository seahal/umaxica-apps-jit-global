# frozen_string_literal: true

require "test_helper"

class AppPasskeySecretSessionStepUpTest < ActionDispatch::IntegrationTest
  test "Base rejects Secret-session registration admission before creating a Ticket ceremony" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, established_authentication_method: "secret")
    headers = as_user_headers(actor, host: host, session_public_id: token.public_id)
    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    )
    nonce = token.device_session.public_id
    [["passkey", "/settings/passkeys/new"], ["totp", "/settings/totps/new"]].each do |method, path|
      pt = verifier.generate(
        { "flow" => "step_up.bootstrap",
          "surface" => "app",
          "session_nonce" => nonce,
          "pt" => path, },
        purpose: :path_target, expires_in: 15.minutes,
      )

      assert_no_difference("ClientStepUpCeremonyTransaction.count") do
        post "/verification", params: { ri: "jp", scope: "settings_#{method}", pt: pt }, headers: headers
      end

      assert_response :bad_request
      assert_nil response.headers["Location"]
      assert_nil token.reload.last_step_up_at
    end
  end

  test "a Secret session can reach registration after a separately bound Passkey Step-Up" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host!(host)
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    credential = actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
    token = ClientToken.create!(user: actor, established_authentication_method: "secret")
    requirement = StepUpRequirement.new(
      scope: "settings_passkey", allowed_methods: [:passkey], purpose: "step_up",
      audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true,
    )
    transaction = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: "/settings/passkeys/new",
    ).transaction
    # Synthetic ceremony evidence prepares the HTTP authorization boundary; this test
    # does not claim to verify a WebAuthn signature or perform Secret Sign in.
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: credential.public_id,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    issuance = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
    )
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: actor, token: token, transaction: transaction, requirement: requirement, raw_result: issuance.code,
    )
    headers = as_user_headers(actor, host: host, session_public_id: token.public_id)

    post "/settings/passkeys", params: { ri: "jp" }, headers: headers, as: :json

    assert_response :unprocessable_content
    assert_equal I18n.t("errors.webauthn.verification_required"), response.parsed_body.fetch("error")
    assert_equal "secret", token.reload.established_authentication_method
    assert_equal "passkey", token.last_step_up_method
    assert_equal "consumed", transaction.reload.status
    assert_equal 1, actor.client_passkeys.count
  end

  test "a normal Secret session without another configured method cannot bootstrap Passkey registration" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host!(host)
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, established_authentication_method: "secret")
    headers = as_user_headers(actor, host: host, session_public_id: token.public_id)
    expected_error = I18n.t("auth.step_up.register_methods_required")

    [
      "/settings/passkeys",
      "/settings/passkeys/options",
      "/settings/passkeys/verification",
    ].each do |path|
      post path, params: { ri: "jp" }, headers: headers, as: :json

      assert_response :unprocessable_content
      assert_equal expected_error, response.parsed_body.fetch("error")
      assert_equal 0, actor.client_passkeys.count
      assert_nil token.reload.last_step_up_at
    end
  end

  test "missing Step-Up methods stop the signed-in registration page without a setup redirect loop" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host!(host)
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, established_authentication_method: "secret")
    headers = as_user_headers(actor, host: host, session_public_id: token.public_id)

    get "/settings/passkeys/new", params: { ri: "jp" }, headers: headers

    assert_response :forbidden
    assert_nil response.headers["Location"]
    assert_equal I18n.t("auth.step_up.register_methods_required"), response.body
    assert_equal 0, actor.client_passkeys.count
    assert_nil token.reload.last_step_up_at
  end
end
