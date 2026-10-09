# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"

class ExternalAuthenticationLoginUseCaseTest < ActiveSupport::TestCase
  include ExternalIdentityTestHelper

  test "returns an authenticated typed result for an existing identity" do
    client = Client.create!(
      status_id: ClientStatus::ACTIVE,
      public_id: "login_uc_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    identity = create_active_external_identity(client: client, provider: "google", subject: "login-use-case-existing")
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: identity.subject,
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )

    result = ExternalAuthenticationLoginUseCase.call(
      principal: principal,
      credential_candidate: nil,
      sign_up_entry: false,
    )

    assert_instance_of ExternalAuthentication::LoginResult, result
    assert_equal :authenticated, result.status
    assert_equal client, result.user
    assert_equal identity, result.identity
    assert result.existing_account
  end

  test "returns signup required without persisting an unknown identity" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "login-use-case-unknown",
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )

    assert_no_difference("ClientExternalIdentity.count") do
      result = ExternalAuthenticationLoginUseCase.call(
        principal: principal,
        credential_candidate: nil,
        sign_up_entry: true,
      )

      assert_instance_of ExternalAuthentication::LoginResult, result
      assert_equal :signup_required, result.status
      assert_nil result.user
      assert_nil result.identity
      assert_not result.existing_account
    end
  end

  test "rejects values that are not verified principals" do
    assert_raises(ArgumentError) do
      ExternalAuthenticationLoginUseCase.call(
        principal: { provider: "google", subject: "unverified" },
        credential_candidate: nil,
        sign_up_entry: false,
      )
    end
  end
  test "an unknown subject at sign-in creates neither an account nor a signup candidate" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google", subject: "unknown-signin-#{SecureRandom.hex(8)}",
      issuer: "https://accounts.google.com", audience: "google-client-id",
      verified_at: Time.current, verification_authority: "provider-contract",
    )
    assert_no_difference("Client.count") do
      assert_no_difference("ClientExternalIdentity.count") do
        assert_raises(SocialAuth::UnauthorizedError) do
          ExternalAuthenticationLoginUseCase.call(principal:, credential_candidate: nil, sign_up_entry: false)
        end
      end
    end
  end
end
