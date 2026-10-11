# typed: false
# frozen_string_literal: true

require "test_helper"

class ValkeyAuthStateOpaqueAdmissionStoreTest < ActiveSupport::TestCase
  setup do
    skip "AUTH_STATE_REDIS_URL unset" if ENV["AUTH_STATE_REDIS_URL"].blank?

    @suite = "suite-#{SecureRandom.hex(4)}"
    @namespace = Umaxica::Valkey::Namespaces.admission(
      suite_run_id: @suite,
      worker_id: "w0",
      test_id: name,
    )
    @connection = Umaxica::Valkey::Connection.new(
      url: ENV.fetch("AUTH_STATE_REDIS_URL"),
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
      purpose: :sign_in_handoff,
      actor_type: "client",
      surface: "app",
      subject_ref: "client:1",
    )
    first = @store.consume!(purpose: :sign_in_handoff, raw_code: raw)

    assert_predicate first, :success?
    assert_equal "sign_in_handoff", first.payload.fetch("purpose")

    second = @store.consume!(purpose: :sign_in_handoff, raw_code: raw)

    assert_predicate second, :replay?
  end

  test "missing code fails closed" do
    result = @store.consume!(purpose: :sign_in_result, raw_code: "missing")

    assert_predicate result, :missing?
  end
end
