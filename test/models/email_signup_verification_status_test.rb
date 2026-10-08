# frozen_string_literal: true

require "test_helper"

class EmailSignupVerificationStatusTest < ActiveSupport::TestCase
  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  %w(app com).each do |surface|
    %i(original foreign_browser wrong_code).each do |input|
      test "#{surface} Email signup status writer validates #{input} consumed evidence" do
        email_model, flow_model, status_key, pending_status, verified_status =
          case surface
          when "app"
            [ClientEmail, ClientSignUpFlow, :user_email_status_id,
             ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, ClientEmailStatus::VERIFIED_WITH_SIGN_UP,]
          when "com"
            [VisitorEmail, VisitorSignUpFlow, :visitor_email_status_id,
             VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP, VisitorEmailStatus::VERIFIED_WITH_SIGN_UP,]
          end
        email = email_model.new(raw_address: "status-writer-#{SecureRandom.hex(8)}@example.test", confirm_policy: true)
        owner = EmailSignUpCandidateCreator.call(email: email)
        nonce = "original-email-status-browser"
        now = flow_model.database_now
        flow = flow_model.create!(
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
          entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
        )
        issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)
        verified = EmailSignUpOtpVerificationCommitter.call(
          flow: flow, email: email, session_nonce: nonce, code: issued.code,
        )

        assert_predicate verified, :success?
        original = email.reload.attributes.slice("otp_attempts_count", "locked_at", "otp_last_sent_at")
        attempted_nonce = (input == :foreign_browser) ? "foreign-status-browser" : nonce
        wrong_code = (issued.code == "000000") ? "000001" : "000000"
        attempted_code = (input == :wrong_code) ? wrong_code : issued.code
        if input == :original
          email.mark_sign_up_verified!(flow: flow, session_nonce: attempted_nonce, code: attempted_code)

          assert_equal verified_status, email.reload[status_key]
          assert_nil email.binding_finalized_at
          email.mark_sign_up_verified!(flow: flow, session_nonce: attempted_nonce, code: attempted_code)

          assert_equal verified_status, email.reload[status_key]
        else
          assert_raises(ArgumentError) do
            email.mark_sign_up_verified!(flow: flow, session_nonce: attempted_nonce, code: attempted_code)
          end
          assert_equal pending_status, email.reload[status_key]
          assert_nil email.binding_finalized_at
        end
        failures_unchanged = original == email.reload.attributes.slice(*original.keys)

        assert failures_unchanged
      end
    end
  end
end
