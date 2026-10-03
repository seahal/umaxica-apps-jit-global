# typed: false
# frozen_string_literal: true

require "test_helper"

# A revoked RP Session may be replaced only after every Access JWT it issued is outside the
# verifier's clock-skew window. These cases pin that window at its boundary and the monotonic
# bookkeeping of the longest Access JWT expiry that feeds it.
class RpSessionRetirementWindowTest < ActiveSupport::TestCase
  setup do
    @session = ClientRpSession.create!(
      client_token: ClientToken.create!(user: Client.create!),
      oidc_client_id: "core-next-rp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
    @access_expires_at = Time.current.change(usec: 0) + 10.minutes
    @leeway = SecurityTokenLifetimes::OIDC_ACCESS_JWT_CLOCK_LEEWAY_SECONDS
  end

  test "a session that is not revoked is still pending retirement" do
    assert @session.retirement_pending?(@access_expires_at + 1.year)
  end

  test "a revoked session with no recorded Access JWT expiry stays pending because nothing proves retirement" do
    @session.revoke!(status: "success")

    assert_nil @session.reload.oidc_access_token_max_expires_at
    assert @session.retirement_pending?(@access_expires_at + 1.year)
  end

  test "a revoked session is pending one second before the leeway after its last Access JWT expiry" do
    @session.record_access_token_expiry!(@access_expires_at)
    @session.revoke!(status: "success")

    assert @session.retirement_pending?(@access_expires_at + @leeway - 1.second)
  end

  test "a revoked session is retired exactly at the leeway after its last Access JWT expiry" do
    @session.record_access_token_expiry!(@access_expires_at)
    @session.revoke!(status: "success")

    assert_not @session.retirement_pending?(@access_expires_at + @leeway)
  end

  test "a revoked session is retired one second after the leeway after its last Access JWT expiry" do
    @session.record_access_token_expiry!(@access_expires_at)
    @session.revoke!(status: "success")

    assert_not @session.retirement_pending?(@access_expires_at + @leeway + 1.second)
  end

  test "recording a shorter Access JWT expiry cannot shorten the retirement window" do
    @session.record_access_token_expiry!(@access_expires_at)

    recorded = @session.record_access_token_expiry!(@access_expires_at - 1.second)

    assert_equal @access_expires_at, recorded
    assert_equal @access_expires_at, @session.reload.oidc_access_token_max_expires_at
  end

  test "recording an equal Access JWT expiry keeps the stored value" do
    @session.record_access_token_expiry!(@access_expires_at)

    assert_equal @access_expires_at, @session.record_access_token_expiry!(@access_expires_at)
  end

  test "recording a longer Access JWT expiry extends the retirement window" do
    @session.record_access_token_expiry!(@access_expires_at)

    recorded = @session.record_access_token_expiry!(@access_expires_at + 1.second)

    assert_equal @access_expires_at + 1.second, recorded
    assert_equal @access_expires_at + 1.second, @session.reload.oidc_access_token_max_expires_at
  end

  test "recording an expiry that is not a time is rejected and stores nothing" do
    assert_raises(ArgumentError) { @session.record_access_token_expiry!(nil) }
    assert_raises(ArgumentError) { @session.record_access_token_expiry!(0) }

    assert_nil @session.reload.oidc_access_token_max_expires_at
  end
end
