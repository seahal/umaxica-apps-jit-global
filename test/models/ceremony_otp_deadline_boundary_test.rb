# frozen_string_literal: true

require "test_helper"

class CeremonyOtpDeadlineBoundaryTest < ActiveSupport::TestCase
  [ClientEmailCeremonyTransaction, VisitorEmailCeremonyTransaction, OperatorEmailCeremonyTransaction].each do |model|
    test "#{model.name} delivery refuses OTP deadline and nearest representable later instant" do
      transaction = model.create_transaction!(
        actor_ref: "deadline-actor", session_ref: "deadline-browser",
        operation: "registration", email_candidate_ref: "deadline-candidate",
      )
      transaction.issue_email_otp!(purpose: "sign_up")
      transaction.reload
      deadline = transaction.otp_expires_at
      generation = transaction.otp_generation

      assert transaction.email_otp_deliverable?(generation: generation, at: deadline - 0.000001)
      assert_not transaction.email_otp_deliverable?(generation: generation, at: deadline)
      assert_not transaction.email_otp_deliverable?(generation: generation, at: deadline + 0.000001)
      [nil, "", 0, "not-a-generation", SecureRandom.uuid].each do |other_generation|
        assert_not transaction.email_otp_deliverable?(generation: other_generation, at: deadline - 1.second)
      end
    end

    test "#{model.name} delivery refuses parent deadline even when the OTP verifier remains present" do
      transaction = model.create_transaction!(
        actor_ref: "deadline-actor", session_ref: "deadline-browser",
        operation: "registration", email_candidate_ref: "deadline-candidate", expires_at: 1.minute.from_now,
      )
      transaction.issue_email_otp!(purpose: "sign_up")
      transaction.reload
      deadline = transaction.expires_at

      assert transaction.email_otp_deliverable?(generation: transaction.otp_generation, at: deadline - 0.000001)
      assert_not transaction.email_otp_deliverable?(generation: transaction.otp_generation, at: deadline)
      assert_not transaction.email_otp_deliverable?(generation: transaction.otp_generation, at: deadline + 0.000001)
    end
  end
  [ClientTelephoneCeremonyTransaction, VisitorTelephoneCeremonyTransaction,
   OperatorTelephoneCeremonyTransaction,].each do |model|
    test "#{model.name} delivery refuses OTP deadline and nearest representable later instant" do
      transaction = model.create_transaction!(
        actor_ref: "deadline-actor", session_ref: "deadline-browser",
        operation: "registration", telephone_candidate_ref: "deadline-candidate",
      )
      transaction.issue_telephone_otp!(purpose: "sign_up")
      transaction.reload
      deadline = transaction.otp_expires_at
      generation = transaction.otp_generation

      assert transaction.telephone_otp_deliverable?(generation: generation, at: deadline - 0.000001)
      assert_not transaction.telephone_otp_deliverable?(generation: generation, at: deadline)
      assert_not transaction.telephone_otp_deliverable?(generation: generation, at: deadline + 0.000001)
      [nil, "", 0, "not-a-generation", SecureRandom.uuid].each do |other_generation|
        assert_not transaction.telephone_otp_deliverable?(generation: other_generation, at: deadline - 1.second)
      end
    end

    test "#{model.name} delivery refuses parent deadline even when the OTP verifier remains present" do
      transaction = model.create_transaction!(
        actor_ref: "deadline-actor", session_ref: "deadline-browser",
        operation: "registration", telephone_candidate_ref: "deadline-candidate", expires_at: 1.minute.from_now,
      )
      transaction.issue_telephone_otp!(purpose: "sign_up")
      transaction.reload
      deadline = transaction.expires_at

      assert transaction.telephone_otp_deliverable?(generation: transaction.otp_generation, at: deadline - 0.000001)
      assert_not transaction.telephone_otp_deliverable?(generation: transaction.otp_generation, at: deadline)
      assert_not transaction.telephone_otp_deliverable?(generation: transaction.otp_generation, at: deadline + 0.000001)
    end
  end
end
