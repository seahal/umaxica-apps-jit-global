# frozen_string_literal: true

require "test_helper"
require "timeout"

class StaffSecretCredentialsDeviceConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "device revocation commits before waiting Secret creation" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    token = OperatorToken.create!(authentication_epoch: 0, staff: operator)
    device = token.device_session_record!
    token.update!(
      last_step_up_at: OperatorToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
      last_step_up_phishing_resistant: false, last_step_up_user_verified: false,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    requirement = StepUpRequirement.new(
      scope: "settings_secret_credential", step_up_required: true, allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, purpose: "step_up", audience: "step_up:org",
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: operator.public_id, resource_ref: nil, tenant_ref: nil,
    )
    ready = Queue.new
    worker = nil
    device.with_lock do
      worker =
        Thread.new do
          OrgPrincipalRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
            OpBaseOrgRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()").to_i
              OperatorSecretCredentialsCreate.call(
                actor: Operator.find(operator.id), staff: Operator.find(operator.id),
                params: { name: "blocked by revocation", enabled: true },
                step_up_token: OperatorToken.find(token.id), step_up_requirement: requirement, step_up_bootstrap: false,
              )
            end
          end
        rescue TokenStatusManagement::StepUpEvidenceUnavailable => e
          e
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      backend_pid = Timeout.timeout(10) { ready.pop }
      Timeout.timeout(10) do
        loop do
          state =
            OperatorDeviceSession.lease_connection.uncached do
              OperatorDeviceSession.lease_connection.select_value(
                "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(backend_pid)}",
              )
            end
          break if state == "Lock"

          sleep 0.01
        end
      end
      device.revoke!
    end

    assert_instance_of TokenStatusManagement::StepUpEvidenceUnavailable, Timeout.timeout(10) { worker.value }
    assert_predicate device.reload, :revoked?
    assert_not OperatorSecretCredential.exists?(staff_id: operator.id)
    assert_equal "settings_secret_credential", token.reload.last_step_up_scope
  ensure
    worker&.join
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    operator&.delete
  end
end
