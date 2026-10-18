# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcRefreshTokenCoalescingTest < ActiveSupport::TestCase
  setup do
    namespace = Umaxica::Valkey::Namespaces.rp_refresh(**Umaxica::Valkey::Namespaces.runtime_scope)
    @coordination_connection = Umaxica::Valkey::Connection.new(namespace: namespace)
    @coordination_forwarder = Umaxica::Valkey::Connection.new(namespace: namespace)
    @client = clients(:one)
    @root_token = ClientToken.create!(user: @client, discard_at: 1.day.from_now)
    @usage = OpAppGrant.create!(
      client_token: @root_token,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
    @refresh_token = @usage.issue_refresh_token!
  end

  teardown do
    @coordination_connection.close
    @coordination_forwarder.close
  end

  test "the same predecessor receives the exact committed successor response once" do
    store = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
    lease_acquisitions = Queue.new
    publications = Queue.new
    @coordination_connection.stub(
      :call, ->(command, *arguments) {
        result = @coordination_forwarder.call(command, *arguments)
        lease_acquisitions << true if command == "SET" && arguments.include?("NX") && result == "OK"
        publications << true if command == "SET" && arguments.include?("EX")
        result
      },
    ) do
      first =
        begin
          fv5073 = store
          fv5074 = @refresh_token
          fv5072 = 300
          OidcRefreshTokenIssuer.call(
            refresh_token: fv5074,
            client_id: "core-app-jp",
            resource_type: "client",
            coordination_store: fv5073,
            response_builder: lambda do |usage:, refresh_token:, now:, **_|
              {
                access_token: "access-#{usage.refresh_generation}",
                token_type: "Bearer",
                expires_in: fv5072,
                refresh_token: refresh_token,
                refresh_token_expires_in: [
                  (usage.refresh_token_expires_at - now).to_i, 0,
                ].max,
                id_token: "id-#{usage.refresh_generation}",
              }
            end,
          )
        end
      second =
        begin
          fv5070 = store
          fv5071 = @refresh_token
          fv5069 = 300
          OidcRefreshTokenIssuer.call(
            refresh_token: fv5071,
            client_id: "core-app-jp",
            resource_type: "client",
            coordination_store: fv5070,
            response_builder: lambda do |usage:, refresh_token:, now:, **_|
              {
                access_token: "access-#{usage.refresh_generation}",
                token_type: "Bearer",
                expires_in: fv5069,
                refresh_token: refresh_token,
                refresh_token_expires_in: [
                  (usage.refresh_token_expires_at - now).to_i, 0,
                ].max,
                id_token: "id-#{usage.refresh_generation}",
              }
            end,
          )
        end

      assert_predicate first, :success?
      assert_predicate second, :success?
      assert_equal first.token_response, second.token_response
      assert_equal 1, @usage.reload.refresh_generation
      assert_not_predicate @usage, :revoked?
      assert_operator lease_acquisitions.size, :>=, 1
      assert_equal 1, publications.size
      assert_equal @usage.refresh_delivery_ciphertext,
                   store.read(resource_type: "client", rp_session_public_id: @usage.public_id)
    end
  end

  test "Valkey failure before lease acquisition leaves the RP Session untouched" do
    store = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
    assert_raises(Umaxica::Valkey::Unavailable) do
      @coordination_connection.stub(
        :call, ->(*) {
                 raise Umaxica::Valkey::Unavailable, "test coordination outage"
               },
      ) do
        begin
          fv5067 = store
          fv5068 = @refresh_token
          fv5066 = 300
          OidcRefreshTokenIssuer.call(
            refresh_token: fv5068,
            client_id: "core-app-jp",
            resource_type: "client",
            coordination_store: fv5067,
            response_builder: lambda do |usage:, refresh_token:, now:, **_|
              {
                access_token: "access-#{usage.refresh_generation}",
                token_type: "Bearer",
                expires_in: fv5066,
                refresh_token: refresh_token,
                refresh_token_expires_in: [
                  (usage.refresh_token_expires_at - now).to_i, 0,
                ].max,
                id_token: "id-#{usage.refresh_generation}",
              }
            end,
          )
        end
      end
    end
    assert_equal 0, @usage.reload.refresh_generation
    assert_equal @usage.refresh_token_digest, OpAppGrant.find(@usage.id).refresh_token_digest
    assert_not_predicate @usage, :revoked?
  end

  test "a publication failure leaves a durable receipt for a later redelivery" do
    failing_store = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
    failed =
      @coordination_connection.stub(
        :call, ->(command, *arguments) {
                 if command == "SET" && arguments.include?("EX")
                   raise Umaxica::Valkey::Unavailable, "publication failed"
                 end

                 @coordination_forwarder.call(command, *arguments)
               },
      ) do
        begin
          fv5064 = failing_store
          fv5065 = @refresh_token
          fv5063 = 300
          OidcRefreshTokenIssuer.call(
            refresh_token: fv5065,
            client_id: "core-app-jp",
            resource_type: "client",
            coordination_store: fv5064,
            response_builder: lambda do |usage:, refresh_token:, now:, **_|
              {
                access_token: "access-#{usage.refresh_generation}",
                token_type: "Bearer",
                expires_in: fv5063,
                refresh_token: refresh_token,
                refresh_token_expires_in: [
                  (usage.refresh_token_expires_at - now).to_i, 0,
                ].max,
                id_token: "id-#{usage.refresh_generation}",
              }
            end,
          )
        end
      end

    assert_not failed.success?
    assert_equal :delivery_publication_failed, failed.reason
    assert_equal 1, @usage.reload.refresh_generation
    assert_predicate @usage.refresh_delivery_ciphertext, :present?

    recovered =
      begin
        fv5061 = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
        fv5062 = @refresh_token
        fv5060 = 300
        OidcRefreshTokenIssuer.call(
          refresh_token: fv5062,
          client_id: "core-app-jp",
          resource_type: "client",
          coordination_store: fv5061,
          response_builder: lambda do |usage:, refresh_token:, now:, **_|
            {
              access_token: "access-#{usage.refresh_generation}",
              token_type: "Bearer",
              expires_in: fv5060,
              refresh_token: refresh_token,
              refresh_token_expires_in: [
                (usage.refresh_token_expires_at - now).to_i, 0,
              ].max,
              id_token: "id-#{usage.refresh_generation}",
            }
          end,
        )
      end

    assert_predicate recovered, :success?
    assert_equal failed.token.refresh_token_digest, recovered.token.refresh_token_digest
    assert_equal 1, @usage.reload.refresh_generation
  end

  test "a token two generations old is not rescued by the receipt" do
    store = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
    first =
      begin
        fv5058 = store
        fv5059 = @refresh_token
        fv5057 = 300
        OidcRefreshTokenIssuer.call(
          refresh_token: fv5059,
          client_id: "core-app-jp",
          resource_type: "client",
          coordination_store: fv5058,
          response_builder: lambda do |usage:, refresh_token:, now:, **_|
            {
              access_token: "access-#{usage.refresh_generation}",
              token_type: "Bearer",
              expires_in: fv5057,
              refresh_token: refresh_token,
              refresh_token_expires_in: [
                (usage.refresh_token_expires_at - now).to_i, 0,
              ].max,
              id_token: "id-#{usage.refresh_generation}",
            }
          end,
        )
      end
    second =
      begin
        fv5055 = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
        fv5056 = first.refresh_token
        fv5054 = 300
        OidcRefreshTokenIssuer.call(
          refresh_token: fv5056,
          client_id: "core-app-jp",
          resource_type: "client",
          coordination_store: fv5055,
          response_builder: lambda do |usage:, refresh_token:, now:, **_|
            {
              access_token: "access-#{usage.refresh_generation}",
              token_type: "Bearer",
              expires_in: fv5054,
              refresh_token: refresh_token,
              refresh_token_expires_in: [
                (usage.refresh_token_expires_at - now).to_i, 0,
              ].max,
              id_token: "id-#{usage.refresh_generation}",
            }
          end,
        )
      end
    old_replay =
      begin
        fv5052 = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
        fv5053 = @refresh_token
        fv5051 = 300
        OidcRefreshTokenIssuer.call(
          refresh_token: fv5053,
          client_id: "core-app-jp",
          resource_type: "client",
          coordination_store: fv5052,
          response_builder: lambda do |usage:, refresh_token:, now:, **_|
            {
              access_token: "access-#{usage.refresh_generation}",
              token_type: "Bearer",
              expires_in: fv5051,
              refresh_token: refresh_token,
              refresh_token_expires_in: [
                (usage.refresh_token_expires_at - now).to_i, 0,
              ].max,
              id_token: "id-#{usage.refresh_generation}",
            }
          end,
        )
      end

    assert_predicate first, :success?
    assert_predicate second, :success?
    assert_not old_replay.success?
    assert_equal :invalid_digest, old_replay.reason
    assert_equal 2, @usage.reload.refresh_generation
    assert_not_predicate @usage, :revoked?
  end

  test "receipt decryption errors fail closed without another rotation" do
    first =
      begin
        fv5049 = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
        fv5050 = @refresh_token
        fv5048 = 300
        OidcRefreshTokenIssuer.call(
          refresh_token: fv5050,
          client_id: "core-app-jp",
          resource_type: "client",
          coordination_store: fv5049,
          response_builder: lambda do |usage:, refresh_token:, now:, **_|
            {
              access_token: "access-#{usage.refresh_generation}",
              token_type: "Bearer",
              expires_in: fv5048,
              refresh_token: refresh_token,
              refresh_token_expires_in: [
                (usage.refresh_token_expires_at - now).to_i, 0,
              ].max,
              id_token: "id-#{usage.refresh_generation}",
            }
          end,
        )
      end
    @usage.update!(refresh_delivery_ciphertext: "corrupt")

    result =
      begin
        fv5046 = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
        fv5047 = @refresh_token
        fv5045 = 300
        OidcRefreshTokenIssuer.call(
          refresh_token: fv5047,
          client_id: "core-app-jp",
          resource_type: "client",
          coordination_store: fv5046,
          response_builder: lambda do |usage:, refresh_token:, now:, **_|
            {
              access_token: "access-#{usage.refresh_generation}",
              token_type: "Bearer",
              expires_in: fv5045,
              refresh_token: refresh_token,
              refresh_token_expires_in: [
                (usage.refresh_token_expires_at - now).to_i, 0,
              ].max,
              id_token: "id-#{usage.refresh_generation}",
            }
          end,
        )
      end

    assert_predicate first, :success?
    assert_not result.success?
    assert_equal :delivery_receipt_invalid, result.reason
    assert_equal 1, @usage.reload.refresh_generation
  end

  test "a receipt is redelivered just inside the fixed five-second TTL" do
    issued_at = OpAppGrant.database_now
    first =
      begin
        fv5043 = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
        fv5042 = @refresh_token
        fv5044 = issued_at
        OpAppGrant.stub(:database_now, fv5044) do
          begin
            fv5040 = fv5043
            fv5041 = fv5042
            fv5039 = 300
            OidcRefreshTokenIssuer.call(
              refresh_token: fv5041,
              client_id: "core-app-jp",
              resource_type: "client",
              coordination_store: fv5040,
              response_builder: lambda do |usage:, refresh_token:, now:, **_|
                {
                  access_token: "access-#{usage.refresh_generation}",
                  token_type: "Bearer",
                  expires_in: fv5039,
                  refresh_token: refresh_token,
                  refresh_token_expires_in: [
                    (usage.refresh_token_expires_at - now).to_i, 0,
                  ].max,
                  id_token: "id-#{usage.refresh_generation}",
                }
              end,
            )
          end
        end
      end
    expiry = @usage.reload.refresh_delivery_expires_at

    redelivered =
      begin
        fv5037 = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
        fv5036 = @refresh_token
        fv5038 = expiry - 0.001.seconds
        OpAppGrant.stub(:database_now, fv5038) do
          begin
            fv5034 = fv5037
            fv5035 = fv5036
            fv5033 = 300
            OidcRefreshTokenIssuer.call(
              refresh_token: fv5035,
              client_id: "core-app-jp",
              resource_type: "client",
              coordination_store: fv5034,
              response_builder: lambda do |usage:, refresh_token:, now:, **_|
                {
                  access_token: "access-#{usage.refresh_generation}",
                  token_type: "Bearer",
                  expires_in: fv5033,
                  refresh_token: refresh_token,
                  refresh_token_expires_in: [
                    (usage.refresh_token_expires_at - now).to_i, 0,
                  ].max,
                  id_token: "id-#{usage.refresh_generation}",
                }
              end,
            )
          end
        end
      end

    assert_predicate first, :success?
    assert_predicate redelivered, :success?
    assert_equal first.token_response, redelivered.token_response
    assert_not_predicate @usage.reload, :revoked?
  end

  test "a receipt at the exact five-second boundary is a replay" do
    issued_at = OpAppGrant.database_now
    begin
      fv5031 = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
      fv5030 = @refresh_token
      fv5032 = issued_at
      OpAppGrant.stub(:database_now, fv5032) do
        begin
          fv5028 = fv5031
          fv5029 = fv5030
          fv5027 = 300
          OidcRefreshTokenIssuer.call(
            refresh_token: fv5029,
            client_id: "core-app-jp",
            resource_type: "client",
            coordination_store: fv5028,
            response_builder: lambda do |usage:, refresh_token:, now:, **_|
              {
                access_token: "access-#{usage.refresh_generation}",
                token_type: "Bearer",
                expires_in: fv5027,
                refresh_token: refresh_token,
                refresh_token_expires_in: [
                  (usage.refresh_token_expires_at - now).to_i, 0,
                ].max,
                id_token: "id-#{usage.refresh_generation}",
              }
            end,
          )
        end
      end
    end
    expiry = @usage.reload.refresh_delivery_expires_at

    replay =
      begin
        fv5025 = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
        fv5024 = @refresh_token
        fv5026 = expiry
        OpAppGrant.stub(:database_now, fv5026) do
          begin
            fv5022 = fv5025
            fv5023 = fv5024
            fv5021 = 300
            OidcRefreshTokenIssuer.call(
              refresh_token: fv5023,
              client_id: "core-app-jp",
              resource_type: "client",
              coordination_store: fv5022,
              response_builder: lambda do |usage:, refresh_token:, now:, **_|
                {
                  access_token: "access-#{usage.refresh_generation}",
                  token_type: "Bearer",
                  expires_in: fv5021,
                  refresh_token: refresh_token,
                  refresh_token_expires_in: [
                    (usage.refresh_token_expires_at - now).to_i, 0,
                  ].max,
                  id_token: "id-#{usage.refresh_generation}",
                }
              end,
            )
          end
        end
      end

    assert_not_predicate replay, :success?
    assert_equal :refresh_token_reuse_detected, replay.reason
    assert_predicate @usage.reload, :revoked?
  end

  test "a receipt 5.001 seconds after issuance is a replay" do
    issued_at = OpAppGrant.database_now
    begin
      fv5019 = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
      fv5018 = @refresh_token
      fv5020 = issued_at
      OpAppGrant.stub(:database_now, fv5020) do
        begin
          fv5016 = fv5019
          fv5017 = fv5018
          fv5015 = 300
          OidcRefreshTokenIssuer.call(
            refresh_token: fv5017,
            client_id: "core-app-jp",
            resource_type: "client",
            coordination_store: fv5016,
            response_builder: lambda do |usage:, refresh_token:, now:, **_|
              {
                access_token: "access-#{usage.refresh_generation}",
                token_type: "Bearer",
                expires_in: fv5015,
                refresh_token: refresh_token,
                refresh_token_expires_in: [
                  (usage.refresh_token_expires_at - now).to_i, 0,
                ].max,
                id_token: "id-#{usage.refresh_generation}",
              }
            end,
          )
        end
      end
    end
    expiry = @usage.reload.refresh_delivery_expires_at

    replay =
      begin
        fv5013 = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
        fv5012 = @refresh_token
        fv5014 = expiry + 0.001.seconds
        OpAppGrant.stub(:database_now, fv5014) do
          begin
            fv5010 = fv5013
            fv5011 = fv5012
            fv5009 = 300
            OidcRefreshTokenIssuer.call(
              refresh_token: fv5011,
              client_id: "core-app-jp",
              resource_type: "client",
              coordination_store: fv5010,
              response_builder: lambda do |usage:, refresh_token:, now:, **_|
                {
                  access_token: "access-#{usage.refresh_generation}",
                  token_type: "Bearer",
                  expires_in: fv5009,
                  refresh_token: refresh_token,
                  refresh_token_expires_in: [
                    (usage.refresh_token_expires_at - now).to_i, 0,
                  ].max,
                  id_token: "id-#{usage.refresh_generation}",
                }
              end,
            )
          end
        end
      end

    assert_not_predicate replay, :success?
    assert_equal :refresh_token_reuse_detected, replay.reason
    assert_predicate @usage.reload, :revoked?
  end

  test "a revoked parent blocks receipt redelivery without another rotation" do
    first =
      begin
        fv5007 = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
        fv5008 = @refresh_token
        fv5006 = 300
        OidcRefreshTokenIssuer.call(
          refresh_token: fv5008,
          client_id: "core-app-jp",
          resource_type: "client",
          coordination_store: fv5007,
          response_builder: lambda do |usage:, refresh_token:, now:, **_|
            {
              access_token: "access-#{usage.refresh_generation}",
              token_type: "Bearer",
              expires_in: fv5006,
              refresh_token: refresh_token,
              refresh_token_expires_in: [
                (usage.refresh_token_expires_at - now).to_i, 0,
              ].max,
              id_token: "id-#{usage.refresh_generation}",
            }
          end,
        )
      end
    @root_token.revoke!

    redelivered =
      begin
        fv5004 = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
        fv5005 = @refresh_token
        fv5003 = 300
        OidcRefreshTokenIssuer.call(
          refresh_token: fv5005,
          client_id: "core-app-jp",
          resource_type: "client",
          coordination_store: fv5004,
          response_builder: lambda do |usage:, refresh_token:, now:, **_|
            {
              access_token: "access-#{usage.refresh_generation}",
              token_type: "Bearer",
              expires_in: fv5003,
              refresh_token: refresh_token,
              refresh_token_expires_in: [
                (usage.refresh_token_expires_at - now).to_i, 0,
              ].max,
              id_token: "id-#{usage.refresh_generation}",
            }
          end,
        )
      end

    assert_predicate first, :success?
    assert_not_predicate redelivered, :success?
    assert_equal :inactive_token, redelivered.reason
    assert_equal 1, @usage.reload.refresh_generation
  end

  test "a reversed response is rejected before rotation commits" do
    original_digest = @usage.refresh_token_digest

    assert_raises(OidcRefreshDeliveryReceipt::Invalid) do
      begin
        fv5001 = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
        fv5002 = @refresh_token
        fv5000 = 2.days.to_i
        OidcRefreshTokenIssuer.call(
          refresh_token: fv5002,
          client_id: "core-app-jp",
          resource_type: "client",
          coordination_store: fv5001,
          response_builder: lambda do |usage:, refresh_token:, now:, **_|
            {
              access_token: "access-#{usage.refresh_generation}",
              token_type: "Bearer",
              expires_in: fv5000,
              refresh_token: refresh_token,
              refresh_token_expires_in: [
                (usage.refresh_token_expires_at - now).to_i, 0,
              ].max,
              id_token: "id-#{usage.refresh_generation}",
            }
          end,
        )
      end
    end

    assert_equal original_digest, @usage.reload.refresh_token_digest
    assert_equal 0, @usage.refresh_generation
    assert_not_predicate @usage, :refresh_delivery_receipt_present?
  end

  private
end

class OidcRefreshTokenCoalescingConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    namespace = Umaxica::Valkey::Namespaces.rp_refresh(**Umaxica::Valkey::Namespaces.runtime_scope)
    @coordination_connection = Umaxica::Valkey::Connection.new(namespace: namespace)
    @coordination_forwarder = Umaxica::Valkey::Connection.new(namespace: namespace)
    @client = clients(:one)
    @root_token = ClientToken.create!(user: @client, discard_at: 1.day.from_now)
    @usage = OpAppGrant.create!(
      client_token: @root_token,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
    @refresh_token = @usage.issue_refresh_token!
  end

  teardown do
    @coordination_connection.close
    @coordination_forwarder.close
    usage_id = @usage&.id
    root_token_id = @root_token&.id
    device_session_id = @root_token&.device_session_id
    OpAppGrant.where(id: usage_id).delete_all if usage_id
    OpAppGrant.where(device_session_id: device_session_id).delete_all if device_session_id
    ClientToken.where(id: root_token_id).delete_all if root_token_id
    ClientDeviceSession.where(id: device_session_id).delete_all if device_session_id
  end

  test "barrier-driven simultaneous presentation rotates once and redelivers the same response" do
    store = OidcRpRefreshCoordinationAdapter.new(connection: @coordination_connection)
    barrier_mutex = Mutex.new
    first_blocked = false
    first_acquired = Queue.new
    second_contended = Queue.new
    release_first = Queue.new
    acquisitions = Queue.new
    @coordination_connection.stub(
      :call, ->(command, *arguments) {
        result = @coordination_forwarder.call(command, *arguments)
        if command == "SET" && arguments.include?("NX")
          acquisitions << true
          block_lease =
            barrier_mutex.synchronize do
              if result == "OK" && !first_blocked
                first_blocked = true
              else
                false
              end
            end
          if block_lease
            first_acquired << true
            release_first.pop
          elsif result != "OK"
            second_contended << true
          end
        end
        result
      },
    ) do
      ready = Queue.new
      start = Queue.new
      ActiveRecord::Base.connection_handler.connection_pool_list.each(&:release_connection)
      threads =
        2.times.map do
          Thread.new do
            ready << true
            start.pop
            OpBaseAppRecord.connection_pool.with_connection do
              OidcRefreshTokenIssuer.call(
                refresh_token: @refresh_token,
                client_id: "core-app-jp",
                resource_type: "client",
                coordination_store: store,
                response_builder: ->(usage:, refresh_token:, now:, **) {
                  {
                    access_token: "access-#{usage.refresh_generation}",
                    token_type: "Bearer",
                    expires_in: 300,
                    refresh_token: refresh_token,
                    refresh_token_expires_in: [
                      (usage.refresh_token_expires_at - now).to_i, 0,
                    ].max,
                    id_token: "id-#{usage.refresh_generation}",
                  }
                },
              )
            end
          rescue StandardError => e
            e
          end
        end

      2.times { ready.pop }
      2.times { start << true }
      first_acquired.pop
      second_contended.pop
      release_first << true
      results = threads.map(&:value)

      assert_empty results.grep(StandardError), results.grep(StandardError).map(&:message).join("; ")
      assert_equal 1, @usage.reload.refresh_generation
      assert_equal 1, results.map { |result| result.token_response }.uniq.length
      assert results.all?(&:success?)
      assert_operator acquisitions.size, :>=, 2
    ensure
      release_first << true
      threads&.each { |thread| thread.join(10) }
    end
  end

  private
end
