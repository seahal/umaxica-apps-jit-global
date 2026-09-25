# frozen_string_literal: true

require "test_helper"
require "timeout"

# `consume` is the whole of the single-use guarantee: it locks the row, checks it is still
# unconsumed and still inside its window, and marks it consumed in the same transaction. Each way
# that check can say no has to answer nothing and leave the row alone, so a refused attempt never
# burns a reveal the rightful caller has not made yet.
class SecurityOneTimeRevealTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ATTRIBUTES = {
    actor_type: "Client",
    actor_id: 1,
    session_nonce_digest: "nonce-digest",
    purpose: "client.recovery_secret_credential",
  }.freeze

  def reveal(expires_at: 15.minutes.from_now, payload: "sealed-payload", **overrides)
    SecurityOneTimeReveal.create!(
      **ATTRIBUTES,
      jti_digest: SecureRandom.hex(16),
      encrypted_payload: payload,
      expires_at: expires_at,
      **overrides,
    )
  end

  def consume(record, **overrides)
    SecurityOneTimeReveal.consume(**ATTRIBUTES, jti_digest: record.jti_digest, **overrides)
  end

  test "an unconsumed reveal inside its window hands back the payload and is marked consumed" do
    record = reveal

    assert_equal "sealed-payload", consume(record)
    assert_not_nil record.reload.consumed_at
  end

  test "a second attempt reveals nothing and does not move the consumed timestamp" do
    record = reveal

    assert_equal "sealed-payload", consume(record)
    consumed_at = record.reload.consumed_at

    assert_nil consume(record)
    assert_equal consumed_at, record.reload.consumed_at
  end

  # An expired reveal is refused without being consumed: burning it here would let an attacker who
  # only has to wait out the window destroy a reveal its owner could still have been issued anew.
  test "an expired reveal is refused and left unconsumed" do
    record = reveal(expires_at: 1.second.ago)

    assert_nil consume(record)
    assert_nil record.reload.consumed_at
  end

  test "a reveal expiring exactly now is already outside its window" do
    frozen = Time.current
    record = reveal(expires_at: frozen)

    assert_nil SecurityOneTimeReveal.consume(**ATTRIBUTES, jti_digest: record.jti_digest, now: frozen)
    assert_nil record.reload.consumed_at
  end

  test "a mismatched actor, nonce or purpose reveals nothing and leaves the row unconsumed" do
    record = reveal

    assert_nil consume(record, actor_id: 2)
    assert_nil consume(record, actor_type: "User")
    assert_nil consume(record, session_nonce_digest: "another-nonce-digest")
    assert_nil consume(record, purpose: "client.some_other_purpose")
    assert_nil record.reload.consumed_at

    assert_equal "sealed-payload", consume(record), "the rightful caller can still consume it"
  end

  test "an unknown jti reveals nothing rather than raising" do
    assert_nil SecurityOneTimeReveal.consume(**ATTRIBUTES, jti_digest: SecureRandom.hex(16))
  end
end

class SecurityOneTimeRevealConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "parallel consumers on independent connections return a reveal only once" do
    attributes = {
      jti_digest: SecureRandom.hex(16),
      actor_type: "Client",
      actor_id: 1,
      session_nonce_digest: "parallel-nonce-digest",
      purpose: "client.recovery_secret_credential",
    }
    record = SecurityOneTimeReveal.create!(
      **attributes,
      encrypted_payload: "sealed-parallel-payload",
      expires_at: 15.minutes.from_now,
    )
    start = Queue.new
    ready = Queue.new
    results = []

    # Separate checked-out connections make PostgreSQL serialize the real row-lock race.
    # rubocop:disable ThreadSafety/NewThread
    threads =
      Array.new(2) do
        Thread.new do
          SecurityOneTimeReveal.connection_pool.with_connection do
            ready << true
            start.pop
            results << SecurityOneTimeReveal.consume(**attributes)
          end
        end
      end
    # rubocop:enable ThreadSafety/NewThread

    Timeout.timeout(5) do
      2.times { ready.pop }
      2.times { start << true }
      threads.each(&:value)
    end

    assert_equal 1, results.count("sealed-parallel-payload")
    assert_equal 1, results.count(nil)
    assert_predicate record.reload.consumed_at, :present?
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
    threads&.each(&:join)
    record&.destroy!
  end
end
