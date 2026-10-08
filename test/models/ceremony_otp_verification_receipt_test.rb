# frozen_string_literal: true

require "test_helper"

class CeremonyOtpVerificationReceiptTest < ActiveSupport::TestCase
  [
    [ClientEmailCeremonyTransaction, "email"],
    [VisitorEmailCeremonyTransaction, "email"],
    [OperatorEmailCeremonyTransaction, "email"],
    [ClientTelephoneCeremonyTransaction, "telephone"],
    [VisitorTelephoneCeremonyTransaction, "telephone"],
    [OperatorTelephoneCeremonyTransaction, "telephone"],
  ].each do |model, channel|
    test "#{model.name} receipt never outlives its parent at sixty second lifetime neighbors" do
      now = model.database_now
      [60.seconds - Rational(1, 1_000_000), 60.seconds, 60.seconds + Rational(1, 1_000_000)].each do |lifetime|
        transaction =
          if channel == "email"
            model.create_transaction!(
              actor_ref: "bounded-owner", session_ref: "bounded-browser", operation: "sign_up",
              email_candidate_ref: "bounded-candidate", normalized_email_digest: "b" * 64,
              expires_at: now + lifetime,
            )
          else
            model.create_transaction!(
              actor_ref: "bounded-owner", session_ref: "bounded-browser", operation: "sign_up",
              telephone_candidate_ref: "bounded-candidate", normalized_number_digest: "b" * 64,
              expires_at: now + lifetime,
            )
          end
        binding = {
          purpose: "sign_up",
          actor_ref: "bounded-owner",
          session_ref: "bounded-browser",
          operation: "sign_up",
          candidate_ref: "bounded-candidate",
        }
        code =
          model.stub(:database_now, now) do
            if channel == "email"
              transaction.issue_email_otp!(purpose: "sign_up")
            else
              transaction.issue_telephone_otp!(purpose: "sign_up")
            end
          end
        verified =
          model.stub(:database_now, now) do
            if channel == "email"
              transaction.verify_email_otp!(code: code, **binding)
            else
              transaction.verify_telephone_otp!(code: code, **binding)
            end
          end

        assert verified
        assert_equal [now + 60.seconds, transaction.expires_at].min, transaction.reload.otp_result_expires_at

        transaction.consume_result!(result_jti: SecureRandom.uuid, consumed_at: now)
        evidence =
          model.stub(:database_now, now + 1.second) do
            if channel == "email"
              transaction.email_otp_verified_evidence?(code: code, **binding)
            else
              transaction.telephone_otp_verified_evidence?(code: code, **binding)
            end
          end

        assert_not evidence, "Consumption of the original transaction closes retained evidence"
      end
    end

    test "#{model.name} single consumption retains only bound keyed evidence for fixed sixty seconds" do
      now = model.database_now
      transaction =
        if channel == "email"
          model.create_transaction!(
            actor_ref: "receipt-owner", session_ref: "receipt-browser", operation: "credential_registration",
            email_candidate_ref: "receipt-candidate", normalized_email_digest: "a" * 64,
            expires_at: now + 10.minutes,
          )
        else
          model.create_transaction!(
            actor_ref: "receipt-owner", session_ref: "receipt-browser", operation: "credential_registration",
            telephone_candidate_ref: "receipt-candidate", normalized_number_digest: "a" * 64,
            expires_at: now + 10.minutes,
          )
        end
      binding = {
        purpose: "credential_registration",
        actor_ref: "receipt-owner",
        session_ref: "receipt-browser",
        operation: "credential_registration",
        candidate_ref: "receipt-candidate",
      }
      code =
        if channel == "email"
          transaction.issue_email_otp!(purpose: "credential_registration")
        else
          transaction.issue_telephone_otp!(purpose: "credential_registration")
        end
      original_verifier = transaction.reload.otp_verifier
      incompatible_code = "123456".encode(Encoding::UTF_16LE)
      transported = false
      malformed_verified =
        if channel == "email"
          transaction.verify_email_otp!(code: incompatible_code, **binding)
        else
          transaction.verify_telephone_otp!(code: incompatible_code, **binding)
        end
      malformed_delivered =
        if channel == "email"
          transaction.deliver_email_otp!(generation: transaction.otp_generation, code: incompatible_code) do
            transported = true
          end
        else
          transaction.deliver_telephone_otp!(generation: transaction.otp_generation, code: incompatible_code) do
            transported = true
          end
        end

      assert_not malformed_verified
      assert_not malformed_delivered
      assert_not transported
      unchanged_verifier = transaction.reload.otp_verifier == original_verifier

      assert unchanged_verifier, "Malformed input must leave proof unchanged without exposing the verifier"
      consumed =
        if channel == "email"
          transaction.verify_email_otp!(code: code, **binding)
        else
          transaction.verify_telephone_otp!(code: code, **binding)
        end

      assert consumed
      transaction.reload

      assert_nil transaction.otp_verifier
      separated_verifier = transaction.otp_receipt_verifier != original_verifier &&
        transaction.otp_receipt_verifier != code

      assert separated_verifier, "The receipt is a domain-separated keyed proof, not the challenge verifier or raw code"
      assert_equal transaction.otp_consumed_at + 60.seconds, transaction.otp_result_expires_at
      binding.each_key do |key|
        foreign_binding = binding.merge(key => "foreign-receipt-binding")
        foreign =
          if channel == "email"
            transaction.email_otp_verified_evidence?(code: code, **foreign_binding)
          else
            transaction.telephone_otp_verified_evidence?(code: code, **foreign_binding)
          end

        assert_not foreign, "Retained proof must refuse a different #{key}"
      end
      wrong_code = (code == "000000") ? "000001" : "000000"
      [wrong_code, nil, 0, false, "", "12345", "1234567", "123\0" + "45", "\xFF",
       "123456".encode(Encoding::UTF_16LE),].each do |submitted|
        wrong =
          if channel == "email"
            transaction.email_otp_verified_evidence?(code: submitted, **binding)
          else
            transaction.telephone_otp_verified_evidence?(code: submitted, **binding)
          end

        assert_not wrong, "Retained proof must refuse wrong or malformed codes"
      end
      deadline = transaction.otp_result_expires_at
      [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
        evidence =
          model.stub(:database_now, deadline + offset) do
            if channel == "email"
              transaction.email_otp_verified_evidence?(code: code, **binding)
            else
              transaction.telephone_otp_verified_evidence?(code: code, **binding)
            end
          end

        assert_equal offset.negative?, evidence, "Result deadline is exclusive and never slides"
        assert_equal deadline, transaction.reload.otp_result_expires_at
      end
      replay =
        if channel == "email"
          transaction.verify_email_otp!(code: code, **binding)
        else
          transaction.verify_telephone_otp!(code: code, **binding)
        end

      assert_not replay, "Reading retained evidence is not a second OTP verification"
      original = transaction.reload.attributes
      model.transaction(requires_new: true) do
        assert_raises(ActiveRecord::StatementInvalid) do
          transaction.update_columns(
            otp_consumed_at: transaction.otp_consumed_at + 1.second,
            otp_result_expires_at: deadline + 1.second,
          )
        end
        raise ActiveRecord::Rollback
      end
      unchanged = original == transaction.reload.attributes

      assert unchanged, "SQL replacement must preserve the original proof without revealing its fields"
      extended =
        model.stub(:database_now, deadline) do
          if channel == "email"
            transaction.email_otp_verified_evidence?(code: code, **binding)
          else
            transaction.telephone_otp_verified_evidence?(code: code, **binding)
          end
        end

      assert_not extended, "SQL replacement of receipt timestamps cannot extend verified authority"
    end
  end
end
