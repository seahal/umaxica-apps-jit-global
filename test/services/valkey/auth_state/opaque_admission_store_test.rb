# typed: false
# frozen_string_literal: true

require "test_helper"

class ValkeyAuthStateOpaqueAdmissionStoreTest < ActiveSupport::TestCase
  setup do
    @suite = "suite-#{SecureRandom.hex(4)}"
    @namespace = Umaxica::Valkey::Namespaces.admission(
      suite_run_id: @suite,
      worker_id: "w0",
      test_id: name,
    )
    @connection = Umaxica::Valkey::Connection.new(
      url: Umaxica::Valkey::Settings.current.auth_state.url,
      namespace: @namespace,
    )
    @store = Valkey::AuthState::OpaqueAdmissionStore.new(connection: @connection)
  end

  teardown do
    next if @connection.nil?

    Umaxica::Valkey::Cleanup.delete_by_prefix(@connection, prefix: "#{@namespace}:")
    Umaxica::Valkey::Cleanup.ensure_empty!(@connection, prefix: "#{@namespace}:")
    @connection.close
  end

  test "handoff consume is one-shot and sixty-second TTL contract" do
    assert_equal 60.seconds, Valkey::AuthState::OpaqueAdmissionStore::CODE_TTL

    raw = @store.issue!(
      purpose: :authentication_handoff,
      actor_type: "client",
      surface: "app",
      subject_ref: "client:1",
    )
    first = @store.consume!(purpose: :authentication_handoff, raw_code: raw)

    assert_predicate first, :success?
    assert_equal "authentication_handoff", first.payload.fetch("purpose")

    second = @store.consume!(purpose: :authentication_handoff, raw_code: raw)

    assert_predicate second, :replay?
  end

  test "missing code fails closed" do
    result = @store.consume!(purpose: :sign_in_result, raw_code: "missing")

    assert_predicate result, :missing?
  end

  test "binding mismatch does not consume the admission" do
    raw = @store.issue!(
      purpose: :authentication_result,
      actor_type: "client",
      surface: "app",
      subject_ref: "transaction-1",
    )

    rejected = @store.consume!(
      purpose: :authentication_result,
      raw_code: raw,
      expected: { actor_type: "visitor", surface: "com", subject_ref: "transaction-1" },
    )

    assert_predicate rejected, :binding_mismatch?

    accepted = @store.consume!(
      purpose: :authentication_result,
      raw_code: raw,
      expected: { actor_type: "client", surface: "app", subject_ref: "transaction-1" },
    )

    assert_predicate accepted, :success?
  end

  test "binding expectations reject unknown payload fields" do
    raw = @store.issue!(
      purpose: :authentication_handoff,
      actor_type: "client",
      surface: "app",
    )

    assert_raises ArgumentError do
      @store.consume!(
        purpose: :authentication_handoff,
        raw_code: raw,
        expected: { unknown: "value" },
      )
    end
  end

  test "result issuance accepts a caller-generated opaque code and records its generation" do
    raw = SecureRandom.urlsafe_base64(32, padding: false)

    stored = @store.issue!(
      purpose: :authentication_result,
      actor_type: "client",
      surface: "app",
      subject_ref: "transaction-1",
      raw_code: raw,
      result_generation: 3,
    )

    assert_equal raw, stored
    assert_equal 3, @store.read(raw).fetch("result_generation")
    assert_equal "transaction-1", @store.read(raw).fetch("subject_ref")
  end

  test "a non-secret reference consumes the admission without putting the code in the URL" do
    raw = @store.issue!(
      purpose: :authentication_handoff,
      actor_type: "client",
      surface: "app",
      subject_ref: "transaction-1",
      reference: "transaction-1",
    )

    consumed = @store.consume_reference!(
      reference: "transaction-1",
      expected: { actor_type: "client", surface: "app" },
      purposes: ["authentication_handoff"],
    )

    assert_predicate consumed, :success?
    assert_equal "authentication_handoff", consumed.payload.fetch("purpose")

    replay = @store.consume_reference!(
      reference: "transaction-1",
      expected: { actor_type: "client", surface: "app" },
      purposes: ["authentication_handoff"],
    )

    assert_predicate replay, :replay?
    assert_predicate raw, :present?
  end

  test "reference binding mismatch does not consume the admission" do
    @store.issue!(
      purpose: :local_sign_in,
      actor_type: "client",
      surface: "app",
      reference: "entry-1",
    )

    rejected = @store.consume_reference!(
      reference: "entry-1",
      expected: { actor_type: "visitor", surface: "com" },
      purposes: ["local_sign_in"],
    )

    assert_predicate rejected, :binding_mismatch?

    accepted = @store.consume_reference!(
      reference: "entry-1",
      expected: { actor_type: "client", surface: "app" },
      purposes: ["local_sign_in"],
    )

    assert_predicate accepted, :success?
  end

  test "every operation reports Valkey unavailability as Unavailable" do
    down = Object.new
    down.define_singleton_method(:key) { |suffix| "down:#{suffix}" }
    down.define_singleton_method(:call) { |*| raise Redis::CannotConnectError, "connection refused" }
    store = Valkey::AuthState::OpaqueAdmissionStore.new(connection: down)

    assert_raises(Umaxica::Valkey::Unavailable) do
      store.issue!(purpose: "authentication_result", actor_type: "client", surface: "app")
    end
    assert_raises(Umaxica::Valkey::Unavailable) { store.read("code") }
    assert_raises(Umaxica::Valkey::Unavailable) { store.consume!(purpose: "authentication_result", raw_code: "code") }
    assert_raises(Umaxica::Valkey::Unavailable) { store.consume_reference!(reference: "ref") }
  end

  test "a stored admission that is not JSON is reported as corrupt" do
    raw = "stored-#{SecureRandom.hex(4)}"
    digest = Valkey::AuthState::OpaqueAdmissionStore.digest_for(purpose: "authentication_result", raw_code: raw)
    @connection.call("SET", @connection.key("admission:authentication_result:#{digest}"), "{not json")

    assert_raises(Umaxica::Valkey::SerializationError) { @store.read(raw) }
  end

  test "an unexpected consume reply fails closed as a corrupt payload" do
    odd = Object.new
    odd.define_singleton_method(:key) { |suffix| "odd:#{suffix}" }
    odd.define_singleton_method(:call) { |*| ["surprise", nil] }
    store = Valkey::AuthState::OpaqueAdmissionStore.new(connection: odd)

    assert_raises(Umaxica::Valkey::SerializationError) do
      store.consume!(purpose: "authentication_result", raw_code: "code")
    end
    assert_raises(Umaxica::Valkey::SerializationError) { store.consume_reference!(reference: "ref") }
  end

  test "binding expectations must be a hash" do
    assert_raises(ArgumentError) do
      @store.consume!(purpose: "authentication_result", raw_code: "code", expected: [["surface", "app"]])
    end
  end

  test "the instance digest matches the class digest" do
    assert_equal Valkey::AuthState::OpaqueAdmissionStore.digest_for(purpose: "p", raw_code: "c"),
                 @store.digest_for(purpose: "p", raw_code: "c")
  end
end
