# frozen_string_literal: true

require "test_helper"

class EmailSignUpOtpDeliveryTest < ActiveJob::TestCase
  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  %w(app).each do |surface|
    test "app signup Notifier sends only encrypted current transaction generation and rejects cancellation" do
      _, email_model, flow_model, notifier, =
        case surface
        when "app"
          [Client, ClientEmail, ClientSignUpFlow, Notify::App::OtpNotifier, :user_id,
           ClientStatus::UNVERIFIED_WITH_SIGN_UP,]
        end
      email = email_model.new(raw_address: "signup-job-#{SecureRandom.hex(8)}@example.test", confirm_policy: true)
      owner = EmailSignUpCandidateCreator.call(email: email)
      now = flow_model.database_now
      nonce = "signup-job-browser"
      flow = flow_model.create!(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_model),
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
      )
      issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)
      arguments = {
        record: email,
        otp_code: issued.code,
        purpose: "sign_up",
        public_id: email.public_id,
        sign_up_flow_ref: flow.public_id,
        sign_up_email_transaction_ref: issued.transaction.transaction_id,
        sign_up_email_otp_generation: issued.transaction.otp_generation,
      }
      notifier.issue(**arguments)
      notification = ActiveJob::Arguments.deserialize(enqueued_jobs.last.fetch(:args)).last
      payload = notification.fetch(:params)

      assert_not OtpNotifierEmailDeliveryJob.log_arguments
      assert_not payload.key?(:sign_up_otp_counter)
      assert_equal issued.transaction.transaction_id, payload.fetch(:sign_up_email_transaction_ref)
      assert_equal issued.transaction.otp_generation, payload.fetch(:sign_up_email_otp_generation)
      encrypted = payload.fetch(:encrypted_hotp_token)

      assert_not encrypted.include?(issued.code)
      recovered = OutboundSensitivePayload.decrypt_email_otp(encrypted) == issued.code

      assert recovered, "Only encrypted delivery material reconstructs the code, not the DB verifier"
      assert_difference "ActionMailer::Base.deliveries.size", 1 do
        perform_enqueued_jobs(only: OtpNotifierEmailDeliveryJob)
      end
      assert_equal [email.address], ActionMailer::Base.deliveries.last.to
      assert_nil issued.transaction.reload.otp_consumed_at
      notifier.issue(**arguments)
      issued.transaction.cancel_email_otp!
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        perform_enqueued_jobs(only: OtpNotifierEmailDeliveryJob)
      end
    end
  end
end
