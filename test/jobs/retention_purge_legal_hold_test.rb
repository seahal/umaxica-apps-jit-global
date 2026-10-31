# frozen_string_literal: true

require "test_helper"

class RetentionPurgeLegalHoldTest < ActiveJob::TestCase
  self.fixture_table_names = []

  test "active hold blocks client purge and records occurrence" do
    client = create_client
    client.update_columns(
      withdrawal_started_at: 40.days.ago,
      deactivated_at: 39.days.ago,
      discard_at: 39.days.ago,
      purge_eligible_at: 1.day.ago,
    )
    ClientRetentionHold.create!(client: client, reason_code: "legal_hold")
    privacy_request = ClientPrivacyRequest.create!(client: client)

    RetentionPurgeJob.perform_now(batch_size: 10)

    assert_nil client.reload.terminated_at
    assert_equal ClientPrivacyRequest.status_id_for("BLOCKED_BY_LEGAL_HOLD"), privacy_request.reload.status_id
    assert_predicate ClientOccurrence.where(event_type: "withdrawal.purge_skipped_by_hold"), :exists?
    assert_predicate ClientOccurrence.where(event_type: "privacy_erasure.blocked_by_legal_hold"), :exists?
  end

  private

  def create_client
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
  end
end
