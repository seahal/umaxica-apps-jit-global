# typed: false
# frozen_string_literal: true

require "test_helper"

class DpopProofStateableTest < ActiveSupport::TestCase
  setup do
    ClientDpopProofState.delete_all
    OperatorDpopProofState.delete_all
  end

  test "record_jti! stores a proof state once and rejects duplicates" do
    now = Time.current

    assert ClientDpopProofState.record_jti!(
      jti: "jti-1",
      jkt: "jkt-1",
      htm: "POST",
      htu: "https://example.com/token",
      now: now,
    )

    state = ClientDpopProofState.find_by!(jti: "jti-1")

    assert_equal "jkt-1", state.jkt
    assert_equal "POST", state.htm
    assert_equal "https://example.com/token", state.htu
    assert_equal now.to_i, state.seen_at.to_i
    assert_equal (now + DpopProofStateable::TTL_SECONDS.seconds).to_i, state.expires_at.to_i
    assert_not ClientDpopProofState.record_jti!(
      jti: "jti-1",
      jkt: "jkt-2",
      htm: "GET",
      htu: "https://example.com/other",
      now: now,
    )
  end

  test "record_jti! returns false for blank jti" do
    assert_not ClientDpopProofState.record_jti!(
      jti: "",
      jkt: "jkt",
      htm: "POST",
      htu: "https://example.com/token",
    )
  end

  test "consume_nonce! rejects blank, expired, and missing nonces" do
    now = Time.current
    expired = OperatorDpopProofState.create!(
      nonce: "expired",
      seen_at: now - 10.minutes,
      expires_at: now - 1.second,
    )
    fresh = OperatorDpopProofState.create!(
      nonce: "fresh",
      seen_at: now,
      expires_at: now + DpopProofStateable::TTL_SECONDS.seconds,
    )

    assert_not OperatorDpopProofState.consume_nonce!("", now: now)
    assert_not OperatorDpopProofState.consume_nonce!("missing", now: now)
    assert_not OperatorDpopProofState.consume_nonce!(expired.nonce, now: now)
    assert OperatorDpopProofState.consume_nonce!(fresh.nonce, now: now)
  end

  test "active_at excludes expired proof states" do
    now = Time.current
    active = ClientDpopProofState.create!(
      nonce: "active",
      seen_at: now,
      expires_at: now + 1.minute,
    )
    expired = ClientDpopProofState.create!(
      nonce: "expired",
      seen_at: now - 10.minutes,
      expires_at: now - 1.second,
    )

    assert_includes ClientDpopProofState.active_at(now), active
    assert_not_includes ClientDpopProofState.active_at(now), expired
  end
end
