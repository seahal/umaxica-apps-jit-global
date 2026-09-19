# typed: false
# frozen_string_literal: true

require "test_helper"

class ValkeyAuthStateSignOutNoticeStoreTest < ActiveSupport::TestCase
  setup do
    @suite = "suite-#{SecureRandom.hex(4)}"
    @namespace = Umaxica::Valkey::Namespaces.sign_out_notices(
      suite_run_id: @suite,
      worker_id: "w0",
      test_id: name,
    )
    @connection = Umaxica::Valkey::Connection.new(
      url: Umaxica::Valkey::Settings.current.auth_state.url,
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

  test "read without delete leaves the notice in place" do
    raw_id = @store.issue!(payload: { actor_ref: "client:2", face: "app", state: "ready" })
    payload = @store.read(raw_id: raw_id, delete: false)

    assert_equal "client:2", payload.fetch("actor_ref")
    assert_equal "client:2", @store.read(raw_id: raw_id, delete: false).fetch("actor_ref")
  end

  test "read returns nil for an expired notice" do
    raw_id = @store.issue!(
      payload: { actor_ref: "client:3", face: "app", state: "ready", expires_at: 1.hour.ago.iso8601 },
    )

    assert_nil @store.read(raw_id: raw_id)
  end

  test "storage key rejects a blank notice id" do
    assert_raises(ArgumentError) { @store.storage_key("") }
    assert_raises(ArgumentError) { @store.storage_key(nil) }
  end

  test "read raises SerializationError for corrupt JSON" do
    raw_id = SecureRandom.urlsafe_base64(32, padding: false)
    @connection.call("SET", @store.storage_key(raw_id), "not-json", "EX", 60)

    assert_raises(Umaxica::Valkey::SerializationError) { @store.read(raw_id: raw_id) }
  end

  test "read raises SerializationError for a non-object payload" do
    raw_id = SecureRandom.urlsafe_base64(32, padding: false)
    @connection.call("SET", @store.storage_key(raw_id), JSON.generate([1, 2, 3]), "EX", 60)

    assert_raises(Umaxica::Valkey::SerializationError) { @store.read(raw_id: raw_id) }
  end

  test "read raises SerializationError for a version mismatch" do
    raw_id = SecureRandom.urlsafe_base64(32, padding: false)
    payload = {
      "version" => Valkey::AuthState::SignOutNoticeStore::VERSION + 1,
      "actor_ref" => "client:5",
      "expires_at" => 1.hour.from_now.iso8601,
    }
    @connection.call("SET", @store.storage_key(raw_id), JSON.generate(payload), "EX", 60)

    assert_raises(Umaxica::Valkey::SerializationError) { @store.read(raw_id: raw_id) }
  end

  test "read raises SerializationError when stored payload carries unknown fields" do
    raw_id = SecureRandom.urlsafe_base64(32, padding: false)
    payload = {
      "version" => Valkey::AuthState::SignOutNoticeStore::VERSION,
      "actor_ref" => "client:6",
      "expires_at" => 1.hour.from_now.iso8601,
      "surprise" => "nope",
    }
    @connection.call("SET", @store.storage_key(raw_id), JSON.generate(payload), "EX", 60)

    assert_raises(Umaxica::Valkey::SerializationError) { @store.read(raw_id: raw_id) }
  end

  test "issue raises OperationError when the notice key already exists" do
    connection = Object.new
    connection.define_singleton_method(:key) { |digest| "ns:#{digest}" }
    connection.define_singleton_method(:call) { |*_args| nil }
    store = Valkey::AuthState::SignOutNoticeStore.new(connection: connection)

    assert_raises(Umaxica::Valkey::OperationError) do
      store.issue!(payload: { actor_ref: "client:7", face: "app", state: "ready" })
    end
  end
end
