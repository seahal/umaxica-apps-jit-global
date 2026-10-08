# frozen_string_literal: true

require "test_helper"

class CeremonyOtpFiniteDeadlineTest < ActiveSupport::TestCase
  [
    [ClientEmailCeremonyTransaction, :email], [VisitorEmailCeremonyTransaction, :email],
    [OperatorEmailCeremonyTransaction, :email], [ClientTelephoneCeremonyTransaction, :telephone],
    [VisitorTelephoneCeremonyTransaction, :telephone], [OperatorTelephoneCeremonyTransaction, :telephone],
  ].each do |model, channel|
    test "#{model.name} infinite parent or proof deadlines cannot admit delivery or verification" do
      %i(expires_at otp_expires_at).product([Float::INFINITY, -Float::INFINITY]).each do |column, invalid_deadline|
        candidate_key = (channel == :email) ? :email_candidate_ref : :telephone_candidate_ref
        transaction = model.create_transaction!(
          :actor_ref => "actor", :session_ref => "browser", :operation => "registration", candidate_key => "candidate",
        )
        code =
          if channel == :email
            transaction.issue_email_otp!(purpose: "credential_registration")
          else
            transaction.issue_telephone_otp!(purpose: "credential_registration")
          end
        transaction.update_columns(column => invalid_deadline)
        sent = false
        binding = {
          code: code,
          purpose: "credential_registration",
          actor_ref: "actor",
          session_ref: "browser",
          operation: "registration",
          candidate_ref: "candidate",
        }
        if channel == :email
          assert_not transaction.email_otp_deliverable?(generation: transaction.otp_generation, at: model.database_now)
          assert_not transaction.deliver_email_otp!(generation: transaction.otp_generation, code: code) { sent = true }
          assert_not transaction.verify_email_otp!(**binding)
        else
          assert_not transaction.telephone_otp_deliverable?(
            generation: transaction.otp_generation,
            at: model.database_now,
          )
          assert_not transaction.deliver_telephone_otp!(generation: transaction.otp_generation, code: code) {
            sent = true
          }
          assert_not transaction.verify_telephone_otp!(**binding)
        end

        assert_not sent
        assert_nil transaction.reload.otp_consumed_at
      end
    end
  end
end
