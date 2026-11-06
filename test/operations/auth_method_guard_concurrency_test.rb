# frozen_string_literal: true

require "test_helper"

# The voluntary-removal decision and the terminal mutation must share the Client owner lock.
# Independent connections make the two competing requests observe the real serialization boundary.
#
# Removal invalidates the Ticket before the independent Zenith mutation, so this case cannot run
# inside the fixture transaction and loads only the reference rows its own records need.
class AuthMethodGuardConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []
  fixtures :client_statuses, :client_passkey_statuses, :client_token_kinds,
           :client_token_statuses, :client_token_binding_methods, :client_token_dbsc_statuses

  CLIENT_ID = 9_122_000_000_000

  setup do
    purge_client!(CLIENT_ID)
    @client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: CLIENT_ID)
    @passkeys =
      2.times.map do
        @client.client_passkeys.create!(
          webauthn_id: SecureRandom.uuid,
          public_key: "concurrent-removal-key-#{SecureRandom.hex(8)}",
          uv_verified_at: Time.current,
        )
      end
    @step_up_evidence_by_token_id = {}
    @tokens =
      @passkeys.map do |_passkey|
        token = ClientToken.create!(authentication_epoch: 0, user: @client)
        now = ClientToken.database_now
        token.update!(root_login_established_at: now, established_authentication_method: "passkey")
        token.rotate_refresh_token!(now:)
        token.device_session_record!
        oidc_client = OidcClientRegistry.find!("base-app-ww")
        grant = OpAppGrant.create!(
          authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
          oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
          oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
        )
        grant.issue_refresh_token!(now:)
        @step_up_evidence_by_token_id[token.id] = StepUpEvidenceValue.new(
          acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
          sub: OidcSubject.for(@client, resource_type: "client"), client_id: oidc_client.client_id,
          aud: [oidc_client.aud], jti: grant.oidc_jti,
        )
        token
      end
  end

  teardown do
    purge_client!(CLIENT_ID)
  end

  test "two competing passkey removals retain one usable sign-in path" do
    ready = Queue.new
    release = Queue.new
    threads =
      @passkeys.each_with_index.map do |passkey, index|
        Thread.new do
          ready << true
          release.pop
          AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
            AppZenithRecord.connected_to(role: :writing) do
              actor = Client.find(@client.id)
              credential = ClientPasskey.find(passkey.id)
              OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
                session = ClientToken.find(@tokens.fetch(index).id)
                IdentityCredentialRemovalCommitter.call!(
                  actor: actor, credential: credential, current_session: session,
                  step_up_evidence: @step_up_evidence_by_token_id.fetch(session.id),
                )
              end
            end
          end
        rescue StandardError => e
          e
        end
      end

    2.times { ready.pop }
    2.times { release << true }
    results = threads.map(&:value)

    assert_empty results.grep(Exception), results.inspect
    assert_equal 1, results.count(true)
    assert_equal 1, results.count(false)
    assert_equal 1, ClientPasskey.where(user_id: @client.id, status_id: ClientPasskeyStatus::ACTIVE).count
    assert_predicate Client.find(@client.id), :has_usable_sign_in_capability?
  ensure
    2.times { release << true } if release
    threads&.each(&:join)
  end

  private

  # Committed rows survive the test, so every dependent record is removed before the owner.
  def purge_client!(client_id)
    client = Client.find_by(id: client_id)
    return unless client

    ref = client.public_id
    ClientPasskeyAuditOutbox.where(actor_ref: ref).delete_all
    ClientContactAuditOutbox.where(owner_ref: ref).delete_all
    ClientChronicle.where(subject_type: "Client", subject_id: client_id.to_s).delete_all
    ClientAuthorityLock.where(client_id: client_id).delete_all
    ClientPreference.where(client_id: client_id).delete_all
    ClientTotpCredential.where(user_id: client_id).delete_all
    ClientEmail.where(user_id: client_id).delete_all
    ClientTelephone.where(user_id: client_id).delete_all
    ClientPasskey.where(user_id: client_id).delete_all

    tokens = ClientToken.where(user_id: client_id).select(:id)
    OpAppGrant.where(client_token_id: tokens).delete_all
    ClientStepUpSession.where(user_token_id: tokens).delete_all
    parents = ClientStepUpCeremonyTransaction.where(actor_ref: ref)
    ClientAuthCeremonySession.where(step_up_ceremony_transaction_ref: parents.select(:transaction_id)).delete_all
    parents.delete_all
    ClientDeviceSession.where(user_id: client_id).update_all(current_refresh_token_id: nil)
    ClientToken.where(user_id: client_id).delete_all
    ClientDeviceSession.where(user_id: client_id).delete_all

    Client.where(id: client_id).delete_all
  end
end
