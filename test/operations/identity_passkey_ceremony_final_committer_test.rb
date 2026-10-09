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
    audit = nil
    created_attrs = nil

    with_stubs(
      result_hash: valid_result_hash, transaction: @transaction,
      consumer_result: consumption,
    ) do
      ClientPasskey.stub(:transaction, ->(&block) { block.call }) do
        ClientPasskey.stub(
          :create!, ->(attrs) {
                      created_attrs = attrs
                      passkey_record
                    },
        ) do
          IdentityAudit.stub(:record!, ->(**kwargs) { audit = kwargs }) do
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
    end

    assert_equal 7, created_attrs.fetch(:user_id)
    assert_equal "webauthn-id-1", created_attrs.fetch(:webauthn_id)
    assert_equal "public-key", created_attrs.fetch(:public_key)
    assert_equal 5, created_attrs.fetch(:sign_count)
    assert_equal "My Passkey", created_attrs.fetch(:description)
    assert_equal "passkey.register", audit.fetch(:action)
    assert_equal ClientChronicleEvent::PASSKEY_REGISTERED, audit.fetch(:event_id)
    assert_equal "1.2.3.4", audit.fetch(:ip_address)
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

  test "raises when the passkey is already registered" do
    with_stubs(
      result_hash: valid_result_hash, transaction: @transaction,
      consumer_result: FakeConsumption.new,
    ) do
      ClientPasskey.stub(:transaction, ->(&block) { block.call }) do
        ClientPasskey.stub(:create!, ->(_attrs) { raise ActiveRecord::RecordNotUnique.new("dup") }) do
          IdentityAudit.stub(:record!, ->(**) { }) do
            error =
              assert_raises(IdentityPasskeyCeremonyContract::Error) do
                IdentityPasskeyCeremonyFinalCommitter.call!(
                  result_token: "token", actor: @actor, session_ref: "session-1",
                  surface: "app", now: @now,
                )
              end
            assert_includes error.message, "passkey credential is already registered"
          end
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
    def initialize(expired: false, consumed: false)
      @expired = expired
      @consumed = consumed
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
