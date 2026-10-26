# frozen_string_literal: true

require "test_helper"
require "timeout"

class OidcJwksConcurrentLookupTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class RecentSuccessfulFetch
    attr_reader :arrivals, :releases

    def initialize
      @arrivals = Queue.new
      @releases = Queue.new
    end

    def acquire(_issuer_key)
      arrivals << true
      releases.pop
      OidcJwksRefetchLimiter::Decision.new(kind: :window, outcome: "ok", kids: ["known"])
    end
  end

  test "concurrent cold lookups of a recently published kid fetch once per client" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    limiter = RecentSuccessfulFetch.new
    fetches = 0
    client = OidcOpJwksClient.new(
      jwks_uri: "https://op.example/.well-known/jwks.json", limiter:,
      fetcher: -> {
        fetches += 1
        { "keys" => [JitSecurityJwtJwk.export_public(key, kid: "known")] }
      },
    )
    workers = Array.new(4) { Thread.new { client.lookup("known") } }

    results =
      Timeout.timeout(10) do
        # Every request observed the cold cache before any fetch can complete.
        4.times { limiter.arrivals.pop }
        4.times { limiter.releases << true }
        workers.map(&:value)
      end

    assert results.all?(&:found?)
    assert_equal 1, fetches
    assert_equal key.public_key.to_octet_string(:uncompressed),
                 results.first.key.public_key.to_octet_string(:uncompressed)
    assert_predicate client.lookup("known"), :found?
    assert_equal 1, fetches
  ensure
    workers&.each { |worker| worker.kill if worker.alive? }
    workers&.each(&:join)
  end
end
