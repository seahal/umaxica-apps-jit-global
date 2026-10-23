# typed: false
# frozen_string_literal: true

require "test_helper"

# D-136 / D-144 decision table for unknown `kid`s (two.md 6.3), through the public JWKS lookup.
class OidcJwksRefetchLimiterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  JWKS_URI = "https://op.example/.well-known/jwks.json"

  class UnavailableValkey
    def key(suffix) = "test:#{suffix}"

    def call(*) = raise(Umaxica::Valkey::Unavailable, "unavailable")
  end

  class CountingUnavailableValkey < UnavailableValkey
    attr_reader :calls

    def initialize
      super
      @calls = 0
    end

    def call(*)
      @calls += 1
      super
    end
  end

  setup do
    @key = OpenSSL::PKey::EC.generate("secp384r1")
    @fetches = 0
  end

  test "a held key verifies while Valkey is unavailable and Valkey is not consulted" do
    valkey = CountingUnavailableValkey.new
    client = client_with(limiter: OidcJwksRefetchLimiter.new(connection: valkey))

    assert_predicate client.lookup("k1"), :found?
    calls_after_first_fetch = valkey.calls

    assert_predicate client.lookup("k1"), :found?
    assert_equal calls_after_first_fetch, valkey.calls
  end

  test "Valkey unavailable keeps a process-local window, never no limit" do
    now = [Time.current]
    limiter = OidcJwksRefetchLimiter.new(connection: UnavailableValkey.new, clock: -> { now.first })
    client = client_with(limiter:)

    assert_equal :invalid, client.lookup("unknown-1").status
    assert_equal :invalid, client.lookup("unknown-2").status
    assert_equal 1, @fetches, "random kids inside the window cause no further fetch"
  end

  test "window boundary: a new fetch is allowed only after the window" do
    base = Time.current
    [[29, 1], [30, 2], [31, 2]].each do |seconds, expected_fetches|
      @fetches = 0
      now = [base]
      client = client_with(
        limiter: OidcJwksRefetchLimiter.new(
          connection: UnavailableValkey.new, clock: -> {
            now.first
          },
        ),
      )
      client.lookup("unknown-a")
      now[0] = base + seconds

      client.lookup("unknown-b")

      assert_equal expected_fetches, @fetches, "#{seconds}s after the last fetch"
    end
  end

  test "a failed recent fetch makes an unknown kid unavailable, not invalid" do
    client = client_with(
      fetcher: -> {
        @fetches += 1
        raise OidcOpJwksClient::FetchError, "down"
      },
      limiter: OidcJwksRefetchLimiter.new(connection: UnavailableValkey.new),
    )

    assert_equal :unavailable, client.lookup("k1").status
    assert_equal :unavailable, client.lookup("k2").status
    assert_equal 1, @fetches
  end

  test "workers share one lease: many unknown kids across threads cause one fetch per window" do
    clients = Array.new(4) { client_with(limiter: OidcJwksRefetchLimiter.new) }

    results = clients.each_with_index.map { |client, index| Thread.new { client.lookup("random-#{index}").status } }
      .map(&:value)

    assert_equal 1, @fetches, "one fetch for the issuer across workers (statuses: #{results.inspect})"
    assert(results.all? { |status| %i(invalid unavailable).include?(status) })
  end

  test "a recent successful fetch that saw the kid lets another worker fetch once for itself" do
    first = client_with(limiter: OidcJwksRefetchLimiter.new)
    first.lookup("k1")
    second = client_with(limiter: OidcJwksRefetchLimiter.new)

    assert_predicate second.lookup("k1"), :found?
    assert_equal :invalid, second.lookup("absent").status
    assert_equal 2, @fetches
  end

  test "a token whose header fails the cheap checks triggers no fetch and no lease" do
    client = client_with(limiter: OidcJwksRefetchLimiter.new(connection: UnavailableValkey.new))
    other_issuer = JWT.encode(
      { "iss" => "https://other.example", "aud" => ["c"] }, @key, "ES384", { "kid" => "k1", "typ" => "at+jwt" },
    )

    result = OidcOpAccessTokenVerifier.new(
      access_token: other_issuer, client_id: "core-app-jp", realm: "app", issuer: "https://op.example",
      audience: "core-app-jp", jwks_client: client,
    ).call

    assert_equal "invalid_token", result.error
    assert_equal 0, @fetches
    assert_equal :invalid, client.lookup("x" * (OidcOpJwksClient::MAXIMUM_KID_LENGTH + 1)).status
    assert_equal 0, @fetches
  end

  private

  def client_with(limiter:, fetcher: nil)
    fetcher ||=
      lambda do
        @fetches += 1
        { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "k1")] }
      end
    OidcOpJwksClient.new(jwks_uri: JWKS_URI, fetcher:, limiter:)
  end
end
