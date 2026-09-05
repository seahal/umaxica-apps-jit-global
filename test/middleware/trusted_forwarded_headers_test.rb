# typed: false
# frozen_string_literal: true

require "test_helper"

class TrustedForwardedHeadersTest < ActiveSupport::TestCase
  test "removes forwarding headers supplied by an untrusted direct peer" do
    app = ->(env) { [200, {}, [env.fetch("HTTP_X_FORWARDED_FOR", "missing")]] }
    middleware = TrustedForwardedHeaders.new(app, trusted_proxies: [IPAddr.new("10.0.0.0/8")])
    env = Rack::MockRequest.env_for(
      "http://example.test/",
      "REMOTE_ADDR" => "198.51.100.7",
      "HTTP_X_FORWARDED_FOR" => "203.0.113.99",
      "HTTP_FORWARDED" => "for=203.0.113.99",
    )

    _status, _headers, body = middleware.call(env)

    assert_equal ["missing"], body
    assert_not env.key?("HTTP_FORWARDED")
  end

  test "preserves forwarding headers supplied by a trusted proxy" do
    app = ->(env) { [200, {}, [env.fetch("HTTP_X_FORWARDED_FOR")]] }
    middleware = TrustedForwardedHeaders.new(app, trusted_proxies: [IPAddr.new("10.0.0.0/8")])
    env = Rack::MockRequest.env_for(
      "http://example.test/",
      "REMOTE_ADDR" => "10.1.2.3",
      "HTTP_X_FORWARDED_FOR" => "203.0.113.99",
    )

    _status, _headers, body = middleware.call(env)

    assert_equal ["203.0.113.99"], body
  end

  # `IPAddr.new` raises on anything that is not an address, and the rescue answers `false`. A peer
  # this middleware cannot even parse is the one case where trusting the headers would be worst:
  # it is not a proxy in the allowlist, so its forwarding headers are attacker-controlled input.
  test "a peer address that cannot be parsed is untrusted and its forwarding headers are stripped" do
    app = ->(env) { [200, {}, [env.fetch("HTTP_X_FORWARDED_FOR", "missing")]] }
    middleware = TrustedForwardedHeaders.new(app, trusted_proxies: [IPAddr.new("10.0.0.0/8")])

    ["not-an-address", "", "10.0.0.999"].each do |peer|
      env = Rack::MockRequest.env_for(
        "http://example.test/",
        "REMOTE_ADDR" => peer,
        "HTTP_X_FORWARDED_FOR" => "203.0.113.99",
        "HTTP_CF_CONNECTING_IP" => "203.0.113.99",
      )

      _status, _headers, body = middleware.call(env)

      assert_equal ["missing"], body, "#{peer.inspect} must not be treated as a trusted proxy"
      assert_not env.key?("HTTP_CF_CONNECTING_IP")
    end
  end
end
