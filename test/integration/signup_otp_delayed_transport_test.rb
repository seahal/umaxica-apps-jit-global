# frozen_string_literal: true

require "test_helper"

class SignupOtpDelayedTransportTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    [ClientSignUpFlowStatus, VisitorSignUpFlowStatus,
     ClientSignUpFlowCleanupStatus, VisitorSignUpFlowCleanupStatus,].each do |model|
      model::DEFAULTS.each { |id| model.find_or_create_by!(id: id) }
    end
  end

  [
    [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
    [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
    [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, :com, :email],
    [Visitor, VisitorTelephone, :visitor_id, VisitorSignUpFlow, :com, :telephone],
  ].each do |owner_model, contact_model, owner_key, flow_model, surface, channel|
    %w(current reissued consumed expired).each do |state|
      test "#{surface} #{channel} delayed signup checks #{state} evidence" do
        owner = owner_model.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          status_id: (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE,
        )
        destination =
          (channel == :email) ? "delayed-#{SecureRandom.hex(8)}@example.test" :
                   "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
        status_key, status =
          case [surface, channel]
          when [:app, :email] then [:user_email_status_id, ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP]
          when [:app, :telephone] then [:user_telephone_status_id, ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP]
          when [:com, :email] then [:visitor_email_status_id, VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP]
          when [:com, :telephone] then [:visitor_telephone_status_id, VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP]
          end
        contact = contact_model.create!(
          owner_key => owner.id, status_key => status, :confirm_policy => "1",
          ((channel == :email) ? :address : :number) => destination,
        )
        now = flow_model.database_now
        nonce = SecureRandom.urlsafe_base64(32)
        flow = flow_model.create!(
          auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_model),
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now,
          expires_at: now + 15.minutes, entry_method: channel.to_s,
          pending_contact_type: channel.to_s, pending_contact_id: contact.id,
        )
        issued =
          if channel == :email
            EmailSignUpOtpIssuer.call(flow: flow, email: contact, session_nonce: nonce)
          else
            TelephoneSignUpOtpIssuer.call(flow: flow, telephone: contact, session_nonce: nonce)
          end

        assert_predicate issued, :success?
        code = issued.code
        generation = issued.transaction.otp_generation
        if state == "reissued"
          contact.update!(otp_last_sent_at: contact.class.database_now - 1.minute)
          replacement =
            if channel == :email
              EmailSignUpOtpIssuer.call(flow: flow, email: contact, session_nonce: nonce)
            else
              TelephoneSignUpOtpIssuer.call(flow: flow, telephone: contact, session_nonce: nonce)
            end

          assert_predicate replacement, :success?
        elsif state == "consumed"
          verification =
            if channel == :email
              EmailSignUpOtpVerificationCommitter.call(flow: flow, email: contact, session_nonce: nonce, code: code)
            else
              TelephoneSignUpOtpVerificationCommitter.call(
                flow: flow, telephone: contact, session_nonce: nonce, code: code,
              )
            end

          assert_predicate verification, :verified_evidence?
        end
        deadline = (state == "expired") ? flow.expires_at : now
        sent = 0
        flow_model.stub(:database_now, deadline) do
          if channel == :email
            before = ActionMailer::Base.deliveries.length
            perform_enqueued_jobs do
              OtpAdapter.for(surface: surface, channel: channel).deliver(
                record: contact, otp_code: code, public_id: contact.public_id, purpose: "sign_up",
                sign_up_flow_ref: flow.public_id,
                sign_up_email_transaction_ref: issued.transaction.transaction_id,
                sign_up_email_otp_generation: generation,
              )
            end
            sent = ActionMailer::Base.deliveries.length - before
          else
            encrypted = OutboundSensitivePayload.encrypt_sms_delivery(
              to: destination, title: "Verification code", body: "Your verification code: #{code}",
              otp_binding: [surface.to_s, "sign_up", flow.public_id, issued.transaction.transaction_id, generation],
              otp_code: code,
            )
            OutboundSms.stub(:deliver_now, ->(**) { sent += 1 }) do
              Outbound::SmsDeliveryJob.perform_now(encrypted_payload: encrypted)
            end
          end
        end

        assert_equal((state == "current") ? 1 : 0, sent)
        expired = flow.reload.sign_up_expired?

        assert_equal state == "expired", expired
        assert_nil contact.reload.binding_finalized_at
      end
    end
  end
end
