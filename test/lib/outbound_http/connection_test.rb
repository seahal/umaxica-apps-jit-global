# typed: false
# frozen_string_literal: true

require "test_helper"

# Every hand-written outbound request is built here so none can be made without
# timeouts. The timeouts are required keyword arguments, and an endpoint that
# must be HTTPS is refused at construction rather than at send time -- a plain
# HTTP request to a provider endpoint would put the credential it carries on the
# wire in clear.
class OutboundHttpConnectionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a connection carries the timeouts it was built with" do
    connection = OutboundHttp::Connection.build(
      url: "https://provider.example/token",
      open_timeout: 2,
      read_timeout: 5,
      require_https: true,
    )

    assert_equal 2, connection.options.open_timeout
    assert_equal 5, connection.options.timeout
    assert_nil connection.options.write_timeout
  end

  test "a write timeout is applied only when the call site pins one" do
    connection = OutboundHttp::Connection.build(
      url: "https://provider.example/jwks",
      open_timeout: 2,
      read_timeout: 5,
      write_timeout: 3,
      require_https: true,
    )

    assert_equal 3, connection.options.write_timeout
  end

  test "an endpoint that must be https refuses a plain http url at construction" do
    error =
      assert_raises(OutboundHttp::Connection::InsecureEndpointError) do
        OutboundHttp::Connection.build(
          url: "http://provider.example/token",
          open_timeout: 2,
          read_timeout: 5,
          require_https: true,
        )
      end

    assert_match(/must be HTTPS/, error.message)
  end

  test "a call site that allows plain http gets a connection for it" do
    connection = OutboundHttp::Connection.build(
      url: URI.parse("http://rp.example/backchannel"),
      open_timeout: 2,
      read_timeout: 5,
      require_https: false,
    )

    assert_equal "rp.example", connection.url_prefix.host
  end

  test "every timeout is a required argument, so a call site cannot inherit a transport default" do
    assert_raises(ArgumentError) do
      OutboundHttp::Connection.build(url: "https://provider.example", read_timeout: 5, require_https: true)
    end
    assert_raises(ArgumentError) do
      OutboundHttp::Connection.build(url: "https://provider.example", open_timeout: 2, require_https: true)
    end
  end

  test "a frozen URI constant passed as the endpoint is not mutated during construction" do
    # Callers such as JitSecurityTurnstileVerifier::VERIFY_URI hand in a frozen
    # URI class constant. Faraday mutates the URI it is given (it sets #path on
    # it), so the connection builder must not pass the caller's object straight
    # through: that raised FrozenError and every Turnstile check failed with a
    # spurious "unavailable" result.
    endpoint = URI("https://provider.example/turnstile/v0/siteverify").freeze

    connection =
      OutboundHttp::Connection.build(
        url: endpoint,
        open_timeout: 2,
        read_timeout: 5,
        require_https: true,
      )

    assert_equal "provider.example", connection.url_prefix.host
    assert_equal "/turnstile/v0/siteverify", endpoint.path, "the caller's URI was mutated"
    assert_predicate endpoint, :frozen?
  end

  test "a shared mutable URI constant is left unchanged so it is safe to reuse across threads" do
    # Faraday rewrites an empty path to "/" on the URI it is handed, so a shared
    # constant without an explicit path would be mutated under other threads.
    endpoint = URI("https://provider.example")

    OutboundHttp::Connection.build(
      url: endpoint,
      open_timeout: 2,
      read_timeout: 5,
      require_https: true,
    )

    assert_equal "", endpoint.path, "the caller's URI was mutated in place"
    assert_equal "https://provider.example", endpoint.to_s
  end

  test "the shared faraday default adapter is left alone" do
    assert_equal :net_http, OutboundHttp::Connection.default_adapter
    assert_equal [Faraday::Error], OutboundHttp::Connection::NETWORK_ERRORS
  end
end
