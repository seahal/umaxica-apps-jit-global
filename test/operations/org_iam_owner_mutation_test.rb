# frozen_string_literal: true

require "test_helper"

class OrgIamOwnerMutationTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  test "grant and revoke bind input, recheck authority and target, and replay without a second write" do
    created_policy = nil
    unless ChronicleRetentionPolicy.exists?(code: "compliance")
      created_policy = ChronicleRetentionPolicy.create!(
        code: "compliance", name: "Compliance", duration_days: 365,
        permanent: false,
      )
    end
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    subject = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
    now = OperatorToken.database_now
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token,
      oidc_client_id: client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "operator"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
    )
    operation_id = SecureRandom.uuid
    Actor.install_context!(
      authz: Actor::Authz.new(
        policy_user: actor,
        token_claims: { AuthenticationContextValue::CLAIM => AuthenticationContextValue::NORMAL_KEY },
        surface: :base,
      ),
    )
    bootstrap_grants = OperatorCapabilityGrant.bootstrap!(
      operator: actor,
      capabilities: [
        OperatorCapabilityGrant::IAM_CAPABILITY_READ,
        OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,
        OperatorCapabilityGrant::IAM_CAPABILITY_REVOKE,
        OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
      ],
      ticket_id: "IAM-TEST", expires_at: 7.days.from_now,
    )
    request = Struct.new(:request_id, :remote_ip, :user_agent).new("owner-test", "127.0.0.1", "test-agent")
    reason = OperatorCapabilityGrant::DELEGATED_GRANT_REASON_CODES.first
    operation_ids = [operation_id, SecureRandom.uuid, SecureRandom.uuid, SecureRandom.uuid]
    arguments = {
      actor:,
      subject:,
      token:,
      evidence:,
      operation_id:,
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
      duration_days: 7,
      reason_code: reason,
      ticket_id: "IAM-TEST",
      request:,
    }
    result = OrgIamOwnerMutation.grant(**arguments)

    assert_equal :confirmed, result.status
    issued_id = result.outcome.result.fetch("grant_public_id")

    assert OperatorCapabilityGrant.exists?(public_id: issued_id, operator_id: subject.id)
    replay = OrgIamOwnerMutation.grant(**arguments)

    assert_equal :confirmed, replay.status
    assert_equal issued_id, replay.outcome.result.fetch("grant_public_id")
    assert_equal 1, OperatorCapabilityGrant.where(public_id: issued_id).count
    assert_raises(OrgIamAuditedCommit::OperationConflict) do
      OrgIamOwnerMutation.grant(**arguments.merge(duration_days: 30))
    end

    issued = OperatorCapabilityGrant.find_by!(public_id: issued_id)
    revoke_arguments = {
      actor:,
      token:,
      evidence:,
      operation_id: operation_ids[1],
      grant: issued,
      reason_code: OperatorCapabilityGrant::REVOKE_REASON_CODES.first,
      request:,
    }
    revoked = OrgIamOwnerMutation.revoke(**revoke_arguments)

    assert_equal :confirmed, revoked.status
    assert_predicate issued.reload, :revoked?
    revoke_replay = OrgIamOwnerMutation.revoke(**revoke_arguments)

    assert_equal :confirmed, revoke_replay.status
    assert_equal issued_id, revoke_replay.outcome.result.fetch("grant_public_id")
    assert_raises(OrgIamAuditedCommit::OperationConflict) do
      OrgIamOwnerMutation.revoke(**revoke_arguments.merge(reason_code: OperatorCapabilityGrant::REVOKE_REASON_CODES.last))
    end

    subject.update!(withdrawal_started_at: Time.current)
    target_denied = OrgIamOwnerMutation.grant(**arguments.merge(operation_id: operation_ids[2]))

    assert_equal :denied, target_denied.status
    assert_not OrgIamOperationOutcome.exists?(operation_id: operation_ids[2])
    subject.update!(withdrawal_started_at: nil)
    delegated_capability = bootstrap_grants.find { |item| item.capability == OperatorCapabilityGrant::ENFORCEMENT_READ_APP }
    delegated_capability.revoke!(by: subject, reason_code: OperatorCapabilityGrant::REVOKE_REASON_CODES.first)
    authority_denied = OrgIamOwnerMutation.grant(**arguments.merge(operation_id: operation_ids[3]))

    assert_equal :denied, authority_denied.status
    assert_not OrgIamOperationOutcome.exists?(operation_id: operation_ids[3])
  ensure
    Actor.clear
    Chronicle.where(event_uuid: operation_ids).delete_all if defined?(operation_ids) && operation_ids
    OrgIamOperationOutcome.where(operation_id: operation_ids).delete_all if defined?(operation_ids) && operation_ids
    if defined?(actor) && actor && defined?(subject) && subject
      OperatorCapabilityGrant.where(operator_id: [actor.id, subject.id]).where(
        granted_by_operator_id: [nil, actor.id, subject.id],
      ).delete_all
    end
    ChronicleRetentionPolicy.where(id: created_policy.id).delete_all if defined?(created_policy) && created_policy
    if defined?(token) && token&.persisted?
      device_id = token.reload.device_session_id
      OpOrgGrant.where(operator_token_id: token.id).delete_all
      OperatorDeviceSession.where(id: device_id, staff_id: actor.id).update_all(current_refresh_token_id: nil)
      OperatorToken.where(device_session_id: device_id, staff_id: actor.id).delete_all
      OperatorDeviceSession.where(id: device_id, staff_id: actor.id).delete_all
    end
    Operator.where(id: subject.id).delete_all if defined?(subject) && subject&.persisted?
    Operator.where(id: actor.id).delete_all if defined?(actor) && actor&.persisted?
  end

  test "last IAM grant revocation records a failed outcome and leaves the only holder unchanged" do
    created_policy = nil
    unless ChronicleRetentionPolicy.exists?(code: "compliance")
      created_policy = ChronicleRetentionPolicy.create!(
        code: "compliance", name: "Compliance", duration_days: 365, permanent: false,
      )
    end
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    subject = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    OperatorCapabilityGrant.bootstrap!(
      operator: actor,
      capabilities: [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_REVOKE],
      ticket_id: "IAM-LAST-ACTOR",
      expires_at: 7.days.from_now,
    )
    last_grant = OperatorCapabilityGrant.bootstrap!(
      operator: subject,
      capabilities: [OperatorCapabilityGrant::IAM_CAPABILITY_GRANT],
      ticket_id: "IAM-LAST-SUBJECT",
      expires_at: 7.days.from_now,
    ).first
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, root_login_established_at: Time.current)
    now = OperatorToken.database_now
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token,
      oidc_client_id: client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "operator"), client_id: client.client_id,
      aud: [client.aud], jti: grant.oidc_jti,
    )
    operation_id = SecureRandom.uuid
    request = Struct.new(:request_id, :remote_ip, :user_agent).new("last-holder-test", "127.0.0.1", "test-agent")
    result = OrgIamOwnerMutation.revoke(
      actor:, token:, evidence:, operation_id:, grant: last_grant,
      reason_code: OperatorCapabilityGrant::REVOKE_REASON_CODES.first, request:,
    )

    assert_equal :last_capability_holder, result.status
    assert_not_predicate last_grant.reload, :revoked?
    chronicle = Chronicle.find_by!(event_uuid: operation_id)

    assert_equal "failed", chronicle.result
    assert_equal({ "error_class" => "OperatorCapabilityGrant::LastCapabilityHolderError" }, chronicle.changeset)
    assert_not OrgIamOperationOutcome.exists?(operation_id:)
  ensure
    Chronicle.where(event_uuid: operation_id).delete_all if defined?(operation_id) && operation_id
    OrgIamOperationOutcome.where(operation_id:).delete_all if defined?(operation_id) && operation_id
    OperatorCapabilityGrant.where(operator_id: [actor.id, subject.id]).delete_all if
      defined?(actor) && actor&.persisted? && defined?(subject) && subject&.persisted?
    ChronicleRetentionPolicy.where(id: created_policy.id).delete_all if defined?(created_policy) && created_policy
    if defined?(token) && token&.persisted?
      device_id = token.reload.device_session_id
      OpOrgGrant.where(operator_token_id: token.id).delete_all
      OperatorDeviceSession.where(id: device_id, staff_id: actor.id).update_all(current_refresh_token_id: nil)
      OperatorToken.where(device_session_id: device_id, staff_id: actor.id).delete_all
      OperatorDeviceSession.where(id: device_id, staff_id: actor.id).delete_all
    end
    Operator.where(id: subject.id).delete_all if defined?(subject) && subject&.persisted?
    Operator.where(id: actor.id).delete_all if defined?(actor) && actor&.persisted?
  end
end
