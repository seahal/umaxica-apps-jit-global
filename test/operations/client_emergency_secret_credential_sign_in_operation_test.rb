# typed: false
# frozen_string_literal: true

require "test_helper"

# Exercises the cross-database contract on the real app_zenith and app_ticket connections, so the
# tests do not run inside a wrapping transaction. RuboCop's thread rule is disabled because
# independent worker threads with their own connections are the behavior under test.
# rubocop:disable ThreadSafety/NewThread
class ClientEmergencySecretCredentialSignInOperationTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  Op = ClientEmergencySecretCredentialSignInOperation
  TTL = 5.minutes
  MAX_FAILURES = 5

  setup do
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientSecretCredentialStatus::DEFAULTS.each { |id| ClientSecretCredentialStatus.find_or_create_by!(id: id) }
    ClientSecretCredentialKind::DEFAULTS.each { |id| ClientSecretCredentialKind.find_or_create_by!(id: id) }
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    @user = Client.create!(status_id: ClientStatus::NOTHING)
    ClientEmail.create!(
      user: @user, address: "emergency-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @issued_at = Time.current.floor
    @credential, @raw = issue!
  end

  teardown do
    token_ids = ClientToken.where(user_id: @user.id).pluck(:id)
    ClientEmergencySignInOperation.where(client_token_id: token_ids).delete_all
    ClientToken.where(id: token_ids).delete_all
    ClientSecretCredential.where(user_id: @user.id).delete_all
    ClientEmail.where(user_id: @user.id).delete_all
    Client.where(id: @user.id).delete_all
  end

  test "claim, session proof, then consume signs in exactly once" do
    claim = Op.claim!(credential_public_id: @credential.public_id, raw_secret: @raw, now: @issued_at)

    assert_kind_of Op::Claim, claim
    token = Op.issue_session!(claim) { create_token! }

    assert_equal :consumed, Op.consume!(operation_id: claim.operation_id)
    assert_predicate @credential.reload.consumed_at, :present?
    assert_equal ClientSecretCredentialStatus::USED, @credential.user_identity_secret_status_id
    assert_equal token.id, ClientEmergencySignInOperation.find_by!(operation_id: claim.operation_id).client_token_id
    assert_equal :claimed, refusal(Op.claim!(credential_public_id: @credential.public_id, raw_secret: @raw))
  end

  test "expiry boundary: one second before is accepted, the expiry instant and after are refused" do
    assert_kind_of Op::Claim, Op.claim!(
      credential_public_id: @credential.public_id, raw_secret: @raw,
      now: @issued_at + TTL - 1.second,
    )

    at_expiry, raw_at = issue!
    after_expiry, raw_after = issue!

    assert_equal :expired, refusal(
      Op.claim!(
        credential_public_id: at_expiry.public_id, raw_secret: raw_at,
        now: @issued_at + TTL,
      ),
    )
    assert_equal :expired, refusal(
      Op.claim!(
        credential_public_id: after_expiry.public_id, raw_secret: raw_after,
        now: @issued_at + TTL + 1.second,
      ),
    )
  end

  test "failure cap: after 4 mismatches the secret still works" do
    4.times { assert_equal :mismatch, refusal(claim_with("wrong")) }

    assert_kind_of Op::Claim, claim_with(@raw)
  end

  test "failure cap: the 5th mismatch locks, and the 6th attempt with the right secret is refused" do
    5.times { assert_equal :mismatch, refusal(claim_with("wrong")) }

    assert_equal 5, @credential.reload.failure_count
    assert_predicate @credential.locked_at, :present?
    assert_equal :locked, refusal(claim_with(@raw))
    assert_equal 5, @credential.reload.failure_count
  end

  test "only credential mismatches count toward the failure cap" do
    @credential.update!(claim_operation_id: SecureRandom.uuid, claimed_at: @issued_at)

    assert_equal :claimed, refusal(claim_with("wrong"))
    assert_equal :not_found, refusal(Op.claim!(credential_public_id: "missing", raw_secret: @raw))

    assert_equal 0, @credential.reload.failure_count
  end

  test "an empty secret is a mismatch" do
    assert_equal :mismatch, refusal(claim_with(""))
    assert_equal 1, @credential.reload.failure_count
  end

  test "a failure before the claim leaves the credential usable; after the claim it is excluded" do
    assert_equal :mismatch, refusal(claim_with("wrong"))
    claim = claim_with(@raw)

    assert_kind_of Op::Claim, claim
    assert_equal :claimed, refusal(claim_with(@raw))
  end

  test "a rolled-back session transaction leaves no proof and the credential stays claimed" do
    claim = claim_with(@raw)

    assert_raises(ActiveRecord::StatementInvalid) do
      Op.issue_session!(claim) do
        create_token!
        raise ActiveRecord::StatementInvalid, "session write failed"
      end
    end

    assert_equal 0, ClientToken.where(user_id: @user.id).count
    assert_nil ClientEmergencySignInOperation.find_by(operation_id: claim.operation_id)
    assert_equal :unconfirmed, Op.consume!(operation_id: claim.operation_id)
    assert_nil @credential.reload.consumed_at
    assert_equal :claimed, refusal(claim_with(@raw))
  end

  test "a stop after the session commit but before consume is finished by reconcile, once" do
    claim = claim_with(@raw)
    Op.issue_session!(claim) { create_token! }
    # Process stops here: consume! never runs.

    assert_equal :claimed, refusal(claim_with(@raw))
    assert_equal :consumed, Op.reconcile!(credential_public_id: @credential.public_id)
    assert_equal :consumed, Op.reconcile!(credential_public_id: @credential.public_id)
    assert_equal 1, ClientToken.where(user_id: @user.id).count
  end

  test "a lost HTTP response cannot be retried into a second session" do
    claim = claim_with(@raw)
    Op.issue_session!(claim) { create_token! }
    Op.consume!(operation_id: claim.operation_id)

    assert_equal :claimed, refusal(claim_with(@raw))
    assert_raises(ActiveRecord::RecordNotUnique) { Op.issue_session!(claim) { create_token! } }
    assert_equal 1, ClientToken.where(user_id: @user.id).count
  end

  test "a forged second operation for the same credential cannot record a second session" do
    claim = claim_with(@raw)
    Op.issue_session!(claim) { create_token! }
    forged = Op::Claim.new(operation_id: SecureRandom.uuid, credential_public_id: @credential.public_id)

    assert_raises(ActiveRecord::RecordNotUnique) { Op.issue_session!(forged) { create_token! } }
    assert_raises(Op::OperationMismatch) { Op.consume!(operation_id: forged.operation_id) }
    assert_equal 1, ClientToken.where(user_id: @user.id).count
  end

  test "an unknown outcome with no proof stays claimed and never revives" do
    claim = claim_with(@raw)

    assert_equal :unconfirmed, Op.reconcile!(credential_public_id: @credential.public_id)
    assert_equal claim.operation_id, @credential.reload.claim_operation_id
    assert_equal :claimed, refusal(claim_with(@raw))
  end

  test "an app_ticket outage during issue leaves the credential claimed and fail-closed" do
    claim = claim_with(@raw)

    assert_raises(ActiveRecord::ConnectionNotEstablished) do
      Op.issue_session!(claim) { raise ActiveRecord::ConnectionNotEstablished, "app_ticket unavailable" }
    end

    assert_equal :unconfirmed, Op.consume!(operation_id: claim.operation_id)
    assert_equal :claimed, refusal(claim_with(@raw))
  end

  test "concurrent claims on independent connections produce exactly one claim" do
    results = concurrently(4) { Op.claim!(credential_public_id: @credential.public_id, raw_secret: @raw) }

    assert_equal 1, results.grep(Op::Claim).size, results.inspect
    assert_equal [:claimed], results.grep(Op::Failure).map(&:reason).uniq
  end

  test "concurrent consumes of one operation consume once and keep one session" do
    claim = claim_with(@raw)
    Op.issue_session!(claim) { create_token! }

    results = concurrently(4) { Op.consume!(operation_id: claim.operation_id) }

    assert_equal [:consumed], results.uniq
    assert_equal 1, @credential.reload.use_count
  end

  private

  def issue!
    result = SignSecretIssue.call(
      credential_collection: @user.client_secret_credentials,
      secret_credential_class: ClientSecretCredential,
      name: "Emergency",
      secret_kind: Op::SECRET_KIND,
      usage_policy: Op::USAGE_POLICY,
      max_uses: 1,
      max_failures: MAX_FAILURES,
      issued_at: @issued_at,
      legacy_attributes: { discard_at: @issued_at + TTL },
    )
    [result.secret_credential, result.raw_secret_credential]
  end

  def claim_with(raw)
    Op.claim!(credential_public_id: @credential.public_id, raw_secret: raw, now: @issued_at)
  end

  def refusal(result)
    assert_kind_of Op::Failure, result
    result.reason
  end

  def create_token!
    ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  def concurrently(count)
    ready = Queue.new
    release = Queue.new
    threads =
      Array.new(count) do
        Thread.new do
          ready << true
          release.pop
          ClientSecretCredential.connection_pool.with_connection do
            ClientEmergencySignInOperation.connection_pool.with_connection { yield }
          end
        rescue StandardError => e
          e
        end
      end

    count.times { ready.pop }
    count.times { release << true }
    threads.map(&:value)
  end
end
# rubocop:enable ThreadSafety/NewThread
