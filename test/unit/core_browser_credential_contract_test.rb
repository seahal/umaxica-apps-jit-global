# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CoreBrowserCredentialContractTest < ActiveSupport::TestCase
  test "cookie options encode required core browser flags" do
    access = CoreBrowserCredentialContract.access_cookie_options(expires_at: 10.minutes.from_now)
    refresh = CoreBrowserCredentialContract.refresh_cookie_options(expires_at: 1.day.from_now)
    oidc = CoreBrowserCredentialContract.oidc_cookie_options(expires_at: 10.minutes.from_now)

    assert access.fetch(:secure)
    assert access.fetch(:httponly)
    assert_equal :strict, access.fetch(:same_site)
    assert_equal "/", access.fetch(:path)

    assert refresh.fetch(:secure)
    assert refresh.fetch(:httponly)
    assert_equal :strict, refresh.fetch(:same_site)
    assert_equal "/", refresh.fetch(:path)

    assert oidc.fetch(:secure)
    assert oidc.fetch(:httponly)
    assert_equal :lax, oidc.fetch(:same_site)
    assert_equal "/", oidc.fetch(:path)
  end

  test "native and side audiences are classified as non core browser" do
    assert CoreBrowserCredentialContract.native_or_side_audience?("aud" => ["palm-api"])
    assert CoreBrowserCredentialContract.native_or_side_audience?("aud" => ["side-service"])
    assert_not CoreBrowserCredentialContract.native_or_side_audience?(
      "aud" => [CoreBrowserCredentialContract::ACCESS_AUDIENCE],
    )
    assert_not CoreBrowserCredentialContract.native_or_side_audience?("aud" => ["port-api"])
  end

  test "core browser access token expiry is capped by the root session deadline" do
    now = Time.utc(2026, 9, 13, 9, 0)
    absolute_expiry = now + 2.minutes
    token = Struct.new(:discarded_at).new(absolute_expiry)

    assert_equal absolute_expiry,
                 CoreBrowserCredentialContract.access_token_expires_at_for(token_record: token, now: now)
  end
end
