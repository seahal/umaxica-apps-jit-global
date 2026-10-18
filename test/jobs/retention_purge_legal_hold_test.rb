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

  test "active hold blocks visitor purge and records occurrence" do
    visitor = create_visitor
    visitor.update_columns(
      withdrawal_started_at: 40.days.ago,
      deactivated_at: 39.days.ago,
      discard_at: 39.days.ago,
      purge_eligible_at: 1.day.ago,
    )
    VisitorRetentionHold.create!(visitor: visitor, reason_code: "legal_hold")
    privacy_request = VisitorPrivacyRequest.create!(visitor: visitor)

    RetentionPurgeJob.perform_now(batch_size: 10)

    assert_nil visitor.reload.terminated_at
    assert_equal VisitorPrivacyRequest.status_id_for("BLOCKED_BY_LEGAL_HOLD"), privacy_request.reload.status_id
    assert_predicate VisitorOccurrence.where(event_type: "withdrawal.purge_skipped_by_hold"), :exists?
    assert_predicate VisitorOccurrence.where(event_type: "privacy_erasure.blocked_by_legal_hold"), :exists?
  end

  private

  def create_client
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
  end

  def create_visitor
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    Visitor.create!(
      status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
      mfa_level_id: VisitorMfaLevel::NOTHING,
      mfa_status_id: VisitorMfaStatus::UNCONFIGURED,
    )
  end
end
