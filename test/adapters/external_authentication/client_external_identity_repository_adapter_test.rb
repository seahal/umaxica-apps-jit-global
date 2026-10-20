# frozen_string_literal: true

require "test_helper"

class ClientExternalIdentityRepositoryAdapterTest < ActiveSupport::TestCase
  fixtures :client_statuses

  test "persists only Apple binding metadata" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: PublicId.generate)
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "apple",
      subject: "repository-apple-subject",
      issuer: "https://appleid.apple.com",
      audience: "apple-client-id",
      verified_at: Time.utc(2026, 7, 24, 12, 0, 0),
      verification_authority: "omniauth-apple/1.4.0",
    )
    repository = ExternalAuthentication::ClientExternalIdentityRepositoryAdapter.new(provider: "apple")

    identity = repository.build_for_user(
      user: client,
      principal: principal,
      credential_candidate: nil,
    )
    identity.save!

    assert_equal identity, repository.find_by_subject("repository-apple-subject", lock: false)
    assert_equal client, identity.user
    assert_equal "repository-apple-subject", identity.uid
    assert_nil repository.refresh_token_for(identity)
    assert_equal "omniauth-apple/1.4.0", identity.verification_authority
  end

  test "refreshes Apple verification metadata without a provider credential" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: PublicId.generate)
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "apple",
      subject: "repository-apple-refresh",
      issuer: "https://appleid.apple.com",
      audience: "apple-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-apple/1.4.0",
    )
    repository = ExternalAuthentication::ClientExternalIdentityRepositoryAdapter.new(provider: "apple")
    identity = repository.build_for_user(
      user: client,
      principal: principal,
      credential_candidate: nil,
    )
    identity.save!

    repository.refresh_credentials!(
      identity,
      principal: principal,
      credential_candidate: nil,
    )

    assert_nil repository.refresh_token_for(identity.reload)
    assert_predicate identity.last_authenticated_at, :present?
    assert_raises(ArgumentError) do
      repository.refresh_credentials!(identity, principal: principal, credential_candidate: Object.new)
    end
  end

  test "keeps Google without a durable provider credential" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: PublicId.generate)
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "repository-google-subject",
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/1.2.1",
    )
    repository = ExternalAuthentication::ClientExternalIdentityRepositoryAdapter.new(provider: "google")
    identity = repository.build_for_user(user: client, principal: principal, credential_candidate: nil)
    identity.save!

    assert_nil repository.refresh_token_for(identity)
  end
end
