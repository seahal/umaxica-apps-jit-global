# frozen_string_literal: true

require "test_helper"

class SignUpOtpDeliveryIssuerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  [
    [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
    [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
    [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, :com, :email],
    [Visitor, VisitorTelephone, :visitor_id, VisitorSignUpFlow, :com, :telephone],
  ].each do |owner_model, contact_model, owner_key, flow_model, surface, channel|
    test "#{surface} #{channel} issuer refuses replacement of a committed proof without claiming delivery" do
      owner = owner_model.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::UNVERIFIED_WITH_SIGN_UP,
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
      nonce = SecureRandom.hex(32)
      flow = flow_model.create!(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_model),
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now,
        expires_at: now + 15.minutes, entry_method: channel.to_s,
        pending_contact_type: channel.to_s, pending_contact_id: contact.id,
      )

      issuer = (channel == :email) ? EmailSignUpOtpIssuer : TelephoneSignUpOtpIssuer
      verifier = (channel == :email) ? EmailSignUpOtpVerificationCommitter : TelephoneSignUpOtpVerificationCommitter
      delivery = (channel == :email) ? EmailSignUpOtpDeliveryIssuer : TelephoneSignUpOtpDeliveryIssuer
      arguments = { :flow => flow, channel => contact, :session_nonce => nonce }
      issued = issuer.call(**arguments)

      assert_predicate issued, :success?
      verified = verifier.call(**arguments, code: issued.code)

      assert_predicate verified, :success?
      contact.reload.update!(otp_last_sent_at: now - 2.minutes, otp_attempts_count: 1)
      original_proof = issued.transaction.reload.attributes
      assert_no_enqueued_jobs do
        refused = delivery.call(**arguments)

        assert_not refused.success?
        assert_nil refused.code
        assert_nil refused.transaction
      end
      unchanged = original_proof == issued.transaction.reload.attributes

      assert unchanged, "Refused issuance preserves the original committed ceremony proof"
      assert_equal 1, contact.reload.otp_attempts_count
    end
  end
end
