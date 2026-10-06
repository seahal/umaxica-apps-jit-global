# frozen_string_literal: true

require "test_helper"

# The voluntary-removal decision and the terminal mutation must share the Client owner lock.
# Independent connections make the two competing requests observe the real serialization boundary.
# rubocop:disable ThreadSafety/NewThread
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
    @tokens = 2.times.map { ClientToken.create!(user: @client) }
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
              AppTicketRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do
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
# rubocop:enable ThreadSafety/NewThread
