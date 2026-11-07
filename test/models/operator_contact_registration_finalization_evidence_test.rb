# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorContactRegistrationFinalizationEvidenceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "ORG email finalization consumes verified OTP evidence and verifies the candidate" do
    operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
    )
    token = OperatorToken.create!(authentication_epoch: 0, staff: operator, discard_at: 1.day.from_now)
    now = OpBaseOrgRecord.database_now
    device_session = token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    client = OidcClientRegistry.find!("base-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch,
      operator_token: token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr,
      amr: ["passkey"],
      auth_time: now.to_i,
      sid: grant.public_id,
      sub: OidcSubject.for(operator, resource_type: "operator"),
      client_id: client.client_id,
      aud: [client.aud],
      jti: grant.oidc_jti,
    )
    email = operator.staff_emails.create!(raw_address: "org-#{SecureRandom.hex(8)}@example.test")
    nonce = SecureRandom.urlsafe_base64(32)
    issued = EmailCredentialRegistrationOtpIssuer.call(
      actor: operator, token: token, email: email, browser_nonce: nonce,
    )

    assert_predicate issued, :success?
    verified = EmailCredentialRegistrationOtpVerificationCommitter.call(
      actor: operator, token: token, email: email, transaction: issued.transaction,
      browser_nonce: nonce, code: issued.code,
    )

    assert_predicate verified, :success?
    context = ActorValuesContext.empty.with(subject: operator, actor_type: :operator, tld: :org, surface: :base)
    requirement = OperatorEmailPolicy.new(email, user: operator).credential_registration_requirement(token: token)

    result = OperatorEmailRegistrationOtpFinalizer.call!(
      actor: operator, actor_context: context, token: token, email: email, transaction: issued.transaction,
      browser_nonce: nonce, code: issued.code, requirement: requirement, step_up_evidence: evidence,
    )

    assert_equal :finalized, result
    assert_equal OperatorEmailStatus::VERIFIED, email.reload.staff_email_status_id
    assert_predicate issued.transaction.reload, :consumed?
    assert_predicate device_session.reload, :usable?
  end

  test "ORG telephone finalization consumes verified OTP evidence and verifies the candidate" do
    operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
    )
    token = OperatorToken.create!(authentication_epoch: 0, staff: operator, discard_at: 1.day.from_now)
    now = OpBaseOrgRecord.database_now
    device_session = token.device_session_record!
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    client = OidcClientRegistry.find!("base-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch,
      operator_token: token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr,
      amr: ["passkey"],
      auth_time: now.to_i,
      sid: grant.public_id,
      sub: OidcSubject.for(operator, resource_type: "operator"),
      client_id: client.client_id,
      aud: [client.aud],
      jti: grant.oidc_jti,
    )
    telephone = operator.staff_telephones.create!(
      raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
    )
    nonce = SecureRandom.urlsafe_base64(32)
    issued = TelephoneCredentialRegistrationOtpIssuer.call(
      actor: operator, token: token, telephone: telephone, browser_nonce: nonce,
    )

    assert_predicate issued, :success?
    verified = TelephoneCredentialRegistrationOtpVerificationCommitter.call(
      actor: operator, token: token, telephone: telephone, transaction: issued.transaction,
      browser_nonce: nonce, code: issued.code,
    )

    assert_predicate verified, :success?
    context = ActorValuesContext.empty.with(subject: operator, actor_type: :operator, tld: :org, surface: :base)
    requirement = OperatorTelephonePolicy.new(telephone, user: operator).credential_registration_requirement(
      token: token,
    )

    result = OperatorTelephoneRegistrationOtpFinalizer.call!(
      actor: operator, actor_context: context, token: token, telephone: telephone, transaction: issued.transaction,
      browser_nonce: nonce, code: issued.code, requirement: requirement, step_up_evidence: evidence,
    )

    assert_equal :finalized, result
    assert_equal OperatorTelephoneStatus::VERIFIED, telephone.reload.staff_telephone_status_id
    assert_predicate issued.transaction.reload, :consumed?
    assert_predicate device_session.reload, :usable?
  end
end
