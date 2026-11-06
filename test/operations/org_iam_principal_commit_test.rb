# frozen_string_literal: true

require "test_helper"

class OrgIamPrincipalCommitTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  test "the public commit checks authorization and records a replayable result with its mutation" do
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
    arguments = {
      actor:,
      token:,
      evidence:,
      operation_id:,
      operation_kind: "grant",
      subject_public_id: subject.public_id,
      request_digest: Digest::SHA256.hexdigest("fixed test request"),
    }
    mutations = 0
    assert_raises(ArgumentError) { OrgIamPrincipalCommit.call(**arguments) { mutations += 1 } }
    assert_raises(OrgIamPrincipalCommit::AuthorizationRejected) do
      OrgIamPrincipalCommit.call(**arguments, authorize: ->(_locked_actor) { false }) do
        mutations += 1
      end
    end
    assert_equal 0, mutations
    assert_not OrgIamOperationOutcome.exists?(operation_id:)

    issued_id = nil
    result =
      OrgIamPrincipalCommit.call(**arguments, authorize: ->(_locked_actor) { true }) do |locked_actor|
        issued = OperatorCapabilityGrant.issue!(
          operator: subject, granted_by: locked_actor, capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
          reason_code: OperatorCapabilityGrant::DELEGATED_GRANT_REASON_CODES.first, ticket_id: nil, duration: 7.days,
        )
        issued_id = issued.public_id
        { "grant_public_id" => issued.public_id, "expires_at" => issued.expires_at.iso8601 }
      end

    assert_equal :confirmed, result.outcome
    issued_id = result.record.result.fetch("grant_public_id")

    assert OperatorCapabilityGrant.exists?(public_id: issued_id, operator_id: subject.id)

    replay =
      OrgIamPrincipalCommit.call(**arguments, authorize: ->(_locked_actor) { true }) do
        mutations += 1
        raise RuntimeError, "replay executed a mutation"
      end

    assert_equal issued_id, replay.record.result.fetch("grant_public_id")
    assert_equal 0, mutations
    assert_equal 1, OrgIamOperationOutcome.where(operation_id:).count

    release_operation_id = SecureRandom.uuid
    release_grant_id = nil
    op_connection = OpBaseOrgRecord.lease_connection
    released =
      op_connection.stub(
        :commit_db_transaction, -> { raise ActiveRecord::ConnectionNotEstablished, "injected OP release failure" },
      ) do
        OrgIamPrincipalCommit.call(
          **arguments.merge(operation_id: release_operation_id), authorize: ->(_locked_actor) { true },
        ) do |locked_actor|
          issued = OperatorCapabilityGrant.issue!(
            operator: subject, granted_by: locked_actor, capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
            reason_code: OperatorCapabilityGrant::DELEGATED_GRANT_REASON_CODES.first, ticket_id: nil, duration: 7.days,
          )
          release_grant_id = issued.public_id
          { "grant_public_id" => issued.public_id, "expires_at" => issued.expires_at.iso8601 }
        end
      end

    assert_equal :confirmed_op_release_failed, released.outcome
    assert OrgIamOperationOutcome.exists?(operation_id: release_operation_id)
    assert OperatorCapabilityGrant.exists?(public_id: release_grant_id)

    unknown_operation_id = SecureRandom.uuid
    unknown_grant_id = nil
    principal_connection = OrgZenithRecord.lease_connection
    original_commit = principal_connection.method(:commit_db_transaction)
    committed =
      principal_connection.stub(
        :commit_db_transaction,
        -> {
          original_commit.call
          raise ActiveRecord::ConnectionFailed, "lost commit acknowledgement"
        },
      ) do
        OrgIamPrincipalCommit.call(
          **arguments.merge(operation_id: unknown_operation_id), authorize: ->(_locked_actor) { true },
        ) do |locked_actor|
          issued = OperatorCapabilityGrant.issue!(
            operator: subject, granted_by: locked_actor, capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
            reason_code: OperatorCapabilityGrant::DELEGATED_GRANT_REASON_CODES.first, ticket_id: nil, duration: 7.days,
          )
          unknown_grant_id = issued.public_id
          { "grant_public_id" => issued.public_id, "expires_at" => issued.expires_at.iso8601 }
        end
      end

    assert_equal :confirmed_after_recovery, committed.outcome
    assert_equal unknown_grant_id, committed.record.result.fetch("grant_public_id")
    assert OperatorCapabilityGrant.exists?(public_id: unknown_grant_id)

    rollback_operation_id = SecureRandom.uuid
    rollback_grant_id = nil
    principal_connection = OrgZenithRecord.lease_connection
    assert_raises(OrgIamPrincipalCommit::IndeterminateCommit) do
      principal_connection.stub(
        :commit_db_transaction, -> { raise ActiveRecord::ConnectionFailed, "connection lost before commit" },
      ) do
        OrgIamPrincipalCommit.call(
          **arguments.merge(operation_id: rollback_operation_id), authorize: ->(_locked_actor) { true },
        ) do |locked_actor|
          issued = OperatorCapabilityGrant.issue!(
            operator: subject, granted_by: locked_actor, capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
            reason_code: OperatorCapabilityGrant::DELEGATED_GRANT_REASON_CODES.first, ticket_id: nil, duration: 7.days,
          )
          rollback_grant_id = issued.public_id
          { "grant_public_id" => issued.public_id, "expires_at" => issued.expires_at.iso8601 }
        end
      end
    end
    assert_not OrgIamOperationOutcome.exists?(operation_id: rollback_operation_id)
    assert_not OperatorCapabilityGrant.exists?(public_id: rollback_grant_id)
  ensure
    if defined?(rollback_operation_id) && rollback_operation_id
      OrgIamOperationOutcome.where(operation_id: rollback_operation_id).delete_all
    end
    if defined?(rollback_grant_id) && rollback_grant_id
      OperatorCapabilityGrant.where(public_id: rollback_grant_id).delete_all
    end
    if defined?(unknown_operation_id) && unknown_operation_id
      OrgIamOperationOutcome.where(operation_id: unknown_operation_id).delete_all
    end
    if defined?(unknown_grant_id) && unknown_grant_id
      OperatorCapabilityGrant.where(public_id: unknown_grant_id).delete_all
    end
    if defined?(release_operation_id) && release_operation_id
      OrgIamOperationOutcome.where(operation_id: release_operation_id).delete_all
    end
    if defined?(release_grant_id) && release_grant_id
      OperatorCapabilityGrant.where(public_id: release_grant_id).delete_all
    end
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
