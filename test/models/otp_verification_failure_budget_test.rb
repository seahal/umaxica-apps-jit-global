# frozen_string_literal: true

require "test_helper"

class OtpVerificationFailureBudgetTest < ActiveSupport::TestCase
  setup do
    @namespace = "otp-verification:#{SecureRandom.hex(12)}"
    @connection = Umaxica::Valkey::Connection.new(namespace: @namespace)
    @budget = OtpVerificationFailureBudget.new(connection: @connection)
    @scope = { surface: :app, purpose: :sign_up, channel: :email, destination_digest: "a" * 64 }
    @key = @connection.key("app:sign_up:email:#{"a" * 64}")
  end

  teardown do
    Umaxica::Valkey::Cleanup.delete_by_prefix(@connection, prefix: "#{@namespace}:")
    @connection.close
  end

  test "four five and six failures share a capped budget and never extend its deadline" do
    3.times { assert_equal :invalid_code, @budget.verify!(**@scope, valid: false) }
    deadline = @connection.call("PEXPIRETIME", @key)

    assert_equal :invalid_code, @budget.verify!(**@scope, valid: false)
    assert_equal "4", @connection.call("GET", @key)
    assert_equal :verified, @budget.verify!(**@scope, valid: true)
    assert_equal "4", @connection.call("GET", @key)
    assert_equal :locked, @budget.verify!(**@scope, valid: false)
    assert_equal "5", @connection.call("GET", @key)
    assert_equal :locked, @budget.verify!(**@scope, valid: false)
    assert_equal :locked, @budget.verify!(**@scope, valid: true)
    assert_equal "5", @connection.call("GET", @key)
    assert_equal deadline, @connection.call("PEXPIRETIME", @key)
    assert_operator @connection.call("PTTL", @key), :>, 0
    assert_operator @connection.call("PTTL", @key), :<=, 900_000
  end

  test "success creates no key and signup exhaustion cannot exhaust other scopes" do
    assert_equal :verified, @budget.verify!(**@scope, valid: true)
    assert_nil @connection.call("GET", @key)
    5.times { @budget.verify!(**@scope, valid: false) }

    [{ surface: :com }, { purpose: :authentication }, { purpose: :credential_registration },
     { purpose: :enforcement_recovery }, { purpose: :withdrawal_reentry },
     { channel: :telephone }, { destination_digest: "b" * 64 },].each do |difference|
      assert_equal :verified, @budget.verify!(**@scope.merge(difference), valid: true)
    end
  end

  test "corrupt persistent or out of range counters refuse even a correct code" do
    ["", "not-an-integer", "-1", "0", "6"].each do |value|
      @connection.call("SET", @key, value, "EX", 900)
      assert_raises(Umaxica::Valkey::SerializationError) { @budget.verify!(**@scope, valid: true) }
    end
    @connection.call("SET", @key, "1")
    assert_raises(Umaxica::Valkey::SerializationError) { @budget.verify!(**@scope, valid: true) }
  end

  test "concurrent failures cannot allocate more than five attempts" do
    results = 12.times.map do
      Concurrent::Promises.future do
        connection = Umaxica::Valkey::Connection.new(namespace: @namespace)
        OtpVerificationFailureBudget.new(connection: connection).verify!(**@scope, valid: false)
      ensure
        connection&.close
      end
    end.map(&:value!)

    assert_equal 4, results.count(:invalid_code)
    assert_equal 8, results.count(:locked)
    assert_equal "5", @connection.call("GET", @key)
  end

  test "expired budget allows verification without resetting any candidate" do
    5.times { @budget.verify!(**@scope, valid: false) }
    # Native Valkey expiry owns this clock. A zero-ms expiry is the nearest deterministic expired
    # boundary; a one-ms network round trip cannot reliably observe immediately before expiry.
    @connection.call("PEXPIRE", @key, 0)

    assert_equal :verified, @budget.verify!(**@scope, valid: true)
    assert_nil @connection.call("GET", @key)
    assert_equal :invalid_code, @budget.verify!(**@scope, valid: false)
    assert_equal "1", @connection.call("GET", @key)
  end

  test "unavailable dependency refuses both matching and nonmatching codes" do
    @connection.stub(:call, ->(*) { raise Umaxica::Valkey::Unavailable, "dependency unavailable" }) do
      [true, false].each do |valid|
        assert_raises(Umaxica::Valkey::Unavailable) { @budget.verify!(**@scope, valid: valid) }
      end
    end
  end

  test "missing empty malformed digests and nonboolean comparisons are explicit errors" do
    [nil, "", " ", "a" * 63, "a" * 65, "g" * 64].each do |digest|
      assert_raises(ArgumentError) { @budget.verify!(**@scope.merge(destination_digest: digest), valid: true) }
    end
    [nil, "true", 0].each do |valid|
      assert_raises(ArgumentError) { @budget.verify!(**@scope, valid: valid) }
    end
  end
end
