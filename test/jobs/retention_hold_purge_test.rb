# typed: false
# frozen_string_literal: true

require "test_helper"

class RetentionHoldPurgeTest < ActiveJob::TestCase
  self.fixture_table_names = []

  test "an active client hold preserves the actor and records the blocked request" do
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    client = Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
    client.update_columns(
      withdrawal_started_at: 40.days.ago,
      deactivated_at: 39.days.ago,
      discard_at: 39.days.ago,
      purge_eligible_at: 1.day.ago,
    )
    ClientRetentionHold.create!(client: client, reason_code: "legal_hold")
    request = ClientPrivacyRequest.create!(client: client)

    RetentionPurgeJob.perform_now(batch_size: 1)

    client.reload
    request.reload

    assert_nil client.terminated_at
    assert_equal ClientPrivacyRequest.status_id_for("BLOCKED_BY_LEGAL_HOLD"), request.status_id
    assert_predicate ClientOccurrence.where(event_type: "withdrawal.purge_skipped_by_hold"), :exists?
    assert_predicate ClientOccurrence.where(event_type: "privacy_erasure.blocked_by_legal_hold"), :exists?
  end

  test "a released client hold no longer blocks an otherwise eligible purge" do
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    client = Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
    client.update_columns(
      withdrawal_started_at: 40.days.ago,
      deactivated_at: 39.days.ago,
      discard_at: 39.days.ago,
      purge_eligible_at: 1.day.ago,
    )
    hold = ClientRetentionHold.create!(client: client, reason_code: "legal_hold")
    hold.update!(status_id: ClientRetentionHoldStatus::RELEASED, released_at: 1.hour.ago)

    RetentionPurgeJob.perform_now(batch_size: 1)

    assert_predicate client.reload, :terminated?
  end
end
