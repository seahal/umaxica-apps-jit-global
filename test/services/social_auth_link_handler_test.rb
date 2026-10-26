# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthLinkHandlerTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
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
          ceremony_started_at: Time.current,
        )
      end

    assert_equal ["errors.social_auth.identity_conflict", :conflict], [error.i18n_key, error.status_code]
    assert_equal @principal.subject, identity.reload.subject
  end

  test "rejects a provider identity already linked to another client" do
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    identity = @repository.build_for_user(user: other, principal: @principal, credential_candidate: nil)
    identity.save!

    error =
      assert_raises(SocialAuth::ConflictError) do
        SocialAuthLinkHandler.call(
          principal: @principal, credential_candidate: nil, current_client: @client,
          repository: @repository, provider: "google", uid: @principal.subject,
          ceremony_started_at: Time.current,
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
            ceremony_started_at: Time.current,
          )
        end
      end

    assert_equal ["errors.social_auth.identity_conflict", :conflict], [error.i18n_key, error.status_code]
    assert_equal 0, ClientExternalIdentity.where(client_id: @client.id).count
  end

  test "Source audit failure rolls back a new social binding" do
    assert_no_difference -> { ClientExternalIdentity.where(client_id: @client.id).count } do
      assert_no_difference -> { ClientSocialAuditOutbox.where(owner_ref: @client.public_id).count } do
        ClientSocialAuditOutbox.stub(:create!, ->(*) { raise RuntimeError, "Source audit unavailable" }) do
          assert_raises(RuntimeError) do
            SocialAuthLinkHandler.call(
              principal: @principal, credential_candidate: nil, current_client: @client,
              repository: @repository, provider: "google", uid: @principal.subject,
              ceremony_started_at: Time.current,
            )
          end
        end
      end
    end
    assert_no_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::SOCIAL_LINKED).count } do
      result = SocialAuthLinkHandler.call(
        principal: @principal, credential_candidate: nil, current_client: @client,
        repository: @repository, provider: "google", uid: @principal.subject,
        ceremony_started_at: Time.current,
      )

      assert_equal @client, result.fetch(:user)
    end
    assert_equal 1, ClientSocialAuditOutbox.where(owner_ref: @client.public_id, event_name: "linked").count
  end

  test "refreshes an active identity already linked to the current client" do
    identity = @repository.build_for_user(user: @client, principal: @principal, credential_candidate: nil)
    identity.save!
    original_verified_at = identity.verified_at
    refreshed = @principal.with(verified_at: original_verified_at + 1.second)
    result = SocialAuthLinkHandler.call(
      principal: refreshed, credential_candidate: nil, current_client: @client,
      repository: @repository, provider: "google", uid: refreshed.subject,
      ceremony_started_at: Time.current,
    )

    assert_equal @client, result.fetch(:user)
    assert_equal identity, result.fetch(:identity)
    assert_equal({ user_id: @client.id }, result.fetch(:jwt_payload))
    assert_equal refreshed.verified_at, identity.reload.verified_at
    assert_predicate identity.last_authenticated_at, :present?
    assert_equal 1, @client.client_external_identities.count
  end

  test "banned Google and Apple subjects are refused before identity lookup or mutation" do
    %w(google apple).each do |provider|
      issuer = (provider == "google") ? "https://accounts.google.com" : "https://appleid.apple.com"
      principal = ExternalAuthentication::VerifiedPrincipal.new(
        provider:, issuer:, subject: "banned-link-#{SecureRandom.hex(12)}",
        audience: "#{provider}-test-client-id", verified_at: ClientExternalIdentity.database_now,
        verification_authority: "provider-fixture",
      )
      enforcement_case = AppEnforcementCase.create!(
        kind: "permanent_ban", duration_mode: "permanent", visibility: "visible", release_mode: "break_glass_only",
        effective_at: 1.minute.ago, reason_code: "abuse", principal_public_id: @client.public_id,
        applied_by_operator_public_id: operators(:one).public_id,
      )
      digest = EnforcementIdentifierDigest.for_social_subject(
        realm: "app", identifier_kind: "#{provider}_subject", issuer:, subject: principal.subject,
      )
      AppEnforcementIdentifierEffect.create!(
        **digest, enforcement_case:, effective_at: 1.minute.ago,
      )
      repository = ExternalAuthentication::ClientExternalIdentityRepositoryAdapter.new(provider:)

      assert_no_difference(["ClientExternalIdentity.count", "ClientSocialAuditOutbox.count", "ClientToken.count"]) do
        repository.stub(:find_for_user_for_link, ->(*) { flunk("a banned subject reached identity lookup") }) do
          error =
            assert_raises(SocialAuth::UnauthorizedError) do
              SocialAuthLinkHandler.call(
                principal:, credential_candidate: nil, current_client: @client, repository:,
                provider:, uid: principal.subject, ceremony_started_at: 1.minute.ago,
              )
            end
          assert_equal "errors.social_auth.unauthorized", error.i18n_key
        end
      end
    end
  end
end
