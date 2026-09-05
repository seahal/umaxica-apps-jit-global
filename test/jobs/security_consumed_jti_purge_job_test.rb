# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SecurityConsumedJtiPurgeJobTest < ActiveJob::TestCase
  setup do
    SecurityConsumedJti.delete_all
  end

  # Boundary: a row whose expires_at is strictly in the past is deleted; one
  # expiring exactly at `now` or later is retained. Deleting a row early would
  # re-open the replay window it exists to close, so the cutoff is the assertion
  # that matters most here.
  test "deletes only rows whose guarded token has already expired" do
    # Time is frozen because the job reads its own `Time.current`. Without this
    # the boundary row is a second in the past by the time the job runs, and the
    # assertion below would pass or fail on how slow the test was.
    freeze_time do
      now = Time.current

      expired = consume!(purpose: :oidc_logout_token, expires_at: now - 1.second)
      boundary = consume!(purpose: :jump_rt_return, expires_at: now)
      active = consume!(purpose: :oidc_client_assertion, expires_at: now + 5.minutes)

      SecurityConsumedJtiPurgeJob.perform_now

      assert_not SecurityConsumedJti.exists?(expired.id)
      assert SecurityConsumedJti.exists?(boundary.id)
      assert SecurityConsumedJti.exists?(active.id)
    end
  end

  test "purges every purpose, not just one" do
    now = Time.current
    SecurityConsumedJti::PURPOSES.each_key { |purpose| consume!(purpose: purpose, expires_at: now - 1.minute) }

    assert_difference -> { SecurityConsumedJti.count }, -SecurityConsumedJti::PURPOSES.size do
      SecurityConsumedJtiPurgeJob.perform_now
    end
  end

  test "is a no-op when nothing is expired" do
    consume!(purpose: :oidc_logout_request, expires_at: 5.minutes.from_now)

    assert_no_difference -> { SecurityConsumedJti.count } do
      SecurityConsumedJtiPurgeJob.perform_now
    end
  end

  private

  def consume!(purpose:, expires_at:)
    SecurityConsumedJti.create!(
      purpose: SecurityConsumedJti::PURPOSES.fetch(purpose),
      issuer: "https://issuer.example",
      jti_digest: SecurityConsumedJti.digest_jti(SecureRandom.uuid),
      expires_at: expires_at,
    )
  end
end
