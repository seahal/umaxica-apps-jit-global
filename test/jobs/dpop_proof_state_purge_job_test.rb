# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class DpopProofStatePurgeJobTest < ActiveJob::TestCase
  setup do
    ClientDpopProofState.delete_all
    OperatorDpopProofState.delete_all
  end

  # Boundary: rows with expires_at strictly in the past are deleted; a row
  # expiring exactly at `now` or later is retained. Covers jti rows and nonce
  # rows (both live in the same table, distinguished only by which columns are
  # set) since the purge keys solely on expires_at.
  test "deletes only expired rows across both surfaces" do
    now = Time.current

    expired_jti = ClientDpopProofState.create!(
      jti: SecureRandom.uuid, jkt: "k", htm: "GET", htu: "http://example.com/a",
      seen_at: now - 10.minutes, expires_at: now - 1.second,
    )
    expired_nonce = ClientDpopProofState.create!(
      nonce: SecureRandom.urlsafe_base64(16),
      seen_at: now - 10.minutes, expires_at: now - 1.second,
    )
    active = ClientDpopProofState.create!(
      jti: SecureRandom.uuid, jkt: "k", htm: "GET", htu: "http://example.com/b",
      seen_at: now, expires_at: now + 5.minutes,
    )

    operator_expired = OperatorDpopProofState.create!(
      jti: SecureRandom.uuid, jkt: "k", htm: "GET", htu: "http://example.com/o",
      seen_at: now - 10.minutes, expires_at: now - 1.second,
    )
    operator_active = OperatorDpopProofState.create!(
      jti: SecureRandom.uuid, jkt: "k", htm: "GET", htu: "http://example.com/o",
      seen_at: now, expires_at: now + 5.minutes,
    )

    DpopProofStatePurgeJob.perform_now

    assert_not ClientDpopProofState.exists?(expired_jti.id)
    assert_not ClientDpopProofState.exists?(expired_nonce.id)
    assert ClientDpopProofState.exists?(active.id)
    assert_not OperatorDpopProofState.exists?(operator_expired.id)
    assert OperatorDpopProofState.exists?(operator_active.id)
  end

  test "is a no-op when nothing is expired" do
    now = Time.current
    ClientDpopProofState.create!(
      jti: SecureRandom.uuid, jkt: "k", htm: "GET", htu: "http://example.com/a",
      seen_at: now, expires_at: now + 5.minutes,
    )

    assert_no_difference -> { ClientDpopProofState.count } do
      DpopProofStatePurgeJob.perform_now
    end
  end
end
