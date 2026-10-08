# frozen_string_literal: true

require "test_helper"
require "timeout"

class StepUpFinalizationRestartRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "finalization holding the source owner lock wins over cancel-and-start on an independent Ticket connection" do
    # Fixture sequence resets can reuse IDs held by committed rows in the separate Ticket database.
    actor = Client.create!(id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE)
    credential = actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
    token = ClientToken.create!(id: SecureRandom.random_number(1 << 60) + 1_000_000_000, user: actor)
    device = token.device_session
    requirement = StepUpRequirement.new(
      scope: "settings_passkey", purpose: "step_up", step_up_required: true, allowed_methods: [:passkey],
      phishing_resistant_required: true, user_verification_required: true, full_reauthentication_required: false,
      audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true, ttl: 15.minutes, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor:, token:, requirement:, return_to: "/identity/passkeys",
      base_browser_nonce: "race-browser-nonce", base_token: token,
    )
    transaction = issuance.transaction
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "step_up", binding:, raw_auth_sid: raw_sid,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
    # Synthetic evidence isolates arbitration; separate tests verify WebAuthn and actual HTTP admission.
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
      verified_at: transaction.class.database_now, verified_credential_ref: credential.public_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(transaction:, ceremony_session_ref: ceremony.id.to_s)
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    finalizer =
      Concurrent::Future.execute do
        Client.connection_pool.with_connection(prevent_permanent_checkout: true) do
          ClientStepUpCeremonyTransaction.connection_pool.with_connection(
            prevent_permanent_checkout: true,
          ) do |connection|
            principal = Client.find(actor.id)
            root = ClientToken.find(token.id)
            parent = ClientStepUpCeremonyTransaction.find(transaction.id)
            principal.with_lock do
              ready << connection.select_value("SELECT pg_backend_pid()")
              release.pop
              IdentityStepUpCeremonyFreshnessCommitter.call!(
                actor: principal, token: root, transaction: parent, requirement:, result_reference: result.reference,
              )
            end
          end
        end
      ensure
        # Leases taken on this pooled thread outlive the future unless released here.
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    finalizer_backend = Timeout.timeout(10) { ready.pop }
    restarter =
      Concurrent::Future.execute do
        Client.connection_pool.with_connection(prevent_permanent_checkout: true) do
          ClientStepUpCeremonyTransaction.connection_pool.with_connection(
            prevent_permanent_checkout: true,
          ) do |connection|
            principal = Client.find(actor.id)
            root = ClientToken.find(token.id)
            parent = ClientStepUpCeremonyTransaction.find(transaction.id)
            ready << [connection.select_value("SELECT pg_backend_pid()"), parent.status]
            BaseStepUpCancelAndStartCommitter.call!(
              actor: principal, token: root, previous_transaction: parent, requirement:,
              return_to: "/identity/passkeys",
              base_browser_nonce: "race-browser-nonce", base_token: root,
            )
          end
        end
      ensure
        # Leases taken on this pooled thread outlive the future unless released here.
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
    restarter_backend, stale_status = Timeout.timeout(10) { ready.pop }
    release << true
    finalized, outcome = Timeout.timeout(10) { [finalizer.value!, restarter.value!] }

    assert_not_equal finalizer_backend, restarter_backend
    assert_equal "verified", stale_status
    assert_instance_of BaseAuthAdmissionCoordinator::TerminalOutcome, outcome
    assert_equal [transaction.id, transaction.id, "consumed", nil, true],
                 [finalized.id, outcome.transaction.id, transaction.reload.status, transaction.canceled_at,
                  ceremony.reload.completed?,]
    assert_equal transaction.verified_at, token.reload.last_step_up_at
    assert_equal 1, ClientStepUpCeremonyTransaction.where(session_ref: token.public_id).count
    assert_equal 1, ClientAuthAdmissionBinding.where(step_up_ceremony_transaction_id: transaction.id).count
  ensure
    release << true if release
    [finalizer, restarter].compact.each { |worker| worker.wait(10) }
    binding&.delete
    ceremony&.delete
    attached&.delete
    ClientStepUpSession.where(user_token_id: token.id).delete_all if token
    transaction&.delete
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    credential&.delete
    actor&.delete
  end
end
