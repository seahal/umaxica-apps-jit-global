# frozen_string_literal: true

require "test_helper"
require "timeout"
require "webauthn/fake_client"
require_relative "../support/webauthn_fake_client_helper"

class PasskeyAuthenticationResubmissionHttpTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  self.fixture_table_names = []

  include WebauthnFakeClientHelper

  setup do
    [ClientStatus, ClientEmailStatus, ClientPasskeyStatus].each(&:ensure_defaults!)
    ClientSecurityMode.insert_missing_fixed_ids!(ClientSecurityMode::DEFAULTS)
    @protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, security_mode_id: ClientSecurityMode::NORMAL)
    @email = ClientEmail.create!(
      user: @user, address: "passkey-race-#{SecureRandom.hex(6)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @email.finalize_binding!
    @fake = webauthn_fake_client(origin: "https://#{@host}")
    @passkey = ClientPasskey.create!(
      user: @user, status_id: ClientPasskeyStatus::ACTIVE, description: "Race key",
      **fake_credential_record_attrs(@fake),
    )
    client = OidcClientRegistry.find!("core-app-jp")
    issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      params: {
        client_id: client.client_id,
        response_type: "code",
        scope: "openid profile",
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        state: SecureRandom.hex(8),
        nonce: SecureRandom.hex(8),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    )
    @oidc_transaction = issuance.transaction
    @binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: "app", reference: issuance.handoff.reference,
    )
    @browser = open_session
    @browser.host!(@host)
    @browser.https!
    @auth_headers = {
      "Host" => @host, "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin",
    }
    auth_entry_params = { ri: "jp", entry_ref: @binding.entry_ref }
    @browser.get(auth_app_sign_in_path(ri: "jp"), params: auth_entry_params, headers: @auth_headers)
    raise RuntimeError, "Auth sign-in entry did not begin ceremony binding" unless
      @browser.response.status == 303 && URI.parse(@browser.response.location).path == "/ceremony_bindings"

    @browser.get(@browser.response.location, headers: @auth_headers)
    raise RuntimeError, "Auth ceremony binding did not reach Base confirmation" unless @browser.response.status == 303

    @binding.reload.confirm_base!(base_token: nil, browser_digest: @binding.base_browser_digest)
    @browser.get(auth_app_sign_in_path(ri: "jp"), params: auth_entry_params, headers: @auth_headers)
    raise RuntimeError, "Auth sign-in admission did not redeem" unless
      @browser.response.status == 303 && @binding.reload.redeemed?

    @browser.post(
      auth_app_sign_in_passkey_options_path(ri: "jp"),
      params: { :identifier => @email.address, "cf-turnstile-response" => "test-token" },
      headers: @auth_headers,
      as: :json,
    )
    raise RuntimeError, "Passkey options failed: HTTP #{@browser.response.status} #{@browser.response.body}" unless
      @browser.response.status == 200

    @options = @browser.response.parsed_body
    @assertion = fake_assertion(
      @fake, challenge: @options.dig("options", "challenge"), user_verified: true, sign_count: 1,
             user_handle: @user.webauthn_user_handle,
    )
    @raw_auth_sid = @browser.cookies[
      JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid",
    ]
    @admitted_session = ClientAuthCeremonySession.find_active_by_raw_sid(@raw_auth_sid)
  end

  teardown do
    @workers&.each { |worker| worker.join(5) }
    ClientPasskey.where(id: @passkey&.id).delete_all if @passkey
    ClientEmail.where(id: @email&.id).delete_all if @email
    ClientAuthAdmissionBinding.where(id: @binding&.id).delete_all if @binding
    ClientOidcAuthorizationTransaction.where(id: @oidc_transaction&.id).delete_all if @oidc_transaction
    ClientAuthCeremonySession.where(id: @admitted_session&.id).delete_all if @admitted_session
    Client.where(id: @user&.id).delete_all if @user
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    ActionController::Base.allow_forgery_protection = @protection
  end

  test "two concurrent HTTP resubmissions admit at most one authentication and preserve its Auth session" do
    browsers = [clone_browser, clone_browser]
    start_gate = Queue.new
    ready = Queue.new
    path = auth_app_sign_in_passkey_verification_path(ri: "jp")
    params = { challenge_id: @options.fetch("challenge_id"), credential: @assertion }
    @workers =
      browsers.map do |browser|
        Thread.new do
          Client.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << Integer(connection.select_value("SELECT pg_backend_pid()"))
            start_gate.pop
            browser.post(path, params: params, headers: @auth_headers, as: :json)
            [browser.response.status, browser.response.parsed_body, browser.response.headers["Set-Cookie"]]
          end
        rescue StandardError => e
          [nil, e.class.name, e.message]
        end
      end

    pids = 2.times.map { ready.pop }
    2.times { start_gate << true }
    results = @workers.map(&:value)
    successes = results.count { |status, body,| status == 200 && body.is_a?(Hash) && body["status"] == "ok" }

    assert_equal 2, pids.uniq.size
    assert_equal 1, successes, results.inspect
    assert_equal 1, @passkey.reload.sign_count
    assert_predicate @admitted_session.reload, :authentication_evidence_recorded?
    assert_equal @admitted_session.id, @binding.reload.admitted_auth_ceremony_session_id
    auth_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    results.each do |status, _body, set_cookie|
      assert_includes [200, 401, 400], status
      assert_not_includes Array(set_cookie).join("\n"), "#{auth_cookie_name}="
    end
    assert_equal 0, ClientToken.where(user_id: @user.id).count
  end

  private

  def clone_browser
    browser = open_session
    browser.host!(@host)
    browser.https!
    uri = URI.parse("https://#{@host}/")
    @browser.cookies.for(uri).split("; ").each { |cookie| browser.cookies.merge(cookie, uri) }
    browser
  end
end
