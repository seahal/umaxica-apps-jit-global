# frozen_string_literal: true

require "test_helper"

# A recent fetch by another worker saw the kid, so this process fetches for itself (two.md 6.3).
# A failed self-fetch is not retried for the same kid in the same process for 30 seconds (D-174).
class OidcJwksSelfFetchNegativeCacheTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class RecentSuccessfulFetch
    def acquire(_issuer_key)
      OidcJwksRefetchLimiter::Decision.new(kind: :window, outcome: "ok", kids: %w(known other))
    end
  end

  setup do
    @key = OpenSSL::PKey::EC.generate("secp384r1")
    @now = Time.zone.parse("2026-10-25 12:00:00")
    @fetches = 0
    @failing = true
  end

  test "a failed self-fetch answers unavailable after one fetch" do
    result = client.lookup("known")

    assert_predicate result, :unavailable?
    assert_equal "fetch_failed", result.reason
    assert_equal 1, @fetches
  end

  test "just below 30 seconds after a failed self-fetch the same kid is not fetched again" do
    jwks = client
    jwks.lookup("known")
    @now += 30.seconds - 0.001

    result = jwks.lookup("known")

    assert_predicate result, :unavailable?
    assert_equal "recent_self_fetch_failed", result.reason
    assert_equal 1, @fetches
  end

  test "at 30 seconds after a failed self-fetch the kid is fetched again" do
    jwks = client
    jwks.lookup("known")
    @now += 30.seconds
    @failing = false

    assert_predicate jwks.lookup("known"), :found?
    assert_equal 2, @fetches
  end

  test "just above 30 seconds after a failed self-fetch the kid is fetched again" do
    jwks = client
    jwks.lookup("known")
    @now += 30.seconds + 0.001

    result = jwks.lookup("known")

    assert_predicate result, :unavailable?
    assert_equal "fetch_failed", result.reason
    assert_equal 2, @fetches
  end

  test "a failed self-fetch for one kid does not suppress another kid" do
    jwks = client
    jwks.lookup("known")

    jwks.lookup("other")

    assert_equal 2, @fetches
  end

  test "a successful self-fetch after the window serves the kid from cache" do
    jwks = client
    jwks.lookup("known")
    @now += 30.seconds
    @failing = false
    jwks.lookup("known")

    assert_predicate jwks.lookup("known"), :found?
    assert_equal 2, @fetches
  end

  private

  def client
    OidcOpJwksClient.new(
      jwks_uri: "https://op.example/.well-known/jwks.json", limiter: RecentSuccessfulFetch.new,
      clock: -> { @now },
      fetcher: -> {
        @fetches += 1
        raise OidcOpJwksClient::FetchError, "unreachable" if @failing

        { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "known"),
                     JitSecurityJwtJwk.export_public(OpenSSL::PKey::EC.generate("secp384r1"), kid: "other"),] }
      },
    )
  end
end
