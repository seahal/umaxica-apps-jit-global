# frozen_string_literal: true

require "test_helper"

class OidcBackchannelLogoutClientTest < ActiveSupport::TestCase
  test "classifies acknowledgements and failures" do
    { 200 => :acknowledged, 204 => :acknowledged, 400 => "http_400", 503 => "http_503" }.each do |status, expected|
      connection = Object.new
      connection.define_singleton_method(:post) { |*| Struct.new(:status).new(status) }

      OutboundHttp::Connection.stub(:build, connection) do
        assert_equal expected,
                     OidcBackchannelLogoutClient.call(endpoint: "https://rp.example/logout", logout_token: "token")
      end
    end
    connection = Object.new
    connection.define_singleton_method(:post) { |*| raise Faraday::TimeoutError, "timeout" }

    OutboundHttp::Connection.stub(:build, connection) do
      assert_equal "transport_failure",
                   OidcBackchannelLogoutClient.call(endpoint: "https://rp.example/logout", logout_token: "token")
    end
  end
  test "a redirect response is reported without following its Location" do
    requests = []
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/logout") do |environment|
          requests << environment.url.path
          [302, { "Location" => "http://169.254.169.254/metadata" }, ""]
        end
      end
    connection = Faraday.new("https://rp.example") { |builder| builder.adapter(:test, stubs) }
    TestSupport::OutboundHttpGuard.allow do
      OutboundHttp::Connection.stub(:build, connection) do
        assert_equal "http_302",
                     OidcBackchannelLogoutClient.call(endpoint: "https://rp.example/logout", logout_token: "test-token")
      end
    end

    assert_equal ["/logout"], requests
    stubs.verify_stubbed_calls
  end
end
