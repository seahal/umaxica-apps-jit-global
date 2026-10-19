# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityPasskeyCeremonyFinalCommitterTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.parse("2026-06-24 12:00:00 UTC")
    @actor = FakeActor.new(id: 7, public_id: "actor-1")
    @transaction = FakeTransaction.new
  end

  test "commits a passkey for the app surface and records an audit event" do
    consumption = FakeConsumption.new
    passkey_record = Object.new
    allocation = nil

    with_stubs(
      result_hash: valid_result_hash, transaction: @transaction,
      consumer_result: consumption,
    ) do
      ClientPasskey.stub(:transaction, ->(&block) { block.call }) do
        PasskeyRegistrationOperation.stub(
          :call!, ->(**kwargs) {
                    allocation = kwargs
                    passkey_record
                  },
        ) do
          commit = IdentityPasskeyCeremonyFinalCommitter.call!(
            result_token: "token",
            actor: @actor,
            session_ref: "session-1",
            surface: "app",
            ip_address: "1.2.3.4",
            user_agent: "UA",
            now: @now,
          )

          assert_same consumption.transaction, commit.transaction
          assert_same consumption.result, commit.result
          assert_same passkey_record, commit.passkey
        end
      end
    end

    assert_same @actor, allocation.fetch(:actor)
    assert_equal ClientPasskey, allocation.fetch(:passkey_class)
    assert_equal "webauthn-id-1", allocation.fetch(:attributes).fetch(:webauthn_id)
    assert_equal "public-key", allocation.fetch(:attributes).fetch(:public_key)
    assert_equal 5, allocation.fetch(:attributes).fetch(:sign_count)
    assert_equal "My Passkey", allocation.fetch(:attributes).fetch(:description)
    assert_equal "passkey.registered.settings", allocation.fetch(:audit).fetch(:event_type)
    assert_equal "app", allocation.fetch(:audit).fetch(:surface)
    assert_equal "actor-1", allocation.fetch(:audit).fetch(:actor_ref)
    assert_equal "txn-1", allocation.fetch(:audit).fetch(:operation_ref)
  end

  test "raises when the surface is invalid" do
    with_stubs(
      result_hash: valid_result_hash.merge("surface" => "bad"),
      transaction: @transaction,
    ) do
      assert_passkey_error("surface is invalid") do
        IdentityPasskeyCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "bad", now: @now,
        )
      end
    end
  end

  test "raises when the actor is blank" do
    with_stubs(result_hash: valid_result_hash, transaction: @transaction) do
      assert_passkey_error("actor is required") do
        IdentityPasskeyCeremonyFinalCommitter.call!(
          result_token: "token", actor: nil, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the session ref is blank" do
    with_stubs(result_hash: valid_result_hash, transaction: @transaction) do
      assert_passkey_error("session_ref is required") do
        IdentityPasskeyCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the result actor does not match the current actor" do
    with_stubs(
      result_hash: valid_result_hash.merge("actor_ref" => "other"),
      transaction: @transaction,
    ) do
      assert_passkey_error("result actor does not match current actor") do
        IdentityPasskeyCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the result session does not match the current session" do
    with_stubs(
      result_hash: valid_result_hash.merge("session_ref" => "other"),
      transaction: @transaction,
    ) do
      assert_passkey_error("result session does not match current session") do
        IdentityPasskeyCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the result surface does not match the current surface" do
    with_stubs(
      result_hash: valid_result_hash.merge("surface" => "com"),
      transaction: @transaction,
    ) do
      assert_passkey_error("result surface does not match current surface") do
        IdentityPasskeyCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the transaction is expired" do
    with_stubs(
      result_hash: valid_result_hash,
      transaction: FakeTransaction.new(expired: true),
    ) do
      assert_passkey_error("transaction is expired") do
        IdentityPasskeyCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the transaction is already consumed" do
    with_stubs(
      result_hash: valid_result_hash,
      transaction: FakeTransaction.new(consumed: true),
    ) do
      assert_passkey_error("transaction is already consumed") do
        IdentityPasskeyCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "propagates an unclassified uniqueness failure without claiming credential duplication" do
    with_stubs(
      result_hash: valid_result_hash, transaction: @transaction,
      consumer_result: FakeConsumption.new,
    ) do
      ClientPasskey.stub(:transaction, ->(&block) { block.call }) do
        PasskeyRegistrationOperation.stub(
          :call!, ->(**) { raise ActiveRecord::RecordNotUnique.new("dup") },
        ) do
          error =
            assert_raises(ActiveRecord::RecordNotUnique) do
              IdentityPasskeyCeremonyFinalCommitter.call!(
                result_token: "token", actor: @actor, session_ref: "session-1",
                surface: "app", now: @now,
              )
            end
          assert_equal "dup", error.message
        end
      end
    end
  end

  private

  def with_stubs(result_hash:, transaction:, consumer_result: FakeConsumption.new)
    store = FakeStore.new(transaction)
    consumer = FakeConsumer.new(consumer_result)
    IdentityPasskeyCeremonyResult.stub(:decode, ->(_token, **) { result_hash }) do
      IdentityPasskeyCeremonyReplayStore.stub(:for, ->(_surface) { store }) do
        IdentityPasskeyCeremonyResultConsumer.stub(:new, ->(**) { consumer }) do
          yield
        end
      end
    end
  end

  def assert_passkey_error(message)
    error = assert_raises(IdentityPasskeyCeremonyContract::Error) { yield }
    assert_includes error.message, message
  end

  def valid_result_hash
    {
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "webauthn_id" => "webauthn-id-1",
      "public_key" => "public-key",
      "sign_count" => 5,
      "description" => "My Passkey",
    }
  end

  class FakeActor
    attr_reader :id, :public_id

    def initialize(id:, public_id:)
      @id = id
      @public_id = public_id
    end

    def blank?
      false
    end

    def present?
      true
    end
  end

  class FakeTransaction
    attr_reader :transaction_id

    def initialize(expired: false, consumed: false, transaction_id: "txn-1")
      @expired = expired
      @consumed = consumed
      @transaction_id = transaction_id
    end

    def expired?(*)
      @expired
    end

    def consumed?
      @consumed
    end
  end

  class FakeStore
    def initialize(transaction)
      @transaction = transaction
    end

    def find_transaction!(_id)
      @transaction
    end
  end

  class FakeConsumer
    def initialize(consumption)
      @consumption = consumption
    end

    def call(_token)
      @consumption
    end
  end

  class FakeConsumption
    attr_reader :transaction, :result

    def initialize
      @transaction = Object.new
      @result = { "webauthn_id" => "webauthn-id-1",
                  "public_key" => "public-key",
                  "sign_count" => 5,
                  "description" => "My Passkey", }
    end
  end
end
