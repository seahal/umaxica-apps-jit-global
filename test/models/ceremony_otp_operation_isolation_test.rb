# frozen_string_literal: true

require "test_helper"

class CeremonyOtpOperationIsolationTest < ActiveSupport::TestCase
  [ClientEmailCeremonyTransaction, VisitorEmailCeremonyTransaction,
   OperatorEmailCeremonyTransaction,].each do |model|
    %w(recovery withdrawal).each do |operation|
      test "#{model.name} #{operation} email proof cannot become a signed registration permission" do
        transaction = model.create_transaction!(
          actor_ref: "actor", session_ref: "browser", operation: operation,
          email_candidate_ref: "candidate", normalized_email_digest: SecureRandom.hex(32),
        )
        code = transaction.issue_email_otp!(purpose: operation)

        assert_not transaction.verify_email_otp!(
          code: code, purpose: operation, actor_ref: "actor", session_ref: "browser",
          operation: "registration", candidate_ref: "candidate",
        )
        error =
          assert_raises(IdentityEmailCeremonyContract::Error) do
            IdentityEmailCeremonyGrant.new(
              transaction.grant_claims.merge(
                "typ" => IdentityEmailCeremonyGrant::TOKEN_TYPE,
                "iss" => IdentityEmailCeremonyContract.acme_issuer(transaction.surface),
                "aud" => IdentityEmailCeremonyContract.sign_audience(transaction.surface),
                "purpose" => IdentityEmailCeremonyGrant::PURPOSE,
              ),
            )
          end

        assert_equal "operation is invalid", error.message
        assert transaction.verify_email_otp!(
          code: code, purpose: operation, actor_ref: "actor", session_ref: "browser",
          operation: operation, candidate_ref: "candidate",
        )
      end
    end
  end

  [ClientTelephoneCeremonyTransaction, VisitorTelephoneCeremonyTransaction,
   OperatorTelephoneCeremonyTransaction,].each do |model|
    %w(recovery withdrawal).each do |operation|
      test "#{model.name} #{operation} telephone proof cannot become a signed registration permission" do
        transaction = model.create_transaction!(
          actor_ref: "actor", session_ref: "browser", operation: operation,
          telephone_candidate_ref: "candidate", normalized_number_digest: SecureRandom.hex(32),
        )
        code = transaction.issue_telephone_otp!(purpose: operation)

        assert_not transaction.verify_telephone_otp!(
          code: code, purpose: operation, actor_ref: "actor", session_ref: "browser",
          operation: "registration", candidate_ref: "candidate",
        )
        error =
          assert_raises(IdentityTelephoneCeremony::Error) do
            IdentityTelephoneCeremonyGrant.new(
              transaction.grant_claims.merge(
                "typ" => IdentityTelephoneCeremonyGrant::TOKEN_TYPE,
                "iss" => IdentityTelephoneCeremonyContract.acme_issuer(transaction.surface),
                "aud" => IdentityTelephoneCeremonyContract.sign_audience(transaction.surface),
                "purpose" => IdentityTelephoneCeremonyGrant::PURPOSE,
              ),
            )
          end

        assert_equal "operation is invalid", error.message
        assert transaction.verify_telephone_otp!(
          code: code, purpose: operation, actor_ref: "actor", session_ref: "browser",
          operation: operation, candidate_ref: "candidate",
        )
      end
    end
  end
end
