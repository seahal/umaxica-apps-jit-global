# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpRtIssuerJwksAuthorityTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "all sixteen canonical Jump issuers publish the exact RT signing key" do
    # Other tests intentionally reload the process-global registry with fixture keys. Rebuild it
    # from the restored process environment so this cross-host contract is order-independent.
    JitSecurityJwtRegistry.reload!

    issuers = {
      "AUTH_APP" => "https://auth.umaxica.app",
      "AUTH_COM" => "https://auth.umaxica.com",
      "AUTH_ORG" => "https://auth.umaxica.org",
      "BASE_APP" => "https://www.umaxica.app",
      "BASE_COM" => "https://www.umaxica.com",
      "BASE_ORG" => "https://www.umaxica.org",
      "VISA_APP" => "https://visa.umaxica.app",
      "VISA_COM" => "https://visa.umaxica.com",
      "VISA_ORG" => "https://visa.umaxica.org",
      "CORE_APP" => "https://jp.umaxica.app",
      "CORE_COM" => "https://jp.umaxica.com",
      "CORE_ORG" => "https://jp.umaxica.org",
      "WARP_APP" => "https://www-jp.umaxica.app",
      "WARP_COM" => "https://www-jp.umaxica.com",
      "WARP_ORG" => "https://www-jp.umaxica.org",
      "PALM_APP" => "https://palm-jp.umaxica.app",
    }

    assert_equal issuers.keys.sort, JumpRtSurface::ISSUER_NAMESPACES.sort
    published_keys = {}
    issuers.each do |namespace, origin|
      tld = namespace.split("_").last.downcase
      peer = namespace.start_with?("BASE_") ? "auth" : "www"
      token = JumpRtIssuer.call(namespace: namespace, url: "https://#{peer}.umaxica.#{tld}/", dst: "internal")
      claims, header = JWT.decode(token, nil, false)

      assert_equal origin, claims.fetch("iss"), namespace
      assert_equal "ES384", header.fetch("alg"), namespace
      assert_equal "reuse", claims.fetch("rpl"), namespace
      host! URI.parse(origin).host
      https!
      get "/.well-known/jwks.json"

      assert_response :ok
      keys = response.parsed_body.fetch("keys")

      assert_includes 1..JitSecurityJwtRegistry::MAX_JUMP_PUBLISHED_JWKS_KEYS, keys.size, namespace
      assert_operator JSON.generate(response.parsed_body).bytesize,
                      :<=,
                      JitSecurityJwtRegistry::MAX_JUMP_PUBLISHED_JWKS_BYTES,
                      namespace
      assert_equal keys.size, keys.pluck("kid").uniq.size, namespace
      keys.each do |key|
        assert_equal "ES384", key.fetch("alg"), namespace
        assert_equal "sig", key.fetch("use"), namespace
        assert_equal "EC", key.fetch("kty"), namespace
        assert_equal "P-384", key.fetch("crv"), namespace
      end
      assert_includes keys.pluck("kid"), header.fetch("kid"), namespace
      assert_empty keys.flat_map(&:keys) & JitSecurityJwtJwk::PRIVATE_FIELDS, namespace
      published_keys[namespace] = keys
      verified, = JWT.decode(
        token, nil, true, algorithms: ["ES384"],
                          jwks: JWT::JWK::Set.new(response.parsed_body),
                          verify_iss: true, iss: origin, verify_aud: true, aud: "https://jump.umaxica.net",
      )

      assert_equal claims, verified, namespace
    end

    %w(APP COM ORG).each do |realm|
      base_keys = published_keys.fetch("BASE_#{realm}")
      visa_keys = published_keys.fetch("VISA_#{realm}")
      base_public_material = base_keys.map { |key| key.slice("kty", "crv", "x", "y") }
      visa_public_material = visa_keys.map { |key| key.slice("kty", "crv", "x", "y") }

      assert_empty base_public_material & visa_public_material, "BASE_#{realm} and VISA_#{realm} JWKS overlap"
    end
  end
end
