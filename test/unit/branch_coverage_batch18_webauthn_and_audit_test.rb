# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch18WebauthnAndAuditTest < ActiveSupport::TestCase
  def stub_credential(user_verified:, user_present:)
    auth_data = Struct.new(:user_verified?, :user_present?).new(user_verified, user_present)
    response = Struct.new(:authenticator_data, :transports).new(auth_data, [])
    credential = Object.new
    credential.define_singleton_method(:verify) { |*| true }
    credential.define_singleton_method(:response) { response }
    credential.define_singleton_method(:authenticator_attachment) { nil }
    credential
  end

  test "assertion verifier raises UV and UP errors after gem verify" do
    config = Struct.new(:relying_party).new(Object.new)
    Webauthn::UvPolicy.stub(:for, Struct.new(:enforce_server_side?, :client_value).new(true, "required")) do
      WebAuthn::Credential.stub(:from_get, stub_credential(user_verified: false, user_present: true)) do
        assert_raises(Webauthn::AssertionVerifier::UserVerificationRequiredError) do
          Webauthn::AssertionVerifier.verify!(
            credential_params: {},
            challenge: "c",
            config: config,
            public_key: "pk",
            sign_count: 0,
            purpose: :authentication,
          )
        end
      end
      WebAuthn::Credential.stub(:from_get, stub_credential(user_verified: true, user_present: false)) do
        assert_raises(Webauthn::AssertionVerifier::UserPresenceRequiredError) do
          Webauthn::AssertionVerifier.verify!(
            credential_params: {},
            challenge: "c",
            config: config,
            public_key: "pk",
            sign_count: 0,
            purpose: :authentication,
          )
        end
      end
    end
  end

  test "registration verifier raises UV and UP errors after gem verify" do
    config = Struct.new(:relying_party).new(Object.new)
    Webauthn::UvPolicy.stub(:for, Struct.new(:enforce_server_side?, :client_value).new(true, "required")) do
      WebAuthn::Credential.stub(:from_create, stub_credential(user_verified: false, user_present: true)) do
        assert_raises(Webauthn::RegistrationVerifier::UserVerificationRequiredError) do
          Webauthn::RegistrationVerifier.verify!(
            credential_params: {},
            challenge: "c",
            config: config,
          )
        end
      end
      WebAuthn::Credential.stub(:from_create, stub_credential(user_verified: true, user_present: false)) do
        assert_raises(Webauthn::RegistrationVerifier::UserPresenceRequiredError) do
          Webauthn::RegistrationVerifier.verify!(
            credential_params: {},
            challenge: "c",
            config: config,
          )
        end
      end
    end
  end
end
