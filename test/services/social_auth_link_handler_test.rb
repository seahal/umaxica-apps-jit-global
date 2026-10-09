# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthLinkHandlerTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!
    @principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google", subject: "subject-#{SecureRandom.hex(12)}", issuer: "https://accounts.google.com",
      audience: "google-test-client-id", verified_at: ClientExternalIdentity.database_now,
      verification_authority: "provider-fixture",
    )
    @repository = ExternalAuthentication::ClientExternalIdentityRepositoryAdapter.new(provider: "google")
  end

  test "rejects linking a second provider identity with a different subject" do
    identity = @repository.build_for_user(user: @client, principal: @principal, credential_candidate: nil)
    identity.save!
    replacement = @principal.with(subject: "replacement-#{SecureRandom.hex(8)}")

    error =
      assert_raises(SocialAuth::ConflictError) do
        SocialAuthLinkHandler.call(
          principal: replacement, credential_candidate: nil, current_client: @client,
          repository: @repository, provider: "google", uid: replacement.subject,
        )
      end

    assert_equal ["errors.social_auth.identity_conflict", :conflict], [error.i18n_key, error.status_code]
    assert_equal @principal.subject, identity.reload.subject
  end

  test "rejects a provider identity already linked to another client" do
    other = Client.create!
    identity = @repository.build_for_user(user: other, principal: @principal, credential_candidate: nil)
    identity.save!

    error =
      assert_raises(SocialAuth::ConflictError) do
        SocialAuthLinkHandler.call(
          principal: @principal, credential_candidate: nil, current_client: @client,
          repository: @repository, provider: "google", uid: @principal.subject,
        )
      end

    assert_equal ["errors.social_auth.linked_to_another_user", :conflict], [error.i18n_key, error.status_code]
    assert_equal other.id, identity.reload.client_id
    assert_empty @client.client_external_identities
  end

  test "turns a storage uniqueness race into the public conflict response without a partial binding" do
    connection = ClientExternalIdentity.connection
    error =
      assert_raises(SocialAuth::ConflictError) do
        # Inject the database write failure, while the production lookups and binding logic remain real.
        connection.stub(
          :insert, ->(*, **) {
                     raise ActiveRecord::RecordNotUnique, "identity uniqueness conflict"
                   },
        ) do
          SocialAuthLinkHandler.call(
            principal: @principal, credential_candidate: nil, current_client: @client,
            repository: @repository, provider: "google", uid: @principal.subject,
          )
        end
      end

    assert_equal ["errors.social_auth.identity_conflict", :conflict], [error.i18n_key, error.status_code]
    assert_equal 0, ClientExternalIdentity.where(client_id: @client.id).count
  end

  test "refreshes an active identity already linked to the current client" do
    identity = @repository.build_for_user(user: @client, principal: @principal, credential_candidate: nil)
    identity.save!
    original_verified_at = identity.verified_at
    refreshed = @principal.with(verified_at: original_verified_at + 1.second)
    result = SocialAuthLinkHandler.call(
      principal: refreshed, credential_candidate: nil, current_client: @client,
      repository: @repository, provider: "google", uid: refreshed.subject,
    )

    assert_equal @client, result.fetch(:user)
    assert_equal identity, result.fetch(:identity)
    assert_equal({ user_id: @client.id }, result.fetch(:jwt_payload))
    assert_equal refreshed.verified_at, identity.reload.verified_at
    assert_predicate identity.last_authenticated_at, :present?
    assert_equal 1, @client.client_external_identities.count
  end
end
