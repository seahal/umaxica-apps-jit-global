# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcRpTokenClientTest < ActiveSupport::TestCase
  setup do
    @original_issuers = JitSecurityJwtRegistry.instance_variable_get(:@issuers)
  end

  teardown do
    JitSecurityJwtRegistry.instance_variable_set(:@issuers, @original_issuers)
  end

  TOKEN_URL = "https://log.umaxica.app/oauth/token"

  test "uses private_key_jwt when a client assertion key is configured" do
    captured = nil
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(TOKEN_URL) do |env|
          captured = Rack::Utils.parse_nested_query(env.body)
          [200, {}, JSON.generate(id_token: "id-token")]
        end
      end

    with_oidc_client_key("ACME_APP") do
      stub_outbound_http(stubs) do
        result = exchange(code: "code", code_verifier: "verifier")

        assert_predicate result, :success?
      end
    end

    stubs.verify_stubbed_calls

    assert_equal OidcClientAssertionJwt::ASSERTION_TYPE, captured.fetch("client_assertion_type")
    assert_predicate captured.fetch("client_assertion"), :present?
    assert_not captured.key?("client_secret")
  end

  test "private_key_jwt clients fail locally instead of falling back to client_secret" do
    refuse_outbound_http =
      lambda do |**_kwargs|
        flunk("private_key_jwt client must not exchange with client_secret when assertion key is missing")
      end

    OidcClientAssertionJwt.stub(:issue, nil) do
      OutboundHttp::Connection.stub(:build, refuse_outbound_http) do
        result = exchange(code: "code", code_verifier: "verifier", client_secret: "fallback-secret")

        assert_not_predicate result, :success?
        assert_equal "client_assertion_unavailable", result.error
      end
    end
  end

  test "logs safe token exchange failure details for non-success responses" do
    body = JSON.generate(error: "invalid_grant", error_description: "Authorization code expired")

    logged =
      capture_exchange_log(->(_env) { [400, {}, body] }) do |result|
        assert_not_predicate result, :success?
        assert_equal "invalid_grant", result.error
      end

    event = token_exchange_failure_event(logged)

    assert_equal "base-rails-rp", event.dig("data", "client_id")
    assert_equal "log.umaxica.app", event.dig("data", "endpoint_host")
    assert_equal 400, event.dig("data", "http_status")
    assert_equal "invalid_grant", event.dig("data", "oauth_error")
    assert_nil event.dig("data", "oauth_error_description")
    assert_no_match(/sensitive-code|sensitive-verifier/, logged.join("\n"))
  end

  # Faraday wraps the SocketError this used to raise, so the logged error_class
  # is now the Faraday class. The invariant under test is unchanged: the class
  # is recorded and the upstream message, which may name a host, is not.
  test "logs safe token exchange failure details for transport errors" do
    transport_failure = ->(_env) { raise Faraday::ConnectionFailed, "connection refused for secret.example" }
    logged =
      capture_exchange_log(transport_failure) do |result|
        assert_not_predicate result, :success?
        assert_equal "token_exchange_failed", result.error
      end

    event = token_exchange_failure_event(logged)

    assert_equal "base-rails-rp", event.dig("data", "client_id")
    assert_equal "log.umaxica.app", event.dig("data", "endpoint_host")
    assert_equal "Faraday::ConnectionFailed", event.dig("data", "error_class")
    assert_no_match(/sensitive-code|sensitive-verifier|secret\.example/, logged.join("\n"))
  end

  # An authorization code is single-use, so the exchange must reach the token
  # endpoint exactly once even when it fails.
  test "does not retry a failed exchange" do
    attempts = 0
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(TOKEN_URL) do
          attempts += 1
          raise Faraday::TimeoutError, "read timeout"
        end
      end

    with_oidc_client_key("ACME_APP") do
      stub_outbound_http(stubs) do
        assert_not_predicate exchange(code: "code", code_verifier: "verifier"), :success?
      end
    end

    assert_equal 1, attempts
  end

  test "allows an explicitly approved local HTTP token endpoint" do
    token_url = "http://www.app.localhost:3000/oauth/token"
    captured_require_https = nil
    response = Struct.new(:body) do
      def success? = true
    end.new(JSON.generate(id_token: "id-token"))
    connection = Object.new
    connection.define_singleton_method(:post) { |_uri, _params| response }
    build_connection =
      lambda do |require_https:, **_options|
        captured_require_https = require_https
        connection
      end

    OutboundHttp::Connection.stub(:build, build_connection) do
      result = OidcRpTokenClient.call(
        token_url: token_url,
        client_id: "base-rails-rp",
        client_secret: nil,
        code: "code",
        redirect_uri: "https://auth.app.localhost/oidc/callback",
        code_verifier: "verifier",
        require_https: false,
      )

      assert_predicate result, :success?
    end

    assert_not captured_require_https
  end

  test "rejects an HTTP token endpoint unless it is explicitly approved" do
    result = OidcRpTokenClient.call(
      token_url: "http://www.app.localhost:3000/oauth/token",
      client_id: "base-rails-rp",
      client_secret: nil,
      code: "code",
      redirect_uri: "https://auth.app.localhost/oidc/callback",
      code_verifier: "verifier",
    )

    assert_not_predicate result, :success?
    assert_equal "token_exchange_failed", result.error
  end

  private

  def exchange(code:, code_verifier:, client_secret: nil)
    OidcRpTokenClient.call(
      token_url: TOKEN_URL,
      client_id: "base-rails-rp",
      client_secret: client_secret,
      code: code,
      redirect_uri: "https://www.umaxica.app/auth/callback",
      code_verifier: code_verifier,
    )
  end

  def capture_exchange_log(response)
    logged = []
    stubs = Faraday::Adapter::Test::Stubs.new { |stub| stub.post(TOKEN_URL, &response) }

    with_oidc_client_key("ACME_APP") do
      Rails.logger.stub(:info, ->(message) { logged << message }) do
        stub_outbound_http(stubs) do
          yield(exchange(code: "sensitive-code", code_verifier: "sensitive-verifier"))
        end
      end
    end

    stubs.verify_stubbed_calls
    logged
  end

  def token_exchange_failure_event(logged)
    event = logged.map { |line| JSON.parse(line) }.find { |line| line["event"] == "oidc.rp.token_exchange.failed" }

    assert event, "expected an oidc.rp.token_exchange.failed event"
    event
  end

  def with_oidc_client_key(namespace, active_kid: "#{namespace.downcase.tr("_", "-")}-oidc-test",
                           private_key: OpenSSL::PKey::EC.generate("secp384r1"))
    env = {
      "OIDC_CLIENT_#{namespace}_ACTIVE_KID" => active_kid,
      "OIDC_CLIENT_#{namespace}_PRIVATE_KEY" => private_key ? Base64.strict_encode64(private_key.to_der) : nil,
    }

    with_env(env) do
      JitSecurityJwtRegistry.reload!
      yield
    ensure
      JitSecurityJwtRegistry.instance_variable_set(:@issuers, @original_issuers)
    end
  end

  def with_env(values)
    previous = {}
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
