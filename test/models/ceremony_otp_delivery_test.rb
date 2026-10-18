# frozen_string_literal: true

require "test_helper"

class CeremonyOtpDeliveryTest < ActiveSupport::TestCase
  [ClientEmailCeremonyTransaction, VisitorEmailCeremonyTransaction,
   OperatorEmailCeremonyTransaction,].each do |model|
    test "#{model.name} delivers only the current authentic email code before cancellation" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "browser", operation: "sign_up", email_candidate_ref: "candidate",
      )
      code = transaction.issue_email_otp!(purpose: "sign_up")
      generation = transaction.otp_generation
      encrypted_code = OutboundSensitivePayload.encrypt_email_otp(code)
      deliveries = 0

      assert_not encrypted_code.include?(code)
      assert transaction.deliver_email_otp!(
        generation: generation, code: OutboundSensitivePayload.decrypt_email_otp(encrypted_code),
      ) { deliveries += 1 }
      [nil, "", 0, false, "12345", "1234567", "12345\0", "\xFF"].each do |invalid|
        assert_not transaction.deliver_email_otp!(generation: generation, code: invalid) { deliveries += 1 }
      end
      wrong = (code == "000000") ? "000001" : "000000"

      assert_not transaction.deliver_email_otp!(generation: generation, code: wrong) { deliveries += 1 }
      replacement_code = transaction.issue_email_otp!(purpose: "sign_up")

      assert_not transaction.deliver_email_otp!(generation: generation, code: code) { deliveries += 1 }
      transaction.cancel_email_otp!

      assert_not transaction.deliver_email_otp!(generation: transaction.otp_generation, code: replacement_code) {
        deliveries += 1
      }
      assert_equal 1, deliveries
      assert_nil transaction.reload.otp_consumed_at
    end
  end

  [ClientEmailCeremonyTransaction, VisitorEmailCeremonyTransaction,
   OperatorEmailCeremonyTransaction,].each do |model|
    test "#{model.name} email delivery accepts deadline minus one microsecond and rejects deadline and plus one" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "browser", operation: "sign_up", email_candidate_ref: "candidate",
      )
      code = transaction.issue_email_otp!(purpose: "sign_up")
      generation = transaction.otp_generation
      deadline = transaction.otp_expires_at
      deliveries = 0

      assert_raises(ArgumentError) { transaction.deliver_email_otp!(generation: generation, code: code) }
      model.stub(:database_now, deadline - Rational(1, 1_000_000)) do
        assert transaction.deliver_email_otp!(generation: generation, code: code) { deliveries += 1 }
      end
      [deadline, deadline + Rational(1, 1_000_000)].each do |at|
        model.stub(:database_now, at) do
          assert_not transaction.deliver_email_otp!(generation: generation, code: code) { deliveries += 1 }
        end
      end

      assert_equal 1, deliveries
      assert_nil transaction.reload.otp_consumed_at
    end
  end

  [ClientTelephoneCeremonyTransaction, VisitorTelephoneCeremonyTransaction,
   OperatorTelephoneCeremonyTransaction,].each do |model|
    test "#{model.name} delivers only the current authentic telephone code before cancellation" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "browser", operation: "sign_up", telephone_candidate_ref: "candidate",
      )
      code = transaction.issue_telephone_otp!(purpose: "sign_up")
      generation = transaction.otp_generation
      deliveries = 0

      assert transaction.deliver_telephone_otp!(generation: generation, code: code) { deliveries += 1 }
      [nil, "", 0, false, "12345", "1234567", "12345\0", "\xFF"].each do |invalid|
        assert_not transaction.deliver_telephone_otp!(generation: generation, code: invalid) { deliveries += 1 }
      end
      wrong = (code == "000000") ? "000001" : "000000"

      assert_not transaction.deliver_telephone_otp!(generation: generation, code: wrong) { deliveries += 1 }
      replacement_code = transaction.issue_telephone_otp!(purpose: "sign_up")

      assert_not transaction.deliver_telephone_otp!(generation: generation, code: code) { deliveries += 1 }
      transaction.cancel_telephone_otp!

      assert_not transaction.deliver_telephone_otp!(generation: transaction.otp_generation, code: replacement_code) {
        deliveries += 1
      }
      assert_equal 1, deliveries
      assert_nil transaction.reload.otp_consumed_at
    end
  end

  [ClientTelephoneCeremonyTransaction, VisitorTelephoneCeremonyTransaction,
   OperatorTelephoneCeremonyTransaction,].each do |model|
    test "#{model.name} telephone delivery accepts deadline minus one microsecond and rejects deadline and plus one" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "browser", operation: "sign_up", telephone_candidate_ref: "candidate",
      )
      code = transaction.issue_telephone_otp!(purpose: "sign_up")
      generation = transaction.otp_generation
      deadline = transaction.otp_expires_at
      deliveries = 0

      assert_raises(ArgumentError) { transaction.deliver_telephone_otp!(generation: generation, code: code) }
      model.stub(:database_now, deadline - Rational(1, 1_000_000)) do
        assert transaction.deliver_telephone_otp!(generation: generation, code: code) { deliveries += 1 }
      end
      [deadline, deadline + Rational(1, 1_000_000)].each do |at|
        model.stub(:database_now, at) do
          assert_not transaction.deliver_telephone_otp!(generation: generation, code: code) { deliveries += 1 }
        end
      end

      assert_equal 1, deliveries
      assert_nil transaction.reload.otp_consumed_at
    end
  end
end
