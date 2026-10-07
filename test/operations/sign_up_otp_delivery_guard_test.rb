# frozen_string_literal: true

require "test_helper"

class SignUpOtpDeliveryGuardTest < ActiveSupport::TestCase
  [
    [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
    [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
    [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, :com, :email],
    [Visitor, VisitorTelephone, :visitor_id, VisitorSignUpFlow, :com, :telephone],
  ].each do |owner_model, contact_model, owner_key, flow_model, surface, channel|
    %w(current reissued consumed expired owner_locked).each do |state|
      test "#{surface} #{channel} signup delivery checks its original #{state} generation under owning locks" do
        owner = owner_model.create!(
          status_id: (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE,
          **((state == "owner_locked") ? {
            access_state: "admin_locked", admin_locked_at: owner_model.database_now,
            admin_locked_by_operator_id: operators(:one).id, admin_locked_reason_code: "security_incident",
          } : {}),
        )
        destination =
          if channel == :email
            "delivery-#{SecureRandom.hex(10)}@example.test"
          else
            "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
          end
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
        contact.store_otp(private_key, 2, (now + 10.minutes).to_i) if state == "reissued"
        contact.clear_otp if state == "consumed"
        deadline = (state == "expired") ? flow.expires_at : now
        sent = 0
        outcome = nil
        flow_model.stub(:database_now, deadline) do
          outcome =
            SignUpOtpDeliveryGuard.call(
              flow: flow, channel: channel, contact_ref: contact.public_id,
              counter: "1", destination: destination, code: code,
            ) { sent += 1 }
        end

        assert_equal state == "current", outcome
        assert_equal((state == "current") ? 1 : 0, sent)
        expired = flow.reload.sign_up_expired?

        assert_equal state == "expired", expired
        assert_nil contact.reload.binding_finalized_at
        assert_equal owner.id, contact.public_send(owner_key)
      end
    end
  end
end
