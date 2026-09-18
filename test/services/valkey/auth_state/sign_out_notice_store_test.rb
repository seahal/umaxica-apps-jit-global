# typed: false
# frozen_string_literal: true

require "test_helper"

class ValkeyAuthStateSignOutNoticeStoreTest < ActiveSupport::TestCase
  setup do
    skip "AUTH_STATE_REDIS_URL unset" if ENV["AUTH_STATE_REDIS_URL"].blank?

    @suite = "suite-#{SecureRandom.hex(4)}"
    @namespace = Umaxica::Valkey::Namespaces.sign_out_notices(
      suite_run_id: @suite,
      worker_id: "w0",
      test_id: name,
    )
    @connection = Umaxica::Valkey::Connection.new(
      url: ENV.fetch("AUTH_STATE_REDIS_URL"),
      namespace: @namespace,
    )
    @store = Valkey::AuthState::SignOutNoticeStore.new(connection: @connection)
  end

  teardown do
    next if @connection.nil?

    Umaxica::Valkey::Cleanup.delete_by_prefix(@connection, prefix: "#{@namespace}:")
    Umaxica::Valkey::Cleanup.ensure_empty!(@connection, prefix: "#{@namespace}:")
    @connection.close
  end

  test "notice consume is one-shot under concurrency" do
    raw_id = @store.issue!(payload: { actor_ref: "client:1", face: "app", state: "ready" })

    results = Array.new(8)
    threads =
      8.times.map do |index|
        Thread.new do # rubocop:disable ThreadSafety/NewThread
          store = Valkey::AuthState::SignOutNoticeStore.new(connection: @connection)
          results[index] = store.consume(raw_id: raw_id)
        end
      end
    threads.each(&:join)

    winners = results.compact

    assert_equal 1, winners.size
    assert_equal "client:1", winners.first.fetch("actor_ref")
    assert_nil @store.consume(raw_id: raw_id)
  end
end
