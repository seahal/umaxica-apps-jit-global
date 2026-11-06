# typed: false
# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class Auth::App::Verification::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @user = clients(:one)
    @token = ClientToken.create!(authentication_epoch: 0, user: @user)
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @fake = WebAuthn::FakeClient.new("https://#{@host}", encoding: :base64url)
    registration = @fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
    relying_party = WebAuthn::RelyingParty.new(
      id: @host, allowed_origins: [@fake.origin], encoding: :base64url,
    )
    credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    @passkey = @user.client_passkeys.create!(
      webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0,
    )
    client = OidcClientRegistry.find!("core-app-jp")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: @token.authentication_epoch, client_token: @token, oidc_client_id: client.client_id,
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
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: @user, resource_type: "client")
    @issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor: @user, token: @token, client:, params:, validated_request:,
    )
    @entry_ref = @issuance.entry_ref
    @transaction = @issuance.ticket
    @ticket = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: @transaction.transaction_id)
    https!
    host! @host
    admit_auth_ceremony_entry!(
      auth_app_verification_path,
      reference: @entry_ref,
      params: { ri: "jp" },
      base_token: @token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: @entry_ref, nonce: @issuance.authorization_transaction.login_challenge,
      ),
    )
    # This controller test covers step-up evidence handling. Rails test mode disables forgery
    # protection; CSRF rejection is covered at the shared boundary tests.
    @csrf = "test-csrf-token"
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  test "a real assertion records admitted evidence without granting Base freshness or Auth root cookies" do
    post auth_app_verification_passkey_options_path(ri: "jp"),
         params: { "cf-turnstile-response" => "test-only" }, headers: { "X-CSRF-Token" => @csrf }, as: :json

    assert_response :success
    options = response.parsed_body
    assertion = @fake.get(challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 1)
    post auth_app_verification_passkey_path(ri: "jp"),
         params: { credential: assertion, challenge_id: options.fetch("challenge_id") },
         headers: { "X-CSRF-Token" => @csrf }, as: :json

    assert_response :success
    assert_equal "ok", response.parsed_body.fetch("status")
    assert_equal "verified", @transaction.reload.status
    assert_equal @passkey.public_id, @transaction.verified_credential_ref
    assert_equal "step_up", @transaction.purpose
    assert_nil @token.reload.last_step_up_at
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
  end

  test "cancel issues an exact cancellation handoff to the OP authorize receiver" do
    post auth_app_verification_cancellation_path(ri: "jp"),
         params: { return_to: "/sign/in/challenge", pt: "/identity/birthdate" },
         headers: { "X-CSRF-Token" => @csrf }

    assert_response :see_other
    gateway = URI.parse(response.location)
    params = Rack::Utils.parse_nested_query(gateway.query)

    expected_endpoint = URI.parse(OidcIssuer.authorization_endpoint("client"))

    assert_equal expected_endpoint.host, gateway.host
    assert_equal expected_endpoint.path, gateway.path
    assert_equal @transaction.transaction_id, params.fetch("step_up_ticket_ref")
    assert_equal @issuance.context.public_id, params.fetch("step_up_context_ref")
    assert_predicate params.fetch("step_up_cancellation_ref"), :present?
    assert_equal "pending", @transaction.reload.status
    assert_nil @token.reload.last_step_up_at
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
  end

  test "GET renders the existing panel without issuing a challenge or extending the transaction" do
    deadline = @transaction.expires_at
    attempts = @ticket.attempt_count
    2.times do
      get new_auth_app_verification_passkey_path(ri: "jp")

      assert_response :success
      props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

      assert_equal auth_app_verification_passkey_options_path(ri: "jp"), props.fetch("panel").fetch("options_url")
      assert_equal auth_app_verification_passkey_path(ri: "jp"), props.fetch("panel").fetch("verification_url")
      assert_equal auth_app_verification_path(ri: "jp"), props.fetch("back").fetch("href")
      assert_equal "post", props.fetch("cancel").fetch("method")
      assert_nil @ticket.reload.passkey_challenge_ref
      assert_equal attempts, @ticket.attempt_count
      assert_equal deadline, @transaction.reload.expires_at
    end
  end

  test "invalid assertion consumes the challenge and cannot create freshness on replay" do
    post auth_app_verification_passkey_options_path(ri: "jp"),
         params: { "cf-turnstile-response" => "test-only" }, headers: { "X-CSRF-Token" => @csrf }, as: :json
    options = response.parsed_body
    assertion = @fake.get(challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 1)
    assertion.fetch("response")["signature"] = Base64.urlsafe_encode64("invalid-signature", padding: false)
    2.times do
      post auth_app_verification_passkey_path(ri: "jp"),
           params: { credential: assertion, challenge_id: options.fetch("challenge_id") },
           headers: { "X-CSRF-Token" => @csrf }, as: :json

      assert_response :unprocessable_content
      assert_equal "pending", @transaction.reload.status
      assert_not_nil @ticket.reload.passkey_challenge_consumed_at
      assert_nil @token.reload.last_step_up_at
    end
  end

  test "query scope and return target cannot replace the admitted transaction" do
    get new_auth_app_verification_passkey_path(
      ri: "jp", scope: "settings_email", return_to: "/identity/emails", pt: "/settings/passkeys/new",
    )

    assert_response :success
    assert_equal "step_up", @transaction.reload.purpose
    assert_equal OidcAuthorizeRequestResolver::STEP_UP_SCOPE, @transaction.required_scope
    assert_equal OidcAuthorizeRequestResolver::STEP_UP_RETURN_TO, @transaction.return_to
    assert_nil @ticket.reload.passkey_challenge_ref
    assert_nil @token.reload.last_step_up_at
  end

  test "an unrelated Auth browser cannot start a ceremony using scope or old grant parameters" do
    other_browser = open_session
    other_browser.https!
    other_browser.host!(@host)
    assert_no_difference ["ClientStepUpCeremonyTransaction.count", "ClientStepUpSession.count"] do
      other_browser.get(
        auth_app_verification_path(ri: "jp"),
        params: { scope: "settings_email", return_to: "/identity/emails", step_up_ceremony_grant: "obsolete-grant" },
      )

      assert_equal 400, other_browser.response.status
      other_browser.get(
        new_auth_app_verification_passkey_path(
          ri: "jp", scope: "settings_passkey",
          pt: "/identity/passkeys",
        ),
      )

      assert_equal 400, other_browser.response.status
    end

    assert_equal "pending", @transaction.reload.status
    assert_nil @ticket.reload.passkey_challenge_ref
    assert_nil @token.reload.last_step_up_at
  end
end
