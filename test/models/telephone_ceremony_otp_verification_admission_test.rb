# frozen_string_literal: true

require "test_helper"

class TelephoneCeremonyOtpVerificationAdmissionTest < ActiveSupport::TestCase
  [ClientTelephoneCeremonyTransaction, VisitorTelephoneCeremonyTransaction,
   OperatorTelephoneCeremonyTransaction,].each do |model|
    test "#{model.name} proof delivery consumption and receipt retain binding across runtime time zones" do
      transaction = nil
      code = nil
      Time.use_zone("Asia/Tokyo") do
        transaction = model.create_transaction!(
          actor_ref: "actor", session_ref: "browser", operation: "sign_up",
          telephone_candidate_ref: "candidate", normalized_number_digest: SecureRandom.hex(32),
        )
        code = transaction.issue_telephone_otp!(purpose: "sign_up")
      end
      Time.use_zone("UTC") do
        transported = false

        assert transaction.deliver_telephone_otp!(generation: transaction.otp_generation, code: code) {
          transported = true
        }
        assert transported
        assert transaction.verify_telephone_otp!(
          code: code, purpose: "sign_up", actor_ref: "actor", session_ref: "browser",
          operation: "sign_up", candidate_ref: "candidate",
        )
      end
      Time.use_zone("Asia/Tokyo") do
        assert transaction.telephone_otp_verified_evidence?(
          code: code, purpose: "sign_up", actor_ref: "actor", session_ref: "browser",
          operation: "sign_up", candidate_ref: "candidate",
        )
      end
    end

    test "#{model.name} admission wait checks the OTP deadline minus at and plus one microsecond" do
      [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
        transaction = model.create_transaction!(
          actor_ref: "actor", session_ref: "browser", operation: "recovery",
          telephone_candidate_ref: "candidate", normalized_number_digest: SecureRandom.hex(32),
        )
        code = transaction.issue_telephone_otp!(purpose: "recovery")
        decision_time = transaction.otp_expires_at - 1.second
        model.stub(:database_now, -> { decision_time }) do
          result =
            transaction.verify_telephone_otp!(
              code: code, purpose: "recovery", actor_ref: "actor", session_ref: "browser",
              operation: "recovery", candidate_ref: "candidate",
            ) do |_valid|
              decision_time = transaction.otp_expires_at + offset
              true
            end

          assert_equal offset.negative?, result
        end

        transaction.reload
        if offset.negative?
          assert transaction.otp_consumed_at
          assert_nil transaction.otp_verifier
        else
          assert_nil transaction.otp_consumed_at
          assert transaction.otp_verifier
        end
      end
    end

    test "#{model.name} shared failure admission runs before consumption and only after binding checks" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "browser", operation: "recovery",
        telephone_candidate_ref: "candidate", normalized_number_digest: SecureRandom.hex(32),
      )
      code = transaction.issue_telephone_otp!(purpose: "recovery")
      scope = { purpose: "recovery",
                actor_ref: "actor",
                session_ref: "browser",
                operation: "recovery",
                candidate_ref: "candidate", }
      comparisons = []

      assert_not transaction.verify_telephone_otp!(code: code, **scope) { |valid| comparisons << valid; false }
      assert_equal [true], comparisons
      assert_nil transaction.reload.otp_consumed_at
      assert transaction.otp_verifier
      wrong = (code == "000000") ? "000001" : "000000"

      assert_not transaction.verify_telephone_otp!(code: wrong, **scope) { |valid| comparisons << valid; true }
      assert_equal [true, false], comparisons
      foreign =
        transaction.verify_telephone_otp!(code: code, **scope.merge(session_ref: "foreign")) do |valid|
          comparisons << valid
          true
        end

      assert_not foreign
      assert_equal [true, false], comparisons
      assert transaction.verify_telephone_otp!(code: code, **scope) { |valid| comparisons << valid; true }
      assert_equal [true, false, true], comparisons
      assert transaction.reload.otp_consumed_at
      assert_not transaction.verify_telephone_otp!(code: code, **scope) { |valid| comparisons << valid; true }
      assert_equal [true, false, true], comparisons
    end
  end
end
