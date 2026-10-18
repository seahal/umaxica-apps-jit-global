# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthCeremonySessionTest < ActiveSupport::TestCase
  CASES = [
    ClientAuthCeremonySession,
    VisitorAuthCeremonySession,
    OperatorAuthCeremonySession,
  ].freeze

  CASES.each do |model|
    test "#{model.name} issues digest-only sid and rotates without authority fields" do
      record, raw_sid = model.issue!

      assert_predicate record, :persisted?
      assert_equal 64, record.sid_digest.length
      assert_not_equal raw_sid, record.sid_digest
      assert_predicate record, :active?
      assert record.asserts_no_authority_api!

      found = model.find_active_by_raw_sid(raw_sid)

      assert_equal record.id, found.id

      rotated = record.rotate!

      assert_nil model.find_active_by_raw_sid(raw_sid)
      assert_equal record.id, model.find_active_by_raw_sid(rotated).id

      record.revoke!

      assert_not record.reload.active?
      assert_nil model.find_active_by_raw_sid(rotated)
    end

    test "#{model.name} default lifecycle timestamps use the writer database clock" do
      database_now = Time.utc(2026, 9, 21, 12, 34, 56)
      record = nil

      model.stub(:database_now, database_now) do
        record, = model.issue!
        record.admit!(admission_purpose: "authentication_handoff", authorization_transaction_ref: "clock-#{model.name}")
        record.complete!
      end

      record.reload

      assert_equal database_now, record.created_at
      assert_equal database_now + model::DEFAULT_TTL, record.expires_at
      assert_equal database_now, record.admitted_at
      assert_equal database_now, record.completed_at
      assert_equal database_now, record.updated_at
    end

    test "#{model.name} admits one authorization transaction and has irreversible terminal states" do
      record, = model.issue!

      record.admit!(
        admission_purpose: "authentication_handoff",
        authorization_transaction_ref: "transaction-#{model.name}",
      )

      assert_predicate record.reload, :admitted?
      assert_equal "transaction-#{model.name}", record.authorization_transaction_ref
      assert_not_predicate record, :terminal?

      record.complete!

      assert_predicate record.reload, :completed?
      assert_predicate record, :terminal?
      assert_not_predicate record, :active?
      assert_raises(AuthCeremonySession::InvalidTransition) { record.complete! }
      assert_raises(AuthCeremonySession::InvalidTransition) { record.cancel! }
      assert_raises(AuthCeremonySession::InvalidTransition) { record.rotate! }
    end

    test "#{model.name} does not allow a second admission binding" do
      record, = model.issue!
      record.admit!(
        admission_purpose: "authentication_handoff",
        authorization_transaction_ref: "transaction-#{model.name}",
      )

      assert_raises(AuthCeremonySession::InvalidTransition) do
        record.admit!(admission_purpose: "authentication_handoff", authorization_transaction_ref: "another-transaction")
      end

      assert_equal "transaction-#{model.name}", record.reload.authorization_transaction_ref
    end

    test "#{model.name} records one-time authentication evidence without granting authority" do
      database_now = Time.utc(2026, 9, 21, 13, 14, 15)
      record, = model.issue!(now: database_now)
      record.admit!(
        admission_purpose: "authentication_handoff",
        authorization_transaction_ref: "evidence-#{model.name}", now: database_now,
      )

      record.class.stub(:database_now, database_now) do
        record.record_authentication_evidence!(method: "secret")
      end

      record.reload

      assert_equal "secret", record.authentication_method
      assert_equal database_now, record.authentication_event_at
      assert_predicate record, :authentication_evidence_recorded?
      assert record.asserts_no_authority_api!

      assert_raises(AuthCeremonySession::InvalidTransition) do
        record.record_authentication_evidence!(method: "passkey", now: database_now)
      end
      assert_equal "secret", record.reload.authentication_method
    end

    test "#{model.name} cannot bind the same authorization transaction twice" do
      first, = model.issue!
      second, = model.issue!
      ref = "shared-transaction-#{model.name}"

      first.admit!(admission_purpose: "authentication_handoff", authorization_transaction_ref: ref)

      assert_raises(ActiveRecord::RecordNotUnique) do
        second.admit!(admission_purpose: "authentication_handoff", authorization_transaction_ref: ref)
      end
    end

    test "#{model.name} atomically replaces the previous admitted session" do
      previous, previous_sid = model.issue!
      previous.admit!(
        admission_purpose: "authentication_handoff",
        authorization_transaction_ref: "previous-#{model.name}",
      )

      replacement, replacement_sid = model.rotate_and_admit!(
        admission_purpose: "authentication_handoff",
        previous_raw_sid: previous_sid,
        authorization_transaction_ref: "replacement-#{model.name}",
      )

      assert_predicate previous.reload, :terminal?
      assert_not_predicate previous, :active?
      assert_predicate replacement, :admitted?
      assert_predicate replacement, :active?
      assert_equal previous.sid_digest, replacement.previous_sid_digest
      assert_nil model.find_active_by_raw_sid(previous_sid)
      assert_equal replacement.id, model.find_active_by_raw_sid(replacement_sid).id
    end

    test "#{model.name} rejects a second replacement from the same previous session" do
      previous, previous_sid = model.issue!
      previous.admit!(
        admission_purpose: "authentication_handoff",
        authorization_transaction_ref: "previous-#{model.name}",
      )
      model.rotate_and_admit!(
        admission_purpose: "authentication_handoff",
        previous_raw_sid: previous_sid,
        authorization_transaction_ref: "replacement-#{model.name}",
      )

      assert_raises(AuthCeremonySession::InvalidTransition) do
        model.rotate_and_admit!(
          admission_purpose: "authentication_handoff",
          previous_raw_sid: previous_sid,
          authorization_transaction_ref: "racing-replacement-#{model.name}",
        )
      end

      assert_equal 1, model.where(previous_sid_digest: previous.sid_digest).count
      assert_equal 1, model.where(
        previous_sid_digest: previous.sid_digest,
        revoked_at: nil,
        completed_at: nil,
        cancelled_at: nil,
      ).count
    end

    test "#{model.name} keeps the previous session when replacement admission conflicts" do
      previous, previous_sid = model.issue!
      transaction_ref = "conflicting-#{model.name}"
      previous.admit!(admission_purpose: "authentication_handoff", authorization_transaction_ref: transaction_ref)

      assert_raises(ActiveRecord::RecordNotUnique) do
        model.rotate_and_admit!(
          admission_purpose: "authentication_handoff",
          previous_raw_sid: previous_sid,
          authorization_transaction_ref: transaction_ref,
        )
      end

      assert_predicate previous.reload, :admitted?
      assert_predicate previous, :active?
      assert_equal previous.id, model.find_active_by_raw_sid(previous_sid).id
      assert_equal 1, model.where(authorization_transaction_ref: transaction_ref).count
    end

    test "#{model.name} database constraints keep terminal state and admission binding coherent" do
      record, = model.issue!

      assert_raises(ActiveRecord::StatementInvalid) do
        model.transaction(requires_new: true) do
          record.update_columns(completed_at: Time.current, cancelled_at: Time.current)
        end
      end

      assert_raises(ActiveRecord::StatementInvalid) do
        model.transaction(requires_new: true) do
          record.update_columns(authorization_transaction_ref: "unadmitted-#{model.name}")
        end
      end
    end

    test "#{model.name} cancellation is terminal and cannot be followed by completion" do
      record, = model.issue!
      record.admit!(admission_purpose: "authentication_handoff")

      record.cancel!

      assert_predicate record.reload, :cancelled?
      assert_raises(AuthCeremonySession::InvalidTransition) { record.complete! }
      assert_raises(AuthCeremonySession::InvalidTransition) { record.revoke! }
    end
  end
end
