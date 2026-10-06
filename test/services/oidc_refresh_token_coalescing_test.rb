# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcRefreshTokenCoalescingTest < ActiveSupport::TestCase
  class MemoryCoordinationStore
    attr_reader :acquisitions, :publications

    def initialize(publication_error: nil)
      @owner = nil
      @publication_error = publication_error
      @acquisitions = 0
      @publications = []
    end

    def acquire(resource_type:, rp_session_public_id:, owner:)
      @acquisitions += 1
      return false if @owner

      @owner = [resource_type, rp_session_public_id, owner]
      true
    end

    def publish(resource_type:, rp_session_public_id:, ciphertext:)
      raise @publication_error if @publication_error

      @publications << [resource_type, rp_session_public_id, ciphertext]
      true
    end

    def release(resource_type:, rp_session_public_id:, owner:)
      @owner = nil if @owner == [resource_type, rp_session_public_id, owner]
      true
    end
  end

  setup do
    @client = clients(:one)
    @root_token = ClientToken.create!(user: @client, discard_at: 1.day.from_now)
    @usage = ClientRpSession.create!(
      client_token: @root_token,
      oidc_client_id: "core-app",
      oidc_scope: "openid profile",
    )
    @refresh_token = @usage.issue_refresh_token!
  end

  test "the same predecessor receives the exact committed successor response once" do
    store = MemoryCoordinationStore.new
    first = rotate_with(store, @refresh_token)
    second = rotate_with(store, @refresh_token)

    assert_predicate first, :success?
    assert_predicate second, :success?
    assert_equal first.token_response, second.token_response
    assert_equal 1, @usage.reload.refresh_generation
    assert_not_predicate @usage, :revoked?
    assert_operator store.acquisitions, :>=, 1
    assert_equal 1, store.publications.length
  end

  test "Valkey failure before lease acquisition leaves the RP Session untouched" do
    store = MemoryCoordinationStore.new
    store.define_singleton_method(:acquire) do |**|
      raise Umaxica::Valkey::Unavailable, "test coordination outage"
    end

    assert_raises(Umaxica::Valkey::Unavailable) do
      rotate_with(store, @refresh_token)
    end

    assert_equal 0, @usage.reload.refresh_generation
    assert_equal @usage.refresh_token_digest, ClientRpSession.find(@usage.id).refresh_token_digest
    assert_not_predicate @usage, :revoked?
  end

  test "a publication failure leaves a durable receipt for a later redelivery" do
    failing_store = MemoryCoordinationStore.new(
      publication_error: Umaxica::Valkey::Unavailable.new("publication failed"),
    )
    failed = rotate_with(failing_store, @refresh_token)

    assert_not failed.success?
    assert_equal :delivery_publication_failed, failed.reason
    assert_equal 1, @usage.reload.refresh_generation
    assert_predicate @usage.refresh_delivery_ciphertext, :present?

    recovered = rotate_with(MemoryCoordinationStore.new, @refresh_token)

    assert_predicate recovered, :success?
    assert_equal failed.token.refresh_token_digest, recovered.token.refresh_token_digest
    assert_equal 1, @usage.reload.refresh_generation
  end

  test "a token two generations old is not rescued by the receipt" do
    store = MemoryCoordinationStore.new
    first = rotate_with(store, @refresh_token)
    second = rotate_with(MemoryCoordinationStore.new, first.refresh_token)
    old_replay = rotate_with(MemoryCoordinationStore.new, @refresh_token)

    assert_predicate first, :success?
    assert_predicate second, :success?
    assert_not old_replay.success?
    assert_equal :invalid_digest, old_replay.reason
    assert_equal 2, @usage.reload.refresh_generation
    assert_not_predicate @usage, :revoked?
  end

  test "receipt decryption errors fail closed without another rotation" do
    first = rotate_with(MemoryCoordinationStore.new, @refresh_token)
    @usage.update!(refresh_delivery_ciphertext: "corrupt")

    result = rotate_with(MemoryCoordinationStore.new, @refresh_token)

    assert_predicate first, :success?
    assert_not result.success?
    assert_equal :delivery_receipt_invalid, result.reason
    assert_equal 1, @usage.reload.refresh_generation
  end

  test "a receipt is redelivered just inside the fixed five-second TTL" do
    issued_at = ClientRpSession.database_now
    first = rotate_with_at(MemoryCoordinationStore.new, @refresh_token, issued_at)
    expiry = @usage.reload.refresh_delivery_expires_at

    redelivered = rotate_with_at(MemoryCoordinationStore.new, @refresh_token, expiry - 0.001.seconds)

    assert_predicate first, :success?
    assert_predicate redelivered, :success?
    assert_equal first.token_response, redelivered.token_response
    assert_not_predicate @usage.reload, :revoked?
  end

  test "a receipt at the exact five-second boundary is a replay" do
    issued_at = ClientRpSession.database_now
    rotate_with_at(MemoryCoordinationStore.new, @refresh_token, issued_at)
    expiry = @usage.reload.refresh_delivery_expires_at

    replay = rotate_with_at(MemoryCoordinationStore.new, @refresh_token, expiry)

    assert_not_predicate replay, :success?
    assert_equal :refresh_token_reuse_detected, replay.reason
    assert_predicate @usage.reload, :revoked?
  end

  test "a receipt 5.001 seconds after issuance is a replay" do
    issued_at = ClientRpSession.database_now
    rotate_with_at(MemoryCoordinationStore.new, @refresh_token, issued_at)
    expiry = @usage.reload.refresh_delivery_expires_at

    replay = rotate_with_at(MemoryCoordinationStore.new, @refresh_token, expiry + 0.001.seconds)

    assert_not_predicate replay, :success?
    assert_equal :refresh_token_reuse_detected, replay.reason
    assert_predicate @usage.reload, :revoked?
  end

  test "a revoked parent blocks receipt redelivery without another rotation" do
    first = rotate_with(MemoryCoordinationStore.new, @refresh_token)
    @root_token.revoke!

    redelivered = rotate_with(MemoryCoordinationStore.new, @refresh_token)

    assert_predicate first, :success?
    assert_not_predicate redelivered, :success?
    assert_equal :inactive_token, redelivered.reason
    assert_equal 1, @usage.reload.refresh_generation
  end

  test "a reversed response is rejected before rotation commits" do
    original_digest = @usage.refresh_token_digest

    assert_raises(OidcRefreshDeliveryReceipt::Invalid) do
      rotate_with(MemoryCoordinationStore.new, @refresh_token, expires_in: 2.days.to_i)
    end

    assert_equal original_digest, @usage.reload.refresh_token_digest
    assert_equal 0, @usage.refresh_generation
    assert_not_predicate @usage, :refresh_delivery_receipt_present?
  end

  private

  def rotate_with(store, refresh_token, expires_in: 300)
    OidcRefreshTokenIssuer.call(
      refresh_token: refresh_token,
      client_id: "core-app",
      resource_type: "client",
      coordination_store: store,
      response_builder: lambda do |usage:, refresh_token:, now:, **_|
        {
          access_token: "access-#{usage.refresh_generation}",
          token_type: "Bearer",
          expires_in: expires_in,
          refresh_token: refresh_token,
          refresh_token_expires_in: [(usage.refresh_token_expires_at - now).to_i, 0].max,
          id_token: "id-#{usage.refresh_generation}",
        }
      end,
    )
  end

  def rotate_with_at(store, refresh_token, now)
    ClientRpSession.stub(:database_now, now) do
      rotate_with(store, refresh_token)
    end
  end
end

class OidcRefreshTokenCoalescingConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  class BarrierCoordinationStore
    attr_reader :acquisitions

    def initialize
      @mutex = Mutex.new
      @owner = nil
      @acquisitions = 0
      @first_lease_blocked = false
      @first_acquired = Queue.new
      @second_contended = Queue.new
      @release_first = Queue.new
    end

    def acquire(resource_type:, rp_session_public_id:, owner:)
      first = false
      block_lease = false
      @mutex.synchronize do
        @acquisitions += 1
        if @owner.nil?
          @owner = [resource_type, rp_session_public_id, owner]
          first = true
          block_lease = !@first_lease_blocked
          @first_lease_blocked = true
        else
          @second_contended << true
        end
      end
      return false unless first

      return true unless block_lease

      @first_acquired << true
      @release_first.pop
      true
    end

    def publish(resource_type:, rp_session_public_id:, ciphertext:)
      true
    end

    def release(resource_type:, rp_session_public_id:, owner:)
      @mutex.synchronize do
        @owner = nil if @owner == [resource_type, rp_session_public_id, owner]
      end
      true
    end

    def wait_until_first_acquired
      @first_acquired.pop
    end

    def wait_until_second_contended
      @second_contended.pop
    end

    def release_first
      @release_first << true
    end
  end

  setup do
    @client = clients(:one)
    @root_token = ClientToken.create!(user: @client, discard_at: 1.day.from_now)
    @usage = ClientRpSession.create!(
      client_token: @root_token,
      oidc_client_id: "core-app",
      oidc_scope: "openid profile",
    )
    @refresh_token = @usage.issue_refresh_token!
  end

  teardown do
    usage_id = @usage&.id
    root_token_id = @root_token&.id
    device_session_id = @root_token&.device_session_id
    ClientRpSession.where(id: usage_id).delete_all if usage_id
    ClientRpSession.where(device_session_id: device_session_id).delete_all if device_session_id
    ClientToken.where(id: root_token_id).delete_all if root_token_id
    ClientDeviceSession.where(id: device_session_id).delete_all if device_session_id
  end

  test "barrier-driven simultaneous presentation rotates once and redelivers the same response" do
    store = BarrierCoordinationStore.new
    ready = Queue.new
    start = Queue.new
    AppTicketRecord.connection_pool.release_connection
    threads =
      2.times.map do
        Thread.new do # rubocop:disable ThreadSafety/NewThread
          ready << true
          start.pop
          AppTicketRecord.connection_pool.with_connection do
            OidcRefreshTokenIssuer.call(
              refresh_token: @refresh_token,
              client_id: "core-app",
              resource_type: "client",
              coordination_store: store,
              response_builder: method(:response_for),
            )
          end
        rescue StandardError => e
          e
        end
      end

    2.times { ready.pop }
    2.times { start << true }
    store.wait_until_first_acquired
    store.wait_until_second_contended
    store.release_first
    results = threads.map(&:value)

    assert_empty results.grep(StandardError), results.grep(StandardError).map(&:message).join("; ")
    assert_equal 1, @usage.reload.refresh_generation
    assert_equal 1, results.map { |result| result.token_response }.uniq.length
    assert results.all?(&:success?)
    assert_operator store.acquisitions, :>=, 2
  ensure
    store&.release_first
    threads&.each { |thread| thread.join(10) }
  end

  private

  def response_for(usage:, refresh_token:, now:, **_)
    {
      access_token: "access-#{usage.refresh_generation}",
      token_type: "Bearer",
      expires_in: 300,
      refresh_token: refresh_token,
      refresh_token_expires_in: [(usage.refresh_token_expires_at - now).to_i, 0].max,
      id_token: "id-#{usage.refresh_generation}",
    }
  end
end
