# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"

class ExternalAuthenticationUnlinkUseCaseTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ExternalIdentityTestHelper

  test "unlinks an identity with a Source audit intent delivered once to Chronicle" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: PublicId.generate)
    identity = create_active_external_identity(client: client, provider: "google", subject: "unlink-use-case-subject")
    client.client_emails.create!(
      address: "unlink-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!

    assert_no_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::SOCIAL_UNLINKED).count } do
      assert_difference -> { ClientSocialAuditOutbox.where(event_name: "unlinked").count }, 1 do
        result = ExternalAuthenticationUnlinkUseCase.call(provider: "google", user: client)

        assert_instance_of ExternalAuthentication::UnlinkResult, result
        assert_equal :unlinked, result.status
        assert_equal "google", result.provider
        assert_not ClientExternalIdentity.effective_binding.exists?(id: identity.id)
        assert_not_nil identity.reload.released_at
      end
    end
    event = ClientSocialAuditOutbox.find_by!(identity_ref: identity.id.to_s, event_name: "unlinked")

    assert_nil event.acknowledged_at

    assert_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::SOCIAL_UNLINKED).count }, 1 do
      SocialAuditDeliveryJob.perform_now
    end
    SocialAuditDeliveryJob.perform_now

    assert_equal 1, ClientChronicle.where(event_uuid: event.event_uuid).count
    assert_not_nil event.reload.acknowledged_at
  end

  test "Source outbox failure rolls back social unlink without a Chronicle event" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: PublicId.generate)
    identity = create_active_external_identity(client: client, provider: "google", subject: SecureRandom.uuid)
    client.client_emails.create!(
      address: "unlink-fault-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!

    assert_no_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::SOCIAL_UNLINKED).count } do
      assert_no_difference -> { ClientSocialAuditOutbox.where(event_name: "unlinked").count } do
        ClientSocialAuditOutbox.stub(:create!, ->(*) { raise RuntimeError, "Source outbox unavailable" }) do
          assert_raises(RuntimeError) do
            ExternalAuthenticationUnlinkUseCase.call(provider: "google", user: client)
          end
        end
      end
    end
    assert_nil identity.reload.released_at
    assert_predicate identity, :active?
  end

  test "does not remove the last active authentication method" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: PublicId.generate)
    identity = create_active_external_identity(client: client, provider: "google", subject: "unlink-last-subject")

    assert_raises(SocialAuth::LastIdentityError) do
      ExternalAuthenticationUnlinkUseCase.call(provider: "google", user: client)
    end

    assert ClientExternalIdentity.exists?(identity.id)
  end

  test "Apple unlink removes the binding without retaining a provider token" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: PublicId.generate)
    identity = create_active_external_identity(
      client: client, provider: "apple", subject: "apple-unlink-subject",
    )
    client.client_emails.create!(
      address: "apple-unlink-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!

    ExternalAuthenticationUnlinkUseCase.call(provider: "apple", user: client)

    assert_not ClientExternalIdentity.effective_binding.exists?(id: identity.id)
    assert_not_nil identity.reload.released_at
  end

  test "returns already unlinked when no provider identity exists" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: PublicId.generate)

    result = ExternalAuthenticationUnlinkUseCase.call(provider: "google", user: client)

    assert_instance_of ExternalAuthentication::UnlinkResult, result
    assert_equal :already_unlinked, result.status
    assert_equal "google", result.provider
  end

  test "repeating an unlink preserves one release and one Source audit intent" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: PublicId.generate)
    identity = create_active_external_identity(client: client, provider: "google", subject: SecureRandom.uuid)
    client.client_emails.create!(
      address: "unlink-retry-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!

    assert_equal :unlinked, ExternalAuthenticationUnlinkUseCase.call(provider: "google", user: client).status
    first_release = identity.reload.released_at

    assert_equal :already_unlinked, ExternalAuthenticationUnlinkUseCase.call(provider: "google", user: client).status

    assert_equal first_release, identity.reload.released_at
    assert_equal 1, ClientSocialAuditOutbox.where(identity_ref: identity.id.to_s, event_name: "unlinked").count
  end

  test "unlink expires unfinished matching evidence without fabricating a result or changing other providers" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: PublicId.generate)
    identity = create_active_external_identity(client: client, provider: "google", subject: SecureRandom.uuid)
    client.client_emails.create!(
      address: "unlink-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!
    digest = IdentitySocialCeremonyContract.provider_subject_digest(provider: "google", subject: identity.subject)
    transaction = ClientSocialCeremonyTransaction.create_transaction!(
      actor_ref: client.public_id, session_ref: SecureRandom.uuid, operation: "link", provider: "google",
      provider_subject_digest: digest,
    )
    pre_callback = ClientSocialCeremonyTransaction.create_transaction!(
      actor_ref: client.public_id, session_ref: SecureRandom.uuid, operation: "link", provider: "google",
    )
    unrelated = ClientSocialCeremonyTransaction.create_transaction!(
      actor_ref: client.public_id, session_ref: SecureRandom.uuid, operation: "link", provider: "apple",
    )
    candidate = IdentitySocialCeremonyCandidateStore.store!(
      surface: "app", actor_ref: client.public_id, session_ref: transaction.session_ref,
      transaction_id: transaction.transaction_id, operation: "link", provider: "google",
      expires_at: transaction.expires_at,
      callback_result: ExternalAuthentication::CallbackResult.verified(
        principal: ExternalAuthentication::VerifiedPrincipal.new(
          provider: "google", subject: identity.subject, issuer: identity.issuer, audience: identity.audience,
          verified_at: identity.verified_at, verification_authority: identity.verification_authority,
        ),
        credential_candidate: nil,
      ),
    )

    assert AuthMethodGuard.can_remove_external_identity?(client, identity)
    assert_equal :unlinked, ExternalAuthenticationUnlinkUseCase.call(provider: "google", user: client).status
    transaction.reload

    assert_predicate transaction, :valid?
    assert_predicate transaction, :expired?
    assert_predicate pre_callback.reload, :expired?
    assert_nil transaction.result_jti
    assert_nil transaction.consumed_at
    assert_not_predicate unrelated.reload, :expired?
    assert_raises(IdentitySocialCeremonyContract::Error) { IdentitySocialCeremonyCandidateStore.fetch!(candidate.ref) }
    assert_raises(IdentitySocialCeremonyContract::Error) do
      IdentitySocialCeremonyCandidateStore.consume!(candidate.ref)
    end
    assert_raises(IdentitySocialCeremonyContract::Error) do
      transaction.consume_result!(
        result_jti: SecureRandom.uuid, provider_subject_ref: identity.id.to_s, provider_subject_digest: digest,
      )
    end
    expired_at = transaction.expires_at
    transaction.expire!

    assert_equal expired_at, transaction.reload.expires_at
  end
end
