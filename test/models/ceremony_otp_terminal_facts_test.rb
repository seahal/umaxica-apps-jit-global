# frozen_string_literal: true

require "test_helper"

class CeremonyOtpTerminalFactsTest < ActiveSupport::TestCase
  test "consumed email proof cannot be revived or rebound through ordinary record updates" do
    transaction = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "actor", session_ref: "browser",
      operation: "registration", email_candidate_ref: "candidate",
    )
    code = transaction.issue_email_otp!(purpose: "sign_up")
    verifier = transaction.otp_verifier

    assert transaction.verify_email_otp!(
      code: code, purpose: "sign_up", actor_ref: "actor", session_ref: "browser",
      operation: "registration", candidate_ref: "candidate",
    )
    assert_raises(ActiveRecord::RecordInvalid) { transaction.update!(otp_consumed_at: nil, otp_verifier: verifier) }
    transaction.reload
    assert_raises(ActiveRecord::RecordInvalid) { transaction.update!(actor_ref: "other-actor") }
    transaction.reload

    assert_not transaction.verify_email_otp!(
      code: code, purpose: "sign_up", actor_ref: "actor", session_ref: "browser",
      operation: "registration", candidate_ref: "candidate",
    )
  end

  test "cancelled telephone proof cannot be revived through ordinary record updates" do
    transaction = OperatorTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "actor", session_ref: "browser",
      operation: "registration", telephone_candidate_ref: "candidate",
    )
    code = transaction.issue_telephone_otp!(purpose: "recovery")
    verifier = transaction.otp_verifier
    transaction.cancel_telephone_otp!

    assert_raises(ActiveRecord::RecordInvalid) { transaction.update!(otp_cancelled_at: nil, otp_verifier: verifier) }
    transaction.reload

    assert_not transaction.verify_telephone_otp!(
      code: code, purpose: "recovery", actor_ref: "actor", session_ref: "browser",
      operation: "registration", candidate_ref: "candidate",
    )
  end
end
