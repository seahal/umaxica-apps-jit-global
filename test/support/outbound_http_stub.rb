# frozen_string_literal: true

require "faraday"

# Stubs the application's outbound HTTP without reaching the network.
#
# The suite used to stub Net::HTTP class methods directly, which coupled each
# test to the exact call shape (`:get_response` here, `:post_form` there) rather
# than to the request the application makes. Faraday ships a test adapter for
# this, so a stub now states the URL and the response and nothing else.
#
#   stubs = Faraday::Adapter::Test::Stubs.new do |stub|
#     stub.get("https://example.test/keys") { [200, {}, jwks_json] }
#   end
#   stub_outbound_http(stubs) do
#     ...
#   end
#   stubs.verify_stubbed_calls
#
# A network failure is expressed the way Faraday reports one, so the assertion
# matches what the application actually rescues:
#
#   stub.get(url) { raise Faraday::ConnectionFailed, "refused" }
module OutboundHttpStub
  # Replaces OutboundHttp::Connection.build for the duration of the block. The
  # timeout arguments the caller passes are irrelevant to a stubbed adapter;
  # they are covered directly in test/lib/outbound_http/connection_test.rb.
  def stub_outbound_http(stubs)
    connection =
      Faraday.new do |builder|
        builder.request(:url_encoded)
        builder.adapter(:test, stubs)
      end

    OutboundHttp::Connection.stub(:build, ->(**_kwargs) { connection }) do
      TestSupport::OutboundHttpGuard.allow { yield }
    end
  end
end
