# frozen_string_literal: true

require "test_helper"

# The voluntary-removal decision and the terminal mutation must share the Client owner lock.
# Independent connections make the two competing requests observe the real serialization boundary.
class AuthMethodGuardConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @client = Client.create!(id: 9_122_000_000_000)
    @passkeys =
      2.times.map do
        @client.client_passkeys.create!(
          webauthn_id: SecureRandom.uuid,
          public_key: "concurrent-removal-key-#{SecureRandom.hex(8)}",
          uv_verified_at: Time.current,
        )
      end
    @tokens =
      @passkeys.map do |passkey|
        ClientToken.create!(
          user: @client, last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_passkey",
          last_step_up_method: "passkey", last_step_up_credential_ref: passkey.public_id,
          last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
          last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
          last_step_up_full_reauthentication: false,
        ).tap do |token|
          token.update!(last_step_up_session_public_id: token.public_id)
        end
      end
  end

  teardown do
    ClientToken.where(user_id: @client.id).delete_all
    ClientPasskey.where(user_id: @client.id).delete_all
    Client.where(id: @client.id).delete_all
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
end
