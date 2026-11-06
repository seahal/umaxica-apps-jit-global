# frozen_string_literal: true

require "test_helper"

class OidcOpRevocationClientTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ENDPOINT = "https://visa.example.test/oauth/revoke"
  REFRESH_TOKEN = "rp-session-id:secret-verifier"

  test "posts only the bound refresh token body using the registered private key client method" do
    client = OidcClientRegistry.find!("core-app-jp")

    assert_equal "private_key_jwt", client.registered_token_endpoint_auth_method

    response = Faraday::Response.new(status: 200, body: "")
    connection = Faraday.new
    calls = []
    build_options = []
    assertions = []
    assertion_issuer =
      lambda do |client_id:, token_url:|
        assertions << [client_id, token_url]
        "assertion-#{assertions.length}"
      end
    request =
      lambda do |uri, body|
        calls << [uri, body]
        response
      end

    result = nil
    OidcIssuer.stub(:revocation_endpoint, ENDPOINT) do
      OidcClientAssertionJwt.stub(:issue, assertion_issuer) do
        OutboundHttp::Connection.stub(
          :build, ->(**options) {
                    build_options << options
                    connection
                  },
        ) do
          connection.stub(:post, request) do
            result = OidcOpRevocationClient.revoke(
              client_id: client.client_id, resource_type: "client", token: REFRESH_TOKEN,
            )
          end
        end
      end
    end

    assert_predicate result, :success?
    assert_equal 1, calls.length
    uri, body = calls.fetch(0)

    assert_equal ENDPOINT, uri.to_s
    assert_equal REFRESH_TOKEN, body.fetch(:token)
    assert_equal "refresh_token", body.fetch(:token_type_hint)
    assert_equal client.client_id, body.fetch(:client_id)
    assert_equal OidcClientAssertionJwt::ASSERTION_TYPE, body.fetch(:client_assertion_type)
    assert_equal "assertion-1", body.fetch(:client_assertion)
    assert_equal [[client.client_id, ENDPOINT]], assertions
    assert_equal 1, build_options.length
    assert_in_delta 1.0, build_options.fetch(0).fetch(:open_timeout), 0.01
    assert_in_delta 1.0, build_options.fetch(0).fetch(:read_timeout), 0.01
    assert_in_delta 1.0, build_options.fetch(0).fetch(:write_timeout), 0.01
    assert_not_includes uri.to_s, REFRESH_TOKEN
  end

  test "a first-party revocation goes to the local port while the assertion audience stays public" do
    client = OidcClientRegistry.find!("core-app-jp")
    public_endpoint = "https://#{ENV.fetch("PUBLIC_VISA_SERVICE_URL")}/oauth/revoke"
    connection = Faraday.new
    posted = []
    audiences = []
    issuer =
      lambda do |client_id:, token_url:|
        audiences << [client_id, token_url]
        "assertion"
      end

    result = nil
    OidcIssuer.stub(:revocation_endpoint, public_endpoint) do
      OidcClientAssertionJwt.stub(:issue, issuer) do
        OutboundHttp::Connection.stub(:build, connection) do
          connection.stub(:post, ->(uri, _body) { (posted << uri) && Faraday::Response.new(status: 200, body: "") }) do
            result = OidcOpRevocationClient.revoke(
              client_id: client.client_id, resource_type: "client",
              token: REFRESH_TOKEN,
            )
          end
        end
      end
    end
    sent = posted.sole

    assert_predicate result, :success?
    assert_equal ["http", ENV.fetch("PUBLIC_VISA_SERVICE_URL"), Integer(ENV.fetch("PORT"), exception: false) || 3000,
                  "/oauth/revoke",],
                 [sent.scheme, sent.host, sent.port, sent.path]
    assert_equal [[client.client_id, public_endpoint]], audiences
  end

  test "retries one transient transport failure with a fresh client assertion" do
    client = OidcClientRegistry.find!("core-app-jp")
    connection = Faraday.new
    response = Faraday::Response.new(status: 200, body: "")
    request_count = 0
    assertions = []
    posted_assertions = []
    assertion_issuer =
      lambda do |client_id:, token_url:|
        assertions << [client_id, token_url]
        "assertion-#{assertions.length}"
      end
    request =
      lambda do |_, body|
        request_count += 1
        posted_assertions << body.fetch(:client_assertion)
        raise Faraday::ConnectionFailed, "temporary transport failure" if request_count == 1

        response
      end

    result = nil
    OidcIssuer.stub(:revocation_endpoint, ENDPOINT) do
      OidcClientAssertionJwt.stub(:issue, assertion_issuer) do
        OutboundHttp::Connection.stub(:build, connection) do
          connection.stub(:post, request) do
            result = OidcOpRevocationClient.revoke(
              client_id: client.client_id, resource_type: "client", token: REFRESH_TOKEN,
            )
          end
        end
      end
    end

    assert_predicate result, :success?
    assert_equal 2, request_count
    assert_equal [[client.client_id, ENDPOINT], [client.client_id, ENDPOINT]], assertions
    assert_equal %w(assertion-1 assertion-2), posted_assertions
  end

  test "classifies response boundaries without retrying any HTTP response" do
    client = OidcClientRegistry.find!("core-app-jp")
    [
      [201, :unexpected_response],
      [299, :unexpected_response],
      [300, :unexpected_redirect],
      [399, :unexpected_redirect],
      [400, :rejected],
      [499, :rejected],
      [500, :endpoint_failure],
    ].each do |status, expected_outcome|
      connection = Faraday.new
      request_count = 0
      request =
        lambda do |*|
          request_count += 1
          Faraday::Response.new(status:, body: "")
        end

      result = nil
      OidcIssuer.stub(:revocation_endpoint, ENDPOINT) do
        OidcClientAssertionJwt.stub(:issue, "assertion") do
          OutboundHttp::Connection.stub(:build, connection) do
            connection.stub(:post, request) do
              result = OidcOpRevocationClient.revoke(
                client_id: client.client_id, resource_type: "client", token: REFRESH_TOKEN,
              )
            end
          end
        end
      end

      assert_equal expected_outcome, result.outcome, status
      assert_equal 1, request_count, status
    end
  end

  test "stops after one retry when both transport attempts fail" do
    client = OidcClientRegistry.find!("core-app-jp")
    connection = Faraday.new
    request_count = 0
    request =
      lambda do |*|
        request_count += 1
        raise Faraday::ConnectionFailed, "temporary transport failure"
      end

    result = nil
    OidcIssuer.stub(:revocation_endpoint, ENDPOINT) do
      OidcClientAssertionJwt.stub(:issue, "assertion") do
        OutboundHttp::Connection.stub(:build, connection) do
          connection.stub(:post, request) do
            result = OidcOpRevocationClient.revoke(
              client_id: client.client_id, resource_type: "client", token: REFRESH_TOKEN,
            )
          end
        end
      end
    end

    assert_equal :network_unavailable, result.outcome
    assert_equal 2, request_count
  end
end
