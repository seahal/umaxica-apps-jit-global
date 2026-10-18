# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/webauthn_fake_client_helper"

module Webauthn
  class VerifiersTest < ActiveSupport::TestCase
    include WebauthnFakeClientHelper

    APP_CONFIG = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.app", origin: "https://auth.umaxica.app")
    COM_CONFIG = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.com", origin: "https://auth.umaxica.com")
    ORG_CONFIG = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.org", origin: "https://auth.umaxica.org")

    setup do
      @client = webauthn_fake_client
    end

    test "registration options demand required user verification" do
      options = RegistrationVerifier.options_for(
        config: APP_CONFIG, user_id: "1", user_name: "user@example.com", surface: :app,
      )

      assert_equal "required", options.authenticator_selection[:user_verification]
      assert_equal "required", options.authenticator_selection[:resident_key]
      assert_equal "auth.umaxica.app", options.rp.id
    end

    test "registration discoverability is required for app and com but unchanged for org" do
      app_options = RegistrationVerifier.options_for(
        config: APP_CONFIG, user_id: "app-user", user_name: "app@example.com", surface: :app,
      )
      com_options = RegistrationVerifier.options_for(
        config: COM_CONFIG, user_id: "com-user", user_name: "com@example.com", surface: :com,
      )
      org_options = RegistrationVerifier.options_for(
        config: ORG_CONFIG, user_id: "org-user", user_name: "org@example.com", surface: :org,
      )

      assert_equal "required", app_options.authenticator_selection[:resident_key]
      assert_equal "required", com_options.authenticator_selection[:resident_key]
      assert_equal "discouraged", org_options.authenticator_selection[:resident_key]
      [app_options, com_options, org_options].each do |options|
        assert_equal "required", options.authenticator_selection[:user_verification]
      end
    end

    test "authentication options demand required user verification" do
      options = AssertionVerifier.options_for(config: APP_CONFIG, allow_ids: ["abc"], purpose: :direct_sign_in)

      assert_equal "required", options.user_verification
    end

    test "a user-verified attestation verifies and yields an aal2-aligned context" do
      challenge = registration_challenge
      params = fake_attestation(
        @client, challenge: challenge, user_verified: true, backup_eligibility: true,
                 backup_state: true,
      )

      context = RegistrationVerifier.verify!(credential_params: params, challenge: challenge, config: APP_CONFIG)

      assert context.user_verified
      assert context.user_present
      assert_predicate context, :aal2_aligned?
      assert context.backup_eligible
      assert context.backup_state
      assert_predicate context.webauthn_id, :present?
    end

    test "a UV=false attestation is rejected" do
      challenge = registration_challenge
      params = fake_attestation(@client, challenge: challenge, user_verified: false)

      assert_raises(RegistrationVerifier::UserVerificationRequiredError, WebAuthn::UserVerifiedVerificationError) do
        RegistrationVerifier.verify!(credential_params: params, challenge: challenge, config: APP_CONFIG)
      end
    end

    test "a user-verified assertion verifies against the stored credential" do
      passkey = register_fake_credential
      challenge = authentication_challenge
      params = fake_assertion(@client, challenge: challenge, user_verified: true, sign_count: 5)

      context = AssertionVerifier.verify!(
        credential_params: params, challenge: challenge, config: APP_CONFIG,
        public_key: passkey[:public_key], sign_count: passkey[:sign_count], purpose: :direct_sign_in,
      )

      assert context.user_verified
      assert_predicate context, :aal2_aligned?
      assert_equal 5, context.sign_count
    end

    test "a UV=false assertion is rejected even with a valid signature" do
      passkey = register_fake_credential
      challenge = authentication_challenge
      params = fake_assertion(@client, challenge: challenge, user_verified: false, sign_count: 5)

      assert_raises(AssertionVerifier::UserVerificationRequiredError, WebAuthn::UserVerifiedVerificationError) do
        AssertionVerifier.verify!(
          credential_params: params, challenge: challenge, config: APP_CONFIG,
          public_key: passkey[:public_key], sign_count: passkey[:sign_count], purpose: :direct_sign_in,
        )
      end
    end

    test "a sign count regression is rejected as a cloned-authenticator signal" do
      passkey = register_fake_credential
      challenge = authentication_challenge
      params = fake_assertion(@client, challenge: challenge, user_verified: true, sign_count: 3)

      assert_raises(WebAuthn::SignCountVerificationError) do
        AssertionVerifier.verify!(
          credential_params: params, challenge: challenge, config: APP_CONFIG,
          public_key: passkey[:public_key], sign_count: 10, purpose: :direct_sign_in,
        )
      end
    end

    test "an assertion produced for another surface's relying party is rejected" do
      passkey = register_fake_credential
      challenge = authentication_challenge
      params = fake_assertion(@client, challenge: challenge, user_verified: true, sign_count: 5)

      assert_raises(WebAuthn::Error) do
        AssertionVerifier.verify!(
          credential_params: params, challenge: challenge, config: COM_CONFIG,
          public_key: passkey[:public_key], sign_count: passkey[:sign_count], purpose: :direct_sign_in,
        )
      end
    end

    test "an assertion from a mismatching origin is rejected" do
      passkey = register_fake_credential
      rogue_client = webauthn_fake_client(
        origin: "https://auth.umaxica.app:8443",
        authenticator: webauthn_authenticator_of(@client),
      )
      challenge = authentication_challenge
      params = fake_assertion(
        rogue_client, challenge: challenge, rp_id: "auth.umaxica.app", user_verified: true,
                      sign_count: 5,
      )

      assert_raises(WebAuthn::Error) do
        AssertionVerifier.verify!(
          credential_params: params, challenge: challenge, config: APP_CONFIG,
          public_key: passkey[:public_key], sign_count: passkey[:sign_count], purpose: :direct_sign_in,
        )
      end
    end

    private

    def registration_challenge
      RegistrationVerifier.options_for(
        config: APP_CONFIG, user_id: "1", user_name: "user@example.com", surface: :app,
      ).challenge
    end

    def authentication_challenge
      AssertionVerifier.options_for(config: APP_CONFIG, allow_ids: [], purpose: :direct_sign_in).challenge
    end

    # Registers a credential on the fake client's authenticator and returns
    # the stored representation the server would keep.
    def register_fake_credential
      challenge = registration_challenge
      params = fake_attestation(@client, challenge: challenge, user_verified: true)
      context = RegistrationVerifier.verify!(credential_params: params, challenge: challenge, config: APP_CONFIG)
      credential = WebAuthn::Credential.from_create(params, relying_party: APP_CONFIG.relying_party)

      { webauthn_id: context.webauthn_id, public_key: credential.public_key, sign_count: context.sign_count }
    end
  end
end
