# frozen_string_literal: true

require "test_helper"

class SignUpOtpResendDeadlineTest < ActiveSupport::TestCase
  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  [[:email, ClientEmail, ClientEmailCeremonyTransaction, EmailSignUpOtpIssuer],
   [:telephone, ClientTelephone, ClientTelephoneCeremonyTransaction, TelephoneSignUpOtpIssuer],].product(
     [[:before, -1], [:at, 0], [:after, 1]],
   ).each do |entry, (label, offset)|
    channel, contact_model, transaction_model, issuer = entry

    test "#{channel} signup resend at #{label} the original OTP deadline" do
      owner = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
      )
      destination =
        if channel == :email
          { address: "deadline-#{SecureRandom.hex(8)}@example.test" }
        else
          { number: "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}" }
        end
      contact = contact_model.create!(**destination, user: owner, confirm_policy: "1")
      now = ClientSignUpFlow.database_now
      nonce = SecureRandom.urlsafe_base64(32)
      flow = ClientSignUpFlow.create!(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
        principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING, step: "contact",
        nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: channel.to_s, pending_contact_type: channel.to_s, pending_contact_id: contact.id,
      )
      arguments = { :flow => flow, channel => contact, :session_nonce => nonce }
      initial = issuer.call(**arguments)

      assert_predicate initial, :success?
      transaction = initial.transaction
      original = transaction.attributes
      previous_sent_at = contact.reload.otp_last_sent_at
      parent_expiry = flow.expires_at
      decision_time = transaction.otp_expires_at + Rational(offset, 1_000_000)
      result =
        contact_model.stub(:database_now, decision_time) do
          transaction_model.stub(:database_now, decision_time) do
            ClientSignUpFlow.stub(:database_now, decision_time) { issuer.call(**arguments) }
          end
        end

      if label == :before
        assert_predicate result, :success?
        assert_withheld("resend rotates its generation") {
          original.fetch("otp_generation") != transaction.reload.otp_generation
        }
        assert_equal parent_expiry, flow.reload.expires_at
      else
        assert_equal :closed_challenge, result.status
        assert_nil result.code
        assert_withheld("expired refusal preserves the original proof") { original == transaction.reload.attributes }
        assert_equal previous_sent_at, contact.reload.otp_last_sent_at
      end
    end
  end
end
