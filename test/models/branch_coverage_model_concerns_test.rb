# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageModelConcernsTest < ActiveSupport::TestCase
  test "AcmeLogoutTransaction covers finalized failed expired and validation arms" do
    txn = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))
    txn.advance_step!("origin_cleared")
    txn.advance_step!("acme_cleared")
    txn.finalize!

    assert_same txn, txn.advance_step!("origin_cleared")
    assert_same txn, txn.finalize!

    failed = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))
    failed.update_columns(status: AcmeLogoutTransaction::STATUS_FAILED, failed_at: Time.current)

    assert_same failed, failed.advance_step!("origin_cleared")

    not_ready = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))
    not_ready.advance_step!("origin_cleared")
    assert_raises(ArgumentError) { not_ready.finalize! }

    expired = AcmeLogoutTransaction.create!(
      transaction_attrs(origin_surface: "sign", expires_at: 1.minute.ago).merge(
        completed_steps: %w(origin_cleared acme_cleared),
        expected_step: "finalized",
      ),
    )
    assert_raises(ArgumentError) { expired.finalize! }

    invalid = AcmeLogoutTransaction.new(
      transaction_attrs(origin_surface: "sign").merge(completed_steps: %w(not_a_step)),
    )

    assert_not invalid.valid?
    assert_includes invalid.errors[:completed_steps].join, "invalid"
  end

  private

  def transaction_attrs(origin_surface:, expires_at: 10.minutes.from_now)
    {
      origin_surface: origin_surface,
      initiating_client_id: "#{origin_surface}-rp",
      completion_url: "https://example.test/#{origin_surface}/sign/out/complete",
      expires_at: expires_at,
      expected_step: AcmeLogoutTransaction.step_sequence_for(origin_surface).first,
      status: AcmeLogoutTransaction::STATUS_INITIATED,
    }
  end
end
