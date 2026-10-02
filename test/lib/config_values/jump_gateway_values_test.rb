# typed: false
# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/config_values_origin_value").to_s
require Rails.root.join("lib/config_values_jump_gateway_values").to_s

class ConfigValuesJumpGatewayValuesTest < ActiveSupport::TestCase
  test "valid public HTTPS root origin is accepted and every Jump value is derived from it" do
    values = ConfigValues::JumpGatewayValues.build(env: { "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net" })

    assert_equal "https://jump.umaxica.net", values.origin
    assert_equal "https://jump.umaxica.net/.well-known/jwks.json", values.jwks_uri
    assert_equal "https://jump.umaxica.net", values.audience
    assert_equal 30, values.ttl_seconds
    assert_empty values.revoked_kids
    assert_predicate values, :frozen?
  end

  test "a trailing root slash and an uppercase host normalize to the same origin" do
    values = ConfigValues::JumpGatewayValues.build(env: { "PUBLIC_JUMP_GATEWAY_URL" => "https://JUMP.umaxica.net/" })

    assert_equal "https://jump.umaxica.net", values.origin
  end

  test "the removed JUMP_GATEWAY_URL is not a fallback when PUBLIC_JUMP_GATEWAY_URL is missing" do
    error =
      assert_raises(ArgumentError) do
        ConfigValues::JumpGatewayValues.build(env: { "JUMP_GATEWAY_URL" => "https://jump.umaxica.net" })
      end

    assert_match(/JUMP_GATEWAY_URL was removed/, error.message)
  end

  # PRIVATE_JUMP_GATEWAY_URL is not a removed setting: Rails has no private path to Jump, so the
  # name is simply undefined and never read.
  test "PRIVATE_JUMP_GATEWAY_URL is not read and cannot change any derived Jump value" do
    env = { "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net", "PRIVATE_JUMP_GATEWAY_URL" => "https://10.0.0.5" }
    values = ConfigValues::JumpGatewayValues.build(env: env)

    assert_equal "https://jump.umaxica.net", values.origin
    assert_equal "https://jump.umaxica.net", values.audience
    assert_equal "https://jump.umaxica.net/.well-known/jwks.json", values.jwks_uri
  end

  test "JWKS URI and audience cannot be supplied separately from the gateway origin" do
    assert_equal %i(origin ttl_seconds revoked_kids), ConfigValues::JumpGatewayValues.members
  end

  test "missing PUBLIC_JUMP_GATEWAY_URL fails closed without a default gateway" do
    error = assert_raises(ArgumentError) { ConfigValues::JumpGatewayValues.build(env: {}) }

    assert_match(/PUBLIC_JUMP_GATEWAY_URL is required/, error.message)
  end

  {
    "blank" => "",
    "whitespace" => "   ",
    "zero sentinel" => "0",
    "NUL character" => "https://jump.umaxica.net\u0000",
    "control character" => "https://jump.umaxica.net\n",
    "relative URL" => "/jump",
    "bare host without scheme" => "jump.umaxica.net",
    "http scheme" => "http://jump.umaxica.net",
    "localhost" => "https://localhost",
    "localhost subdomain" => "https://jump.localhost",
    "mDNS local suffix" => "https://jump.local",
    "internal suffix" => "https://jump.internal",
    "single-label host" => "https://jump",
    "private IPv4 literal" => "https://10.0.0.1",
    "loopback IPv4 literal" => "https://127.0.0.1",
    "link-local IPv4 literal" => "https://169.254.1.1",
    "loopback IPv6 literal" => "https://[::1]",
    "userinfo" => "https://user:pass@jump.umaxica.net",
    "non-root path" => "https://jump.umaxica.net/rt",
    "query" => "https://jump.umaxica.net/?rt=1",
    "empty query" => "https://jump.umaxica.net/?",
    "fragment" => "https://jump.umaxica.net/#top",
    "non-default port" => "https://jump.umaxica.net:8443",
    "malformed URL" => "https://jump umaxica net",
    "missing host" => "https://",
  }.each do |label, raw|
    test "PUBLIC_JUMP_GATEWAY_URL rejects #{label}" do
      assert_raises(ArgumentError) do
        ConfigValues::JumpGatewayValues.build(env: { "PUBLIC_JUMP_GATEWAY_URL" => raw })
      end
    end
  end

  %w(
    JUMP_GATEWAY_URL PUBLIC_JUMP_GATEWAY_JWKS_URL JUMP_GATEWAY_JWKS_URL
    PUBLIC_JUMP_GATEWAY_AUDIENCE JUMP_GATEWAY_AUDIENCE
  ).each do |removed|
    test "removed setting #{removed} is a configuration error even beside a valid PUBLIC_JUMP_GATEWAY_URL" do
      env = { "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net", removed => "https://jump.umaxica.net" }

      error = assert_raises(ArgumentError) { ConfigValues::JumpGatewayValues.build(env: env) }

      assert_match(/#{removed} was removed/, error.message)
    end

    test "removed setting #{removed} is a configuration error even when blank" do
      env = { "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net", removed => "" }

      assert_raises(ArgumentError) { ConfigValues::JumpGatewayValues.build(env: env) }
    end
  end

  test "ttl boundary: 0 below the minimum is rejected" do
    env = { "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net", "JUMP_RT_TTL_SECONDS" => "0" }

    assert_raises(ArgumentError) { ConfigValues::JumpGatewayValues.build(env: env) }
  end

  test "ttl boundary: 1 and 30 are accepted" do
    %w(1 30).each do |ttl|
      env = { "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net", "JUMP_RT_TTL_SECONDS" => ttl }

      assert_equal Integer(ttl), ConfigValues::JumpGatewayValues.build(env: env).ttl_seconds
    end
  end

  test "ttl boundary: 31 above the maximum is rejected" do
    env = { "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net", "JUMP_RT_TTL_SECONDS" => "31" }

    error = assert_raises(ArgumentError) { ConfigValues::JumpGatewayValues.build(env: env) }

    assert_match(/JUMP_RT_TTL_SECONDS must be between 1 and 30/, error.message)
  end

  test "revoked kids are parsed and blank entries dropped" do
    env = {
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
      "JUMP_RETURN_REVOKED_KIDS" => "kid-one, , kid-two ,",
    }
    values = ConfigValues::JumpGatewayValues.build(env: env)

    assert_equal %w(kid-one kid-two), values.revoked_kids
    assert_predicate values.revoked_kids, :frozen?
  end
end
