# frozen_string_literal: true

require "test_helper"

class EmailSignupBindingAuthorityTest < ActiveSupport::TestCase
  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  %w(app com).each do |surface|
    %i(late_checkpoint foreign_browser uncleared_otp unconsumed_child expired_parent).each do |state|
      test "#{surface} Email signup binding validates #{state} durable authority" do
        email_model, flow_model, status_key, verified_status =
          case surface
          when "app"
            [ClientEmail, ClientSignUpFlow, :user_email_status_id, ClientEmailStatus::VERIFIED_WITH_SIGN_UP]
          when "com"
            [VisitorEmail, VisitorSignUpFlow, :visitor_email_status_id, VisitorEmailStatus::VERIFIED_WITH_SIGN_UP]
          end
        email = email_model.new(raw_address: "signup-writer-#{SecureRandom.hex(8)}@example.test", confirm_policy: true)
        owner = EmailSignUpCandidateCreator.call(email: email)
        nonce = "original-email-signup-browser"
        now = flow_model.database_now
        flow = flow_model.create!(
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
          entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
        )
        issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)
        unless state == :unconsumed_child
          verified = EmailSignUpOtpVerificationCommitter.call(
            flow: flow, email: email, session_nonce: nonce, code: issued.code,
          )

          assert_predicate verified, :success?
        end
        flow.verify_sign_up_contact!
        flow.advance_sign_up_to_guardrail!
        flow.advance_sign_up_to_checkpoint!
        flow.update!(completed_requirements: { "otp" => { "cleared" => state != :uncleared_otp } })
        flow.update!(expires_at: flow_model.database_now - Rational(1, 1_000_000)) if state == :expired_parent
        original = email.reload.attributes.slice("otp_attempts_count", "locked_at", "otp_last_sent_at")
        original_proof = issued.transaction.reload.attributes.slice(
          "otp_consumed_at", "otp_receipt_verifier", "otp_result_expires_at", "otp_generation",
        )
        if state == :late_checkpoint
          checkpoint_time = issued.transaction.otp_result_expires_at + Rational(1, 1_000_000)
          flow_model.stub(:database_now, checkpoint_time) do
            issued.transaction.class.stub(:database_now, checkpoint_time) do
              email.finalize_sign_up_binding!(flow: flow, session_nonce: nonce)
            end
          end

          assert_predicate email.reload, :binding_effective?
          assert_equal verified_status, email[status_key]
          if surface == "app"
            owner.finalize_email_sign_up!(email: email, flow: flow)

            assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, owner.reload.status_id
          end
        else
          attempted_nonce = (state == :foreign_browser) ? "foreign-browser" : nonce
          assert_raises(ArgumentError) do
            email.finalize_sign_up_binding!(flow: flow, session_nonce: attempted_nonce)
          end
          assert_nil email.reload.binding_finalized_at
        end

        failures_unchanged = original == email.reload.attributes.slice(*original.keys)
        proof_unchanged = original_proof == issued.transaction.reload.attributes.slice(*original_proof.keys)

        assert failures_unchanged
        assert proof_unchanged
      end
    end
  end
end
