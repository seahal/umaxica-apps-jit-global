# frozen_string_literal: true

require "test_helper"

class OrgIamAuditedCommitTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  test "a completed operation replays only after authorization and never repeats its mutation" do
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
    reason = OperatorCapabilityGrant::DELEGATED_GRANT_REASON_CODES.first
    arguments = {
      actor:,
      subject:,
      token:,
      evidence:,
      operation_id:,
      operation_kind: "grant",
      request_digest: Digest::SHA256.hexdigest("fixed test request"),
      reason_code: reason,
      metadata: {},
      request_id: "test-request",
      ip_address: "127.0.0.1",
      user_agent: "test-agent",
      authorize: ->(_locked_actor) { true },
    }
    issued_id = nil
    result =
      OrgIamAuditedCommit.call(**arguments) do |locked_actor|
        issued = OperatorCapabilityGrant.issue!(
          operator: subject, granted_by: locked_actor, capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
          reason_code: reason, ticket_id: nil, duration: 7.days,
        )
        issued_id = issued.public_id
        { "grant_public_id" => issued.public_id, "expires_at" => issued.expires_at.iso8601 }
      end

    assert_equal :confirmed, result.status
    issued_id = result.outcome.result.fetch("grant_public_id")

    assert_equal "succeeded", Chronicle.find_by!(event_uuid: operation_id).result

    replay = OrgIamAuditedCommit.call(**arguments) { raise RuntimeError, "replay executed mutation" }

    assert_equal :confirmed, replay.status
    assert_equal issued_id, replay.outcome.result.fetch("grant_public_id")
    assert_equal 1, OperatorCapabilityGrant.where(public_id: issued_id).count

    denied =
      OrgIamAuditedCommit.call(**arguments.merge(authorize: ->(_locked_actor) { false })) do
        raise RuntimeError, "denied replay executed mutation"
      end

    assert_equal :denied, denied.status

    second_operation_id = SecureRandom.uuid
    second_issued_id = nil
    second_arguments = arguments.merge(operation_id: second_operation_id)
    unconfirmed =
      ChronicleResultWriter.stub(
        :call, ->(**) { raise ActiveRecord::ConnectionNotEstablished, "injected audit outage" },
      ) do
        OrgIamAuditedCommit.call(**second_arguments) do |locked_actor|
          issued = OperatorCapabilityGrant.issue!(
            operator: subject, granted_by: locked_actor, capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
            reason_code: reason, ticket_id: nil, duration: 7.days,
          )
          second_issued_id = issued.public_id
          { "grant_public_id" => issued.public_id, "expires_at" => issued.expires_at.iso8601 }
        end
      end

    assert_equal :audit_unconfirmed, unconfirmed.status
    assert_equal "intent", Chronicle.find_by!(event_uuid: second_operation_id).result
    recovered =
      OrgIamAuditedCommit.call(**second_arguments) do
        raise RuntimeError, "audit recovery executed mutation"
      end

    assert_equal :confirmed, recovered.status
    assert_equal second_issued_id, recovered.outcome.result.fetch("grant_public_id")
    assert_equal "succeeded", Chronicle.find_by!(event_uuid: second_operation_id).result
  ensure
    Chronicle.where(event_uuid: operation_id).delete_all if defined?(operation_id) && operation_id
    Chronicle.where(event_uuid: second_operation_id).delete_all if defined?(second_operation_id) && second_operation_id
    if defined?(second_operation_id) && second_operation_id
      OrgIamOperationOutcome.where(operation_id: second_operation_id).delete_all
    end
    OperatorCapabilityGrant.where(public_id: second_issued_id).delete_all if defined?(second_issued_id) &&
      second_issued_id
    ChronicleRetentionPolicy.where(id: created_policy.id).delete_all if defined?(created_policy) && created_policy
    if defined?(operation_id) && operation_id
      OrgIamOperationOutcome.where(operation_id:).delete_all
    end
    if defined?(issued_id) && issued_id
      OperatorCapabilityGrant.where(public_id: issued_id).delete_all
    end
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
