# frozen_string_literal: true

require "test_helper"

class OperatorContactRegistrationDeviceTest < ActiveSupport::TestCase
  test "ORG contact OTP issuance and verification reject a rebound token" do
    %i(email telephone).product(%i(issuance verification)).each do |channel, stage|
      operator = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
      )
      token = OperatorToken.create!(authentication_epoch: 0, staff: operator, discard_at: 1.day.from_now)
      token.rotate_refresh_token!
      issuer, verifier, source =
        if channel == :email
          record = operator.staff_emails.create!(raw_address: "org-#{SecureRandom.hex(8)}@example.test")
          [EmailCredentialRegistrationOtpIssuer, EmailCredentialRegistrationOtpVerificationCommitter, { email: record }]
        else
          record = operator.staff_telephones.create!(
            raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
          )
          [TelephoneCredentialRegistrationOtpIssuer, TelephoneCredentialRegistrationOtpVerificationCommitter,
           { telephone: record },]
        end
      nonce = SecureRandom.urlsafe_base64(32)
      issued = issuer.call(actor: operator, token: token, browser_nonce: nonce, **source) if stage == :verification
      stale_token = OperatorToken.find(token.id)
      replacement = OperatorToken.create!(authentication_epoch: 0, staff: operator)
      new_device = replacement.device_session_record!
      OperatorToken.find(token.id).update!(device_session_id: new_device.id)
      new_device.update!(current_refresh_token_id: token.id)

      if stage == :issuance
        result = issuer.call(actor: operator, token: stale_token, browser_nonce: nonce, **source)

        assert_equal :unavailable, result.status
      else
        result = verifier.call(
          actor: operator, token: stale_token, transaction: issued.transaction,
          browser_nonce: nonce, code: issued.code, **source,
        )

        assert_equal :unavailable, result.status
        assert_nil issued.transaction.reload.otp_consumed_at
      end
    end
  end

  test "ORG contact finalization requires the device locked for the token" do
    %i(email telephone).each do |channel|
      operator = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
      )
      token = OperatorToken.create!(authentication_epoch: 0, staff: operator, discard_at: 1.day.from_now)
      token.rotate_refresh_token!
      passkey = operator.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "org-contact-key")
      contact, issuer, verifier, finalizer, policy, source =
        if channel == :email
          record = operator.staff_emails.create!(raw_address: "org-#{SecureRandom.hex(8)}@example.test")
          [record, EmailCredentialRegistrationOtpIssuer, EmailCredentialRegistrationOtpVerificationCommitter,
           OperatorEmailRegistrationOtpFinalizer, OperatorEmailPolicy, { email: record },]
        else
          record = operator.staff_telephones.create!(
            raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
          )
          [record, TelephoneCredentialRegistrationOtpIssuer, TelephoneCredentialRegistrationOtpVerificationCommitter,
           OperatorTelephoneRegistrationOtpFinalizer, OperatorTelephonePolicy, { telephone: record },]
        end
      token.update!(
        last_step_up_at: OperatorToken.database_now, last_step_up_scope: "settings_#{channel}",
        last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
        last_step_up_credential_ref: passkey.external_id, last_step_up_phishing_resistant: true,
        last_step_up_user_verified: true, last_step_up_full_reauthentication: false,
      )
      nonce = SecureRandom.urlsafe_base64(32)
      issued = issuer.call(actor: operator, token: token, browser_nonce: nonce, **source)

      assert_predicate issued, :success?
      verified = verifier.call(
        actor: operator, token: token, transaction: issued.transaction, browser_nonce: nonce, code: issued.code,
        **source,
      )

      assert_predicate verified, :success?
      context = ActorValuesContext.empty.with(subject: operator, actor_type: :operator, tld: :org, surface: :base)
      requirement = policy.new(contact, user: operator).credential_registration_requirement(token: token)
      stale_token = OperatorToken.find(token.id)
      replacement = OperatorToken.create!(authentication_epoch: 0, staff: operator)
      new_device = replacement.device_session_record!
      OperatorToken.find(token.id).update!(device_session_id: new_device.id)
      new_device.update!(current_refresh_token_id: token.id)
      before = contact.reload.attributes

      assert_equal :unavailable, finalizer.call!(
        actor: operator, actor_context: context, token: stale_token, transaction: issued.transaction,
        browser_nonce: nonce, code: issued.code, requirement: requirement, **source,
      )
      assert_equal before, contact.reload.attributes
      assert_not_predicate issued.transaction.reload, :consumed?
    end
  end
end
