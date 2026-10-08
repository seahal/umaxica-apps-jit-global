# frozen_string_literal: true

require "test_helper"

class CeremonyOtpDestinationBindingTest < ActiveSupport::TestCase
  [ClientEmailCeremonyTransaction, VisitorEmailCeremonyTransaction,
   OperatorEmailCeremonyTransaction,].each do |model|
    test "#{model.name} email proof cannot authenticate a replaced destination digest" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "browser", operation: "registration",
        email_candidate_ref: "candidate", normalized_email_digest: SecureRandom.hex(32),
      )
      code = transaction.issue_email_otp!(purpose: "sign_up")
      generation = transaction.otp_generation
      transaction.update!(normalized_email_digest: SecureRandom.hex(32))

      delivered = false

      assert_not transaction.deliver_email_otp!(generation: generation, code: code) { delivered = true }
      assert_not delivered

      assert_not transaction.verify_email_otp!(
        code: code, purpose: "sign_up", actor_ref: "actor", session_ref: "browser",
        operation: "registration", candidate_ref: "candidate",
      )
      assert_nil transaction.reload.otp_consumed_at
    end
  end

  [ClientTelephoneCeremonyTransaction, VisitorTelephoneCeremonyTransaction,
   OperatorTelephoneCeremonyTransaction,].each do |model|
    test "#{model.name} telephone proof cannot authenticate a replaced destination digest" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "browser", operation: "registration",
        telephone_candidate_ref: "candidate", normalized_number_digest: SecureRandom.hex(32),
      )
      code = transaction.issue_telephone_otp!(purpose: "sign_up")
      generation = transaction.otp_generation
      transaction.update!(normalized_number_digest: SecureRandom.hex(32))

      delivered = false

      assert_not transaction.deliver_telephone_otp!(generation: generation, code: code) { delivered = true }
      assert_not delivered

      assert_not transaction.verify_telephone_otp!(
        code: code, purpose: "sign_up", actor_ref: "actor", session_ref: "browser",
        operation: "registration", candidate_ref: "candidate",
      )
      assert_nil transaction.reload.otp_consumed_at
    end
  end
end
