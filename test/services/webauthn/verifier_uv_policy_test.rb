# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/webauthn_fake_client_helper"

# Regression coverage for the user-verification guarantee: every ceremony
# purpose resolves to "required" through Webauthn::UvPolicy, and a UV=false
# response is rejected server-side with real cryptography (FakeClient), not
# stubs. A weakening of either the options value or the server-side check
# must fail here.
class WebauthnVerifierUvPolicyTest < ActiveSupport::TestCase
  include WebauthnFakeClientHelper

  ORIGIN = "https://auth.umaxica.app"

  setup do
    @config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.app", origin: ORIGIN)
    @client = webauthn_fake_client(origin: ORIGIN)
  end

  test "every UV policy purpose is required and enforced server-side" do
    assert_equal %i(
      registration direct_sign_in emergency_sign_in mfa_challenge ordinary_step_up high_risk_step_up
    ).sort,
                 Webauthn::UvPolicy::REGISTRY.keys.sort

    Webauthn::UvPolicy::REGISTRY.each_value do |policy|
      assert_equal "required", policy.client_value, "#{policy.purpose} must be required"
      assert_predicate policy, :enforce_server_side?
    end
  end

  test "unknown UV purpose raises instead of falling back" do
    assert_raises(Webauthn::UvPolicy::UnknownPurposeError) { Webauthn::UvPolicy.for(:banana) }
  end

  test "registration options and every assertion purpose request required user verification" do
    registration_options = Webauthn::RegistrationVerifier.options_for(
      config: @config, user_id: SecureRandom.urlsafe_base64(32), user_name: "user@example.com",
    )

    assert_equal "required", registration_options.authenticator_selection[:user_verification]

    %i(direct_sign_in mfa_challenge ordinary_step_up high_risk_step_up).each do |purpose|
      options = Webauthn::AssertionVerifier.options_for(config: @config, allow_ids: [], purpose: purpose)

      assert_equal "required", options.user_verification, "#{purpose} assertion options must require UV"
    end
  end

  test "UV=false attestation is rejected at registration" do
    challenge = Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false)
    params = fake_attestation(@client, challenge: challenge, user_verified: false)

    assert_raises(WebAuthn::UserVerifiedVerificationError) do
      Webauthn::RegistrationVerifier.verify!(credential_params: params, challenge: challenge, config: @config)
    end
  end

  test "UV=true attestation verifies and yields persistable authenticator metadata" do
    challenge = Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false)
    params = fake_attestation(@client, challenge: challenge, user_verified: true, backup_eligibility: true)

    context = Webauthn::RegistrationVerifier.verify!(
      credential_params: params, challenge: challenge, config: @config,
    )

    assert_predicate context, :user_verified
    assert_predicate context, :aal2_aligned?
    assert context.backup_eligible
    assert_not context.backup_state
    # FakeAuthenticator reports a random (non-zero) AAGUID; the context must
    # surface it in canonical UUID form for catalog resolution.
    assert_match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/, context.aaguid)
  end

  test "UV=false assertion is rejected for every assertion purpose" do
    record = fake_credential_record_attrs(@client)

    %i(direct_sign_in mfa_challenge ordinary_step_up high_risk_step_up).each do |purpose|
      challenge = Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false)
      params = fake_assertion(@client, challenge: challenge, user_verified: false)

      assert_raises(WebAuthn::UserVerifiedVerificationError, "#{purpose} must reject UV=false") do
        Webauthn::AssertionVerifier.verify!(
          credential_params: params,
          challenge: challenge,
          config: @config,
          public_key: record[:public_key],
          sign_count: record[:sign_count],
          purpose: purpose,
        )
      end
    end
  end

  test "UV=true assertion verifies and reports a user-verified context" do
    record = fake_credential_record_attrs(@client)
    challenge = Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false)
    params = fake_assertion(@client, challenge: challenge, user_verified: true)

    context = Webauthn::AssertionVerifier.verify!(
      credential_params: params,
      challenge: challenge,
      config: @config,
      public_key: record[:public_key],
      sign_count: record[:sign_count],
      purpose: :direct_sign_in,
    )

    assert_predicate context, :user_verified
    assert_predicate context, :aal2_aligned?
    assert_equal record[:webauthn_id], context.webauthn_id
  end
end
