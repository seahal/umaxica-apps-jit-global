# frozen_string_literal: true

require "test_helper"
require "timeout"

class OrgIamTargetEligibilityRaceTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  test "a target cannot become ineligible between authorization and principal commit" do
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
    issued_id = nil
    locked = Queue.new
    release = Queue.new
    revoker_started = Queue.new
    writer =
      Thread.new do
        OrgIamPrincipalCommit.call(
          actor:, token:, evidence:, operation_id:, operation_kind: "grant", subject_public_id: subject.public_id,
          request_digest: Digest::SHA256.hexdigest("target eligibility race request"),
          authorize: ->(_locked_actor) { Operator.find(subject.id).capability_eligible? },
        ) do |locked_actor|
          locked << true
          release.pop
          issued = OperatorCapabilityGrant.issue!(
            operator: subject, granted_by: locked_actor, capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
            reason_code: OperatorCapabilityGrant::DELEGATED_GRANT_REASON_CODES.first, ticket_id: nil, duration: 7.days,
          )
          issued_id = issued.public_id
          { "grant_public_id" => issued.public_id, "expires_at" => issued.expires_at.iso8601 }
        end
      ensure
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    Timeout.timeout(10) { locked.pop }
    revoker =
      Thread.new do
        OrgZenithRecord.connection_pool.with_connection do |connection|
          connection.execute("SET lock_timeout = '15s'")
          connection.execute("SET statement_timeout = '15s'")
          revoker_started << connection.select_value("SELECT pg_backend_pid()")
          Operator.find(subject.id).update!(withdrawal_started_at: Time.current)
          OrgIamOperationOutcome.exists?(operation_id:)
        ensure
          connection.execute("RESET lock_timeout")
          connection.execute("RESET statement_timeout")
        end
      end
    revoker_pid = Timeout.timeout(10) { revoker_started.pop }
    Timeout.timeout(10) do
      loop do
        wait_type =
          OrgZenithRecord.uncached do
            OrgZenithRecord.lease_connection.select_value(
              "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(revoker_pid)}",
            )
          end
        break if wait_type == "Lock"

        Thread.pass
      end
    end
    release << true
    committed = Timeout.timeout(10) { writer.value }
    principal_was_committed = Timeout.timeout(10) { revoker.value }

    assert_equal :confirmed, committed.outcome
    assert principal_was_committed
    assert_not Operator.find(subject.id).capability_eligible?
    assert OperatorCapabilityGrant.exists?(public_id: issued_id)
  ensure
    release << true if defined?(release) && release
    if defined?(writer) && writer
      writer.join
    end
    if defined?(revoker) && revoker
      revoker.join
    end
    OrgIamOperationOutcome.where(operation_id: operation_id).delete_all if defined?(operation_id) && operation_id
    operator_ids = [actor&.id, subject&.id].compact
    OperatorCapabilityGrant.where(operator_id: operator_ids).delete_all if operator_ids.any?
    OperatorCapabilityGrant.where(granted_by_operator_id: operator_ids).delete_all if operator_ids.any?
    OperatorCapabilityGrant.where(public_id: issued_id).delete_all if defined?(issued_id) && issued_id
    if defined?(token) && token&.persisted?
      device_id = token.reload.device_session_id
      OpOrgGrant.where(operator_token_id: token.id).delete_all
      OperatorDeviceSession.where(id: device_id, staff_id: actor.id).update_all(current_refresh_token_id: nil)
      OperatorToken.where(device_session_id: device_id, staff_id: actor.id).delete_all
      OperatorDeviceSession.where(id: device_id, staff_id: actor.id).delete_all
    end
    OperatorAuthorityLock.where(operator_id: operator_ids).delete_all if operator_ids.any?
    OperatorAccount.where(staff_id: operator_ids).delete_all if operator_ids.any?
    Operator.where(id: operator_ids).delete_all if operator_ids.any?
  end
end
