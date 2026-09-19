# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientPersonaCreatorConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    ClientIdentityState.ensure_defaults!
    @owner = Client.create!(id: unique_client_id, status_id: ClientStatus::ACTIVE)
    @identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "creator-concurrency-#{SecureRandom.hex(8)}",
      audience: "acme_app",
      source_record_id: @owner.id,
      status_id: ClientIdentityState::ACTIVE,
    )
  end

  teardown do
    next unless @owner

    if @identity
      persona_ids = ClientPersona.where(client_identity_id: @identity.id).pluck(:id)
      ClientPersonaOwnership.where(client_persona_id: persona_ids).delete_all
      ClientPersona.where(id: persona_ids).delete_all
      ClientIdentity.where(id: @identity.id).delete_all
    end
    ClientAuthorityLock.where(client_id: @owner.id).delete_all
    Client.where(id: @owner.id).delete_all
  end

  test "concurrent creation for one identity yields one resource and one winner" do
    # The test database pool is intentionally two connections. Release the setup
    # thread's idle checkout so both race participants can obtain independent
    # writer connections instead of waiting for a third connection forever.
    ActiveRecord::Base.connection_handler.clear_active_connections!

    results =
      concurrently(2) do
        ClientPersonaCreator.call(
          actor: Client.find(@owner.id),
          owner: Client.find(@owner.id),
          client_identity: ClientIdentity.find(@identity.id),
          title: "Concurrent",
        )
      end

    assert_equal 1, results.count { |result| result.is_a?(ClientPersona) }
    failures =
      results.select do |result|
        result.is_a?(ActiveRecord::RecordInvalid) || result.is_a?(ActiveRecord::RecordNotUnique)
      end

    assert_equal 1, failures.size
    assert_equal 1, ClientPersona.where(client_identity_id: @identity.id).count
    assert_equal 1, ClientPersonaOwnership.where(client_id: @owner.id).count
  end

  private

  # Separate checked-out connections are required; one connection cannot observe
  # the PostgreSQL lock/unique-index race this test is intended to cover.
  # rubocop:disable ThreadSafety/NewThread
  def concurrently(count)
    ready = Queue.new
    release = Queue.new
    threads =
      Array.new(count) do
        Thread.new do
          AppZenithRecord.connection_pool.with_connection do
            ready << true
            release.pop
            yield
          end
        rescue StandardError => e
          e
        end
      end

    count.times { ready.pop }
    count.times { release << true }
    threads.map(&:value)
  end
  # rubocop:enable ThreadSafety/NewThread

  def unique_client_id
    loop do
      candidate = 2_100_000_000 + SecureRandom.random_number(100_000_000)
      next if Client.exists?(id: candidate)
      next if ClientIdentity.exists?(source_record_id: candidate)

      break candidate
    end
  end
end
