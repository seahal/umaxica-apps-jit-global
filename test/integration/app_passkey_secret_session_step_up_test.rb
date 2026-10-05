# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class AppPasskeySecretSessionStepUpTest < ActionDispatch::IntegrationTest
  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

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

      assert_no_difference -> { ClientStepUpCeremonyTransaction.count } do
        get "/verification/setup", params: { ri: "jp", scope: "settings_#{method}", pt: pt }, headers: headers

        assert_response :unprocessable_content
        assert_nil response.headers["Location"]
        post "/verification/setup",
             params: { ri: "jp", scope: "settings_#{method}", pt: pt, registration_method: method }, headers: headers

        assert_response :bad_request
      end
      assert_equal 0, ClientSecretIssuance.where(client_id: actor.id).count
      assert_equal 0, actor.client_passkeys.count
      assert_equal 0, actor.client_totp_credentials.count
    end
  end

  test "a Secret session can reach registration after a separately bound Passkey Step-Up" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host!(host)
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    origin = "https://#{host}"
    fake = WebAuthn::FakeClient.new(origin, encoding: :base64url)
    registration = fake.create(
      challenge: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false), user_verified: true,
    )
    relying_party = WebAuthn::RelyingParty.new(
      id: URI.parse(origin).host, allowed_origins: [origin], encoding: :base64url,
    )
    registered = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    credential = actor.client_passkeys.create!(
      webauthn_id: registered.id, public_key: registered.public_key, sign_count: 0,
    )
    token = ClientToken.create!(user: actor, established_authentication_method: "secret")
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(base_host)
    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    )
    pt = verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => "app",
        "session_nonce" => token.device_session.public_id,
        "pt" => "/settings/passkeys/new", },
      purpose: :path_target, expires_in: 15.minutes,
    )
    post base_app_verification_path(ri: "jp"), params: { scope: "settings_passkey", pt: pt },
                                               headers: as_user_headers(
                                                 actor, host: base_host, session_public_id: token.public_id,
                                               )

    assert_response :see_other
    admission_url = response.location
    jump_uri = URI.parse(admission_url)
    if jump_uri.host == "jump.umaxica.net"
      jump_payload, = JWT.decode(Rack::Utils.parse_query(jump_uri.query).fetch("rt"), nil, false)
      admission_url = jump_payload.fetch("url")
    end
    transaction = ClientStepUpCeremonyTransaction.find_by!(actor_ref: actor.public_id, session_ref: token.public_id)
    admission_ref = Rack::Utils.parse_query(URI.parse(admission_url).query).fetch("entry_ref")
    host!(host)
    get admission_url
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_path(ri: "jp"), params: { entry_ref: admission_ref, authenticity_token: csrf }
    get new_auth_app_verification_passkey_path(ri: "jp")
    panel = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props").fetch("panel")
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    post panel.fetch("options_url"), params: { "cf-turnstile-response" => "test-only" },
                                     headers: { "X-CSRF-Token" => csrf }, as: :json

    assert_response :success
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
    assertion = fake.get(challenge: record.passkey_challenge, user_present: true, user_verified: true, sign_count: 2)
    post panel.fetch("verification_url"),
         params: { credential: assertion, challenge_id: record.passkey_challenge_ref },
         headers: { "X-CSRF-Token" => csrf }, as: :json

    assert_response :success
    assert_equal credential.public_id, transaction.reload.verified_credential_ref
    assert_nil token.reload.last_step_up_at
    get response.parsed_body.fetch("redirect_url")
    form = response.parsed_body.at_css("form")
    post form["action"], params: { authenticity_token: form.at_css('input[name="authenticity_token"]')["value"] }
    result_form = response.parsed_body.at_css("form")
    result_params = result_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    completion_action = result_form["action"]
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(base_host)
    post completion_action, params: result_params,
                            headers: as_user_headers(actor, host: base_host, session_public_id: token.public_id)
                              .except("Cookie", "HTTP_COOKIE").merge(
                                "Origin" => origin,
                              )

    assert_response :see_other
    assert_equal "passkey", token.reload.last_step_up_method
    host!(host)
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
