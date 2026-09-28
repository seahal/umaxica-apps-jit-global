# typed: false
# frozen_string_literal: true

require "test_helper"

class ValkeyAuthStateAuthorizationCodeStoreTest < ActiveSupport::TestCase
  CLIENT_ID = "core-app"
  REDIRECT_URI = "https://core.umaxica.app/sign/callback"

  setup do
    @suite = "suite-#{SecureRandom.hex(4)}"
    @namespace = Umaxica::Valkey::Namespaces.authorization_codes(
      suite_run_id: @suite,
      worker_id: "w0",
      test_id: name,
    )
    @connection = Umaxica::Valkey::Connection.new(
      url: Umaxica::Valkey::Settings.current.auth_state.url,
      namespace: @namespace,
    )
    @store = Valkey::AuthState::AuthorizationCodeStore.new(connection: @connection)
  end

  teardown do
    next if @connection.nil?

    Umaxica::Valkey::Cleanup.delete_by_prefix(@connection, prefix: "#{@namespace}:")
    Umaxica::Valkey::Cleanup.ensure_empty!(@connection, prefix: "#{@namespace}:")
    @connection.close
  end

  test "issue and consume succeed once; second consume is replay" do
    raw = @store.issue!(
      client_id: CLIENT_ID,
      redirect_uri: REDIRECT_URI,
      subject: "sub-1",
      code_challenge: "challenge",
      code_challenge_method: "S256",
      resource_type: "client",
      scope: "openid",
    )

    first = @store.consume!(
      raw_code: raw,
      expected: {
        client_id: CLIENT_ID,
        redirect_uri: REDIRECT_URI,
      },
    )

    assert_predicate first, :success?

    second = @store.consume!(
      raw_code: raw,
      expected: {
        client_id: CLIENT_ID,
        redirect_uri: REDIRECT_URI,
      },
    )

    assert_predicate second, :replay?
  end

  test "unknown code is missing and mismatch fails closed" do
    missing = @store.consume!(raw_code: "no-such-code", expected: { client_id: CLIENT_ID })

    assert_predicate missing, :missing?

    raw = @store.issue!(
      client_id: CLIENT_ID,
      redirect_uri: REDIRECT_URI,
      subject: "sub-1",
      code_challenge: "challenge",
      code_challenge_method: "S256",
      resource_type: "client",
    )
    mismatch = @store.consume!(
      raw_code: raw,
      expected: { client_id: "other-rp" },
    )

    assert_predicate mismatch, :mismatch?
  end

  test "a consumed code with mismatched ownership fields is not classified as replay" do
    raw = @store.issue!(
      client_id: CLIENT_ID,
      redirect_uri: REDIRECT_URI,
      subject: "sub-1",
      code_challenge: "challenge",
      code_challenge_method: "S256",
      resource_type: "client",
    )

    consumed = @store.consume!(
      raw_code: raw,
      expected: {
        client_id: CLIENT_ID,
        redirect_uri: REDIRECT_URI,
      },
    )

    assert_predicate consumed, :success?

    wrong_owner = @store.consume!(
      raw_code: raw,
      expected: {
        client_id: "other-rp",
        redirect_uri: REDIRECT_URI,
      },
    )

    assert_predicate wrong_owner, :mismatch?
  end

  test "concurrent consume has a single winner" do
    raw = @store.issue!(
      client_id: CLIENT_ID,
      redirect_uri: REDIRECT_URI,
      subject: "sub-1",
      code_challenge: "challenge",
      code_challenge_method: "S256",
      resource_type: "client",
    )

    results = Array.new(8)
    threads =
      8.times.map do |index|
        Thread.new do # rubocop:disable ThreadSafety/NewThread
          store = Valkey::AuthState::AuthorizationCodeStore.new(connection: @connection)
          results[index] = store.consume!(
            raw_code: raw,
            expected: {
              client_id: CLIENT_ID,
              redirect_uri: REDIRECT_URI,
            },
          ).status
        end
      end
    threads.each(&:join)

    assert_equal 1, results.count(:consumed)
    assert_equal 7, results.count(:replay)
  end

  test "family linkage is idempotent for the same owner and rejects a different owner" do
    raw = @store.issue!(
      client_id: CLIENT_ID,
      redirect_uri: REDIRECT_URI,
      subject: "sub-1",
      code_challenge: "challenge",
      code_challenge_method: "S256",
      resource_type: "client",
    )
    @store.consume!(
      raw_code: raw,
      expected: {
        client_id: CLIENT_ID,
        redirect_uri: REDIRECT_URI,
      },
    )

    first = @store.link_family!(
      raw_code: raw,
      rp_session_ref: "rp-session-a",
      refresh_family_ref: "family-a",
    )
    same_owner = @store.link_family!(
      raw_code: raw,
      rp_session_ref: "rp-session-a",
      refresh_family_ref: "family-a",
    )
    different_owner = @store.link_family!(
      raw_code: raw,
      rp_session_ref: "rp-session-b",
      refresh_family_ref: "family-b",
    )

    assert_equal :linked, first.status
    assert_equal :linked, same_owner.status
    assert_equal :already_linked, different_owner.status
    assert_equal "rp-session-a", @store.read(raw).fetch("rp_session_ref")
    assert_equal "family-a", @store.read(raw).fetch("refresh_family_ref")
  end

  test "a replay marked before the family link makes the link fail" do
    raw = consumed_code

    marked = @store.mark_replay!(raw_code: raw)
    link = @store.link_family!(raw_code: raw, rp_session_ref: "rp-session-a", refresh_family_ref: "family-a")

    assert_equal :marked, marked.status
    assert_equal :replay_detected, link.status
    assert_nil @store.read(raw)["rp_session_ref"]
  end

  test "a replay marked after the family link returns the linked family for revocation" do
    raw = consumed_code
    @store.link_family!(raw_code: raw, rp_session_ref: "rp-session-a", refresh_family_ref: "family-a")

    marked = @store.mark_replay!(raw_code: raw)

    assert_equal :marked, marked.status
    assert_equal "rp-session-a", marked.payload.fetch("rp_session_ref")
    assert_equal "family-a", marked.payload.fetch("refresh_family_ref")
    assert_predicate marked.payload.fetch("replay_detected_at"), :present?
  end

  test "marking a replay keeps the tombstone expiry and refuses an unconsumed code" do
    raw = consumed_code
    # This test's namespace holds only the consumed code's key until issued_code runs below.
    code_keys = @connection.call("KEYS", "#{@namespace}:*")

    assert_equal 1, code_keys.size
    key_ttl = -> { @connection.call("TTL", code_keys.first) }
    before = key_ttl.call

    @store.mark_replay!(raw_code: raw)

    assert_operator key_ttl.call, :<=, before
    assert_operator key_ttl.call, :>, 0
    assert_equal :invalid_state, @store.mark_replay!(raw_code: issued_code).status
    assert_equal :missing, @store.mark_replay!(raw_code: "unknown-code").status
  end

  private

  def issued_code
    @store.issue!(
      client_id: CLIENT_ID,
      redirect_uri: REDIRECT_URI,
      subject: "sub-1",
      code_challenge: "challenge",
      code_challenge_method: "S256",
      resource_type: "client",
    )
  end

  def consumed_code
    raw = issued_code
    @store.consume!(
      raw_code: raw,
      expected: { client_id: CLIENT_ID, redirect_uri: REDIRECT_URI },
    )
    raw
  end

  test "every operation reports Valkey unavailability as Unavailable" do
    down = Object.new
    down.define_singleton_method(:key) { |digest| "down:#{digest}" }
    down.define_singleton_method(:call) { |*| raise Redis::CannotConnectError, "connection refused" }
    store = Valkey::AuthState::AuthorizationCodeStore.new(connection: down)

    {
      "issue" => -> {
        store.issue!(
          client_id: CLIENT_ID, redirect_uri: REDIRECT_URI, subject: "sub", code_challenge: "c",
          code_challenge_method: "S256", resource_type: "client",
        )
      },
      "read" => -> { store.read("code") },
      "consume" => -> { store.consume!(raw_code: "code", expected: {}) },
      "link" => -> { store.link_family!(raw_code: "code", rp_session_ref: "rp") },
      "replay mark" => -> { store.mark_replay!(raw_code: "code") },
    }.each do |operation, action|
      error = assert_raises(Umaxica::Valkey::Unavailable, operation) { action.call }

      assert_includes error.message, operation
    end
  end

  test "issue refuses a key that already exists instead of overwriting it" do
    taken = Object.new
    taken.define_singleton_method(:key) { |digest| "taken:#{digest}" }
    taken.define_singleton_method(:call) { |*| nil }
    store = Valkey::AuthState::AuthorizationCodeStore.new(connection: taken)

    assert_raises(Umaxica::Valkey::OperationError) do
      store.issue!(
        client_id: CLIENT_ID, redirect_uri: REDIRECT_URI, subject: "sub", code_challenge: "c",
        code_challenge_method: "S256", resource_type: "client",
      )
    end
  end

  test "issue rejects a non-S256 code challenge method" do
    assert_raises(ArgumentError) do
      @store.issue!(
        client_id: CLIENT_ID, redirect_uri: REDIRECT_URI, subject: "sub", code_challenge: "c",
        code_challenge_method: "plain", resource_type: "client",
      )
    end
  end

  test "a blank code has no storage key" do
    assert_raises(ArgumentError) { @store.storage_key("") }
  end

  test "reading a stored value that is not the expected payload fails as a serialization error" do
    {
      "corrupt" => "{not json",
      "not an object" => "[1]",
      "version mismatch" => JSON.generate({ "version" => -1, "state" => "issued" }),
      "state invalid" => JSON.generate(
        { "version" => Valkey::AuthState::AuthorizationCodeStore::VERSION,
          "state" => "bogus", },
      ),
      "unknown fields" => JSON.generate(
        {
          "version" => Valkey::AuthState::AuthorizationCodeStore::VERSION, "state" => "issued", "extra" => "x",
        },
      ),
    }.each do |label, stored|
      raw = "stored-#{SecureRandom.hex(4)}"
      @connection.call("SET", @store.storage_key(raw), stored)

      assert_raises(Umaxica::Valkey::SerializationError, label) { @store.read(raw) }
    end
  end

  test "an unexpected script reply fails closed for consume, link and replay mark" do
    odd = Object.new
    odd.define_singleton_method(:key) { |digest| "odd:#{digest}" }
    odd.define_singleton_method(:call) { |*| ["surprise", nil] }
    store = Valkey::AuthState::AuthorizationCodeStore.new(connection: odd)

    assert_raises(Umaxica::Valkey::OperationError) { store.consume!(raw_code: "code", expected: {}) }
    assert_raises(Umaxica::Valkey::OperationError) { store.link_family!(raw_code: "code", rp_session_ref: "rp") }
    assert_raises(Umaxica::Valkey::OperationError) { store.mark_replay!(raw_code: "code") }
  end

  test "a non-array script reply is treated as a corrupt payload" do
    broken = Object.new
    broken.define_singleton_method(:key) { |digest| "broken:#{digest}" }
    broken.define_singleton_method(:call) { |*| "OK" }
    store = Valkey::AuthState::AuthorizationCodeStore.new(connection: broken)

    assert_raises(Umaxica::Valkey::SerializationError) { store.consume!(raw_code: "code", expected: {}) }
    assert_raises(Umaxica::Valkey::SerializationError) { store.link_family!(raw_code: "code", rp_session_ref: "rp") }
    assert_raises(Umaxica::Valkey::SerializationError) { store.mark_replay!(raw_code: "code") }
  end
end
