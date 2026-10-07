# frozen_string_literal: true

require "test_helper"

class SignupOtpDelayedTransportTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  [
    [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
    [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
    [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, :com, :email],
    [Visitor, VisitorTelephone, :visitor_id, VisitorSignUpFlow, :com, :telephone],
  ].each do |owner_model, contact_model, owner_key, flow_model, surface, channel|
    ((channel == :email) ? [false, true] : [false]).each do |notifier_enabled|
      %w(current reissued consumed expired).each do |state|
        test "#{surface} #{channel} delayed signup notifier=#{notifier_enabled} checks #{state} evidence" do
          owner = owner_model.create!(
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
          private_key = ROTP::Base32.random_base32
          contact.store_otp(private_key, 1, (now + 10.minutes).to_i)
          code = ROTP::HOTP.new(private_key).at(1).to_s
          flow = flow_model.create!(
            principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
            nonce_digest: flow_model.digest_nonce(SecureRandom.hex(32)), issued_at: now,
            expires_at: now + 15.minutes, entry_method: channel.to_s,
            pending_contact_type: channel.to_s, pending_contact_id: contact.id,
          )
          binding = SignUpOtpDeliveryBindingValue.for_sms(
            otp_binding: [surface.to_s, "sign_up", flow.public_id, contact.public_id, "1"],
          )
          contact.store_otp(private_key, 2, (now + 10.minutes).to_i) if state == "reissued"
          contact.clear_otp if state == "consumed"
          deadline = (state == "expired") ? flow.expires_at : now
          sent = 0
          flow_model.stub(:database_now, deadline) do
            if channel == :email
              before = ActionMailer::Base.deliveries.length
              OtpEmailNotifierRollout.stub(:enabled?, notifier_enabled) do
                perform_enqueued_jobs do
                  OtpAdapter.for(surface: surface, channel: channel).deliver(
                    record: contact, otp_code: code, public_id: contact.public_id, purpose: "sign_up",
                    **binding.email_params,
                  )
                end
              end
              sent = ActionMailer::Base.deliveries.length - before
            else
              encrypted = OutboundSensitivePayload.encrypt_sms_delivery(
                to: destination, title: "Verification code", body: "Your verification code: #{code}",
                otp_binding: binding.to_a,
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
end
