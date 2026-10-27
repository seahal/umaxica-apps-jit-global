# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"
require "zlib"

module Auth::App::In
  # These HTTP cases use real Base admission and Email primary authentication. Assertion stubs
  # isolate refusal/continuation contracts; real MFA signatures are covered by the WebAuthn verifier tests.
  class MfaPasskeysControllerTest < ActionDispatch::IntegrationTest
    include ActiveSupport::Testing::TimeHelpers
    include AuthEmailMfaHelper

    fixtures :client_statuses, :client_passkey_statuses, :client_email_statuses, :client_totp_credential_statuses

    setup do
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      https!
      ClientSignInFlowState.ensure_defaults!
      TurnstileVerifierStub.challenge_enabled = true
      TurnstileVerifierStub.challenge_response = { "success" => true }

      @user = Client.create!(id: 9_116_000_000_000 + Zlib.crc32(name), security_mode_id: SecurityModeConfigurable::ADVANCED)
      @email = "mfa_passkey_#{SecureRandom.hex(4)}@example.com".freeze
      @email_record = @user.client_emails.create!(address: @email, user_email_status_id: ClientEmailStatus::VERIFIED)
      @email_record.finalize_binding!
      ClientTotpCredential.create!(
        user: @user,
        private_key: ROTP::Base32.random_base32,
        user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        title: "totp",
      )

      @raw_credential_id = "mfa-credential-123"
      @passkey = ClientPasskey.create!(
        user: @user,
        webauthn_id: Base64.urlsafe_encode64(@raw_credential_id, padding: false),
        external_id: SecureRandom.uuid,
        public_key: "dummy-public-key",
        sign_count: 10,
        description: "MFA passkey",
        status_id: ClientPasskeyStatus::ACTIVE,
      )
      # A real Base admission precedes every Auth-only MFA assertion; no root cookie is injected.
      @issuance = OidcTestEntry.issue!(
        surface: "app",
        intent: "sign_in",
        base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
        base_token: nil,
      )
      admit_auth_ceremony_entry!(
        auth_app_sign_in_path, reference: @issuance.reference, params: { ri: "jp" },
      )
      @primary_sign_in_binding = nil
    end

    teardown do
      TurnstileVerifierStub.challenge_enabled = false
      TurnstileVerifierStub.challenge_response = nil
    end

    test "new redirects to sign in when pending_mfa is missing" do
      get mfa_passkey_path

      # Without an MFA-phase flow the request restarts at the OIDC sign-in page.
      assert_response :see_other
      assert_equal auth_app_sign_in_path(ri: "jp"), URI.parse(response.location).request_uri
    end

    %i(failed foreign_actor advanced).each do |interruption|
      test "late #{interruption} interruption of OIDC MFA returns to sign-in without recording evidence" do
        email = @email_record
        post auth_app_sign_in_email_path(fb: @primary_sign_in_binding),
             params: { :user_email => { address: email.address }, "cf-turnstile-response" => "test-only", :ri => "jp" }
        delivery =
          ActiveJob::Base.queue_adapter.enqueued_jobs.reverse.find do |entry|
            entry.fetch(:job) == OtpNotifierEmailDeliveryJob
          end
        payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
        code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))
        patch auth_app_sign_in_email_path(fb: @primary_sign_in_binding),
              params: { :user_email => { pass_code: code },
                        "cf-turnstile-response" => "test-only",
                        :ri => "jp", }

        assert_predicate mfa_flow.reload, :sign_in_mfa_pending?
        get mfa_passkey_path

        assert_response :success
        challenge_id = session[:passkey_challenges].keys.first
        continuity = ClientAuthCeremonySession.find_by!(
          authorization_transaction_ref: @issuance.transaction.transaction_id,
        )
        foreign = Client.create!(
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
        assert_redirected_to auth_app_sign_in_url(ri: "jp")
        assert_nil session[:pending_mfa]
        assert_empty session[:passkey_challenges].to_h
        assert_nil mfa_flow.reload.authentication_event_at
        assert_nil @issuance.transaction.base_finalized_at
        assert_not_predicate continuity.reload, :authentication_evidence_recorded?
        assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
        assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
        assert_equal 0, ClientToken.where(user_id: @user.id).count
      end
    end

    test "a stale MFA Cookie cannot reopen a Base flow that has advanced past MFA" do
      travel(31.seconds) { establish_pending_mfa_via_email! }
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
      travel(31.seconds) { establish_pending_mfa_via_email! }
      foreign = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_118_000_000_000)
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
    # sign-in. These four arms had no test on this surface.
    test "new sends the client back to the chooser when no passkey is registered" do
      @passkey.destroy!
      travel(31.seconds) { establish_pending_mfa_via_email! }

      get mfa_passkey_path

      assert_response :see_other
      assert_redirected_to_path(mfa_challenge_path)
    end

    test "new refuses an ACTIVE Passkey whose writer deadline has passed" do
      travel(31.seconds) { establish_pending_mfa_via_email! }
      @passkey.update!(discard_at: ClientPasskey.database_now)
      get mfa_passkey_path

      assert_response :see_other
      assert_redirected_to_path(mfa_challenge_path)
      assert_nil session[:passkey_challenges]
      assert_predicate mfa_flow.reload, :sign_in_mfa_pending?
    end

    test "new sends the client back to the chooser when the relying party is not configured" do
      travel(31.seconds) { establish_pending_mfa_via_email! }
      missing_config =
        lambda do |*|
          raise Webauthn::RelyingPartyConfigResolver::MissingConfigurationError, "rp_id missing"
        end

      Webauthn::RelyingPartyConfigResolver.stub(:resolve, missing_config) do
        get mfa_passkey_path
      end

      assert_response :see_other
      assert_redirected_to_path(mfa_challenge_path)
    end

    test "create refuses a failed stealth challenge and keeps the passkey challenge for a retry" do
      travel(31.seconds) { establish_pending_mfa_via_email! }
      get mfa_passkey_path
      challenge_id = session[:passkey_challenges].keys.first
      TurnstileVerifierStub.challenge_response = { "success" => false }

      post mfa_passkey_submit_path,
           params: { mfa_passkey_form: { challenge_id: challenge_id } }

      assert_response :see_other
      assert_redirected_to_path(mfa_passkey_path)
      assert_includes session[:passkey_challenges].keys, challenge_id
    end

    test "create sends the client back to the chooser when the assertion does not verify" do
      travel(31.seconds) { establish_pending_mfa_via_email! }
      get mfa_passkey_path
      challenge_id = session[:passkey_challenges].keys.first
      failure = ->(**) { raise Webauthn::AssertionVerifier::VerificationError, "bad assertion" }

      Webauthn::AssertionVerifier.stub(:verify!, failure) do
        post mfa_passkey_submit_path, params: {
          mfa_passkey_form: {
            challenge_id: challenge_id,
            credential_json: {
              id: @passkey.webauthn_id,
              type: "public-key",
              response: { clientDataJSON: "d",
                          authenticatorData: "d",
                          signature: "d",
                          userHandle: @user.public_id, },
            }.to_json,
          },
        }
      end

      assert_response :see_other
      assert_redirected_to_path(mfa_challenge_path)
    end

    test "MFA rejects missing empty scalar array and NUL credential JSON without advancing Base evidence" do
      travel(31.seconds) { establish_pending_mfa_via_email! }
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

    test "create sends the client back to the chooser when the credential belongs to another account" do
      other_user = Client.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
      travel(31.seconds) { establish_pending_mfa_via_email! }
      get mfa_passkey_path
      challenge_id = session[:passkey_challenges].keys.first
      @passkey.update!(user_id: other_user.id)

      post mfa_passkey_submit_path, params: {
        mfa_passkey_form: {
          challenge_id: challenge_id,
          credential_json: {
            id: @passkey.webauthn_id,
            type: "public-key",
            response: { clientDataJSON: "d",
                        authenticatorData: "d",
                        signature: "d",
                        userHandle: other_user.public_id, },
          }.to_json,
        },
      }

      assert_response :see_other
      assert_redirected_to_path(mfa_challenge_path)
    end

    test "create verifies passkey and finalizes login with pending_mfa" do
      travel 31.seconds do
        establish_pending_mfa_via_email!
      end

      get mfa_passkey_path

      assert_response :success

      challenge_id = session[:passkey_challenges].keys.first

      assert_not_nil challenge_id

      verification_context = Struct.new(:sign_count, :verified_at).new(11, Time.current)

      Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
        post mfa_passkey_submit_path, params: {
          mfa_passkey_form: {
            challenge_id: challenge_id,
            credential_json: {
              id: @passkey.webauthn_id,
              type: "public-key",
              response: {
                clientDataJSON: "dummy",
                authenticatorData: "dummy",
                signature: "dummy",
                userHandle: @user.public_id,
              },
            }.to_json,
          },
        }
      end

      assert_response :found
      assert_predicate ClientAuthCeremonySession.find_by!(
        authorization_transaction_ref: @issuance.transaction.transaction_id,
      ), :authentication_evidence_recorded?
      assert_nil session[:pending_mfa]
      assert_nil session[:mfa_user_id]
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
      assert_equal "email", mfa_flow.reload.authentication_method
      assert_equal 11, @passkey.reload.sign_count
    end

    private

    # An OIDC-parent sign-in has no flow until primary authentication succeeds; the MFA phase
    # then lives on the actor's newest flow.
    def mfa_flow
      @mfa_flow ||= ClientSignInFlow.where(principal_id: @user.id).recent_first.first
    end

    def assert_redirected_to_path(path)
      assert_equal URI.parse(path).path, URI.parse(response.location).path
    end

    def mfa_binding_params
      return {} unless mfa_flow

      { fb: SignInFlowBindingCodec.encode(flow: mfa_flow, surface: "app", phase: "MFA_PENDING") }
    end

    def mfa_challenge_path
      auth_app_sign_in_challenge_path(ri: "jp", **mfa_binding_params)
    end

    def mfa_passkey_path
      new_auth_app_sign_in_challenge_passkey_path(ri: "jp", **mfa_binding_params)
    end

    def mfa_passkey_submit_path
      auth_app_sign_in_challenge_passkey_path(ri: "jp", **mfa_binding_params)
    end

    def establish_pending_mfa_via_email!
      sign_in_with_email_to_mfa!(surface: :app, email_record: @email_record, email: @email)

      assert_predicate session[:pending_mfa], :present?
    end
  end
end
