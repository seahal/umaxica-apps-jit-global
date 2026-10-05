# typed: false
# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class Auth::Com::Verification::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures :visitors

  setup do
    @visitor = Visitor.create!
    @visitor.visitor_emails.create!(
      address: "com-passkey-stepup-#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = VisitorToken.create!(visitor: @visitor)
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    @fake = WebAuthn::FakeClient.new("https://#{@host}", encoding: :base64url)
    registration = @fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
    relying_party = WebAuthn::RelyingParty.new(
      id: @host, allowed_origins: [@fake.origin], encoding: :base64url,
    )
    credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    @passkey = @visitor.visitor_passkeys.create!(
      webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0,
    )
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", required_aal: "aal1", allowed_methods: [:passkey],
      session_binding: @token.public_id, token_binding: @token.public_id,
      purpose: "step_up", audience: "step_up:com", require_session_binding: true,
    )
    @issuance = BaseStepUpAdmissionIssuer.call!(
      actor: @visitor, token: @token, requirement: requirement, return_to: "/identity/birthdate?ri=jp",
    )
    @ticket = VisitorStepUpSession.find_by!(step_up_ceremony_transaction_ref: @issuance.transaction.transaction_id)
    https!
    host! @host
    get auth_com_verification_path(ri: "jp", entry_ref: @issuance.reference)
    @csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_com_verification_path(ri: "jp"), params: {
      entry_ref: @issuance.reference, authenticity_token: @csrf,
    }
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  test "a real assertion records admitted evidence without granting Base freshness or Auth root cookies" do
    post auth_com_verification_passkey_options_path(ri: "jp"),
         params: { "cf-turnstile-response" => "test-only" }, headers: { "X-CSRF-Token" => @csrf }, as: :json

    assert_response :success
    options = response.parsed_body
    assertion = @fake.get(challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 1)
    post auth_com_verification_passkey_path(ri: "jp"),
         params: { credential: assertion, challenge_id: options.fetch("challenge_id") },
         headers: { "X-CSRF-Token" => @csrf }, as: :json

    assert_response :success
    assert_equal "ok", response.parsed_body.fetch("status")
    assert_equal "verified", @issuance.transaction.reload.status
    assert_equal @passkey.public_id, @issuance.transaction.verified_credential_ref
    assert_equal "settings_birthdate", @issuance.transaction.required_scope
    assert_nil @token.reload.last_step_up_at
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
  end

  test "cancel closes the exact transaction and chooses the fixed Base dashboard" do
    post auth_com_verification_cancellation_path(ri: "jp"),
         params: { return_to: "/sign/in/challenge", pt: "/identity/birthdate" },
         headers: { "X-CSRF-Token" => @csrf }

    assert_response :see_other
    gateway = URI.parse(response.location)
    payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)

    assert_equal base_com_dashboard_url(host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), ri: "jp", protocol: "https"),
                 payload.fetch("url")
    assert_equal "canceled", @issuance.transaction.reload.status
    assert_nil @token.reload.last_step_up_at
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
  end

  test "GET renders the existing panel without issuing a challenge or extending the transaction" do
    deadline = @issuance.transaction.expires_at
    attempts = @ticket.attempt_count
    [["jp", "ja"], ["jp", "en"], ["us", "ja"], ["us", "en"]].each do |region, language|
      get new_auth_com_verification_passkey_path(ri: region, lx: language)

      assert_response :success
      props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

      assert_equal auth_com_verification_passkey_options_path(ri: region), props.fetch("panel").fetch("options_url")
      assert_equal auth_com_verification_passkey_path(ri: region), props.fetch("panel").fetch("verification_url")
      assert_equal auth_com_verification_path(ri: region), props.fetch("back").fetch("href")
      assert_equal "post", props.fetch("cancel").fetch("method")
      assert_equal((language == "en") ? "Verification" : "本人確認", props.fetch("title"))
      assert_nil @ticket.reload.passkey_challenge_ref
      assert_equal attempts, @ticket.attempt_count
      assert_equal deadline, @issuance.transaction.reload.expires_at
    end
  end

  test "invalid assertion consumes the challenge and cannot create freshness on replay" do
    post auth_com_verification_passkey_options_path(ri: "jp"),
         params: { "cf-turnstile-response" => "test-only" }, headers: { "X-CSRF-Token" => @csrf }, as: :json
    options = response.parsed_body
    assertion = @fake.get(challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 1)
    assertion.fetch("response")["signature"] = Base64.urlsafe_encode64("invalid-signature", padding: false)
    2.times do
      post auth_com_verification_passkey_path(ri: "jp"),
           params: { credential: assertion, challenge_id: options.fetch("challenge_id") },
           headers: { "X-CSRF-Token" => @csrf }, as: :json

      assert_response :unprocessable_content
      assert_equal "pending", @issuance.transaction.reload.status
      assert_not_nil @ticket.reload.passkey_challenge_consumed_at
      assert_nil @token.reload.last_step_up_at
    end
  end

  test "query scope and return target cannot replace the admitted transaction" do
    get new_auth_com_verification_passkey_path(
      ri: "jp", scope: "settings_email", return_to: "/identity/emails", pt: "/settings/passkeys/new",
    )

    assert_response :success
    assert_equal "settings_birthdate", @issuance.transaction.reload.required_scope
    assert_equal "/identity/birthdate?ri=jp", @issuance.transaction.return_to
    assert_nil @ticket.reload.passkey_challenge_ref
    assert_nil @token.reload.last_step_up_at
  end

  test "an unrelated Auth browser cannot start a ceremony using scope or old grant parameters" do
    other_browser = open_session
    other_browser.https!
    other_browser.host!(@host)
    assert_no_difference ["VisitorStepUpCeremonyTransaction.count", "VisitorStepUpSession.count"] do
      other_browser.get(
        auth_com_verification_path(ri: "jp"),
        params: { scope: "settings_email", return_to: "/identity/emails", step_up_ceremony_grant: "obsolete-grant" },
      )

      assert_equal 400, other_browser.response.status
      other_browser.get(
        new_auth_com_verification_passkey_path(
          ri: "jp", scope: "settings_passkey",
          pt: "/identity/passkeys",
        ),
      )

      assert_equal 400, other_browser.response.status
    end

    assert_equal "pending", @issuance.transaction.reload.status
    assert_nil @ticket.reload.passkey_challenge_ref
    assert_nil @token.reload.last_step_up_at
  end
end
