# typed: false
# frozen_string_literal: true

require "test_helper"

class AcceptanceWu02JwksSeparationTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "A02-6: Visa and Base JWKS have disjoint kids and public key material in every realm" do
    realms = [
      %w(app PUBLIC_VISA_SERVICE_URL PUBLIC_BASE_SERVICE_URL VISA_APP BASE_APP),
      %w(com PUBLIC_VISA_CORPORATE_URL PUBLIC_BASE_CORPORATE_URL VISA_COM BASE_COM),
      %w(org PUBLIC_VISA_STAFF_URL PUBLIC_BASE_STAFF_URL VISA_ORG BASE_ORG),
    ]

    realms.each do |realm, visa_host_key, base_host_key, visa_namespace, base_namespace|
      visa_browser = open_session
      visa_browser.https!
      visa_browser.host!(ENV.fetch(visa_host_key))
      visa_browser.get("/.well-known/jwks.json")

      assert_equal 200, visa_browser.response.status, "Visa #{realm} JWKS request"
      visa_keys = visa_browser.response.parsed_body.fetch("keys")

      base_browser = open_session
      base_browser.https!
      base_browser.host!(ENV.fetch(base_host_key))
      base_browser.get("/.well-known/jwks.json")

      assert_equal 200, base_browser.response.status, "Base #{realm} JWKS request"
      base_keys = base_browser.response.parsed_body.fetch("keys")

      assert_includes visa_keys.map { |key| key.fetch("kid") },
                      JitSecurityJwtRegistry.surface(visa_namespace).current_kid,
                      "Visa #{realm} JWKS must publish the Visa issuer's active key"
      assert_includes base_keys.map { |key| key.fetch("kid") },
                      JitSecurityJwtRegistry.surface(base_namespace).current_kid,
                      "Base #{realm} JWKS must publish the Base issuer's active key"
      assert_empty visa_keys.map { |key| key.fetch("kid") } & base_keys.map { |key| key.fetch("kid") },
                   "Visa and Base #{realm} JWKS must not share a kid"

      visa_material = visa_keys.map { |key| key.slice("kty", "crv", "x", "y") }
      base_material = base_keys.map { |key| key.slice("kty", "crv", "x", "y") }

      assert_empty visa_material & base_material,
                   "Visa and Base #{realm} JWKS must not share public key material"
    end
  end
end
