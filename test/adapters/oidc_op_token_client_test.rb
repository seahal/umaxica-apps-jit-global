# frozen_string_literal: true

require "test_helper"

class OidcOpTokenClientTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # Not a registered Base host, so the request reaches the stubbed adapter, not the in-process OP.
  TOKEN_URL = "https://op.example.test/oauth/token"

  test "a 200 JSON token response is a success" do
    result = refresh_with { [200, json, { access_token: "a", refresh_token: "r" }.to_json] }

    assert_predicate result, :success?
    assert_equal "a", result.token_response[:access_token]
  end

  test "a 200 without an access token or with a corrupt body is an invalid remote answer" do
    assert_equal :invalid_remote, refresh_with { [200, json, { refresh_token: "r" }.to_json] }.outcome
    assert_equal :invalid_remote, refresh_with { [200, json, "not-json"] }.outcome
  end

  test "an OAuth refusal on 400, 401 or 403 is a definitive refusal" do
    [400, 401, 403].each do |status|
      result = refresh_with { [status, json, { error: "invalid_grant" }.to_json] }

      assert_equal :refused, result.outcome, status
      assert_equal "invalid_grant", result.error
    end
  end

  test "a 400 without a known OAuth error is not treated as a refusal" do
    assert_equal :invalid_remote, refresh_with { [400, json, { error: "something_else" }.to_json] }.outcome
  end

  test "429 and every 5xx are dependency failures, never invalid_grant" do
    [429, 500, 502, 503, 599].each do |status|
      assert_equal :dependency, refresh_with { [status, json, { error: "invalid_grant" }.to_json] }.outcome, status
    end
  end

  test "a redirect is refused instead of followed" do
    [301, 302, 307, 399].each do |status|
      assert_equal :invalid_remote, refresh_with { [status, { "Location" => "https://evil.test" }, ""] }.outcome
    end
  end

  test "a connection failure is a dependency failure and a read timeout is indeterminate" do
    assert_equal :dependency, refresh_with { raise Faraday::ConnectionFailed, "refused" }.outcome
    assert_equal :indeterminate, refresh_with { raise Faraday::TimeoutError, "read" }.outcome
  end

  test "an unavailable client assertion stops before any request" do
    OidcClientAssertionJwt.stub(:issue, nil) do
      result = OidcOpTokenClient.refresh(client_id: "core-app-jp", token_url: TOKEN_URL, refresh_token: "r")

      assert_equal :invalid_remote, result.outcome
      assert_equal "client_assertion_unavailable", result.error
    end
  end

  test "success requires a nonempty string access token rather than another JSON type" do
    [nil, "", " ", 0, false, [], {}].each do |access_token|
      connection = Faraday.new
      reply = Faraday::Response.new(status: 200, body: { access_token: }.to_json)
      OidcClientAssertionJwt.stub(:issue, "assertion") do
        OutboundHttp::Connection.stub(:build, connection) do
          connection.stub(:post, reply) do
            response = OidcOpTokenClient.refresh(client_id: "core-app-jp", token_url: TOKEN_URL, refresh_token: "r")

            assert_equal :invalid_remote, response.outcome, access_token.inspect
          end
        end
      end
    end
  end

  test "initial and receipt calls bound the entire HTTP exchange to two and one seconds" do
    [:refresh, :query].each do |operation|
      connection = Faraday.new
      reply = Faraday::Response.new(status: 200, body: { access_token: "a" }.to_json)
      limits = []
      timer =
        lambda do |seconds, error_class, &request|
          limits << seconds

          assert_equal OidcOpTokenClient::RequestDeadlineExceeded, error_class
          request.call
        end
      OidcClientAssertionJwt.stub(:issue, "assertion") do
        Process.stub(:clock_gettime, 100.0) do
          OutboundHttp::Connection.stub(:build, connection) do
            connection.stub(:post, reply) do
              Timeout.stub(:timeout, timer) do
                response =
                  if operation == :refresh
                    OidcOpTokenClient.refresh(
                      client_id: "core-app-jp", token_url: TOKEN_URL,
                      refresh_token: "r",
                    )
                  else
                    OidcOpTokenClient.query_delivery(
                      client_id: "core-app-jp", query_url: TOKEN_URL, refresh_token: "r", attempt_ref: "attempt",
                    )
                  end

                assert_predicate response, :success?
              end
            end
          end
        end
      end

      assert_equal [(operation == :refresh) ? 2.0 : 1.0], limits
    end
  end

  test "caller deadline caps the exchange and already expired deadlines never dispatch" do
    [-0.001, 0.0, 0.001].each do |remaining|
      dispatched = 0
      connection = Faraday.new
      reply = Faraday::Response.new(status: 200, body: { access_token: "a" }.to_json)
      request =
        lambda do |*|
          dispatched += 1
          reply
        end
      timer =
        lambda do |seconds, _error_class, &exchange|
          assert_in_delta remaining, seconds, 0.0000001
          exchange.call
        end
      OidcClientAssertionJwt.stub(:issue, "assertion") do
        Process.stub(:clock_gettime, 100.0) do
          OutboundHttp::Connection.stub(:build, connection) do
            connection.stub(:post, request) do
              Timeout.stub(:timeout, timer) do
                response = OidcOpTokenClient.refresh(
                  client_id: "core-app-jp", token_url: TOKEN_URL, refresh_token: "r", deadline: 100.0 + remaining,
                )

                assert_equal remaining.positive? ? :success : :indeterminate, response.outcome
              end
            end
          end
        end
      end

      assert_equal remaining.positive? ? 1 : 0, dispatched
    end
  end

  test "a response arriving immediately before at or after the exchange deadline obeys the cutoff" do
    [-0.001, 0.0, 0.001].each do |offset|
      now = 100.0
      connection = Faraday.new
      request =
        lambda do |*|
          now = 102.0 + offset
          Faraday::Response.new(status: 200, body: { access_token: "a" }.to_json)
        end
      OidcClientAssertionJwt.stub(:issue, "assertion") do
        Process.stub(:clock_gettime, ->(*) { now }) do
          OutboundHttp::Connection.stub(:build, connection) do
            connection.stub(:post, request) do
              response = OidcOpTokenClient.refresh(client_id: "core-app-jp", token_url: TOKEN_URL, refresh_token: "r")

              assert_equal offset.negative? ? :success : :indeterminate, response.outcome
            end
          end
        end
      end
    end
  end

  test "total HTTP deadline exhaustion is indeterminate even without a socket read timeout" do
    connection = Faraday.new
    OidcClientAssertionJwt.stub(:issue, "assertion") do
      OutboundHttp::Connection.stub(:build, connection) do
        connection.stub(:post, ->(*) { raise OidcOpTokenClient::RequestDeadlineExceeded }) do
          response = OidcOpTokenClient.refresh(client_id: "core-app-jp", token_url: TOKEN_URL, refresh_token: "r")

          assert_equal :indeterminate, response.outcome
          assert_equal "timeout", response.error
        end
      end
    end
  end

  test "the request carries an assertion bound to the exact token endpoint" do
    captured = nil
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(TOKEN_URL) do |env|
          captured = Rack::Utils.parse_query(env.body)
          [200, json, { access_token: "a" }.to_json]
        end
      end
    OidcClientAssertionJwt.stub(:issue, ->(client_id:, token_url:) { "assertion:#{client_id}:#{token_url}" }) do
      stub_outbound_http(stubs) do
        OidcOpTokenClient.refresh(client_id: "core-app-jp", token_url: TOKEN_URL, refresh_token: "r")
      end
    end

    assert_equal "refresh_token", captured.fetch("grant_type")
    assert_equal "core-app-jp", captured.fetch("client_id")
    assert_equal "assertion:core-app-jp:#{TOKEN_URL}", captured.fetch("client_assertion")
    assert_equal OidcClientAssertionJwt::ASSERTION_TYPE, captured.fetch("client_assertion_type")
  end

  private

  def json
    { "Content-Type" => "application/json" }
  end

  def refresh_with(&)
    stubs = Faraday::Adapter::Test::Stubs.new { |stub| stub.post(TOKEN_URL, &) }
    OidcClientAssertionJwt.stub(:issue, "assertion") do
      stub_outbound_http(stubs) do
        OidcOpTokenClient.refresh(client_id: "core-app-jp", token_url: TOKEN_URL, refresh_token: "r")
      end
    end
  end
end
