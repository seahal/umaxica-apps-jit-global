# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeLogoutTransactionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "logout challenge is an opaque public identifier" do
    transaction = build_transaction(origin_surface: "sign")
    other = build_transaction(origin_surface: "sign")

    assert_predicate transaction, :valid?
    assert_predicate other, :valid?
    assert_match(/\A[A-Za-z0-9_-]{10,}\z/, transaction.logout_challenge)
    assert_no_match(/\A\d+\z/, transaction.logout_challenge)
    assert_not_equal transaction.logout_challenge, other.logout_challenge
  end

  test "sign origin progresses origin cleared then acme cleared then finalization" do
    transaction = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))

    transaction.advance_step!("origin_cleared")

    assert_equal %w(origin_cleared), transaction.completed_steps
    assert_equal "acme_cleared", transaction.expected_step

    transaction.advance_step!("acme_cleared")

    assert_equal %w(origin_cleared acme_cleared), transaction.completed_steps
    assert_equal "finalized", transaction.expected_step

    transaction.finalize!

    assert_predicate transaction, :finalized?
    assert_equal %w(origin_cleared acme_cleared finalized), transaction.completed_steps
    assert_predicate transaction.finalized_at, :present?
  end

  test "acme origin requires sign cleared before finalization" do
    transaction = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "acme"))

    transaction.advance_step!("origin_cleared")

    assert_equal "sign_cleared", transaction.expected_step

    assert_raises(ArgumentError) { transaction.finalize! }

    transaction.advance_step!("sign_cleared")
    transaction.finalize!

    assert_predicate transaction, :finalized?
  end

  test "wrong step is rejected" do
    transaction = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "core"))

    assert_raises(ArgumentError) { transaction.advance_step!("acme_cleared") }
    assert_equal [], transaction.completed_steps
    assert_equal "origin_cleared", transaction.expected_step
  end

  test "Browser RP logout starts with its authority-first step sequence" do
    transaction = AcmeLogoutTransaction.create!(
      transaction_attrs(
        origin_surface: "core",
        workflow: AcmeLogoutTransaction::BROWSER_RP_WORKFLOW,
        initiating_client_id: "core-app",
        expected_step: AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
      ),
    )

    assert_predicate transaction, :browser_rp_workflow?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED, transaction.expected_step
    assert_equal [], transaction.completed_steps

    transaction.advance_step!(AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED)
    transaction.advance_step!(AcmeLogoutTransaction::STEP_AUTHORITY_CLEANUP_ISSUED)
    transaction.advance_step!(AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED)
    transaction.advance_step!(AcmeLogoutTransaction::STEP_ORIGIN_RP_SESSION_REVOKED)
    transaction.finalize!

    assert_predicate transaction, :finalized?
    assert_equal AcmeLogoutTransaction.browser_rp_step_sequence + [AcmeLogoutTransaction::STEP_FINALIZED],
                 transaction.completed_steps
  end

  test "Browser RP workflow rejects a historical origin-first step" do
    transaction = build_transaction(
      origin_surface: "core",
      workflow: AcmeLogoutTransaction::BROWSER_RP_WORKFLOW,
      expected_step: AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
      completed_steps: [AcmeLogoutTransaction::STEP_ORIGIN_CLEARED],
    )

    assert_not transaction.valid?
    assert_includes transaction.errors[:completed_steps], "contains steps from another logout workflow"
  end

  test "replaying a completed step is idempotent" do
    transaction = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "base"))

    transaction.advance_step!("origin_cleared")
    assert_no_changes -> { transaction.reload.completed_steps } do
      transaction.advance_step!("origin_cleared")
    end

    assert_equal %w(origin_cleared), transaction.reload.completed_steps
  end

  test "expired transactions fail closed" do
    transaction = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "palm", expires_at: 1.minute.ago))

    assert_predicate transaction, :expired?
    assert_raises(ArgumentError) { transaction.advance_step!("origin_cleared") }
  end

  test "finalization is one-time" do
    transaction = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))
    transaction.advance_step!("origin_cleared")
    transaction.advance_step!("acme_cleared")
    transaction.finalize!

    assert_predicate transaction, :finalized?
    first_finalized_at = transaction.finalized_at

    assert_no_changes -> { transaction.reload.finalized_at } do
      transaction.finalize!
    end

    assert_equal first_finalized_at.to_i, transaction.reload.finalized_at.to_i
  end

  private

  def build_transaction(**overrides)
    AcmeLogoutTransaction.new(transaction_attrs(**overrides))
  end

  def transaction_attrs(origin_surface:, expires_at: 10.minutes.from_now, **overrides)
    {
      origin_surface: origin_surface,
      initiating_client_id: "#{origin_surface}-rp",
      completion_url: "https://example.test/#{origin_surface}/sign/out/complete",
      expires_at: expires_at,
      expected_step: AcmeLogoutTransaction.step_sequence_for(origin_surface).first,
      status: AcmeLogoutTransaction::STATUS_INITIATED,
    }.merge(overrides)
  end
end
