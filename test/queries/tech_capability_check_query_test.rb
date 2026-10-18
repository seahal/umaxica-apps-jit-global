# frozen_string_literal: true

require "test_helper"

class TechCapabilityCheckQueryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ENDPOINT = "https://www.umaxica.org/api/v0/tech-capability-checks"

  test "a caller that is not the Tech client with an assertion bound to this endpoint is denied" do
    OidcClientRegistry.stub(:authenticate_assertion, false) do
      assert_not TechCapabilityCheckQuery.call(
        access_token: "t", client_assertion: "a", endpoint_uri: ENDPOINT,
        host: "www.umaxica.org",
      )
    end
  end

  test "an Access JWT that does not authenticate is denied" do
    OidcClientRegistry.stub(:authenticate_assertion, true) do
      assert_not TechCapabilityCheckQuery.call(
        access_token: "not-a-jwt", client_assertion: "a",
        endpoint_uri: ENDPOINT, host: "www.umaxica.org",
      )
    end
  end

  test "an authority database failure denies instead of permitting" do
    OidcClientRegistry.stub(:authenticate_assertion, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
      assert_not TechCapabilityCheckQuery.call(
        access_token: "t", client_assertion: "a", endpoint_uri: ENDPOINT,
        host: "www.umaxica.org",
      )
    end
  end

  test "the RP client fails closed without a token or on transport failure" do
    assert_not TechCapabilityClient.allowed?(access_token: "")
    stubs = Faraday::Adapter::Test::Stubs.new { |stub| stub.post(%r{tech-capability-checks}) { raise Faraday::TimeoutError } }
    OidcClientAssertionJwt.stub(:issue, "assertion") do
      OutboundHttp::Connection.stub(
        :build, Faraday.new { |b|
                  b.request(:url_encoded)
                  b.adapter(:test, stubs)
                },
      ) do
        TestSupport::OutboundHttpGuard.allow { assert_not TechCapabilityClient.allowed?(access_token: "t") }
      end
    end
  end
end
