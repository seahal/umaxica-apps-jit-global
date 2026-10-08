# typed: false
# frozen_string_literal: true

require "test_helper"
require "concurrent"

class LogoutTransactionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "issue creates an opaque token and stores only the digest" do
    transaction, raw_token = LogoutTransaction.issue!(
      issuer: "acme",
      audience: "sign_app",
      purpose: "sign_out",
      expires_in: 2.minutes,
    )

    public_id, verifier = LogoutTransaction.parse_one_time_url_token(raw_token)

    assert_match(/\A[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\z/, raw_token)
    assert_equal transaction.public_id, public_id
    assert_predicate verifier, :present?
    assert_predicate transaction.token_digest, :present?
    assert_equal 48, transaction.token_digest.bytesize
    assert_not_equal verifier, transaction.token_digest
  end

  test "consume rejects mismatched or expired tokens" do
    transaction, raw_token = LogoutTransaction.issue!(
      issuer: "acme",
      audience: "sign_app",
      purpose: "sign_out",
      expires_in: 1.minute,
    )
    _, verifier = LogoutTransaction.parse_one_time_url_token(raw_token)

    assert_equal :invalid,
                 transaction.consume!(
                   verifier: "wrong", issuer: "acme", audience: "sign_app",
                   purpose: "sign_out",
                 ).status
    transaction.update!(expires_at: 1.minute.ago)

    assert_equal :invalid,
                 transaction.consume!(
                   verifier: verifier, issuer: "acme", audience: "sign_app",
                   purpose: "sign_out",
                 ).status
  end

  test "consume_one_time_url_token rejects malformed tokens and public_id only tokens" do
    assert_equal :invalid, LogoutTransaction.consume_one_time_url_token!(
      raw_token: "",
      issuer: "acme",
      audience: "sign_app",
      purpose: "sign_out",
    ).status
    assert_equal :invalid, LogoutTransaction.consume_one_time_url_token!(
      raw_token: "public_only",
      issuer: "acme",
      audience: "sign_app",
      purpose: "sign_out",
    ).status
    assert_equal :invalid, LogoutTransaction.consume_one_time_url_token!(
      raw_token: "missing.verifier.extra",
      issuer: "acme",
      audience: "sign_app",
      purpose: "sign_out",
    ).status
  end

  test "consume_one_time_url_token rejects unknown public ids without fallback" do
    raw_token = "unknown.#{SecureRandom.urlsafe_base64(48)}"

    assert_equal :invalid, LogoutTransaction.consume_one_time_url_token!(
      raw_token: raw_token,
      issuer: "acme",
      audience: "sign_app",
      purpose: "sign_out",
    ).status
  end

  test "consume rejects issuer audience and purpose mismatches" do
    transaction, raw_token = LogoutTransaction.issue!(
      issuer: "acme",
      audience: "sign_app",
      purpose: "sign_out",
      expires_in: 1.minute,
    )
    _, verifier = LogoutTransaction.parse_one_time_url_token(raw_token)

    assert_equal :invalid,
                 transaction.consume!(
                   verifier: verifier, issuer: "sign", audience: "sign_app",
                   purpose: "sign_out",
                 ).status
    assert_equal :invalid,
                 transaction.consume!(verifier: verifier, issuer: "acme", audience: "other", purpose: "sign_out").status
    assert_equal :invalid,
                 transaction.consume!(verifier: verifier, issuer: "acme", audience: "sign_app", purpose: "other").status
  end

  test "consume rejects revoked tokens" do
    transaction, raw_token = LogoutTransaction.issue!(
      issuer: "acme",
      audience: "sign_app",
      purpose: "sign_out",
      expires_in: 1.minute,
    )
    _, verifier = LogoutTransaction.parse_one_time_url_token(raw_token)
    transaction.revoke!

    assert_equal :invalid,
                 transaction.consume!(
                   verifier: verifier, issuer: "acme", audience: "sign_app",
                   purpose: "sign_out",
                 ).status
  end

  test "consume is idempotent after first success" do
    transaction, raw_token = LogoutTransaction.issue!(
      issuer: "acme",
      audience: "sign_app",
      purpose: "sign_out",
      expires_in: 1.minute,
    )
    _, verifier = LogoutTransaction.parse_one_time_url_token(raw_token)

    first = transaction.consume!(verifier: verifier, issuer: "acme", audience: "sign_app", purpose: "sign_out")
    second = transaction.consume!(verifier: verifier, issuer: "acme", audience: "sign_app", purpose: "sign_out")

    assert_equal :consumed_now, first.status
    assert_equal :consumed, second.status
    assert_predicate transaction.reload.consumed_at, :present?
  end

  test "concurrent consume attempts cannot both consume the same token" do
    transaction, raw_token = LogoutTransaction.issue!(
      issuer: "acme",
      audience: "sign_app",
      purpose: "sign_out",
      expires_in: 1.minute,
    )

    results = consume_concurrently(raw_token)

    assert_equal 2, results.size
    assert_equal 1, results.count { |status| status == :consumed_now }, results.inspect
    assert_equal 1, results.count { |status| status.in?(%i(consumed invalid)) }, results.inspect
    assert_predicate transaction.reload.consumed_at, :present?
  end

  private

  def consume_concurrently(raw_token)
    gate = Queue.new

    futures =
      2.times.map do
        Concurrent::Future.execute do
          ActiveRecord::Base.connection_pool.with_connection do
            gate.pop
            LogoutTransaction.consume_one_time_url_token!(
              raw_token: raw_token,
              issuer: "acme",
              audience: "sign_app",
              purpose: "sign_out",
            )
          end
        ensure
          # Leases taken on this pooled thread outlive the future unless released here.
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end

    2.times { gate << true }
    futures.map { |future| future.value!.status }
  end
end
