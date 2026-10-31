# frozen_string_literal: true

require "test_helper"

class SignUpOtpDeliveryGuardTest < ActiveSupport::TestCase
  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  [
    [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
    [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
  ].each do |owner_model, contact_model, owner_key, flow_model, surface, channel|
    %w(
      current reissued consumed expired owner_locked cancelled expiry_mismatch verified_expiry_mismatch
    ).each do |state|
      test "#{surface} #{channel} signup delivery checks its original #{state} generation under owning locks" do
        owner = owner_model.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
        )
        destination =
          if channel == :email
            "delivery-#{SecureRandom.hex(10)}@example.test"
          else
            "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
          end
        status_key, status =
          case channel
          when :email then [:user_email_status_id, ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP]
          when :telephone then [:user_telephone_status_id, ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP]
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
        guard = (channel == :email) ? EmailSignUpOtpDeliveryGuard : TelephoneSignUpOtpDeliveryGuard
        issued = issuer.call(:flow => flow, channel => contact, :session_nonce => nonce)

        assert_predicate issued, :success?
        generation = issued.transaction.otp_generation
        if state == "reissued"
          if channel == :email
            issued.transaction.issue_email_otp!(purpose: "sign_up")
          else
            issued.transaction.issue_telephone_otp!(purpose: "sign_up")
          end
        elsif %w(consumed verified_expiry_mismatch).include?(state)
          verifier = (channel == :email) ? EmailSignUpOtpVerificationCommitter : TelephoneSignUpOtpVerificationCommitter
          verified = verifier.call(:flow => flow, channel => contact, :session_nonce => nonce, :code => issued.code)

          assert_predicate verified, :success?
          if state == "verified_expiry_mismatch"
            flow.update_columns(expires_at: flow.expires_at - 1.second)
          end
        elsif state == "owner_locked"
          owner.update!(
            access_state: "admin_locked", admin_locked_at: owner_model.database_now,
            admin_locked_by_operator_id: operators(:one).id, admin_locked_reason_code: "security_incident",
          )
        elsif state == "cancelled"
          result = SignUpTermination.call(cycle: flow, event: :cancel)

          assert_equal :ok, result.status
        elsif state == "expiry_mismatch"
          issued.transaction.update_columns(expires_at: flow.expires_at + 1.second)
        end
        deadline = (state == "expired") ? flow.expires_at : now
        sent = 0
        outcome = nil
        flow_model.stub(:database_now, deadline) do
          outcome =
            guard.call(
              :flow => flow, channel => contact, :transaction => issued.transaction,
              :generation => generation, :destination => destination, :code => issued.code,
            ) { sent += 1 }
        end

        assert_equal state == "current", outcome
        assert_equal((state == "current") ? 1 : 0, sent)
        # D-177: expiry during delivery leaves termination to SignUpExpiryJob.
        assert_equal state == "cancelled", flow.reload.sign_up_terminal?
        assert_nil contact.reload.binding_finalized_at
        assert_equal owner.id, contact[owner_key]
        if state == "cancelled"
          verifier = (channel == :email) ? EmailSignUpOtpVerificationCommitter : TelephoneSignUpOtpVerificationCommitter
          verification = verifier.call(:flow => flow, channel => contact, :session_nonce => nonce, :code => issued.code)

          assert_not_predicate verification, :success?
          assert_equal :inactive_flow, verification.status
          assert_nil issued.transaction.reload.otp_consumed_at
        elsif %w(expiry_mismatch verified_expiry_mismatch).include?(state)
          verifier = (channel == :email) ? EmailSignUpOtpVerificationCommitter : TelephoneSignUpOtpVerificationCommitter
          verification = verifier.call(:flow => flow, channel => contact, :session_nonce => nonce, :code => issued.code)

          assert_not_predicate verification, :success?
          assert_not_predicate verification, :verified_evidence?
          assert_equal :missing_challenge, verification.status
          assert_nil issued.transaction.reload.otp_consumed_at if state == "expiry_mismatch"
        end
      end
    end
  end
end
