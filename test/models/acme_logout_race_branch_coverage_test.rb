# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeLogoutRaceBranchCoverageTest < ActiveSupport::TestCase
  test "advance_step! after lock returns when concurrently finalized failed or completed" do
    txn = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))

    # Concurrent finalize between outer check and lock
    txn.define_singleton_method(:lock!) do
      update_columns(
        completed_steps: %w(origin_cleared acme_cleared finalized),
        expected_step: "finalized",
        finalized_at: Time.current,
        status: AcmeLogoutTransaction::STATUS_FINALIZED,
      )
      reload
    end

    assert_same txn, txn.advance_step!("origin_cleared")

    txn2 = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))
    txn2.define_singleton_method(:lock!) do
      update_columns(status: AcmeLogoutTransaction::STATUS_FAILED, failed_at: Time.current)
      reload
    end

    assert_same txn2, txn2.advance_step!("origin_cleared")

    txn3 = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))
    txn3.advance_step!("origin_cleared")
    txn3.define_singleton_method(:lock!) do
      # already completed origin_cleared on reload path
      reload
    end
    # Force completed_steps include after lock by updating before lock returns
    txn3.define_singleton_method(:lock!) do
      update_columns(completed_steps: %w(origin_cleared), expected_step: "acme_cleared")
      reload
    end

    assert_same txn3, txn3.advance_step!("origin_cleared")
  end

  test "advance_step! after lock raises when concurrently expired or wrong step" do
    txn = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))
    txn.define_singleton_method(:lock!) do
      update_columns(expires_at: 1.minute.ago)
      reload
    end
    assert_raises(ArgumentError) { txn.advance_step!("origin_cleared") }

    txn2 = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))
    txn2.define_singleton_method(:lock!) do
      update_columns(expected_step: "acme_cleared")
      reload
    end
    assert_raises(ArgumentError) { txn2.advance_step!("origin_cleared") }
  end

  test "finalize! after lock returns when concurrently finalized and raises when expired or not ready" do
    txn = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))
    txn.advance_step!("origin_cleared")
    txn.advance_step!("acme_cleared")
    txn.define_singleton_method(:lock!) do
      update_columns(
        completed_steps: %w(origin_cleared acme_cleared finalized),
        expected_step: "finalized",
        finalized_at: Time.current,
        status: AcmeLogoutTransaction::STATUS_FINALIZED,
      )
      reload
    end

    assert_same txn, txn.finalize!

    expired = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))
    expired.advance_step!("origin_cleared")
    expired.advance_step!("acme_cleared")
    expired.define_singleton_method(:lock!) do
      update_columns(expires_at: 1.minute.ago)
      reload
    end
    assert_raises(ArgumentError) { expired.finalize! }

    not_ready = AcmeLogoutTransaction.create!(transaction_attrs(origin_surface: "sign"))
    not_ready.advance_step!("origin_cleared")
    not_ready.advance_step!("acme_cleared")
    not_ready.define_singleton_method(:lock!) do
      update_columns(expected_step: "acme_cleared", completed_steps: %w(origin_cleared))
      reload
    end
    assert_raises(ArgumentError) { not_ready.finalize! }
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
