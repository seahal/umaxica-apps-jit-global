# frozen_string_literal: true

require "test_helper"

class AuthorityOwnerFamilyCutoverConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    ClientIdentityState.ensure_defaults!
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    @client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "cutover-concurrency-#{SecureRandom.hex(8)}",
      audience: "acme_app",
      source_record_id: @client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    @persona =
      I18n.with_locale(:en) do
        ClientPersona.create!(client_identity: @identity, title: "Cutover")
      end
    ClientPersonaLifecycle.create!(
      client_persona: @persona,
      state: AuthorityResourceLifecycleStateValue::ACTIVE,
    )
    ClientPersonaOwnership.create!(client_persona: @persona, client: @client, ownership_revision: 0)
  end

  teardown do
    ClientPersonaAuthorityCutover.where(id: 1).delete_all
    ClientPersonaOwnership.where(client_persona_id: @persona&.id).delete_all if @persona
    ClientPersonaLifecycle.where(client_persona_id: @persona&.id).delete_all if @persona
    ClientPersona.where(id: @persona&.id).delete_all if @persona
    ClientIdentity.where(id: @identity&.id).delete_all if @identity
    ClientAuthorityLock.where(client_id: @client&.id).delete_all if @client
    Client.where(id: @client&.id).delete_all if @client
  end

  test "concurrent family cutovers establish one immutable winner" do
    ActiveRecord::Base.connection_handler.clear_active_connections!

    results =
      concurrently(2) do
        AuthorityOwnerFamilyCutoverOperation.call(surface: :app, resource_kind: :client_persona)
      end

    assert_equal 1, results.count { |result| result.status == :established }, results.inspect
    assert_equal 1, results.count { |result| result.status == :already_cut_over }, results.inspect
    assert_equal 1, ClientPersonaAuthorityCutover.count
  end

  private

  # Separate writer connections are required to exercise the PostgreSQL table-lock boundary.
  # rubocop:disable ThreadSafety/NewThread
  def concurrently(count)
    ready = Queue.new
    release = Queue.new
    threads =
      Array.new(count) do
        Thread.new do
          AppRpRecord.connection_pool.with_connection do
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
end
