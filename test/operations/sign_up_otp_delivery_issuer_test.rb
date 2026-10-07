# frozen_string_literal: true

require "test_helper"

class SignUpOtpDeliveryIssuerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  [
    [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
    [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
    [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, :com, :email],
    [Visitor, VisitorTelephone, :visitor_id, VisitorSignUpFlow, :com, :telephone],
  ].each do |owner_model, contact_model, owner_key, flow_model, surface, channel|
    test "#{surface} #{channel} issuer refuses replacement of a committed proof without claiming delivery" do
      owner = owner_model.create!(
        status_id: (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE,
      )
      destination =
        (channel == :email) ? "issuer-#{SecureRandom.hex(8)}@example.test" :
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

      assert SignUpOtpChallengeRecorder.call(flow: flow, record: contact, channel: channel, code: code)
      verified = SignOtpCeremony.verify!(
        purpose: :sign_up, surface: surface, channel: channel, subject: flow,
        destination: destination, code: code, session_nonce: flow.public_id,
      )

      assert_predicate verified, :success?
      contact.reload.store_otp(private_key, 1, (now + 10.minutes).to_i)
      assert_no_enqueued_jobs do
        assert_not SignUpOtpDeliveryIssuer.call(flow: flow, record: contact, channel: channel)
      end
    end
  end
end
