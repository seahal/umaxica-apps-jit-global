# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentitySocialCeremonyResultConsumerTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.parse("2026-06-24 12:00:00 UTC")
  end

  test "decodes, validates the binding, and consumes the transaction" do
    transaction = fake_transaction
    result = valid_result_hash
    consumed = Object.new
    transaction.consume_return = consumed

    IdentitySocialCeremonyResult.stub(:decode, ->(_token, **) { result }) do
      outcome = IdentitySocialCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")

      assert_same consumed, outcome.transaction
      assert_same result, outcome.result
    end

    assert_equal 1, transaction.consume_calls.size
  end

  test "raises when the transaction is expired" do
    transaction = fake_transaction(expired: true)

    IdentitySocialCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash }) do
      assert_social_error("transaction is expired") do
        IdentitySocialCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  test "raises when the transaction is already consumed" do
    transaction = fake_transaction(consumed: true)

    IdentitySocialCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash }) do
      assert_social_error("transaction is already consumed") do
        IdentitySocialCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  test "raises when the result surface does not match the transaction" do
    transaction = fake_transaction

    IdentitySocialCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash("surface" => "com") }) do
      assert_social_error("result surface does not match transaction") do
        IdentitySocialCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  test "raises when the result actor does not match the transaction" do
    transaction = fake_transaction

    IdentitySocialCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash("actor_ref" => "other") }) do
      assert_social_error("result actor does not match transaction") do
        IdentitySocialCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  test "raises when the result session does not match the transaction" do
    transaction = fake_transaction

    IdentitySocialCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash("session_ref" => "other") }) do
      assert_social_error("result session does not match transaction") do
        IdentitySocialCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  test "raises when the result operation does not match the transaction" do
    transaction = fake_transaction

    IdentitySocialCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash("operation" => "deletion") }) do
      assert_social_error("result operation does not match transaction") do
        IdentitySocialCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  test "raises when the result provider does not match the transaction" do
    transaction = fake_transaction

    IdentitySocialCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash("provider" => "apple") }) do
      assert_social_error("result provider does not match transaction") do
        IdentitySocialCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  test "raises when the result transaction id does not match the transaction" do
    transaction = fake_transaction

    IdentitySocialCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash("transaction_id" => "other") }) do
      assert_social_error("result transaction does not match transaction") do
        IdentitySocialCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  test "raises when the result grant jti does not match the transaction" do
    transaction = fake_transaction

    IdentitySocialCeremonyResult.stub(:decode, ->(_token, **) { valid_result_hash("grant_jti" => "other") }) do
      assert_social_error("result grant does not match transaction") do
        IdentitySocialCeremonyResultConsumer.new(transaction: transaction, now: @now).call("token")
      end
    end
  end

  private

  def assert_social_error(message)
    error = assert_raises(IdentitySocialCeremonyContract::Error) { yield }
    assert_includes error.message, message
  end

  def valid_result_hash(overrides = {})
    {
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "operation" => "registration",
      "provider" => "google",
      "transaction_id" => "txn-1",
      "grant_jti" => "grant-1",
      "result_jti" => "result-1",
      "provider_subject_ref" => "subj",
      "provider_subject_digest" => "digest",
    }.merge(overrides)
  end

  def fake_transaction(expired: false, consumed: false)
    FakeTransaction.new(expired: expired, consumed: consumed)
  end

  class FakeTransaction
    attr_accessor :consume_return
    attr_reader :consume_calls, :surface, :actor_ref, :session_ref, :operation, :provider, :transaction_id, :grant_jti

    def initialize(expired:, consumed:)
      @expired = expired
      @consumed = consumed
      @consume_calls = []
      @surface = "app"
      @actor_ref = "actor-1"
      @session_ref = "session-1"
      @operation = "registration"
      @provider = "google"
      @transaction_id = "txn-1"
      @grant_jti = "grant-1"
    end

    def expired?(*) = @expired

    def consumed? = @consumed

    def consume_result!(result_jti:, provider_subject_ref:, provider_subject_digest:, consumed_at:)
      @consume_calls << {
        result_jti: result_jti,
        provider_subject_ref: provider_subject_ref,
        provider_subject_digest: provider_subject_digest,
        consumed_at: consumed_at,
      }
      @consume_return
    end
  end
end
