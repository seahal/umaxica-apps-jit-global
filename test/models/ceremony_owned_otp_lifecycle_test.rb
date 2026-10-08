# frozen_string_literal: true

require "test_helper"

class CeremonyOwnedOtpLifecycleTest < ActiveSupport::TestCase
  [ClientEmailCeremonyTransaction, VisitorEmailCeremonyTransaction, OperatorEmailCeremonyTransaction].each do |model|
    test "#{model.name} accepts a random code exactly once and rejects malformed input" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "browser",
        operation: "registration", email_candidate_ref: "candidate",
      )
      code = transaction.issue_email_otp!(purpose: "sign_up")

      [nil, "", " ", "12345", "1234567", "12345\0", "\xFF", 0, false].each do |input|
        assert_not transaction.verify_email_otp!(
          code: input, purpose: "sign_up", actor_ref: "actor",
          session_ref: "browser", operation: "registration", candidate_ref: "candidate",
        )
      end
      assert transaction.verify_email_otp!(
        code: code, purpose: "sign_up", actor_ref: "actor",
        session_ref: "browser", operation: "registration", candidate_ref: "candidate",
      )
      assert_not transaction.verify_email_otp!(
        code: code, purpose: "sign_up", actor_ref: "actor",
        session_ref: "browser", operation: "registration", candidate_ref: "candidate",
      )
      assert_nil transaction.reload.otp_verifier
      assert_raises(ArgumentError) { transaction.issue_email_otp!(purpose: "sign_up") }
    end

    test "#{model.name} expired parent transaction cannot verify or issue" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "browser",
        operation: "registration", email_candidate_ref: "candidate",
      )
      code = transaction.issue_email_otp!(purpose: "withdrawal")
      deadline = transaction.reload.otp_expires_at

      # PostgreSQL database_now owns the decision clock; travel_to cannot replace that clock.
      # Move the whole transaction expiry into the past through its public persisted lifetime.
      transaction.update!(expires_at: transaction.class.database_now - 1.second)

      assert_not transaction.verify_email_otp!(
        code: code, purpose: "withdrawal", actor_ref: "actor",
        session_ref: "browser", operation: "registration", candidate_ref: "candidate",
      )
      assert_nil transaction.reload.otp_consumed_at
      assert_operator deadline, :>, transaction.class.database_now
      assert_raises(ArgumentError) { transaction.issue_email_otp!(purpose: "withdrawal") }
    end

    test "#{model.name} cancel removes verifier and cannot be reopened by resend" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "browser",
        operation: "registration", email_candidate_ref: "candidate",
      )
      code = transaction.issue_email_otp!(purpose: "recovery")

      assert transaction.cancel_email_otp!
      assert_not transaction.cancel_email_otp!
      assert_nil transaction.reload.otp_verifier
      assert_not transaction.verify_email_otp!(
        code: code, purpose: "recovery", actor_ref: "actor",
        session_ref: "browser", operation: "registration", candidate_ref: "candidate",
      )
      assert_raises(ArgumentError) { transaction.issue_email_otp!(purpose: "recovery") }
    end
  end
  [ClientTelephoneCeremonyTransaction, VisitorTelephoneCeremonyTransaction,
   OperatorTelephoneCeremonyTransaction,].each do |model|
    test "#{model.name} accepts a random code exactly once and rejects malformed input" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "browser",
        operation: "registration", telephone_candidate_ref: "candidate",
      )
      code = transaction.issue_telephone_otp!(purpose: "sign_up")

      [nil, "", " ", "12345", "1234567", "12345\0", "\xFF", 0, false].each do |input|
        assert_not transaction.verify_telephone_otp!(
          code: input, purpose: "sign_up", actor_ref: "actor",
          session_ref: "browser", operation: "registration", candidate_ref: "candidate",
        )
      end
      assert transaction.verify_telephone_otp!(
        code: code, purpose: "sign_up", actor_ref: "actor",
        session_ref: "browser", operation: "registration", candidate_ref: "candidate",
      )
      assert_not transaction.verify_telephone_otp!(
        code: code, purpose: "sign_up", actor_ref: "actor",
        session_ref: "browser", operation: "registration", candidate_ref: "candidate",
      )
      assert_nil transaction.reload.otp_verifier
      assert_raises(ArgumentError) { transaction.issue_telephone_otp!(purpose: "sign_up") }
    end

    test "#{model.name} expired parent transaction cannot verify or issue" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "browser",
        operation: "registration", telephone_candidate_ref: "candidate",
      )
      code = transaction.issue_telephone_otp!(purpose: "withdrawal")
      deadline = transaction.reload.otp_expires_at

      # PostgreSQL database_now owns the decision clock; travel_to cannot replace that clock.
      # Move the whole transaction expiry into the past through its public persisted lifetime.
      transaction.update!(expires_at: transaction.class.database_now - 1.second)

      assert_not transaction.verify_telephone_otp!(
        code: code, purpose: "withdrawal", actor_ref: "actor",
        session_ref: "browser", operation: "registration", candidate_ref: "candidate",
      )
      assert_nil transaction.reload.otp_consumed_at
      assert_operator deadline, :>, transaction.class.database_now
      assert_raises(ArgumentError) { transaction.issue_telephone_otp!(purpose: "withdrawal") }
    end

    test "#{model.name} cancel removes verifier and cannot be reopened by resend" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "browser",
        operation: "registration", telephone_candidate_ref: "candidate",
      )
      code = transaction.issue_telephone_otp!(purpose: "recovery")

      assert transaction.cancel_telephone_otp!
      assert_not transaction.cancel_telephone_otp!
      assert_nil transaction.reload.otp_verifier
      assert_not transaction.verify_telephone_otp!(
        code: code, purpose: "recovery", actor_ref: "actor",
        session_ref: "browser", operation: "registration", candidate_ref: "candidate",
      )
      assert_raises(ArgumentError) { transaction.issue_telephone_otp!(purpose: "recovery") }
    end
  end
end
