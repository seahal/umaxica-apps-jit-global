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
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! @host
    https!
    VisitorSignInFlowState.ensure_defaults!
    @origin_headers = { "HTTP_ORIGIN" => "https://#{@host}", "Origin" => "https://#{@host}" }.freeze
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }

    @visitor = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: 9_116_000_000_000 + Zlib.crc32(name),
    )
    email = VisitorEmail.create!(
      visitor_id: @visitor.id,
      address: "com_mfa_passkey_#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    @visitor.reload.update!(security_mode_id: SecurityModeConfigurable::ADVANCED)
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
    @issuance = OidcTestEntry.issue!(
      surface: "com",
      intent: "sign_in",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )
    admit_auth_ceremony_entry!(
      auth_com_sign_in_path, reference: @issuance.reference, params: { ri: "jp" },
    )
    @primary_sign_in_binding = nil
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "new requires pending MFA session" do
    get mfa_passkey_path, headers: @origin_headers

    # Without an MFA-phase flow the request restarts at the OIDC sign-in page.
    assert_response :see_other
    assert_equal auth_com_sign_in_path(ri: "jp"), URI.parse(response.location).request_uri
  end

  %i(failed foreign_actor advanced).each do |interruption|
    test "late #{interruption} interruption of OIDC MFA returns to sign-in without recording evidence" do
      email = @visitor.visitor_emails.first
      post auth_com_sign_in_email_path(fb: @primary_sign_in_binding),
           params: { :user_email => { address: email.address }, "cf-turnstile-response" => "test-only", :ri => "jp" }
      delivery =
        ActiveJob::Base.queue_adapter.enqueued_jobs.reverse.find do |entry|
          entry.fetch(:job) == OtpNotifierEmailDeliveryJob
        end
      payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
      code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))
      patch auth_com_sign_in_email_path(fb: @primary_sign_in_binding),
            params: { :user_email => { pass_code: code },
                      "cf-turnstile-response" => "test-only",
                      :ri => "jp", }

      assert_predicate mfa_flow.reload, :sign_in_mfa_pending?
      get mfa_passkey_path

      assert_response :success
      challenge_id = session[:passkey_challenges].keys.first
      continuity = VisitorAuthCeremonySession.find_by!(
        authorization_transaction_ref: @issuance.transaction.transaction_id,
      )
      foreign = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        id: 9_127_000_000_000,
      ) if interruption == :foreign_actor
      verification =
        ->(**) do
          # Public verifier fault seam models the flow changing after successful signature validation.
          if interruption == :failed
            mfa_flow.halt_sign_in!
          elsif interruption == :advanced
            mfa_flow.advance_sign_in_to_guardrail!
          else
            mfa_flow.update!(principal_id: foreign.id)
          end
          Struct.new(:sign_count, :verified_at).new(11, Time.current)
        end

      Webauthn::AssertionVerifier.stub(:verify!, verification) do
        post mfa_passkey_submit_path, params: {
          mfa_passkey_form: { challenge_id: challenge_id, credential_json: { id: @passkey.webauthn_id }.to_json },
        }
      end

      # An OIDC-parent refusal records nothing and returns to the sign-in page of the same transaction.
      assert_redirected_to auth_com_sign_in_url(ri: "jp")
      assert_nil session[:pending_mfa]
      assert_empty session[:passkey_challenges].to_h
      assert_nil mfa_flow.reload.authentication_event_at
      assert_nil @issuance.transaction.base_finalized_at
      assert_not_predicate continuity.reload, :authentication_evidence_recorded?
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
      assert_equal 0, VisitorToken.where(visitor_id: @visitor.id).count
    end
  end

  test "a stale MFA Cookie cannot reopen a Base flow that has advanced past MFA" do
    establish_pending_mfa!
    mfa_flow.advance_sign_in_to_guardrail!
    get mfa_passkey_path

    assert_response :conflict
    assert_equal "この画面は古くなっています。最初からやり直してください。", response.body
    assert_predicate session[:pending_mfa], :present?
    assert_nil session[:passkey_challenges]
    assert_predicate mfa_flow.reload, :sign_in_guardrail_pending?
    assert_nil mfa_flow.authentication_event_at
  end

  test "the MFA Cookie actor must match the admitted Base flow principal" do
    establish_pending_mfa!
    foreign = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_118_000_000_000)
    mfa_flow.update!(principal_id: foreign.id)
    get mfa_passkey_path

    assert_response :conflict
    assert_equal "この画面は古くなっています。最初からやり直してください。", response.body
    assert_predicate session[:pending_mfa], :present?
    assert_nil session[:passkey_challenges]
    assert_nil mfa_flow.reload.authentication_event_at
  end

  # Every refusal on the MFA passkey challenge sends the person back to the challenge
  # chooser rather than leaving them on a dead page, and none of them completes the
  # sign-in. These four arms had no test.
  test "new sends the visitor back to the chooser when no passkey is registered" do
    @passkey.destroy!
    establish_pending_mfa!

    get mfa_passkey_path, headers: @origin_headers

    assert_response :see_other
    assert_redirected_to_path(mfa_challenge_path)
  end

  test "new refuses an ACTIVE Passkey whose writer deadline has passed" do
    establish_pending_mfa!
    @passkey.update!(discard_at: VisitorPasskey.database_now)
    get mfa_passkey_path

    assert_response :see_other
    assert_redirected_to_path(mfa_challenge_path)
    assert_nil session[:passkey_challenges]
    assert_predicate mfa_flow.reload, :sign_in_mfa_pending?
  end

  test "new sends the visitor back to the chooser when the relying party is not configured" do
    establish_pending_mfa!
    missing_config =
      lambda do |*|
        raise Webauthn::RelyingPartyConfigResolver::MissingConfigurationError, "rp_id missing"
      end

    Webauthn::RelyingPartyConfigResolver.stub(:resolve, missing_config) do
      get mfa_passkey_path, headers: @origin_headers
    end

    assert_response :see_other
    assert_redirected_to_path(mfa_challenge_path)
  end

  test "create refuses a failed stealth challenge without consuming the passkey challenge" do
    establish_pending_mfa!
    get mfa_passkey_path, headers: @origin_headers
    challenge_id = session[:passkey_challenges].keys.first
    TurnstileVerifierStub.challenge_response = { "success" => false }

    post mfa_passkey_submit_path,
         params: { mfa_passkey_form: { challenge_id: challenge_id } },
         headers: @origin_headers

    assert_response :see_other
    assert_redirected_to_path(mfa_passkey_path)
    assert_includes session[:passkey_challenges].keys, challenge_id,
                    "a refused challenge must still be there for the retry"
  end

  test "create sends the visitor back to the chooser when the assertion does not verify" do
    establish_pending_mfa!
    get mfa_passkey_path, headers: @origin_headers
    challenge_id = session[:passkey_challenges].keys.first
    failure = ->(**) { raise Webauthn::AssertionVerifier::VerificationError, "bad assertion" }

    Webauthn::AssertionVerifier.stub(:verify!, failure) do
      post mfa_passkey_submit_path,
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
    assert_redirected_to_path(mfa_challenge_path)
  end

  test "MFA rejects missing empty scalar array and NUL credential JSON without advancing Base evidence" do
    establish_pending_mfa!
    [nil, "", "{not-json", "null", "[]", "0", "false", "{}", '{"id":null}', '{"id":0}', '{"id":""}',
     '{"id":"\\u0000"}',].each_with_index do |payload, index|
      get mfa_passkey_path
      challenge_id = session[:passkey_challenges].keys.first
      post mfa_passkey_submit_path,
           params: { mfa_passkey_form: { challenge_id: challenge_id, credential_json: payload }.compact },
           headers: { "REMOTE_ADDR" => "192.0.2.#{index + 1}" }

      assert_response :see_other
      assert_redirected_to_path(mfa_challenge_path)
      assert_predicate mfa_flow.reload, :sign_in_mfa_pending?
      assert_nil mfa_flow.authentication_event_at
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    end
  end

  test "create sends the visitor back to the chooser when the credential belongs to another account" do
    other_visitor = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
    )
    establish_pending_mfa!
    get mfa_passkey_path, headers: @origin_headers
    challenge_id = session[:passkey_challenges].keys.first
    @passkey.update!(visitor_id: other_visitor.id)

    post mfa_passkey_submit_path,
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
    assert_redirected_to_path(mfa_challenge_path)
  end

  test "create verifies passkey and redirects on success" do
    establish_pending_mfa!

    get mfa_passkey_path, headers: @origin_headers

    assert_response :success

    challenge_id = session[:passkey_challenges].keys.first

    verification_context = Struct.new(:sign_count, :verified_at).new(6, Time.current)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post mfa_passkey_submit_path,
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

    assert_predicate VisitorAuthCeremonySession.find_by!(
      authorization_transaction_ref: @issuance.transaction.transaction_id,
    ), :authentication_evidence_recorded?
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal "email", mfa_flow.reload.authentication_method
    assert_nil session[:pending_mfa]
    assert_equal 6, @passkey.reload.sign_count
  end

  private

  # An OIDC-parent sign-in has no flow until primary authentication succeeds; the MFA phase
  # then lives on the actor's newest flow.
  def mfa_flow
    @mfa_flow ||= VisitorSignInFlow.where(principal_id: @visitor.id).recent_first.first
  end

  def assert_redirected_to_path(path)
    assert_equal URI.parse(path).path, URI.parse(response.location).path
  end

  def mfa_binding_params
    return {} unless mfa_flow

    { fb: SignInFlowBindingCodec.encode(flow: mfa_flow, surface: "com", phase: "MFA_PENDING") }
  end

  def mfa_challenge_path
    auth_com_sign_in_challenge_path(ri: "jp", **mfa_binding_params)
  end

  def mfa_passkey_path
    new_auth_com_sign_in_challenge_passkey_path(ri: "jp", **mfa_binding_params)
  end

  def mfa_passkey_submit_path
    auth_com_sign_in_challenge_passkey_path(ri: "jp", **mfa_binding_params)
  end

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
