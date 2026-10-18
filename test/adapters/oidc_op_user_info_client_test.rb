# frozen_string_literal: true

require "test_helper"

class OidcOpUserInfoClientTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "UserInfo accepts an exact subject object and classifies malformed success as dependency failure" do
    bodies = [{ "sub" => "opaque-subject" }, {}, { "sub" => nil }, { "sub" => "" },
              { "sub" => 0 }, { "sub" => true }, [], nil,]
    connection = Faraday.new
    bodies.each do |body|
      response = Faraday::Response.new(status: 200, body: body.to_json)
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:get, response) do
          result = OidcOpUserInfoClient.call(
            access_token: "synthetic-access", userinfo_url: "https://op.example.test/oauth/userinfo",
            require_https: true,
          )
          if body == { "sub" => "opaque-subject" }
            assert_predicate result, :success?
            assert_not_predicate result, :dependency_failure?
            assert_equal body, result.claims
          else
            assert_not_predicate result, :success?
            assert_predicate result, :dependency_failure?
            assert_nil result.claims
          end
        end
      end
    end
  end

  test "UserInfo 429 server error redirects and corrupt success never become credential refusal" do
    connection = Faraday.new
    [[429, '{"error":"invalid_token"}'], [500, '{"error":"invalid_token"}'],
     [503, "unavailable"], [302, '{"sub":"subject"}'], [200, "not-json"],].each do |status, body|
      response = Faraday::Response.new(status: status, body: body)
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:get, response) do
          result = OidcOpUserInfoClient.call(
            access_token: "synthetic-access", userinfo_url: "https://op.example.test/oauth/userinfo",
            require_https: true,
          )

          assert_not_predicate result, :success?
          assert_predicate result, :dependency_failure?
          assert_nil result.claims
        end
      end
    end
  end

  test "UserInfo preserves definitive OAuth refusal from the owner" do
    connection = Faraday.new
    [400, 401, 403].each do |status|
      response = Faraday::Response.new(status: status, body: '{"error":"invalid_token"}')
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:get, response) do
          result = OidcOpUserInfoClient.call(
            access_token: "synthetic-access", userinfo_url: "https://op.example.test/oauth/userinfo",
            require_https: true,
          )

          assert_not_predicate result, :success?
          assert_not_predicate result, :dependency_failure?
          assert_equal "invalid_token", result.error
        end
      end
    end
  end
end
