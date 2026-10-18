# frozen_string_literal: true

require "test_helper"

class TelephoneCredentialRegistrationOtpReceiptTest < ActiveSupport::TestCase
  [ClientTelephoneCeremonyTransaction, VisitorTelephoneCeremonyTransaction].each do |model|
    test "#{model} finalized registration keeps only bounded same-code reconciliation evidence" do
      reference = SecureRandom.uuid
      session_ref = CredentialRegistrationOtpSessionValue.for(
        surface: model.ceremony_surface, channel: :telephone, transaction_ref: reference,
        root_ref: "original-root", browser_nonce: SecureRandom.urlsafe_base64(32),
      ).dump
      transaction = model.create_transaction!(
        transaction_id: reference, actor_ref: "original-owner", session_ref: session_ref,
        operation: "registration", telephone_candidate_ref: "candidate", normalized_number_digest: "a" * 64,
      )
      code = transaction.issue_telephone_otp!(purpose: "credential_registration")
      scope = {
        code: code,
        actor_ref: "original-owner",
        session_ref: session_ref,
        candidate_ref: "candidate",
      }

      assert transaction.verify_telephone_otp!(**scope, purpose: "credential_registration", operation: "registration")
      transaction.consume_registration_result!
      deadline = transaction.reload.otp_result_expires_at
      [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
        model.stub(:database_now, deadline + offset) do
          assert_not transaction.verify_telephone_otp!(
            **scope, purpose: "credential_registration", operation: "registration",
          )
          assert_not transaction.telephone_otp_verified_evidence?(
            **scope, purpose: "credential_registration", operation: "registration",
          )
          assert_equal offset.negative?, transaction.telephone_registration_otp_evidence?(**scope)
          wrong = (code == "000000") ? "000001" : "000000"

          assert_not transaction.telephone_registration_otp_evidence?(**scope.merge(code: wrong))
        end
      end

      assert_predicate transaction.reload, :consumed?
      assert_nil transaction.otp_verifier
      assert_equal deadline, transaction.otp_result_expires_at
    end
  end
end
