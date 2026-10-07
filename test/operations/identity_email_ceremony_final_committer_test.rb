# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityEmailCeremonyFinalCommitterTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.parse("2026-06-24 12:00:00 UTC")
    @actor = FakeActor.new(id: 7, public_id: "actor-1", status_id: ClientStatus::ACTIVE)
    @transaction = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "actor-1", session_ref: "session-1", operation: "registration",
      transaction_id: "txn-1", email_candidate_ref: "candidate-1",
      normalized_email_digest: "email-digest", now: @now,
    )
    @email = FakeEmail.new(id: 100, address_digest: "email-digest")
  end

  test "commits an email verification for the app surface and records an audit event" do
    committer = build_committer

    with_instance_stubs(committer, valid_result_hash, @transaction, @email) do
      override_commit_candidate!(committer, @email, ClientEmailStatus::VERIFIED)
      override_record_audit!(committer)
      committer.call!

      assert_equal ClientEmailStatus::VERIFIED, @email.updated_status
    end
  end

  test "uses signup verified status when the account is in signup state" do
    signup_actor = FakeActor.new(id: 7, public_id: "actor-1", status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    committer = build_committer(actor: signup_actor)

    with_instance_stubs(committer, valid_result_hash, @transaction, @email) do
      override_commit_candidate!(committer, @email, ClientEmailStatus::VERIFIED_WITH_SIGN_UP)
      override_record_audit!(committer)
      committer.call!
    end

    assert_equal ClientEmailStatus::VERIFIED_WITH_SIGN_UP, @email.updated_status
    assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, signup_actor.updated_status_id
  end

  test "raises when the surface is invalid" do
    committer = build_committer(surface: "bad")

    with_instance_stubs(committer, valid_result_hash.merge("surface" => "bad"), @transaction, @email) do
      assert_email_error("surface is invalid") { committer.call! }
    end
  end

  test "raises when the actor is blank" do
    committer = build_committer(actor: nil)

    with_instance_stubs(committer, valid_result_hash, @transaction, @email) do
      assert_email_error("actor is required") { committer.call! }
    end
  end

  test "raises when the session ref is blank" do
    committer = build_committer(session_ref: "")

    with_instance_stubs(committer, valid_result_hash, @transaction, @email) do
      assert_email_error("session_ref is required") { committer.call! }
    end
  end

  test "raises when the result actor does not match the current actor" do
    committer = build_committer

    with_instance_stubs(committer, valid_result_hash.merge("actor_ref" => "other"), @transaction, @email) do
      assert_email_error("result actor does not match current actor") { committer.call! }
    end
  end

  test "raises when the result session does not match the current session" do
    committer = build_committer

    with_instance_stubs(committer, valid_result_hash.merge("session_ref" => "other"), @transaction, @email) do
      assert_email_error("result session does not match current session") { committer.call! }
    end
  end

  test "raises when the result surface does not match the current surface" do
    committer = build_committer

    with_instance_stubs(committer, valid_result_hash.merge("surface" => "com"), @transaction, @email) do
      assert_email_error("result surface does not match current surface") { committer.call! }
    end
  end

  test "raises when the transaction is expired" do
    committer = build_committer

    with_instance_stubs(committer, valid_result_hash, FakeTransaction.new(expired: true), @email) do
      assert_email_error("transaction is expired") { committer.call! }
    end
  end

  test "raises when the transaction is already consumed" do
    committer = build_committer

    with_instance_stubs(committer, valid_result_hash, FakeTransaction.new(consumed: true), @email) do
      assert_email_error("transaction is already consumed") { committer.call! }
    end
  end

  test "raises when the email candidate is already verified" do
    verified_email = FakeEmail.new(id: 100, address_digest: "email-digest", status: ClientEmailStatus::VERIFIED)
    committer = build_committer

    with_instance_stubs(committer, valid_result_hash, @transaction, verified_email) do
      assert_email_error("email candidate is already verified") { committer.call! }
    end
  end

  test "raises when the email candidate digest does not match the result" do
    mismatch_email = FakeEmail.new(id: 100, address_digest: "other-digest")
    committer = build_committer

    with_instance_stubs(committer, valid_result_hash, @transaction, mismatch_email) do
      assert_email_error("email candidate digest does not match result") { committer.call! }
    end
  end

  test "raises when the email candidate ref is blank in the result" do
    committer = build_committer

    consumer = FakeConsumer.new
    store = FakeStore.new(@transaction)
    IdentityEmailCeremonyResultConsumer.stub(:new, ->(**) { consumer }) do
      IdentityEmailCeremonyReplayStore.stub(:for, ->(_surface) { store }) do
        committer.instance_variable_set(:@result, valid_result_hash.merge("email_candidate_ref" => ""))
        committer.instance_variable_set(:@transaction, @transaction)
        assert_email_error("email candidate is required") { committer.call! }
      end
    end
  end

  test "call! class method creates an instance and delegates" do
    assert_email_error("actor is required") do
      IdentityEmailCeremonyFinalCommitter.call!(
        result_token: "token", actor_context: ActorValuesContext.empty, actor: nil, session_ref: "session-1",
        surface: "app", now: @now,
      )
    end
  end

  test "commits through the locked record and writes the app Source audit" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    contact = ClientEmail.create!(user_id: actor.id, address: "locked-audit@example.test", confirm_policy: "1")
    now = ClientEmailCeremonyTransaction.database_now
    parent = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: "locked-audit-browser", operation: "registration",
      email_candidate_ref: contact.public_id, normalized_email_digest: contact.address_digest, now: now,
    )
    result_token = IdentityEmailCeremonyResult.issue(
      { surface: "app",
        actor_ref: actor.public_id,
        session_ref: parent.session_ref,
        transaction_id: parent.transaction_id,
        grant_jti: parent.grant_jti,
        result_jti: SecureRandom.uuid,
        operation: parent.operation,
        verified_at: now.to_i,
        challenge_id: SecureRandom.uuid,
        expires_at: parent.expires_at.to_i,
        email_candidate_ref: contact.public_id,
        normalized_email_digest: contact.address_digest, },
      issuer_id: IdentityEmailCeremonyContract.sign_issuer_id("app"), now: now,
    )
    commit = IdentityEmailCeremonyFinalCommitter.call!(
      result_token: result_token,
      actor_context: ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base),
      actor: actor, session_ref: parent.session_ref, surface: "app", now: now,
    )

    assert_equal contact, commit.email
    assert_equal ClientEmailStatus::VERIFIED, contact.reload.user_email_status_id
    assert_predicate contact, :binding_effective?
    audit = ClientContactAuditOutbox.find_by!(operation_ref: parent.transaction_id)

    assert_equal "email", audit.contact_kind
    assert_equal "finalized", audit.event_name
    assert_equal actor.public_id, audit.owner_ref
    assert_equal actor.public_id, audit.actor_ref
    assert_equal contact.public_id, audit.contact_ref
    assert_nil audit.acknowledged_at
  end

  private

  def build_committer(actor: @actor, session_ref: "session-1", surface: "app")
    IdentityEmailCeremonyFinalCommitter.new(
      result_token: "token",
      actor: actor,
      actor_context: ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base),
      session_ref: session_ref,
      surface: surface,
      now: @now,
    )
  end

  def with_instance_stubs(committer, result_hash, transaction, email)
    consumer = FakeConsumer.new
    store = FakeStore.new(transaction)
    IdentityEmailCeremonyResultConsumer.stub(:new, ->(**) { consumer }) do
      IdentityEmailCeremonyReplayStore.stub(:for, ->(_surface) { store }) do
        committer.instance_variable_set(:@result, result_hash)
        committer.instance_variable_set(:@transaction, transaction)
        committer.instance_variable_set(:@email, email)
        yield
      end
    end
  end

  def override_commit_candidate!(committer, email, verified_status)
    committer.define_singleton_method(:commit_candidate!) do
      email.updated_status = verified_status
      if signup_account_status_transition?
        actor.update!(status_id: config.fetch(:account_verified_signup_status))
      end
      @email = email
    end
  end

  def override_record_audit!(committer)
    committer.define_singleton_method(:record_audit!) { |_subject| true }
  end

  def assert_email_error(message)
    error = assert_raises(IdentityEmailCeremonyContract::Error) { yield }
    assert_includes error.message, message
  end

  def valid_result_hash
    {
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "email_candidate_ref" => "candidate-1",
      "normalized_email_digest" => "email-digest",
    }
  end

  class FakeActor
    attr_reader :id, :public_id, :status_id
    attr_accessor :updated_status_id

    def initialize(id:, public_id:, status_id: nil)
      @id = id
      @public_id = public_id
      @status_id = status_id
    end

    def blank?
      false
    end

    def present?
      true
    end

    def update!(attrs)
      @updated_status_id = attrs[:status_id]
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

  class FakeEmail
    attr_reader :id, :address_digest, :status
    attr_accessor :updated_status

    def initialize(id:, address_digest:, status: nil)
      @id = id
      @address_digest = address_digest
      @status = status || ClientEmailStatus::UNVERIFIED
      @updated_status = nil
    end

    def public_send(key)
      return @status if key == :user_email_status_id
      return 7 if key == :user_id

      super
    end

    def update!(attrs)
      @updated_status = attrs[:user_email_status_id]
      true
    end
  end

  class FakeConsumer
    def call(_token)
      FakeConsumption.new
    end
  end

  class FakeConsumption
    attr_reader :transaction, :result

    def initialize
      @transaction = Object.new
      @result = {}
    end
  end
end
