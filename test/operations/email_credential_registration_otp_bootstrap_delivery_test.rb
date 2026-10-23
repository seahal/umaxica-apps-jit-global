# frozen_string_literal: true

require "test_helper"

class EmailCredentialRegistrationOtpBootstrapDeliveryTest < ActiveSupport::TestCase
  %i(app com).each do |surface|
    %i(cancel expiry_before expiry_at expiry_after return_target scope).each do |change|
      test "#{surface} Email bootstrap delivery refuses #{change} of its original unconsumed parent" do
        actor_model, token_model, email_model, auth_model, owner_key =
          if surface == :app
            [Client, ClientToken, ClientEmail, ClientAuthCeremonySession, :user_id]
          else
            [Visitor, VisitorToken, VisitorEmail, VisitorAuthCeremonySession, :visitor_id]
          end
        actor = actor_model.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
          status_id: (surface == :app) ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE,
        )
        token = token_model.create!(
          :authentication_epoch => 0,
          owner_key => actor.id, :root_login_established_at => token_model.database_now, :discard_at => 1.day.from_now,
        )
        token.rotate_refresh_token!
        nonce = SecureRandom.urlsafe_base64(32)
        requirement = StepUpRequirement.new(
          step_up_required: false, scope: "settings_email", purpose: "bootstrap",
          allowed_methods: [:email_otp], ttl: 15.minutes, audience: "step_up:#{surface}",
          phishing_resistant_required: false, user_verification_required: false,
          full_reauthentication_required: false, session_binding: token.public_id,
          token_binding: token.public_id, require_session_binding: true,
          actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
        )
        admission = BaseStepUpAdmissionIssuer.call!(
          actor: actor, token: token, requirement: requirement, return_to: "/identity/emails",
          base_browser_nonce: nonce, base_token: token,
        )
        parent = admission.transaction
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: surface, reference: admission.reference)
        attached, sid = auth_model.issue!
        binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
        binding.confirm_base!(
          base_token: token,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: surface, entry_ref: binding.entry_ref, nonce: nonce,
          ),
        )
        BaseAuthAdmissionCoordinator.consume_entry_reference!(
          reference: admission.reference, surface: surface, expected_intent: "bootstrap", binding: binding,
          raw_auth_sid: sid,
        )
        ceremony, = auth_model.rotate_and_admit!(
          admission_purpose: "bootstrap_handoff", previous_raw_sid: sid,
          step_up_ceremony_transaction_ref: parent.transaction_id,
        )
        binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
        email = email_model.create!(
          owner_key => actor.id, :raw_address => "bootstrap-job-#{SecureRandom.hex(8)}@example.test",
          :confirm_policy => "1",
        )
        issued = EmailCredentialRegistrationOtpIssuer.call(
          actor: actor, token: token, email: email, browser_nonce: nonce, bootstrap_transaction: parent,
        )
        scope = {
          transaction: issued.transaction,
          email: email,
          generation: issued.transaction.otp_generation,
          destination: email.address,
          code: issued.code,
        }
        transports = 0

        assert EmailCredentialRegistrationOtpDeliveryGuard.call(**scope) { transports += 1 }
        original_generation = issued.transaction.otp_generation
        original_deadline = issued.transaction.otp_expires_at
        email.update!(otp_last_sent_at: email.class.database_now - 1.minute, otp_attempts_count: 1)
        live_resend = EmailCredentialRegistrationOtpResendIssuer.call(
          actor: actor, token: token, email: email, transaction: issued.transaction, browser_nonce: nonce,
        )

        assert_predicate live_resend, :success?
        assert_not_equal original_generation, issued.transaction.reload.otp_generation
        assert_equal original_deadline, issued.transaction.otp_expires_at
        assert_equal 1, email.reload.otp_attempts_count
        assert_not EmailCredentialRegistrationOtpDeliveryGuard.call(**scope) { transports += 1 }
        scope = scope.merge(generation: live_resend.transaction.otp_generation, code: live_resend.code)
        issued = live_resend
        case change
        when :cancel then parent.commit_cancellation!(now: parent.class.database_now)
        when :expiry_before, :expiry_at, :expiry_after
          parent.update_columns(expires_at: parent.class.database_now + 30.seconds)
        when :return_target then parent.update_columns(return_to: "https://foreign.example.test/identity/emails")
        when :scope then parent.update_columns(required_scope: "unknown_operation")
        end

        if %i(expiry_before expiry_at expiry_after).include?(change)
          offset = { expiry_before: -Rational(1, 1_000_000),
                     expiry_at: 0,
                     expiry_after: Rational(1, 1_000_000), }.fetch(change)
          delivered =
            parent.class.stub(:database_now, parent.expires_at + offset) do
              EmailCredentialRegistrationOtpDeliveryGuard.call(**scope) { transports += 1 }
            end

          assert_equal change == :expiry_before, delivered
          assert_equal((change == :expiry_before) ? 2 : 1, transports)
        else
          assert_not EmailCredentialRegistrationOtpDeliveryGuard.call(**scope) { transports += 1 }
          assert_equal 1, transports
          failed_attempts = email.reload.otp_attempts_count
          generation = issued.transaction.otp_generation
          email.update!(otp_last_sent_at: email.class.database_now - 1.minute)
          resend = EmailCredentialRegistrationOtpResendIssuer.call(
            actor: actor, token: token, email: email, transaction: issued.transaction, browser_nonce: nonce,
          )

          assert_equal :unavailable, resend.status
          assert_equal generation, issued.transaction.reload.otp_generation
          verification = EmailCredentialRegistrationOtpVerificationCommitter.call(
            actor: actor, token: token, email: email, transaction: issued.transaction, browser_nonce: nonce,
            code: issued.code,
          )

          assert_equal :unavailable, verification.status
          assert_equal failed_attempts, email.reload.otp_attempts_count
        end

        assert_nil issued.transaction.reload.otp_consumed_at
      end
    end
  end
end
