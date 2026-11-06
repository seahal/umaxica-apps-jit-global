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
      now = OpBaseOrgRecord.database_now
      token.device_session_record!
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      oidc_client = OidcClientRegistry.find!("base-org-ww")
      grant = OpOrgGrant.create!(
        authentication_epoch: token.authentication_epoch, operator_token: token,
        oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
        oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
        oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
        refresh_token_expires_at: now + 1.hour,
      )
      grant.issue_refresh_token!(now:)
      step_up_evidence = StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(operator, resource_type: "operator"), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
      )
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
        browser_nonce: nonce, code: issued.code, requirement: requirement, step_up_evidence: step_up_evidence,
        **source,
      )
      assert_equal before, contact.reload.attributes
      assert_not_predicate issued.transaction.reload, :consumed?
    end
  end
end
