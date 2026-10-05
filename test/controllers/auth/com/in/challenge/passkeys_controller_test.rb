# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"
require "zlib"

# Real Base admission and Email primary precede these HTTP cases. Assertion stubs isolate
# refusal/continuation contracts; LocalAuthenticationBoundaryTest exercises real MFA signatures.
class Auth::Com::Sign::In::Challenge::PasskeysControllerTest < ActionDispatch::IntegrationTest
  include AuthEmailMfaHelper

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    host! @host
    @origin_headers = { "HTTP_ORIGIN" => "http://#{@host}", "Origin" => "http://#{@host}" }.freeze
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }

    @visitor = Visitor.create!(id: 9_116_000_000_000 + Zlib.crc32(name))
    @visitor.visitor_emails.create!(
      address: "com_mfa_passkey_#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    @visitor.update!(mfa_level_enabled: true)
    @visitor.visitor_telephones.create!(
      number: "+8190" + format("%08d", SecureRandom.random_number(100_000_000)),
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    @passkey = VisitorPasskey.create!(
      visitor: @visitor,
      webauthn_id: Base64.urlsafe_encode64("com_mfa_passkey_id_eeec6cca6c4c1cbd", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "mfa-passkey-public",
      sign_count: 5,
      description: "MFA Passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
    )
    # A real Base admission precedes every Auth-only MFA assertion; no root cookie is injected.
    @issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "com", intent: "sign_in")
    get auth_com_sign_in_path, params: { entry_ref: @issuance.reference, ri: "jp" }
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_com_sign_in_path, params: { entry_ref: @issuance.reference, authenticity_token: csrf, ri: "jp" }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "new requires pending MFA session" do
    get new_auth_com_sign_in_challenge_passkey_path(ri: "jp"), headers: @origin_headers

    assert_response :redirect

    assert_redirected_to auth_com_sign_in_path(ri: "jp")
  end

  %i(failed foreign_actor advanced).each do |interruption|
    test "late #{interruption} interruption of local MFA returns to Base without issuing root credentials" do
      email = @visitor.visitor_emails.first
      post auth_com_sign_in_email_path,
           params: { :user_email => { address: email.address }, "cf-turnstile-response" => "test-only", :ri => "jp" }
      secret = ROTP::Base32.random_base32
      email.reload.store_otp(secret, 7, 5.minutes.from_now.to_i)
      patch auth_com_sign_in_email_path,
            params: { :user_email => { pass_code: ROTP::HOTP.new(secret).at(7).to_s },
                      "cf-turnstile-response" => "test-only",
                      :ri => "jp", }

      assert_equal "mfa", @issuance.transaction.reload.step
      get new_auth_com_sign_in_challenge_passkey_path(ri: "jp")

      assert_response :success
      challenge_id = session[:passkey_challenges].keys.first
      continuity = VisitorAuthCeremonySession.find_by!(local_sign_in_flow_ref: @issuance.transaction.public_id)
      foreign = Visitor.create!(id: 9_127_000_000_000) if interruption == :foreign_actor
      verification =
        ->(**) do
          # Public verifier fault seam models the flow changing after successful signature validation.
          if interruption == :failed
            @issuance.transaction.fail_sign_in!
          elsif interruption == :advanced
            @issuance.transaction.advance_sign_in_to_guardrail!
          else
            @issuance.transaction.update!(principal_id: foreign.id)
          end
          Struct.new(:sign_count, :verified_at).new(11, Time.current)
        end

      Webauthn::AssertionVerifier.stub(:verify!, verification) do
        post auth_com_sign_in_challenge_passkey_path(ri: "jp"), params: {
          mfa_passkey_form: { challenge_id: challenge_id, credential_json: { id: @passkey.webauthn_id }.to_json },
        }
      end

      assert_redirected_to base_com_sign_show_url(
        host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), protocol: "https", ri: "jp",
      )
      assert_nil session[:pending_mfa]
      assert_nil session[:passkey_challenges]
      assert_nil @issuance.transaction.reload.authentication_event_at
      assert_nil @issuance.transaction.base_finalized_at
      assert_not_nil continuity.reload.revoked_at
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
      assert_equal 0, VisitorToken.where(visitor_id: @visitor.id).count
      follow_redirect!

      assert_response :success
      assert_not_nil response.parsed_body.at_css('form[method="post"]')
    end
  end

  test "a stale MFA Cookie cannot reopen a Base flow that has advanced past MFA" do
    establish_pending_mfa!
    @issuance.transaction.advance_sign_in_to_guardrail!
    get new_auth_com_sign_in_challenge_passkey_path(ri: "jp")

    assert_response :see_other
    assert_redirected_to auth_com_sign_in_path(ri: "jp")
    assert_nil session[:pending_mfa]
    assert_nil session[:passkey_challenges]
    assert_equal "guardrail", @issuance.transaction.reload.step
    assert_nil @issuance.transaction.authentication_event_at
  end

  test "the MFA Cookie actor must match the admitted Base flow principal" do
    establish_pending_mfa!
    foreign = Visitor.create!(id: 9_118_000_000_000)
    @issuance.transaction.update!(principal_id: foreign.id)
    get new_auth_com_sign_in_challenge_passkey_path(ri: "jp")

    assert_response :see_other
    assert_redirected_to auth_com_sign_in_path(ri: "jp")
    assert_nil session[:pending_mfa]
    assert_nil session[:passkey_challenges]
    assert_nil @issuance.transaction.reload.authentication_event_at
  end

  # Every refusal on the MFA passkey challenge sends the person back to the challenge
  # chooser rather than leaving them on a dead page, and none of them completes the
  # sign-in. These four arms had no test.
  test "new sends the visitor back to the chooser when no passkey is registered" do
    @passkey.destroy!
    establish_pending_mfa!

    get new_auth_com_sign_in_challenge_passkey_path(ri: "jp"), headers: @origin_headers

    assert_response :see_other
    assert_redirected_to auth_com_sign_in_challenge_path(ri: "jp")
  end

  test "new refuses an ACTIVE Passkey whose writer deadline has passed" do
    establish_pending_mfa!
    @passkey.update!(discard_at: VisitorPasskey.database_now)
    get new_auth_com_sign_in_challenge_passkey_path(ri: "jp")

    assert_response :see_other
    assert_redirected_to auth_com_sign_in_challenge_path(ri: "jp")
    assert_nil session[:passkey_challenges]
    assert_equal "mfa", @issuance.transaction.reload.step
  end

  test "new sends the visitor back to the chooser when the relying party is not configured" do
    establish_pending_mfa!
    missing_config =
      lambda do |*|
        raise Webauthn::RelyingPartyConfigResolver::MissingConfigurationError, "rp_id missing"
      end

    Webauthn::RelyingPartyConfigResolver.stub(:resolve, missing_config) do
      get new_auth_com_sign_in_challenge_passkey_path(ri: "jp"), headers: @origin_headers
    end

    assert_response :see_other
    assert_redirected_to auth_com_sign_in_challenge_path(ri: "jp")
  end

  test "create refuses a failed stealth challenge without consuming the passkey challenge" do
    establish_pending_mfa!
    get new_auth_com_sign_in_challenge_passkey_path(ri: "jp"), headers: @origin_headers
    challenge_id = session[:passkey_challenges].keys.first
    TurnstileVerifierStub.challenge_response = { "success" => false }

    post auth_com_sign_in_challenge_passkey_path(ri: "jp"),
         params: { mfa_passkey_form: { challenge_id: challenge_id } },
         headers: @origin_headers

    assert_response :see_other
    assert_redirected_to new_auth_com_sign_in_challenge_passkey_path(ri: "jp")
    assert_includes session[:passkey_challenges].keys, challenge_id,
                    "a refused challenge must still be there for the retry"
  end

  test "create sends the visitor back to the chooser when the assertion does not verify" do
    establish_pending_mfa!
    get new_auth_com_sign_in_challenge_passkey_path(ri: "jp"), headers: @origin_headers
    challenge_id = session[:passkey_challenges].keys.first
    failure = ->(**) { raise Webauthn::AssertionVerifier::VerificationError, "bad assertion" }

    Webauthn::AssertionVerifier.stub(:verify!, failure) do
      post auth_com_sign_in_challenge_passkey_path(ri: "jp"),
           params: {
             mfa_passkey_form: {
               challenge_id: challenge_id,
               credential_json: {
                 id: @passkey.webauthn_id,
                 type: "public-key",
                 response: { clientDataJSON: "d",
                             authenticatorData: "d",
                             signature: "d",
                             userHandle: @visitor.public_id, },
               }.to_json,
             },
           },
           headers: @origin_headers
    end

    assert_response :see_other
    assert_redirected_to auth_com_sign_in_challenge_path(ri: "jp")
  end

  test "MFA rejects missing empty scalar array and NUL credential JSON without advancing Base evidence" do
    establish_pending_mfa!
    [nil, "", "{not-json", "null", "[]", "0", "false", "{}", '{"id":null}', '{"id":0}', '{"id":""}',
     '{"id":"\\u0000"}',].each_with_index do |payload, index|
      get new_auth_com_sign_in_challenge_passkey_path(ri: "jp")
      challenge_id = session[:passkey_challenges].keys.first
      post auth_com_sign_in_challenge_passkey_path(ri: "jp"),
           params: { mfa_passkey_form: { challenge_id: challenge_id, credential_json: payload }.compact },
           headers: { "REMOTE_ADDR" => "192.0.2.#{index + 1}" }

      assert_response :see_other
      assert_redirected_to auth_com_sign_in_challenge_path(ri: "jp")
      assert_equal "mfa", @issuance.transaction.reload.step
      assert_nil @issuance.transaction.authentication_event_at
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    end
  end

  test "create sends the visitor back to the chooser when the credential belongs to another account" do
    other_visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    establish_pending_mfa!
    get new_auth_com_sign_in_challenge_passkey_path(ri: "jp"), headers: @origin_headers
    challenge_id = session[:passkey_challenges].keys.first
    @passkey.update!(visitor_id: other_visitor.id)

    post auth_com_sign_in_challenge_passkey_path(ri: "jp"),
         params: {
           mfa_passkey_form: {
             challenge_id: challenge_id,
             credential_json: {
               id: @passkey.webauthn_id,
               type: "public-key",
               response: { clientDataJSON: "d",
                           authenticatorData: "d",
                           signature: "d",
                           userHandle: other_visitor.public_id, },
             }.to_json,
           },
         },
         headers: @origin_headers

    assert_response :see_other
    assert_redirected_to auth_com_sign_in_challenge_path(ri: "jp")
  end

  test "create verifies passkey and redirects on success" do
    establish_pending_mfa!

    get new_auth_com_sign_in_challenge_passkey_path(ri: "jp"), headers: @origin_headers

    assert_response :success

    challenge_id = session[:passkey_challenges].keys.first

    verification_context = Struct.new(:sign_count, :verified_at).new(6, Time.current)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_com_sign_in_challenge_passkey_path(ri: "jp"),
           params: {
             mfa_passkey_form: {
               challenge_id: challenge_id,
               credential_json: {
                 id: @passkey.webauthn_id,
                 type: "public-key",
                 response: {
                   clientDataJSON: "dummy",
                   authenticatorData: "dummy",
                   signature: "dummy",
                   userHandle: @visitor.public_id,
                 },
               }.to_json,
             },
           },
           headers: @origin_headers
    end

    assert_response :redirect

    uri = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), uri.host
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal "email", @issuance.transaction.reload.authentication_method
    assert_equal auth_com_sign_in_check_path, uri.path
    assert_nil session[:pending_mfa]
    assert_equal 6, @passkey.reload.sign_count
  end

  private

  def establish_pending_mfa!
    email_record = @visitor.visitor_emails.first
    sign_in_with_email_to_mfa!(
      surface: :com,
      email_record: email_record,
      email: email_record.address,
      headers: @origin_headers,
    )
  end
end
