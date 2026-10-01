# typed: false
# frozen_string_literal: true

require "test_helper"

# The external Jump gateway verifies a Rails-issued rt against the JWKS of the issuing surface
# (adr/secure-jump-link-redirector.md). That only works when the token's `iss` is the origin that
# publishes the signing `kid` at `/.well-known/jwks.json`. These tests pin that authority contract
# end to end: issue the rt, then fetch the JWKS from the origin the token names.
class JumpRtIssuerJwksAuthorityTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  AUTH_NAMESPACES = {
    "AUTH_APP" => :sign_service,
    "AUTH_COM" => :sign_corporate,
    "AUTH_ORG" => :sign_staff,
  }.freeze

  AUTH_NAMESPACES.each do |namespace, host_key|
    test "#{namespace} jump rt iss is the canonical auth origin from boot config" do
      payload, = decode_unverified(issue(namespace))

      assert_equal boot_hosts.public_send(host_key).to_s, payload.fetch("iss")
    end

    test "#{namespace} jump rt kid is published by the JWKS at its iss origin" do
      payload, header = decode_unverified(issue(namespace))

      assert_includes published_kids(payload.fetch("iss")), header.fetch("kid")
    end
  end

  test "BASE_APP jump rt kid stays published by the JWKS at its iss origin" do
    payload, header = decode_unverified(issue("BASE_APP"))

    assert_equal boot_hosts.base_service.to_s, payload.fetch("iss")
    assert_includes published_kids(payload.fetch("iss")), header.fetch("kid")
  end

  test "Core Warp and Palm publish the signing kid at the canonical issuer origin" do
    %w(CORE_APP CORE_COM CORE_ORG WARP_APP WARP_COM WARP_ORG PALM_APP).each do |namespace|
      token = JumpRtIssuer.call(namespace: namespace, url: "https://www.umaxica.app/")
      payload, header = JWT.decode(token, nil, false)
      uri = URI.parse(payload.fetch("iss"))
      host! uri.host
      https!
      get "/.well-known/jwks.json"

      assert_response :ok
      assert_includes response.parsed_body.fetch("keys").pluck("kid"), header.fetch("kid")
      assert_not_includes response.parsed_body.fetch("keys").flat_map(&:keys), "d"
    end
  end

  private

  def issue(namespace)
    token = JumpRtIssuer.call(namespace: namespace, url: "https://www.umaxica.app/", dst: "internal")

    assert_predicate token, :present?, "#{namespace} must issue a jump rt"
    token
  end

  def decode_unverified(token)
    JWT.decode(token, nil, false)
  end

  def published_kids(issuer_origin)
    uri = URI.parse(issuer_origin)
    host!(uri.host)
    https!(uri.scheme == "https")
    get("/.well-known/jwks.json")

    assert_response :ok
    response.parsed_body.fetch("keys").pluck("kid")
  end

  def boot_hosts
    Rails.configuration.x.boot_config.fetch(:hosts)
  end
end
