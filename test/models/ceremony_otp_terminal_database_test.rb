# frozen_string_literal: true

require "test_helper"

class CeremonyOtpTerminalDatabaseTest < ActiveSupport::TestCase
  [
    [ClientEmailCeremonyTransaction, :email], [VisitorEmailCeremonyTransaction, :email],
    [OperatorEmailCeremonyTransaction, :email], [ClientTelephoneCeremonyTransaction, :telephone],
    [VisitorTelephoneCeremonyTransaction, :telephone], [OperatorTelephoneCeremonyTransaction, :telephone],
  ].each do |model, channel|
    %i(verified cancelled).each do |terminal|
      test "#{model.name} direct database writes cannot erase or replace #{terminal} OTP facts" do
        candidate_key = (channel == :email) ? :email_candidate_ref : :telephone_candidate_ref
        digest_key = (channel == :email) ? :normalized_email_digest : :normalized_number_digest
        transaction = model.create_transaction!(
          :actor_ref => "original-actor", :session_ref => "original-browser", :operation => "registration",
          candidate_key => "original-candidate", digest_key => "a" * 64,
        )
        code =
          if channel == :email
            transaction.issue_email_otp!(purpose: "credential_registration")
          else
            transaction.issue_telephone_otp!(purpose: "credential_registration")
          end
        binding = {
          code: code,
          purpose: "credential_registration",
          actor_ref: "original-actor",
          session_ref: "original-browser",
          operation: "registration",
          candidate_ref: "original-candidate",
        }
        closed =
          if channel == :email
            (terminal == :verified) ? transaction.verify_email_otp!(**binding) : transaction.cancel_email_otp!
          else
            (terminal == :verified) ? transaction.verify_telephone_otp!(**binding) : transaction.cancel_telephone_otp!
          end

        assert closed
        original = transaction.reload.attributes
        replacements = [
          { otp_consumed_at: nil, otp_cancelled_at: nil, otp_receipt_verifier: nil, otp_result_expires_at: nil },
          { otp_generation: SecureRandom.uuid }, { otp_verifier: "b" * 64 },
          { otp_receipt_verifier: "b" * 64 },
          { otp_result_expires_at: transaction.class.database_now + 30.seconds },
          { otp_consumed_at: transaction.class.database_now },
          { otp_cancelled_at: transaction.class.database_now },
          { purpose: "sign_in" }, { actor_ref: "another-actor" }, { session_ref: "another-browser" },
          { operation: "replacement" }, { candidate_key => "another-candidate" }, { digest_key => "b" * 64 },
          { otp_expires_at: transaction.otp_expires_at + 1.second },
          { expires_at: transaction.expires_at + 1.second }, { transaction_id: SecureRandom.uuid },
          { surface: "another-realm" },
        ]
        replacements << { bootstrap_ceremony_transaction_ref: SecureRandom.uuid } if channel == :email
        replacements.each do |replacement|
          model.transaction(requires_new: true) do
            assert_raises(ActiveRecord::StatementInvalid) { transaction.update_columns(replacement) }
            raise ActiveRecord::Rollback
          end
          unchanged = original == transaction.reload.attributes

          assert unchanged, "Rejected SQL writes must retain all original terminal proof and binding facts"
        end
      end
    end
  end
end
