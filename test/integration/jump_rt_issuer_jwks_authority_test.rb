# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpRtIssuerJwksAuthorityTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "all thirteen canonical Jump issuers publish the exact RT signing key" do
    issuers = {
      "AUTH_APP" => "https://auth.umaxica.app",
      "AUTH_COM" => "https://auth.umaxica.com",
      "AUTH_ORG" => "https://auth.umaxica.org",
      "BASE_APP" => "https://www.umaxica.app",
      "BASE_COM" => "https://www.umaxica.com",
      "BASE_ORG" => "https://www.umaxica.org",
      "CORE_APP" => "https://jp.umaxica.app",
      "CORE_COM" => "https://jp.umaxica.com",
      "CORE_ORG" => "https://jp.umaxica.org",
      "WARP_APP" => "https://www-jp.umaxica.app",
      "WARP_COM" => "https://www-jp.umaxica.com",
      "WARP_ORG" => "https://www-jp.umaxica.org",
      "PALM_APP" => "https://palm-jp.umaxica.app",
    }
    issuers.each do |namespace, origin|
      tld = namespace.split("_").last.downcase
      peer = namespace.start_with?("BASE_") ? "auth" : "www"
      token = JumpRtIssuer.call(namespace: namespace, url: "https://#{peer}.umaxica.#{tld}/")
      claims, header = JWT.decode(token, nil, false)
      assert_equal origin, claims.fetch("iss"), namespace
      assert_equal "ES384", header.fetch("alg"), namespace
      host! URI.parse(origin).host
      https!
      get "/.well-known/jwks.json"

      assert_response :ok
      keys = response.parsed_body.fetch("keys")
      assert_includes keys.pluck("kid"), header.fetch("kid"), namespace
      assert_empty keys.flat_map(&:keys) & JitSecurityJwtJwk::PRIVATE_FIELDS, namespace
      verified, = JWT.decode(token, nil, true, algorithms: ["ES384"],
                             jwks: JWT::JWK::Set.new(response.parsed_body),
                             verify_iss: true, iss: origin, verify_aud: true, aud: "https://jump.umaxica.net")
      assert_equal claims, verified, namespace
    end
  end
end
