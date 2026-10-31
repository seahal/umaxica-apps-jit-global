# frozen_string_literal: true

require "test_helper"
require "timeout"
require "webauthn/fake_client"

class IdentityPasskeyCandidateDeviceConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "device revocation during attestation prevents candidate recording" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
    )
    token = ClientToken.create!(
      authentication_epoch: 0, user: actor, id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
    )
    device = token.device_session_record!
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
      required_scope: "settings_passkey", required_aal: "none", step_up_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      phishing_resistant_required: false, audience: "step_up:app", token_binding: token.public_id,
      require_session_binding: true, allowed_methods: ["passkey"], return_to: "/identity/passkeys",
    )
    record = ClientStepUpSession.create!(
      user_token: token, scope: "settings_passkey", return_to: "/identity/passkeys", status: "PENDING",
      step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
    )
    fake = WebAuthn::FakeClient.new("https://auth.umaxica.app", encoding: :base64url)
    config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.app", origin: fake.origin)
    challenge = SecureRandom.urlsafe_base64(32)
    reference = record.issue_bound_passkey_registration_challenge!(
      transaction: transaction, challenge: challenge, rp_id: config.rp_id, origin: config.origin,
    )
    attestation = fake.create(challenge: challenge, user_verified: true)
    ready = Queue.new
    proceed = Queue.new
    verifier = Webauthn::RegistrationVerifier.method(:verify!)
    pause_after_attestation =
      lambda do |**arguments|
        result = verifier.call(**arguments)
        ready << true
        proceed.pop
        result
      end
    worker = nil
    Webauthn::RegistrationVerifier.stub(:verify!, pause_after_attestation) do
      worker =
        Thread.new do
          Client.connection_pool.with_connection(prevent_permanent_checkout: true) do
            OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
              IdentityPasskeyRegistrationVerificationCommitter.call!(
                actor: Client.find(actor.id), token: ClientToken.find(token.id),
                transaction: ClientStepUpCeremonyTransaction.find(transaction.id),
                session_record: ClientStepUpSession.find(record.id), config: config,
                reference: reference, credential_params: attestation, description: "Laptop",
              )
            end
          end
        rescue IdentityPasskeyCeremonyContract::Error => e
          e
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end

      assert Timeout.timeout(10) { ready.pop }
      device.revoke!
      proceed << true

      assert_instance_of IdentityPasskeyCeremonyContract::Error, Timeout.timeout(10) { worker.value }
    end
    assert_equal "pending", transaction.reload.status
    assert_not_nil record.reload.passkey_challenge_consumed_at
    assert_not IdentityPasskeyCeremonyCandidate.exists?(step_up_ceremony_transaction_ref: transaction.transaction_id)
  ensure
    proceed << true if proceed
    worker&.join
    if transaction
      IdentityPasskeyCeremonyCandidate.where(step_up_ceremony_transaction_ref: transaction.transaction_id).delete_all
    end
    record&.delete
    transaction&.delete
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    actor&.delete
  end
end
