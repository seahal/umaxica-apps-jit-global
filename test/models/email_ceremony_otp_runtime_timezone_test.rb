# frozen_string_literal: true

require "test_helper"

class EmailCeremonyOtpRuntimeTimezoneTest < ActiveSupport::TestCase
  [ClientEmailCeremonyTransaction, VisitorEmailCeremonyTransaction, OperatorEmailCeremonyTransaction].each do |model|
    test "#{model.name} proof delivery consumption and receipt use canonical timestamps across runtime zones" do
      transaction = nil
      code = nil
      Time.use_zone("Asia/Tokyo") do
        transaction = model.create_transaction!(
          actor_ref: "actor", session_ref: "browser", operation: "sign_up",
          email_candidate_ref: "candidate", normalized_email_digest: SecureRandom.hex(32),
        )
        code = transaction.issue_email_otp!(purpose: "sign_up")
      end
      Time.use_zone("UTC") do
        transported = false

        assert transaction.deliver_email_otp!(generation: transaction.otp_generation, code: code) { transported = true }
        assert transported
        assert transaction.verify_email_otp!(
          code: code, purpose: "sign_up", actor_ref: "actor", session_ref: "browser",
          operation: "sign_up", candidate_ref: "candidate",
        )
      end
      Time.use_zone("Asia/Tokyo") do
        assert transaction.email_otp_verified_evidence?(
          code: code, purpose: "sign_up", actor_ref: "actor", session_ref: "browser",
          operation: "sign_up", candidate_ref: "candidate",
        )
      end
    end
  end
end
