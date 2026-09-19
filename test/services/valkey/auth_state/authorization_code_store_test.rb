# typed: false
# frozen_string_literal: true

require "test_helper"

class ValkeyAuthStateAuthorizationCodeStoreTest < ActiveSupport::TestCase
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
      client_id: "core-app-rp",
      redirect_uri: "https://core.umaxica.app/sign/in/callback",
      subject: "sub-1",
      code_challenge: "challenge",
      code_challenge_method: "S256",
      resource_type: "client",
      scope: "openid",
    )

    first = @store.consume!(
      raw_code: raw,
      expected: {
        client_id: "core-app-rp",
        redirect_uri: "https://core.umaxica.app/sign/in/callback",
      },
    )

    assert_predicate first, :success?

    second = @store.consume!(
      raw_code: raw,
      expected: {
        client_id: "core-app-rp",
        redirect_uri: "https://core.umaxica.app/sign/in/callback",
      },
    )

    assert_predicate second, :replay?
  end

  test "unknown code is missing and mismatch fails closed" do
    missing = @store.consume!(raw_code: "no-such-code", expected: { client_id: "core-app-rp" })

    assert_predicate missing, :missing?

    raw = @store.issue!(
      client_id: "core-app-rp",
      redirect_uri: "https://core.umaxica.app/sign/in/callback",
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
      client_id: "core-app-rp",
      redirect_uri: "https://core.umaxica.app/sign/in/callback",
      subject: "sub-1",
      code_challenge: "challenge",
      code_challenge_method: "S256",
      resource_type: "client",
    )

    consumed = @store.consume!(
      raw_code: raw,
      expected: {
        client_id: "core-app-rp",
        redirect_uri: "https://core.umaxica.app/sign/in/callback",
      },
    )

    assert_predicate consumed, :success?

    wrong_owner = @store.consume!(
      raw_code: raw,
      expected: {
        client_id: "other-rp",
        redirect_uri: "https://core.umaxica.app/sign/in/callback",
      },
    )

    assert_predicate wrong_owner, :mismatch?
  end

  test "concurrent consume has a single winner" do
    raw = @store.issue!(
      client_id: "core-app-rp",
      redirect_uri: "https://core.umaxica.app/sign/in/callback",
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
              client_id: "core-app-rp",
              redirect_uri: "https://core.umaxica.app/sign/in/callback",
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
      client_id: "core-app-rp",
      redirect_uri: "https://core.umaxica.app/sign/in/callback",
      subject: "sub-1",
      code_challenge: "challenge",
      code_challenge_method: "S256",
      resource_type: "client",
    )
    @store.consume!(
      raw_code: raw,
      expected: {
        client_id: "core-app-rp",
        redirect_uri: "https://core.umaxica.app/sign/in/callback",
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
    key_ttl = -> { @connection.call("TTL", @store.send(:storage_key, raw)) }
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
      client_id: "core-app-rp",
      redirect_uri: "https://core.umaxica.app/sign/in/callback",
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
      expected: { client_id: "core-app-rp", redirect_uri: "https://core.umaxica.app/sign/in/callback" },
    )
    raw
  end
end
