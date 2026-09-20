# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"

class SocialAuthLoginHandlerTest < ActiveSupport::TestCase
  include ExternalIdentityTestHelper

  FakeRepository =
    Struct.new(:identity, :raise_error, keyword_init: true) do
      def find_by_subject(*)
        raise raise_error if raise_error

        identity
      end

      def refresh_credentials!(*)
        identity
      end
    end

  test "authenticates an existing identity linked to a user" do
    client = Client.create!(
      status_id: ClientStatus::ACTIVE,
      public_id: "sah_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    identity = create_active_external_identity(
      client: client,
      provider: "google",
      subject: "social-auth-handler-existing",
    )
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: identity.subject,
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )
    repository = ExternalAuthentication::ClientExternalIdentityRepositoryAdapter.new(provider: "google")

    result = SocialAuthLoginHandler.call(
      principal: principal,
      credential_candidate: nil,
      repository: repository,
      provider: principal.provider,
      uid: principal.subject,
    )

    assert_equal client, result[:user]
    assert_equal identity, result[:identity]
    assert_equal({ user_id: client.id }, result[:jwt_payload])
    assert_not result[:step_up_authenticated]
    assert result[:existing_account]
    assert_not result.key?(:pending_social_signup)
  end

  test "returns pending social signup when the identity is unknown" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "social-auth-handler-unknown",
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )
    repository = FakeRepository.new(identity: nil)

    result = SocialAuthLoginHandler.call(
      principal: principal,
      credential_candidate: nil,
      repository: repository,
      provider: principal.provider,
      uid: principal.subject,
    )

    assert result[:pending_social_signup]
    assert_nil result[:user]
    assert_nil result[:identity]
    assert_equal({}.freeze, result[:jwt_payload])
    assert_not result[:existing_account]
    assert_equal "google", result[:provider]
    assert_equal principal.subject, result[:uid]
  end

  test "returns pending social signup when the identity is not linked to a user" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "social-auth-handler-orphaned",
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )
    orphaned_identity = Struct.new(:user).new(nil)
    repository = FakeRepository.new(identity: orphaned_identity)

    result = SocialAuthLoginHandler.call(
      principal: principal,
      credential_candidate: nil,
      repository: repository,
      provider: principal.provider,
      uid: principal.subject,
    )

    assert result[:pending_social_signup]
    assert_nil result[:user]
    assert_nil result[:identity]
  end

  test "raises a conflict error when a race condition occurs" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "social-auth-handler-conflict",
      issuer: "https://accounts.google.com",
      audience: "google-test-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )
    repository = FakeRepository.new(
      identity: nil,
      raise_error: ActiveRecord::RecordNotUnique.new("duplicate key value"),
    )

    error =
      assert_raises(SocialAuth::ConflictError) do
        SocialAuthLoginHandler.call(
          principal: principal,
          credential_candidate: nil,
          repository: repository,
          provider: principal.provider,
          uid: principal.subject,
        )
      end

    assert_equal "errors.social_auth.identity_conflict", error.i18n_key
  end
end
