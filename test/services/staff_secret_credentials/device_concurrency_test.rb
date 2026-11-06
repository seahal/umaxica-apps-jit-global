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
    now = OperatorToken.database_now
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
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(operator, resource_type: "operator"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
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
                step_up_token: OperatorToken.find(token.id), step_up_evidence: evidence, step_up_bootstrap: false,
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
  ensure
    worker&.join
    grant&.delete
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    operator&.delete
  end
end
