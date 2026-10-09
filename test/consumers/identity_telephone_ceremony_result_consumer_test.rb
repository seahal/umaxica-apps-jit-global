# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityTelephoneCeremonyResultConsumerTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.parse("2026-06-24 12:00:00 UTC")
  end

  test "decodes, validates the binding, and consumes the transaction" do
    transaction = fake_transaction
    result = valid_result_hash
    consumed = Object.new

    transaction.consume_return = consumed

    IdentityTelephoneCeremonyResult.stub(:decode, ->(_token, **) { result }) do
      outcome = IdentityTelephoneCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")

      assert_same consumed, outcome.transaction
      assert_same result, outcome.result
    end

    assert_equal [{ result_jti: "result-1", consumed_at: @now }], transaction.consume_calls
  end

  test "uses the supplied issuer id when decoding" do
    transaction = fake_transaction
    captured = nil

    IdentityTelephoneCeremonyResult.stub(
      :decode, ->(_token, **kwargs) {
                 captured = kwargs
                 valid_result_hash
               },
    ) do
      IdentityTelephoneCeremonyResultConsumer.new(
        transaction: transaction,
        issuer_id: "custom-issuer",
        now: @now,
      ).call("token")
    end

    assert_equal "custom-issuer", captured.fetch(:issuer_id)
  end

  test "defaults the issuer id from the transaction surface" do
    transaction = fake_transaction
    captured = nil

    IdentityTelephoneCeremonyResult.stub(
      :decode, ->(_token, **kwargs) {
                 captured = kwargs
                 valid_result_hash
               },
    ) do
      IdentityTelephoneCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
    end

    assert_equal IdentityTelephoneCeremonyContract.sign_issuer_id("app"), captured.fetch(:issuer_id)
  end

  test "raises when the transaction is expired" do
    transaction = fake_transaction(expired: true)

    IdentityTelephoneCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash }) do
      assert_telephone_error("transaction is expired") do
        IdentityTelephoneCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end

    assert_empty transaction.consume_calls
  end

  test "raises when the transaction is already consumed" do
    transaction = fake_transaction(consumed: true)

    IdentityTelephoneCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash }) do
      assert_telephone_error("transaction is already consumed") do
        IdentityTelephoneCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end

    assert_empty transaction.consume_calls
  end

  test "raises when the result surface does not match the transaction" do
    transaction = fake_transaction

    IdentityTelephoneCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash("surface" => "com") }) do
      assert_telephone_error("surface does not match transaction") do
        IdentityTelephoneCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  test "raises when the result actor does not match the transaction" do
    transaction = fake_transaction

    IdentityTelephoneCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash("actor_ref" => "other") }) do
      assert_telephone_error("actor_ref does not match transaction") do
        IdentityTelephoneCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  test "raises when the result session does not match the transaction" do
    transaction = fake_transaction

    IdentityTelephoneCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash("session_ref" => "other") }) do
      assert_telephone_error("session_ref does not match transaction") do
        IdentityTelephoneCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  test "raises when the result transaction id does not match the transaction" do
    transaction = fake_transaction

    IdentityTelephoneCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash("transaction_id" => "other") }) do
      assert_telephone_error("transaction_id does not match transaction") do
        IdentityTelephoneCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  test "raises when the result grant jti does not match the transaction" do
    transaction = fake_transaction

    IdentityTelephoneCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash("grant_jti" => "other") }) do
      assert_telephone_error("grant_jti does not match transaction") do
        IdentityTelephoneCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  test "raises when the result operation does not match the transaction" do
    transaction = fake_transaction

    IdentityTelephoneCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash("operation" => "deletion") }) do
      assert_telephone_error("operation does not match transaction") do
        IdentityTelephoneCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  test "raises when the transaction cannot durably consume the result" do
    transaction = PlainTransaction.new

    IdentityTelephoneCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash }) do
      assert_telephone_error("durable telephone ceremony transaction is required") do
        IdentityTelephoneCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  private

  def assert_telephone_error(message)
    error = assert_raises(IdentityTelephoneCeremony::Error) { yield }
    assert_includes error.message, message
  end

  def valid_result_hash(overrides = {})
    {
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "operation" => "registration",
      "transaction_id" => "txn-1",
      "grant_jti" => "grant-1",
      "result_jti" => "result-1",
    }.merge(overrides)
  end

  def fake_transaction(expired: false, consumed: false)
    FakeTransaction.new(expired: expired, consumed: consumed)
  end

  class FakeTransaction
    attr_accessor :consume_return
    attr_reader :consume_calls, :surface, :actor_ref, :session_ref, :operation, :transaction_id, :grant_jti

    def initialize(expired:, consumed:)
      @expired = expired
      @consumed = consumed
      @consume_calls = []
      @surface = "app"
      @actor_ref = "actor-1"
      @session_ref = "session-1"
      @operation = "registration"
      @transaction_id = "txn-1"
      @grant_jti = "grant-1"
    end

    def expired?(*)
      @expired
    end

    def consumed?
      @consumed
    end

    def consume_result!(result_jti:, consumed_at:)
      @consume_calls << { result_jti: result_jti, consumed_at: consumed_at }
      @consume_return
    end
  end

  class PlainTransaction
    attr_reader :surface, :actor_ref, :session_ref, :operation, :transaction_id, :grant_jti

    def initialize
      @surface = "app"
      @actor_ref = "actor-1"
      @session_ref = "session-1"
      @operation = "registration"
      @transaction_id = "txn-1"
      @grant_jti = "grant-1"
    end

    def expired?(*)
      false
    end

    def consumed?
      false
    end
  end
end
