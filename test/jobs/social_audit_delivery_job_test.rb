# frozen_string_literal: true

require "test_helper"

class SocialAuditDeliveryJobTest < ActiveJob::TestCase
  test "Chronicle failure leaves a committed Source intent for one later delivery" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
    )
    identity = ClientExternalIdentity.create!(
      client: client, provider: "google", issuer: "https://accounts.google.com",
      subject: SecureRandom.uuid, audience: "google-test-client-id",
      verification_authority: "provider-fixture", verified_at: ClientExternalIdentity.database_now,
    )
    event =
      AppPrincipalRecord.transaction do
        ClientSocialAuditOutbox.record!(identity: identity, owner: client, event_name: "linked")
      end

    ClientChronicle.stub(:create!, ->(*) { raise RuntimeError, "Chronicle unavailable" }) do
      assert_raises(RuntimeError) { SocialAuditDeliveryJob.perform_now }
    end
    assert_nil event.reload.acknowledged_at
    assert_nil ClientChronicle.find_by(event_uuid: event.event_uuid)

    assert_difference -> { ClientChronicle.where(event_uuid: event.event_uuid).count }, 1 do
      SocialAuditDeliveryJob.perform_now
    end
    SocialAuditDeliveryJob.perform_now

    assert_equal 1, ClientChronicle.where(event_uuid: event.event_uuid).count
    assert_not_nil event.reload.acknowledged_at
  end

  test "a conflicting Chronicle UUID does not acknowledge the Source event" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
    )
    identity = ClientExternalIdentity.create!(
      client: client, provider: "apple", issuer: "https://appleid.apple.com",
      subject: SecureRandom.uuid, audience: "apple-test-client-id",
      verification_authority: "provider-fixture", verified_at: ClientExternalIdentity.database_now,
    )
    event =
      AppPrincipalRecord.transaction do
        ClientSocialAuditOutbox.record!(identity: identity, owner: client, event_name: "linked")
      end
    ClientChronicle.create!(
      event_uuid: event.event_uuid, actor_type: "Client", actor_id: client.id,
      event_id: ClientChronicleEvent::SOCIAL_LINKED, level_id: ClientChronicleLevel::NOTHING,
      subject_id: client.id.to_s, subject_type: "Client", occurred_at: event.occurred_at,
      context: { "auth_method" => "social",
                 "provider" => "google",
                 "social_identity_type" => "ClientExternalIdentity", },
    )

    assert_raises(ArgumentError) { SocialAuditDeliveryJob.perform_now }
    assert_nil event.reload.acknowledged_at
  end

  test "Source acknowledgement failure after Chronicle creation retries without duplicating delivery" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
    )
    identity = ClientExternalIdentity.create!(
      client: client, provider: "google", issuer: "https://accounts.google.com",
      subject: SecureRandom.uuid, audience: "google-test-client-id",
      verification_authority: "provider-fixture", verified_at: ClientExternalIdentity.database_now,
    )
    event =
      AppPrincipalRecord.transaction do
        ClientSocialAuditOutbox.record!(identity: identity, owner: client, event_name: "linked")
      end

    ClientSocialAuditOutbox.stub(:database_now, -> { raise RuntimeError, "Source acknowledgement unavailable" }) do
      assert_raises(RuntimeError) { SocialAuditDeliveryJob.perform_now }
    end

    assert_nil event.reload.acknowledged_at
    assert_equal 1, ClientChronicle.where(event_uuid: event.event_uuid).count

    SocialAuditDeliveryJob.perform_now

    assert_not_nil event.reload.acknowledged_at
    assert_equal 1, ClientChronicle.where(event_uuid: event.event_uuid).count
  end

  test "batch bounds reject zero and 501 while one and 500 are accepted" do
    assert_raises(ArgumentError) { SocialAuditDeliveryJob.perform_now(batch_size: 0) }
    assert_nothing_raised { SocialAuditDeliveryJob.perform_now(batch_size: 1) }
    assert_nothing_raised { SocialAuditDeliveryJob.perform_now(batch_size: 500) }
    assert_raises(ArgumentError) { SocialAuditDeliveryJob.perform_now(batch_size: 501) }
    assert_raises(ArgumentError) { SocialAuditDeliveryJob.perform_now(batch_size: "1") }
  end
end
