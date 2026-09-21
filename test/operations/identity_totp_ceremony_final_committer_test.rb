# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityTotpCeremonyFinalCommitterTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.parse("2026-06-24 12:00:00 UTC")
    @actor = FakeActor.new(id: 7, public_id: "actor-1")
    @transaction = FakeTransaction.new
    @candidate = FakeCandidate.new
  end

  test "commits a totp credential and records an audit event" do
    totp_record = Object.new
    audit = nil
    deleted_ref = nil
    credentials_assoc = FakeAssociation.new([FakeTotpRecord.new], create_result: totp_record)

    with_stubs do
      @actor.stub(:client_totp_credentials, credentials_assoc) do
        ClientTotpCredential.stub(
          :create_for_user!, ->(user:, **attrs) {
                               assert_same @actor, user
                               credentials_assoc.created_attrs = attrs
                               totp_record
                             },
        ) do
          IdentityTotpCeremonyCandidateStore.stub(:delete, ->(ref) { deleted_ref = ref }) do
            IdentityAudit.stub(:record!, ->(**kwargs) { audit = kwargs }) do
              commit = IdentityTotpCeremonyFinalCommitter.call!(
                result_token: "token",
                actor: @actor,
                session_ref: "session-1",
                surface: "app",
                ip_address: "1.2.3.4",
                user_agent: "UA",
                now: @now,
              )

              assert_not_nil commit.transaction
              assert_not_nil commit.result
              assert_same totp_record, commit.totp
            end
          end
        end
      end
    end

    assert_equal "totp-key", credentials_assoc.created_attrs.fetch(:private_key)
    assert_equal "Authenticator", credentials_assoc.created_attrs.fetch(:title)
    assert_equal ClientTotpCredentialStatus::ACTIVE,
                 credentials_assoc.created_attrs.fetch(:user_totp_credential_status_id)
    assert_equal "candidate-1", deleted_ref
    assert_equal "totp.enable", audit.fetch(:action)
    assert_equal ClientChronicleEvent::TOTP_ENABLED, audit.fetch(:event_id)
    assert_equal "1.2.3.4", audit.fetch(:ip_address)
  end

  test "raises when the surface is not app" do
    with_stubs(_surface: "com", result_hash: valid_result_hash.merge("surface" => "com")) do
      assert_totp_error("surface is invalid") do
        IdentityTotpCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "com", now: @now,
        )
      end
    end
  end

  test "raises when the actor is blank" do
    with_stubs do
      assert_totp_error("actor is required") do
        IdentityTotpCeremonyFinalCommitter.call!(
          result_token: "token", actor: nil, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the session ref is blank" do
    with_stubs do
      assert_totp_error("session_ref is required") do
        IdentityTotpCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the result actor does not match the current actor" do
    with_stubs(result_hash: valid_result_hash.merge("actor_ref" => "other")) do
      assert_totp_error("result actor does not match current actor") do
        IdentityTotpCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the result session does not match the current session" do
    with_stubs(result_hash: valid_result_hash.merge("session_ref" => "other")) do
      assert_totp_error("result session does not match current session") do
        IdentityTotpCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the result surface does not match the current surface" do
    with_stubs(result_hash: valid_result_hash.merge("surface" => "com")) do
      assert_totp_error("result surface does not match current surface") do
        IdentityTotpCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the transaction is expired" do
    with_stubs(transaction: FakeTransaction.new(expired: true)) do
      assert_totp_error("transaction is expired") do
        IdentityTotpCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the transaction is already consumed" do
    with_stubs(transaction: FakeTransaction.new(consumed: true)) do
      assert_totp_error("transaction is already consumed") do
        IdentityTotpCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the candidate digest does not match the result" do
    with_stubs(candidate: FakeCandidate.new(digest: "other")) do
      assert_totp_error("candidate digest does not match result") do
        IdentityTotpCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the candidate actor does not match the current actor" do
    with_stubs(candidate: FakeCandidate.new(actor_ref: "other")) do
      assert_totp_error("candidate actor does not match current actor") do
        IdentityTotpCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the candidate session does not match the current session" do
    with_stubs(candidate: FakeCandidate.new(session_ref: "other")) do
      assert_totp_error("candidate session does not match current session") do
        IdentityTotpCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the candidate surface does not match the current surface" do
    with_stubs(candidate: FakeCandidate.new(surface: "com")) do
      assert_totp_error("candidate surface does not match current surface") do
        IdentityTotpCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the totp credential limit is reached" do
    with_stubs do
      full_assoc = FakeAssociation.new(Array.new(ClientTotpCredential::MAX_TOTP_SLOTS) { FakeTotpRecord.new })
      @actor.stub(:client_totp_credentials, full_assoc) do
        IdentityTotpCeremonyCandidateStore.stub(:delete, ->(_ref) { }) do
          assert_totp_error("TOTP credential limit is reached") do
            IdentityTotpCeremonyFinalCommitter.call!(
              result_token: "token", actor: @actor, session_ref: "session-1",
              surface: "app", now: @now,
            )
          end
        end
      end
    end
  end

  private

  def with_stubs(_surface: "app", result_hash: valid_result_hash, transaction: @transaction,
                 candidate: @candidate)
    store = FakeStore.new(transaction)
    consumer = FakeConsumer.new(FakeConsumption.new)
    IdentityTotpCeremonyResult.stub(:decode, ->(_token, **) { result_hash }) do
      IdentityTotpCeremonyReplayStore.stub(:for, ->(_surface) { store }) do
        IdentityTotpCeremonyResultConsumer.stub(:new, ->(**) { consumer }) do
          IdentityTotpCeremonyCandidateStore.stub(:fetch!, ->(_ref) { candidate }) do
            yield
          end
        end
      end
    end
  end

  def assert_totp_error(message)
    error = assert_raises(IdentityTotpCeremonyContract::Error) { yield }
    assert_includes error.message, message
  end

  def valid_result_hash
    {
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "credential_candidate_ref" => "candidate-1",
      "credential_candidate_digest" => "digest-1",
    }
  end

  class FakeActor
    attr_reader :id, :public_id

    def initialize(id:, public_id:)
      @id = id
      @public_id = public_id
      @totp_credentials = FakeAssociation.new([])
    end

    def blank?
      false
    end

    def present?
      true
    end

    def client_totp_credentials
      @totp_credentials
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

  class FakeCandidate
    attr_reader :ref, :digest, :actor_ref, :session_ref, :surface, :private_key, :title, :last_otp_at

    def initialize(ref: "candidate-1", digest: "digest-1", actor_ref: "actor-1",
                   session_ref: "session-1", surface: "app", private_key: "totp-key",
                   title: "Authenticator", last_otp_at: nil)
      @ref = ref
      @digest = digest
      @actor_ref = actor_ref
      @session_ref = session_ref
      @surface = surface
      @private_key = private_key
      @title = title
      @last_otp_at = last_otp_at
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
      @result = {}
    end
  end

  class FakeAssociation
    include Enumerable

    attr_reader :created_attrs

    def initialize(records, create_result: Object.new)
      @records = records
      @create_result = create_result
      @created_attrs = nil
    end

    delegate :count, to: :@records

    def each(&)
      @records.each(&)
    end

    def create!(attrs)
      @created_attrs = attrs
      @create_result
    end

    def created_attrs=(attrs)
      @created_attrs = attrs
    end
  end

  # rubocop:disable Lint/EmptyClass
  class FakeTotpRecord
  end
  # rubocop:enable Lint/EmptyClass
end
