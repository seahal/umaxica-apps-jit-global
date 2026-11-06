# frozen_string_literal: true

require "test_helper"
require "timeout"

class BaseStepUpAdmissionReferenceRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  %w(app org).each do |surface|
    test "#{surface} parent reference replacement while admission waits is refused" do
      actor, token, parent_model, session_model, token_key, op_record =
        if surface == "app"
          client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
          [client, ClientToken.create!(authentication_epoch: 0, user: client), ClientStepUpCeremonyTransaction,
           ClientStepUpSession, :user_token, OpBaseAppRecord,]
        else
          operator = Operator.create!(
            security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
          )
          [operator, OperatorToken.create!(authentication_epoch: 0, staff: operator), OperatorStepUpCeremonyTransaction,
           OperatorStepUpSession, :staff_token, OpBaseOrgRecord,]
        end
      device = token.device_session_record!
      now = parent_model.database_now
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      parent_args = {
        actor_ref: actor.public_id,
        session_ref: token.public_id,
        required_scope: "settings_passkey",
        required_aal: "none",
        purpose: "bootstrap",
        step_up_required: false,
        allowed_methods: ["passkey"],
        return_to: "/identity/passkeys",
      }
      first = parent_model.create_transaction!(**parent_args)
      second = parent_model.create_transaction!(**parent_args)
      session_record = session_model.create!(
        token_key => token, :step_up_ceremony_transaction_ref => first.transaction_id,
        :scope => first.required_scope, :return_to => first.return_to, :status => "PENDING",
        :discard_at => first.expires_at,
      )
      requirement = StepUpRequirement.new(
        scope: "settings_passkey", purpose: "bootstrap", step_up_required: false, allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
        audience: "step_up:#{surface}", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true, ttl: 15.minutes, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )
      ready = Queue.new
      worker = nil
      first.with_lock do
        worker =
          Thread.new do
            actor.class.connection_pool.with_connection(prevent_permanent_checkout: true) do
              op_record.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                other_actor = actor.class.find(actor.id)
                other_token = token.class.find(token.id)
                ready << connection.select_value("SELECT pg_backend_pid()").to_i
                BaseStepUpAdmissionIssuer.call!(
                  actor: other_actor, token: other_token, requirement: requirement, return_to: "/identity/passkeys",
                  base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: other_token,
                )
              end
            end
          rescue BaseAuthAdmissionCoordinator::Denied => e
            e
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end

        pid = Timeout.timeout(10) { ready.pop }
        Timeout.timeout(10) do
          loop do
            waiting =
              op_record.connected_to(role: :writing) do
                op_record.uncached do
                  op_record.lease_connection.select_value(
                    "SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0",
                  )
                end
              end
            break if waiting

            Thread.pass
          end
        end
        session_record.update!(step_up_ceremony_transaction_ref: second.transaction_id)
      end

      result = Timeout.timeout(10) { worker.value }

      assert_instance_of BaseAuthAdmissionCoordinator::Denied, result
      assert_equal "session_binding_mismatch", result.code
      assert_equal second.transaction_id, session_record.reload.step_up_ceremony_transaction_ref
      assert_equal ["pending", "pending"], [first.reload.status, second.reload.status]
    ensure
      begin
        worker&.join(10)
      rescue StandardError
        # The test reports the worker failure; cleanup must still remove its synthetic records.
      end
      session_record&.delete
      first&.delete
      second&.delete
      device&.update!(current_refresh_token_id: nil)
      token&.delete
      device&.delete
      if actor.is_a?(Operator)
        OperatorAuthorityLock.where(operator_id: actor.id).delete_all
        OperatorAccount.where(staff_id: actor.id).delete_all
      end
      actor&.delete
    end
  end
end
