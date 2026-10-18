# typed: false
# frozen_string_literal: true

require "test_helper"

# Linking a social identity to an account is where two accounts can end up
# sharing one identity, so the handler records what it saw at each decision
# point. Those lines only exist at debug level; they must still be safe to
# build, and the conflicts they describe must still be refused.
class SocialAuthLinkHandlerDiagnosticsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @previous_level = Rails.logger.level
    Rails.logger.level = Logger::DEBUG
    @client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
  end

  teardown do
    Rails.logger.level = @previous_level
  end

  test "an account that already has this provider linked to a different uid is refused" do
    identity = ClientExternalIdentity.create!(
      client: @client, provider: "google", issuer: "https://accounts.google.com", subject: "uid-2",
      audience: "test-client", verification_authority: "google_oidc", verified_at: ClientExternalIdentity.database_now,
    )
    subject = SocialAuthLinkHandler.new(
      principal: ExternalAuthentication::VerifiedPrincipal.new(
        provider: "google", subject: "uid-1", issuer: "https://accounts.google.com",
        audience: "test-client", verified_at: Time.current, verification_authority: "google_oidc",
      ), credential_candidate: nil, current_client: @client,
      repository: ExternalAuthentication::ClientExternalIdentityRepositoryAdapter.new(provider: "google"),
      provider: "google", uid: "uid-1", ceremony_started_at: Time.current,
    )

    assert_raises(SocialAuth::ConflictError) { subject.call }
    assert_nil identity.reload.released_at
    assert_predicate identity, :active?
  end

  test "an identity that belongs to another account is refused" do
    foreign = Client.create!(status_id: ClientStatus::ACTIVE)
    identity = ClientExternalIdentity.create!(
      client: foreign, provider: "google", issuer: "https://accounts.google.com", subject: "uid-1",
      audience: "test-client", verification_authority: "google_oidc", verified_at: ClientExternalIdentity.database_now,
    )
    subject = SocialAuthLinkHandler.new(
      principal: ExternalAuthentication::VerifiedPrincipal.new(
        provider: "google", subject: "uid-1", issuer: "https://accounts.google.com",
        audience: "test-client", verified_at: Time.current, verification_authority: "google_oidc",
      ), credential_candidate: nil, current_client: @client,
      repository: ExternalAuthentication::ClientExternalIdentityRepositoryAdapter.new(provider: "google"),
      provider: "google", uid: "uid-1", ceremony_started_at: Time.current,
    )

    assert_raises(SocialAuth::ConflictError) { subject.call }
    assert_nil identity.reload.released_at
    assert_predicate identity, :active?
  end
end
