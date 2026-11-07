# frozen_string_literal: true

require "test_helper"

class AvatarAuthorityClientSensitiveMutationsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "accept transfer sends the escaped reference and preserves the owner refusal" do
    connection = Faraday.new
    ref = "../foreign?state=approved#fragment"
    requests = []
    response = Faraday::Response.new(status: 403, body: { errors: { base: ["forbidden"] } }.to_json)
    request =
      lambda do |verb, uri, body, headers|
        requests << [verb, uri, body, headers]
        response
      end
    url = nil
    assertion =
      lambda do |client_id:, token_url:|
        url = token_url

        assert_equal "base-app-ww", client_id
        "test-client-assertion"
      end

    OidcClientAssertionJwt.stub(:issue, assertion) do
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:run_request, request) do
          TestSupport::OutboundHttpGuard.allow do
            result = AvatarAuthorityClient.new(
              surface: "app", access_token: "test-access-token", persona: "persona-reference",
            ).accept_transfer(ref, transfer_kind: "app")

            assert_equal :forbidden, result.status
            assert_equal({ "base" => ["forbidden"] }, result.errors)
          end
        end
      end
    end

    verb, uri, body, headers = requests.fetch(0)

    assert_equal :post, verb
    assert_equal "/api/v0/avatar/app/ownership-transfers/#{ERB::Util.url_encode(ref)}/accept", uri.path
    assert_nil uri.query
    assert_nil uri.fragment
    assert_equal url, uri.to_s
    assert_equal "Bearer test-access-token", headers.fetch("Authorization")
    assert_equal "test-client-assertion", headers.fetch("X-Client-Assertion")
    assert_equal "app", Rack::Utils.parse_nested_query(body).fetch("transfer_kind")
  end

  test "cancel transfer relays a successful owner response" do
    connection = Faraday.new
    response = Faraday::Response.new(status: 204, body: "")
    request =
      lambda do |verb, uri, body, _headers|
        assert_equal :post, verb
        assert_equal "/api/v0/avatar/org/ownership-transfers/transfer-reference/cancel", uri.path
        assert_equal "org", Rack::Utils.parse_nested_query(body).fetch("transfer_kind")
        response
      end

    OidcClientAssertionJwt.stub(:issue, "test-client-assertion") do
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:run_request, request) do
          TestSupport::OutboundHttpGuard.allow do
            result = AvatarAuthorityClient.new(
              surface: "org", access_token: "test-access-token", persona: "persona-reference",
            ).cancel_transfer("transfer-reference", transfer_kind: "org")

            assert_equal :ok, result.status
          end
        end
      end
    end
  end

  test "destroy selected avatar maps owner success and refusal" do
    connection = Faraday.new
    responses = [
      Faraday::Response.new(status: 204, body: ""),
      Faraday::Response.new(status: 403, body: { errors: { base: ["forbidden"] } }.to_json),
    ]
    request =
      lambda do |verb, uri, _body, _headers|
        assert_equal :delete, verb
        assert_equal "/api/v0/avatar/org/selected-avatar", uri.path
        responses.shift
      end

    OidcClientAssertionJwt.stub(:issue, "test-client-assertion") do
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:run_request, request) do
          TestSupport::OutboundHttpGuard.allow do
            client = AvatarAuthorityClient.new(
              surface: "org", access_token: "test-access-token", persona: "persona-reference",
            )

            assert_equal :ok, client.destroy_selected_avatar.status
            assert_equal :forbidden, client.destroy_selected_avatar.status
          end
        end
      end
    end
  end
end
