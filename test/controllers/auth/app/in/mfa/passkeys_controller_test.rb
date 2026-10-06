# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"
require "zlib"

module Auth::App::In
  # These HTTP cases use real Base admission and Email primary authentication. Assertion stubs
  # isolate refusal/continuation contracts; real MFA signatures are covered by LocalAuthenticationBoundaryTest.
  class MfaPasskeysControllerTest < ActionDispatch::IntegrationTest
    include ActiveSupport::Testing::TimeHelpers
    include AuthEmailMfaHelper

    fixtures :client_statuses, :client_passkey_statuses, :client_email_statuses, :client_totp_credential_statuses

    setup do
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
      TurnstileVerifierStub.challenge_enabled = true
      TurnstileVerifierStub.challenge_response = { "success" => true }

      @user = Client.create!(id: 9_116_000_000_000 + Zlib.crc32(name), mfa_level_enabled: true)
      @email = "mfa_passkey_#{SecureRandom.hex(4)}@example.com".freeze
      @email_record = @user.client_emails.create!(address: @email, user_email_status_id: ClientEmailStatus::VERIFIED)
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
      @issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: "app", intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
      )
      get auth_app_sign_in_path, params: { entry_ref: @issuance.reference, ri: "jp" }
      csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      post auth_app_sign_in_path, params: { entry_ref: @issuance.reference, authenticity_token: csrf, ri: "jp" }
    end

    teardown do
      TurnstileVerifierStub.challenge_enabled = false
      TurnstileVerifierStub.challenge_response = nil
    end

    test "new redirects to sign in when pending_mfa is missing" do
      get new_auth_app_sign_in_challenge_passkey_path(ri: "jp")

      assert_response :see_other
      assert_redirected_to auth_app_sign_in_path(ri: "jp")
    end

    %i(failed foreign_actor advanced).each do |interruption|
      test "late #{interruption} interruption of local MFA returns to Base without issuing root credentials" do
        email = @user.client_emails.first
        post auth_app_sign_in_email_path,
             params: { :user_email => { address: email.address }, "cf-turnstile-response" => "test-only", :ri => "jp" }
        secret = ROTP::Base32.random_base32
        email.reload.store_otp(secret, 7, 5.minutes.from_now.to_i)
        patch auth_app_sign_in_email_path,
              params: { :user_email => { pass_code: ROTP::HOTP.new(secret).at(7).to_s },
                        "cf-turnstile-response" => "test-only",
                        :ri => "jp", }

        assert_equal "mfa", @issuance.transaction.reload.step
        get new_auth_app_sign_in_challenge_passkey_path(ri: "jp")

        assert_response :success
        challenge_id = session[:passkey_challenges].keys.first
        continuity = ClientAuthCeremonySession.find_by!(local_sign_in_flow_ref: @issuance.transaction.public_id)
        foreign = Client.create!(id: 9_127_000_000_000) if interruption == :foreign_actor
        verification =
          ->(**) do
            # Public verifier fault seam models the flow changing after successful signature validation.
            if interruption == :failed
              @issuance.transaction.halt_sign_in!
            elsif interruption == :advanced
              @issuance.transaction.advance_sign_in_to_guardrail!
            else
              @issuance.transaction.update!(principal_id: foreign.id)
            end
            Struct.new(:sign_count, :verified_at).new(11, Time.current)
          end

        Webauthn::AssertionVerifier.stub(:verify!, verification) do
          post auth_app_sign_in_challenge_passkey_path(ri: "jp"), params: {
            mfa_passkey_form: { challenge_id: challenge_id, credential_json: { id: @passkey.webauthn_id }.to_json },
          }
        end

        assert_redirected_to base_app_sign_show_url(
          host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), protocol: "https", ri: "jp",
        )
        assert_nil session[:pending_mfa]
        assert_nil session[:passkey_challenges]
        assert_nil @issuance.transaction.reload.authentication_event_at
        assert_nil @issuance.transaction.base_finalized_at
        assert_not_nil continuity.reload.revoked_at
        assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
        assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
        assert_equal 0, ClientToken.where(user_id: @user.id).count
        follow_redirect!

        assert_response :success
        assert_not_nil response.parsed_body.at_css('form[method="post"]')
      end
    end

    test "a stale MFA Cookie cannot reopen a Base flow that has advanced past MFA" do
      travel(31.seconds) { establish_pending_mfa_via_email! }
      @issuance.transaction.advance_sign_in_to_guardrail!
      get new_auth_app_sign_in_challenge_passkey_path(ri: "jp")

      assert_response :see_other
      assert_redirected_to auth_app_sign_in_path(ri: "jp")
      assert_nil session[:pending_mfa]
      assert_nil session[:passkey_challenges]
      assert_equal "guardrail", @issuance.transaction.reload.step
      assert_nil @issuance.transaction.authentication_event_at
    end

    test "the MFA Cookie actor must match the admitted Base flow principal" do
      travel(31.seconds) { establish_pending_mfa_via_email! }
      foreign = Client.create!(id: 9_118_000_000_000)
      @issuance.transaction.update!(principal_id: foreign.id)
      get new_auth_app_sign_in_challenge_passkey_path(ri: "jp")

      assert_response :see_other
      assert_redirected_to auth_app_sign_in_path(ri: "jp")
      assert_nil session[:pending_mfa]
      assert_nil session[:passkey_challenges]
      assert_nil @issuance.transaction.reload.authentication_event_at
    end

    # Every refusal on the MFA passkey challenge sends the person back to the challenge
    # chooser rather than leaving them on a dead page, and none of them completes the
    # sign-in. These four arms had no test on this surface.
    test "new sends the client back to the chooser when no passkey is registered" do
      @passkey.destroy!
      travel(31.seconds) { establish_pending_mfa_via_email! }

      get new_auth_app_sign_in_challenge_passkey_path(ri: "jp")

      assert_response :see_other
      assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")
    end

    test "new refuses an ACTIVE Passkey whose writer deadline has passed" do
      travel(31.seconds) { establish_pending_mfa_via_email! }
      @passkey.update!(discard_at: ClientPasskey.database_now)
      get new_auth_app_sign_in_challenge_passkey_path(ri: "jp")

      assert_response :see_other
      assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")
      assert_nil session[:passkey_challenges]
      assert_equal "mfa", @issuance.transaction.reload.step
    end

    test "new sends the client back to the chooser when the relying party is not configured" do
      travel(31.seconds) { establish_pending_mfa_via_email! }
      missing_config =
        lambda do |*|
          raise Webauthn::RelyingPartyConfigResolver::MissingConfigurationError, "rp_id missing"
        end

      Webauthn::RelyingPartyConfigResolver.stub(:resolve, missing_config) do
        get new_auth_app_sign_in_challenge_passkey_path(ri: "jp")
      end

      assert_response :see_other
      assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")
    end

    test "create refuses a failed stealth challenge and keeps the passkey challenge for a retry" do
      travel(31.seconds) { establish_pending_mfa_via_email! }
      get new_auth_app_sign_in_challenge_passkey_path(ri: "jp")
      challenge_id = session[:passkey_challenges].keys.first
      TurnstileVerifierStub.challenge_response = { "success" => false }

      post auth_app_sign_in_challenge_passkey_path(ri: "jp"),
           params: { mfa_passkey_form: { challenge_id: challenge_id } }

      assert_response :see_other
      assert_redirected_to new_auth_app_sign_in_challenge_passkey_path(ri: "jp")
      assert_includes session[:passkey_challenges].keys, challenge_id
    end

    test "create sends the client back to the chooser when the assertion does not verify" do
      travel(31.seconds) { establish_pending_mfa_via_email! }
      get new_auth_app_sign_in_challenge_passkey_path(ri: "jp")
      challenge_id = session[:passkey_challenges].keys.first
      failure = ->(**) { raise Webauthn::AssertionVerifier::VerificationError, "bad assertion" }

      Webauthn::AssertionVerifier.stub(:verify!, failure) do
        post auth_app_sign_in_challenge_passkey_path(ri: "jp"), params: {
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
      assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")
    end

    test "MFA rejects missing empty scalar array and NUL credential JSON without advancing Base evidence" do
      travel(31.seconds) { establish_pending_mfa_via_email! }
      [nil, "", "{not-json", "null", "[]", "0", "false", "{}", '{"id":null}', '{"id":0}', '{"id":""}',
       '{"id":"\\u0000"}',].each_with_index do |payload, index|
        get new_auth_app_sign_in_challenge_passkey_path(ri: "jp")
        challenge_id = session[:passkey_challenges].keys.first
        post auth_app_sign_in_challenge_passkey_path(ri: "jp"),
             params: { mfa_passkey_form: { challenge_id: challenge_id, credential_json: payload }.compact },
             headers: { "REMOTE_ADDR" => "192.0.2.#{index + 1}" }

        assert_response :see_other
        assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")
        assert_equal "mfa", @issuance.transaction.reload.step
        assert_nil @issuance.transaction.authentication_event_at
        assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
        assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
      end
    end

    test "create sends the client back to the chooser when the credential belongs to another account" do
      other_user = Client.create!(mfa_level_enabled: true)
      travel(31.seconds) { establish_pending_mfa_via_email! }
      get new_auth_app_sign_in_challenge_passkey_path(ri: "jp")
      challenge_id = session[:passkey_challenges].keys.first
      @passkey.update!(user_id: other_user.id)

      post auth_app_sign_in_challenge_passkey_path(ri: "jp"), params: {
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
      assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")
    end

    test "create verifies passkey and finalizes login with pending_mfa" do
      travel 31.seconds do
        establish_pending_mfa_via_email!
      end

      get new_auth_app_sign_in_challenge_passkey_path(ri: "jp")

      assert_response :success

      challenge_id = session[:passkey_challenges].keys.first

      assert_not_nil challenge_id

      verification_context = Struct.new(:sign_count, :verified_at).new(11, Time.current)

      Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
        post auth_app_sign_in_challenge_passkey_path(ri: "jp"), params: {
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
      uri = URI.parse(response.location)

      assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), uri.host
      assert_equal auth_app_sign_in_check_path, uri.path
      assert_nil session[:pending_mfa]
      assert_nil session[:mfa_user_id]
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
      assert_equal "email", @issuance.transaction.reload.authentication_method
      assert_equal 11, @passkey.reload.sign_count
    end

    private

    def establish_pending_mfa_via_email!
      sign_in_with_email_to_mfa!(surface: :app, email_record: @email_record, email: @email)

      assert_predicate session[:pending_mfa], :present?
    end
  end
end
