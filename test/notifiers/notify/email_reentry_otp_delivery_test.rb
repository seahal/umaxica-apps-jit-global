# frozen_string_literal: true

require "test_helper"

class EmailReentryOtpDeliveryTest < ActiveJob::TestCase
  %w(app com org).each do |surface|
    test "#{surface} email worker refuses foreign actor destination generation realm and consumed proof" do
      email_model, transaction_model, owner_key, owner =
        case surface
        when "app" then [ClientEmail, ClientEmailCeremonyTransaction, :user_id, clients(:one)]
        when "com" then [VisitorEmail, VisitorEmailCeremonyTransaction, :visitor_id, visitors(:reserved_visitor)]
        when "org" then [OperatorEmail, OperatorEmailCeremonyTransaction, :staff_id, operators(:one)]
        end
      email = email_model.create!(
        owner_key => owner.id, :raw_address => "ceremony-binding-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true,
      )
      transaction = transaction_model.create_transaction!(
        actor_ref: owner.public_id, session_ref: SecureRandom.uuid, operation: "withdrawal",
        email_candidate_ref: email.public_id, normalized_email_digest: email.address_digest,
      )
      code = transaction.issue_email_otp!(purpose: "withdrawal")
      payload = {
        surface: surface,
        purpose: "withdrawal",
        transaction_ref: transaction.transaction_id,
        generation: transaction.otp_generation,
        encrypted_code: OutboundSensitivePayload.encrypt_email_otp(code),
      }

      assert_no_difference "ActionMailer::Base.deliveries.size" do
        transaction.update!(actor_ref: "foreign-owner")
        deliver_payload(email: email, **payload)
        transaction.update!(actor_ref: owner.public_id, normalized_email_digest: SecureRandom.hex(32))
        deliver_payload(email: email, **payload)
        transaction.update!(normalized_email_digest: email.address_digest)

        [nil, "", 0].each do |generation|
          assert_raises(ArgumentError) { deliver_payload(email: email, **payload.merge(generation: generation)) }
        end
        deliver_payload(email: email, **payload.merge(generation: SecureRandom.uuid))
        foreign_surface = (surface == "app") ? "com" : "app"
        deliver_payload(email: email, **payload.merge(surface: foreign_surface))
      end
      assert transaction.verify_email_otp!(
        code: code, purpose: "withdrawal", actor_ref: owner.public_id,
        session_ref: transaction.session_ref, operation: "withdrawal", candidate_ref: email.public_id,
      )
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        deliver_payload(email: email, **payload)
      end
    end

    test "#{surface} email worker delivers encrypted current generation but refuses reissue cancellation and expiry" do
      email_model, transaction_model, owner_key, owner =
        case surface
        when "app" then [ClientEmail, ClientEmailCeremonyTransaction, :user_id, clients(:one)]
        when "com" then [VisitorEmail, VisitorEmailCeremonyTransaction, :visitor_id, visitors(:reserved_visitor)]
        when "org" then [OperatorEmail, OperatorEmailCeremonyTransaction, :staff_id, operators(:one)]
        end
      email = email_model.create!(
        owner_key => owner.id, :raw_address => "ceremony-delivery-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true,
      )
      transaction = transaction_model.create_transaction!(
        actor_ref: owner.public_id, session_ref: SecureRandom.uuid, operation: "recovery",
        email_candidate_ref: email.public_id, normalized_email_digest: email.address_digest,
      )
      code = transaction.issue_email_otp!(purpose: "recovery")
      payload = {
        surface: surface,
        purpose: "recovery",
        transaction_ref: transaction.transaction_id,
        generation: transaction.otp_generation,
        encrypted_code: OutboundSensitivePayload.encrypt_email_otp(code),
      }

      assert_not OtpNotifierEmailDeliveryJob.log_arguments
      assert_not payload[:encrypted_code].include?(code)
      assert_difference "ActionMailer::Base.deliveries.size", 1 do
        deliver_payload(email: email, **payload)
      end
      assert_equal [email.address], ActionMailer::Base.deliveries.last.to
      assert_nil transaction.reload.otp_consumed_at
      transaction.issue_email_otp!(purpose: "recovery")
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        deliver_payload(email: email, **payload)
      end
      replacement = transaction.issue_email_otp!(purpose: "recovery")
      current_payload = payload.merge(
        generation: transaction.otp_generation, encrypted_code: OutboundSensitivePayload.encrypt_email_otp(replacement),
      )

      transaction_model.stub(:database_now, transaction.otp_expires_at) do
        assert_no_difference "ActionMailer::Base.deliveries.size" do
          deliver_payload(email: email, **current_payload)
        end
      end
      decision_time = transaction.otp_expires_at - 1.second
      transaction_model.stub(:database_now, -> { decision_time }) do
        ActiveSupport::Notifications.subscribed(
          ->(_event) { decision_time = transaction.otp_expires_at }, "process.action_mailer",
        ) do
          assert_no_difference "ActionMailer::Base.deliveries.size" do
            deliver_payload(email: email, **current_payload)
          end
        end
      end
      transaction.cancel_email_otp!
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        deliver_payload(email: email, **current_payload)
      end
    end
  end

  private

  def deliver_payload(email:, surface:, purpose:, transaction_ref:, generation:, encrypted_code:)
    notifier =
      case surface
      when "app" then Notify::App::OtpNotifier
      when "com" then Notify::Com::OtpNotifier
      when "org" then Notify::Org::OtpNotifier
      else raise ArgumentError, "unsupported test delivery surface"
      end
    code = OutboundSensitivePayload.decrypt_email_otp(encrypted_code)
    notifier.issue(
      record: email, otp_code: code, purpose: purpose, public_id: email.public_id,
      email_ceremony_transaction_ref: transaction_ref, email_otp_generation: generation,
    )
    perform_enqueued_jobs(only: OtpNotifierEmailDeliveryJob)
  end
end
