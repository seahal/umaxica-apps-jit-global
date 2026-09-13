# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require Rails.root.join("lib/config_values_origin_value").to_s
require Rails.root.join("lib/config_values_jump_gateway_values").to_s

class ConfigValuesJumpGatewayValuesTest < ActiveSupport::TestCase
  test "build in non-production mode applies the default gateway URL and jwks URI" do
    values = ConfigValues::JumpGatewayValues.build(env: {}, production: false)

    assert_equal "https://jump.umaxica.net", values.origin.to_s
    assert_equal "https://jump.umaxica.net/.well-known/jwks.json", values.jwks_uri
    assert_equal "https://jump.umaxica.net", values.audience
    assert_equal 30, values.ttl_seconds
    assert_empty values.revoked_kids
    assert_predicate values, :frozen?
  end

  test "build honors explicit ENV overrides for origin, audience, and ttl" do
    env = {
      "PUBLIC_JUMP_GATEWAY_URL" => "https://gateway.example.test",
      "PUBLIC_JUMP_GATEWAY_JWKS_URL" => "https://gateway.example.test/.well-known/jwks.json",
      "PUBLIC_JUMP_GATEWAY_AUDIENCE" => "custom-audience",
      "JUMP_RT_TTL_SECONDS" => "30",
    }
    values = ConfigValues::JumpGatewayValues.build(env: env, production: true)

    assert_equal "https://gateway.example.test", values.origin.to_s
    assert_equal "https://gateway.example.test/.well-known/jwks.json", values.jwks_uri
    assert_equal "custom-audience", values.audience
    assert_equal 30, values.ttl_seconds
  end

  test "build in production rejects a jwks url that is not the origin well-known path" do
    env = {
      "PUBLIC_JUMP_GATEWAY_URL" => "https://gateway.example.test",
      "PUBLIC_JUMP_GATEWAY_JWKS_URL" => "https://jwks.example.test/.well-known/jwks.json",
    }

    error =
      assert_raises(ArgumentError) do
        ConfigValues::JumpGatewayValues.build(env: env, production: true)
      end

    assert_match(/JUMP_GATEWAY_JWKS_URL must equal/, error.message)
  end

  test "build rejects a ttl longer than thirty seconds" do
    env = {
      "PUBLIC_JUMP_GATEWAY_URL" => "https://gateway.example.test",
      "JUMP_RT_TTL_SECONDS" => "900",
    }

    error =
      assert_raises(ArgumentError) do
        ConfigValues::JumpGatewayValues.build(env: env, production: false)
      end

    assert_match(/JUMP_RT_TTL_SECONDS must be between 1 and 30/, error.message)
  end

  test "build derives the jwks URI from the origin when JUMP_GATEWAY_JWKS_URL is absent" do
    env = { "PUBLIC_JUMP_GATEWAY_URL" => "https://gateway.example.test" }
    values = ConfigValues::JumpGatewayValues.build(env: env, production: true)

    assert_equal "https://gateway.example.test/.well-known/jwks.json", values.jwks_uri
  end

  test "build parses revoked kids and drops blank entries" do
    env = {
      "PUBLIC_JUMP_GATEWAY_URL" => "https://gateway.example.test",
      "JUMP_RETURN_REVOKED_KIDS" => "kid-one, , kid-two ,",
    }
    values = ConfigValues::JumpGatewayValues.build(env: env, production: true)

    assert_equal %w(kid-one kid-two), values.revoked_kids
    assert_predicate values.revoked_kids, :frozen?
  end

  test "build in production mode raises KeyError when PUBLIC_JUMP_GATEWAY_URL is missing" do
    assert_raises(KeyError) do
      ConfigValues::JumpGatewayValues.build(env: {}, production: true)
    end
  end

  test "build allows localhost origins in non-production mode" do
    env = { "PUBLIC_JUMP_GATEWAY_URL" => "http://jump.localhost" }
    values = ConfigValues::JumpGatewayValues.build(env: env, production: false)

    assert_equal "http://jump.localhost", values.origin.to_s
    assert_equal "http://jump.localhost/.well-known/jwks.json", values.jwks_uri
  end
end
