# frozen_string_literal: true

require "test_helper"

class EmailCredentialRegistrationOtpDeliveryTest < ActiveJob::TestCase
  %w(app com org).each do |surface|
    test "#{surface} registration Notifier encrypts random code and delivers only its live generation" do
      actor, token, email, notifier =
        case surface
        when "app"
          owner = Client.create!(status_id: ClientStatus::ACTIVE)
          root = ClientToken.create!(user: owner, discard_at: 1.day.from_now)
          candidate = owner.client_emails.create!(
            raw_address: "registration-job-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
          )
          [owner, root, candidate, Notify::App::OtpNotifier]
        when "org"
          owner = Operator.create!(status_id: OperatorStatus::ACTIVE)
          root = OperatorToken.create!(staff: owner, discard_at: 1.day.from_now)
          candidate = owner.staff_emails.create!(
            raw_address: "registration-job-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
          )
          [owner, root, candidate, Notify::Org::OtpNotifier]
        when "com"
          owner = Visitor.create!(status_id: VisitorStatus::ACTIVE)
          root = VisitorToken.create!(visitor: owner, discard_at: 1.day.from_now)
          candidate = owner.visitor_emails.create!(
            raw_address: "registration-job-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
          )
          [owner, root, candidate, Notify::Com::OtpNotifier]
        end
      token.rotate_refresh_token!
      issued = EmailCredentialRegistrationOtpIssuer.call(
        actor: actor, token: token, email: email, browser_nonce: SecureRandom.urlsafe_base64(32),
      )
      arguments = {
        record: email,
        otp_code: issued.code,
        purpose: "credential_registration",
        public_id: email.public_id,
        contact_ceremony_transaction_ref: issued.transaction.transaction_id,
        contact_otp_generation: issued.transaction.otp_generation,
      }
      notifier.issue(**arguments)
      notification = ActiveJob::Arguments.deserialize(enqueued_jobs.last.fetch(:args)).last
      payload = notification.fetch(:params)

      assert_not OtpNotifierEmailDeliveryJob.log_arguments
      assert_not payload.key?(:contact_otp_counter)
      assert_equal issued.transaction.transaction_id, payload.fetch(:contact_ceremony_transaction_ref)
      assert_equal issued.transaction.otp_generation, payload.fetch(:contact_otp_generation)
      recovered = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token)) == issued.code

      assert recovered, "Only the encrypted transport payload reconstructs the code"
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
