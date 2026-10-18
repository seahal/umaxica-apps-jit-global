# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcRpBrowserCredentialContractTest < ActiveSupport::TestCase
  test "RP cookie names stay separate from root cookie families" do
    assert_equal "__Host-rp-access", OidcRpCookieName.access(production: true)
    assert_equal "__Host-rp-refresh", OidcRpCookieName.refresh(production: true)
    assert_equal "rp-access", OidcRpCookieName.access(production: false)
    assert_equal "rp-refresh", OidcRpCookieName.refresh(production: false)
    assert_not_equal AuthenticationCookieName.access(production: true), OidcRpCookieName.access(production: true)
    assert_not_equal AuthenticationCookieName.refresh(production: true), OidcRpCookieName.refresh(production: true)
  end

  test "RP cookie flags and expiries come from the token response" do
    now = Time.utc(2026, 10, 6, 1, 0, 0)
    response = {
      access_token: "access",
      refresh_token: "refresh",
      expires_in: 300,
      refresh_token_expires_in: 3600,
    }

    expiries = OidcRpBrowserCredentialContract.cookie_expiries_from_response(response, now: now)
    access = OidcRpBrowserCredentialContract.access_cookie_options(expires_at: expiries.fetch(:access_expires_at))
    refresh = OidcRpBrowserCredentialContract.refresh_cookie_options(expires_at: expiries.fetch(:refresh_expires_at))

    assert_equal now + 5.minutes, expiries.fetch(:access_expires_at)
    assert_equal now + 1.hour, expiries.fetch(:refresh_expires_at)
    [access, refresh].each do |options|
      assert_equal JitSessionCookieConfig.force_secure?, options.fetch(:secure)
      assert options.fetch(:httponly)
      assert_equal :lax, options.fetch(:same_site)
      assert_equal "/", options.fetch(:path)
      assert_not options.fetch(:domain)
      assert_predicate options.fetch(:expires), :present?
    end
  end

  test "a reversed response expiry is rejected instead of extending refresh authority" do
    error =
      assert_raises(ArgumentError) do
        OidcRpBrowserCredentialContract.cookie_expiries_from_response(
          { expires_in: 301, refresh_token_expires_in: 300 },
        )
      end

    assert_match(/precedes access expiry/, error.message)
  end

  test "a token response without server expiry cannot create an RP cookie" do
    assert_raises(ArgumentError) do
      OidcRpBrowserCredentialContract.cookie_expiries_from_response(
        { access_token: "access", refresh_token: "refresh", expires_in: 300 },
      )
    end
  end
end
