# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# Boolean comparisons avoid disclosing OTP, proof and session facts on failure.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/AssertIncludes, Minitest/MultipleAssertions
class ContactRegistrationOtpNoticedTransportTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  %i(app com).each do |surface|
    %i(current verified reissued revoked expired).each do |state|
      test "#{surface} Noticed registration OTP #{state} retains original delivery authority" do
        actor, token, contact, flow_model, notifier, notifier_name =
          case surface
          when :app
            owner = Client.create!(status_id: ClientStatus::ACTIVE)
            root = ClientToken.create!(user: owner, discard_at: 1.day.from_now)
            candidate = owner.client_emails.create!(
              raw_address: "noticed-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
            )
            [owner, root, candidate, ClientEmailCeremonyTransaction, Notify::App::OtpNotifier,
             "Notify::App::OtpNotifier::Notification",]
          when :com
            owner = Visitor.create!
            root = VisitorToken.create!(visitor: owner, discard_at: 1.day.from_now)
            candidate = owner.visitor_emails.create!(
              raw_address: "noticed-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
            )
            [owner, root, candidate, VisitorEmailCeremonyTransaction, Notify::Com::OtpNotifier,
             "Notify::Com::OtpNotifier::Notification",]
          end
        token.rotate_refresh_token!
        nonce = SecureRandom.urlsafe_base64(32)
        issued = EmailCredentialRegistrationOtpIssuer.call(
          actor:, token:, email: contact, browser_nonce: nonce,
        )

        assert_instance_of EmailCredentialRegistrationOtpIssueResult, issued
        assert_predicate issued, :success?
        transaction = issued.transaction
        code = issued.code
        clear_enqueued_jobs
        clear_performed_jobs
        notifier.issue(
          record: contact, otp_code: code, purpose: "credential_registration", public_id: contact.public_id,
          contact_ceremony_transaction_ref: transaction.transaction_id,
          contact_otp_generation: transaction.otp_generation,
        )

        assert_equal 1, enqueued_jobs.length
        job = enqueued_jobs.first

        assert_equal OtpNotifierEmailDeliveryJob, job.fetch(:job)
        assert_not job.fetch(:job).log_arguments
        serialized_arguments = job.fetch(:args)
        arguments = ActiveJob::Arguments.deserialize(serialized_arguments)

        assert_equal "email", arguments.first.to_s
        assert_equal notifier_name, arguments.fetch(1)
        params = arguments.last.fetch(:params).stringify_keys

        assert_equal "credential_registration", params.fetch("purpose")
        assert params.fetch("contact_ceremony_transaction_ref") == transaction.transaction_id,
               "Noticed must queue the original ceremony UUID"
        assert params.fetch("public_id") == contact.public_id, "Noticed must queue the original Contact reference"
        assert params.fetch("contact_otp_generation") == transaction.otp_generation,
               "Noticed must queue the original independent Email generation"
        assert OutboundSensitivePayload.decrypt_email_otp(params.fetch("encrypted_hotp_token")) == code,
               "Noticed must encrypt the issued random code before enqueue"
        assert_not serialized_arguments.to_s.include?(code), "Noticed must not queue a plaintext OTP"
        assert_not params.key?("otp_code"), "Noticed must not retain the raw OTP parameter"

        case state
        when :verified
          verified = EmailCredentialRegistrationOtpVerificationCommitter.call(
            actor:, token:, email: contact, transaction:, browser_nonce: nonce, code:,
          )

          assert_predicate verified, :success?
          assert_predicate verified, :verified_evidence?
          assert_nil transaction.reload.otp_verifier
          assert_not_nil transaction.otp_consumed_at
          assert_not_nil transaction.otp_receipt_verifier
        when :reissued
          generation = transaction.otp_generation
          transaction.reissue_email_otp!

          assert_not_equal transaction.reload.otp_generation, generation,
                           "Reissuance must supersede the queued generation"
        when :revoked
          token.revoke!
        when :expired
          # D-115 permits moving the original deadline without inventing a business transition.
          transaction.update_columns(expires_at: flow_model.database_now - 1.second)
        end
        contact_facts = contact.reload.attributes
        ticket_facts = transaction.reload.attributes
        root_facts = token.reload.attributes
        device_facts = token.device_session.reload.attributes
        owner_facts = actor.reload.attributes
        before = ActionMailer::Base.deliveries.length
        perform_enqueued_jobs

        assert_equal((state == :current) ? 1 : 0, ActionMailer::Base.deliveries.length - before)
        assert_performed_jobs 1, only: OtpNotifierEmailDeliveryJob
        if state == :current
          delivered = ActionMailer::Base.deliveries.last

          assert delivered.to == [contact.address], "Noticed must deliver to the bound Contact destination"
          assert_not_nil delivered.text_part
          assert delivered.text_part.body.decoded.include?(code), "Noticed must deliver the actual issued OTP"
        end

        assert contact_facts == contact.reload.attributes, "Noticed must preserve Source failure and issuance facts"
        assert ticket_facts == transaction.reload.attributes, "Noticed must preserve the original pending Ticket"
        assert root_facts == token.reload.attributes, "Noticed must preserve root facts"
        assert device_facts == token.device_session.reload.attributes, "Noticed must preserve device facts"
        assert owner_facts == actor.reload.attributes, "Noticed must preserve owner facts"
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/AssertIncludes, Minitest/MultipleAssertions
