# frozen_string_literal: true

require "test_helper"

class ChannelOtpVerificationFailureBudgetTest < ActiveSupport::TestCase
  [[:email, EmailOtpVerificationFailureBudget],
   [:telephone, TelephoneOtpVerificationFailureBudget],].each do |channel, model|
    test "#{channel} independently owns its failure threshold and refuses the other channel" do
      namespace = "otp-channel-budget:#{SecureRandom.hex(12)}"
      connection = Umaxica::Valkey::Connection.new(namespace: namespace)
      scope = { surface: :app, purpose: :sign_up, channel: channel, destination_digest: "a" * 64 }
      budget = model.new(connection: connection)
      key = connection.key("app:sign_up:#{channel}:#{"a" * 64}")

      assert_equal :verified, budget.verify!(**scope, valid: true)
      assert_nil connection.call("GET", key)
      4.times { assert_equal :invalid_code, budget.verify!(**scope, valid: false) }
      deadline = connection.call("PEXPIRETIME", key)

      assert_equal :locked, budget.verify!(**scope, valid: false)
      assert_equal :locked, budget.verify!(**scope, valid: true)
      assert_equal :locked, budget.verify!(**scope, valid: false)
      assert_equal "5", connection.call("GET", key)
      assert_equal deadline, connection.call("PEXPIRETIME", key)
      other_channel = (channel == :email) ? :telephone : :email

      assert_raises(ArgumentError) { budget.verify!(**scope.merge(channel: other_channel), valid: true) }
    ensure
      Umaxica::Valkey::Cleanup.delete_by_prefix(connection, prefix: "#{namespace}:") if connection
      connection&.close
    end

    test "#{channel} budget rejects corrupt counters malformed inputs and unavailable infrastructure" do
      namespace = "otp-channel-invalid:#{SecureRandom.hex(12)}"
      connection = Umaxica::Valkey::Connection.new(namespace: namespace)
      scope = { surface: :org, purpose: :authentication, channel: channel, destination_digest: "b" * 64 }
      budget = model.new(connection: connection)
      key = connection.key("org:authentication:#{channel}:#{"b" * 64}")
      ["", "-1", "0", "6", "NaN"].each do |value|
        connection.call("SET", key, value, "EX", 900)

        assert_raises(Umaxica::Valkey::SerializationError) { budget.verify!(**scope, valid: true) }
      end
      connection.call("SET", key, "1")

      assert_raises(Umaxica::Valkey::SerializationError) { budget.verify!(**scope, valid: true) }
      [nil, "", "b" * 63, "b" * 65, "g" * 64, "b\0"].each do |digest|
        assert_raises(ArgumentError) { budget.verify!(**scope.merge(destination_digest: digest), valid: true) }
      end
      [nil, "true", 0].each do |valid|
        assert_raises(ArgumentError) { budget.verify!(**scope, valid: valid) }
      end
      connection.stub(:call, ->(*) { raise Umaxica::Valkey::Unavailable, "dependency unavailable" }) do
        [true, false].each do |valid|
          assert_raises(Umaxica::Valkey::Unavailable) { budget.verify!(**scope, valid: valid) }
        end
      end
    ensure
      Umaxica::Valkey::Cleanup.delete_by_prefix(connection, prefix: "#{namespace}:") if connection
      connection&.close
    end

    test "#{channel} concurrent failures cannot allocate more than five attempts" do
      namespace = "otp-channel-concurrency:#{SecureRandom.hex(12)}"
      connection = Umaxica::Valkey::Connection.new(namespace: namespace)
      scope = { surface: :com, purpose: :authentication, channel: channel, destination_digest: "e" * 64 }
      outcomes = 12.times.map do
        Concurrent::Promises.future do
          peer = Umaxica::Valkey::Connection.new(namespace: namespace)
          model.new(connection: peer).verify!(**scope, valid: false)
        ensure
          peer&.close
        end
      end.map(&:value!)

      assert_equal 4, outcomes.count(:invalid_code)
      assert_equal 8, outcomes.count(:locked)
      assert_equal "5", connection.call("GET", connection.key("com:authentication:#{channel}:#{"e" * 64}"))
    ensure
      Umaxica::Valkey::Cleanup.delete_by_prefix(connection, prefix: "#{namespace}:") if connection
      connection&.close
    end

    test "#{channel} exhausted budget remains realm and purpose scoped and expires without reset or TTL extension" do
      namespace = "otp-channel-scopes:#{SecureRandom.hex(12)}"
      connection = Umaxica::Valkey::Connection.new(namespace: namespace)
      scope = { surface: :app, purpose: :sign_up, channel: channel, destination_digest: "c" * 64 }
      budget = model.new(connection: connection)
      key = connection.key("app:sign_up:#{channel}:#{"c" * 64}")
      5.times { budget.verify!(**scope, valid: false) }

      [{ surface: :com }, { surface: :org }, { purpose: :authentication },
       { purpose: :credential_registration }, { purpose: :enforcement_recovery },
       { purpose: :withdrawal_reentry }, { destination_digest: "d" * 64 },].each do |difference|
        assert_equal :verified, budget.verify!(**scope.merge(difference), valid: true)
      end
      connection.call("PEXPIRE", key, 0)

      assert_equal :verified, budget.verify!(**scope, valid: true)
      assert_nil connection.call("GET", key)
      assert_equal :invalid_code, budget.verify!(**scope, valid: false)
      assert_equal "1", connection.call("GET", key)
    ensure
      Umaxica::Valkey::Cleanup.delete_by_prefix(connection, prefix: "#{namespace}:") if connection
      connection&.close
    end
  end
end
