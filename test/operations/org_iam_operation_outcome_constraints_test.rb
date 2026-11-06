# frozen_string_literal: true

require "test_helper"

class OrgIamOperationOutcomeConstraintsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "database accepts only the minimal grant and revoke result shapes and nonempty owners" do
    base = {
      operation_kind: "grant",
      actor_public_id: "actor-ref",
      subject_public_id: "subject-ref",
      request_digest: "a" * 64,
      result: { grant_public_id: "grant-ref", expires_at: "2026-11-10T00:00:00Z" },
    }
    invalid = [
      { actor_public_id: "" },
      { subject_public_id: " " },
      { result: {} },
      { result: { grant_public_id: "grant-ref" } },
      { result: { grant_public_id: "", expires_at: "2026-11-10T00:00:00Z" } },
      { result: { grant_public_id: "grant-ref", expires_at: "" } },
      { result: { grant_public_id: "grant-ref", expires_at: "2026-11-10T00:00:00Z", extra: "no" } },
      { operation_kind: "revoke", result: { grant_public_id: "grant-ref", expires_at: "2026-11-10T00:00:00Z" } },
      { operation_kind: "revoke", result: { grant_public_id: 7 } },
      { request_digest: "not-a-digest" },
      { operation_kind: "unknown" },
    ]

    invalid.each do |change|
      assert_raises(ActiveRecord::StatementInvalid, change.inspect) do
        OrgZenithRecord.transaction(requires_new: true) do
          OrgIamOperationOutcome.insert_all!([base.merge(change).merge(operation_id: SecureRandom.uuid)])
        end
      end
    end

    grant_id = SecureRandom.uuid
    revoke_id = SecureRandom.uuid
    OrgIamOperationOutcome.insert_all!(
      [
        base.merge(operation_id: grant_id),
        base.merge(operation_id: revoke_id, operation_kind: "revoke", result: { grant_public_id: "grant-ref" }),
      ],
    )

    assert_equal 2, OrgIamOperationOutcome.where(operation_id: [grant_id, revoke_id]).count
  ensure
    OrgIamOperationOutcome.where(operation_id: [grant_id, revoke_id].compact).delete_all if defined?(grant_id)
  end
end
