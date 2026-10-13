# frozen_string_literal: true

require "test_helper"

class CeremonyOwnedOtpTest < ActiveSupport::TestCase
  test "email proof is owned by its ceremony and rejects session actor purpose operation and candidate substitution" do
    transaction = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "actor-1", session_ref: "session-1", operation: "sign_up",
      email_candidate_ref: "candidate-1",
    )
    code = transaction.issue_email_otp!(purpose: "sign_up")

    assert_match(/\A[0-9]{6}\z/, code)
    assert_not_equal code, transaction.reload.otp_verifier
    assert_not transaction.verify_email_otp!(
      code: code, purpose: "sign_in", actor_ref: "actor-1",
      session_ref: "session-1", operation: "sign_up", candidate_ref: "candidate-1",
    )
    assert_not transaction.verify_email_otp!(
      code: code, purpose: "sign_up", actor_ref: "actor-2",
      session_ref: "session-1", operation: "registration", candidate_ref: "candidate-1",
    )
    assert_not transaction.verify_email_otp!(
      code: code, purpose: "sign_up", actor_ref: "actor-1",
      session_ref: "session-2", operation: "sign_up", candidate_ref: "candidate-1",
    )
    assert_not transaction.verify_email_otp!(
      code: code, purpose: "sign_up", actor_ref: "actor-1",
      session_ref: "session-1", operation: "replacement", candidate_ref: "candidate-1",
    )
    assert_not transaction.verify_email_otp!(
      code: code, purpose: "sign_up", actor_ref: "actor-1",
      session_ref: "session-1", operation: "sign_up", candidate_ref: "candidate-2",
    )
    assert transaction.verify_email_otp!(
      code: code, purpose: "sign_up", actor_ref: "actor-1",
      session_ref: "session-1", operation: "sign_up", candidate_ref: "candidate-1",
    )
    assert_not transaction.verify_email_otp!(
      code: code, purpose: "sign_up", actor_ref: "actor-1",
      session_ref: "session-1", operation: "sign_up", candidate_ref: "candidate-1",
    )
    assert transaction.reload.otp_consumed_at
  end

  test "telephone keyed proof rejects copying to another flow and becomes unavailable after cancellation" do
    first = OperatorTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "operator-1", session_ref: "browser-1",
      operation: "registration", telephone_candidate_ref: "telephone-1",
    )
    second = OperatorTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "operator-1", session_ref: "browser-1",
      operation: "registration", telephone_candidate_ref: "telephone-1",
    )
    code = first.issue_telephone_otp!(purpose: "credential_registration")
    second.issue_telephone_otp!(purpose: "credential_registration")
    second.update!(otp_verifier: first.otp_verifier)

    assert_not second.verify_telephone_otp!(
      code: code, purpose: "credential_registration", actor_ref: "operator-1",
      session_ref: "browser-1", operation: "registration", candidate_ref: "telephone-1",
    )
    first.cancel_telephone_otp!

    assert_not first.verify_telephone_otp!(
      code: code, purpose: "credential_registration", actor_ref: "operator-1",
      session_ref: "browser-1", operation: "registration", candidate_ref: "telephone-1",
    )
    assert first.reload.otp_cancelled_at
  end
end
