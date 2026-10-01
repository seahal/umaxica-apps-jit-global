# typed: false
# frozen_string_literal: true

require "test_helper"

# An anonymous staff request on an Edit host that is not same-site with the Base authority starts
# OIDC sign-in through the Jump gateway. The Jump RT is issued under the EDIT_ORG namespace, and its
# `iss` is the Edit origin, whose `/.well-known/jwks.json` publishes the verification key
# (adr/secure-jump-link-redirector.md).
class EditOrgJumpRtSignInTest < ActionDispatch::IntegrationTest

  test "anonymous Publishing management request on a cross-site Edit host redirects through Jump" do
    host!("edit.org.localhost")

    get("/publishing/info/org/entries", params: { ri: "jp" })

    assert_response :found
    location = URI.parse(response.location)

    assert_equal "jump.umaxica.net", location.host
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "the Edit Jump RT verifies against the Edit JWKS and names the Edit origin as issuer" do
    host!("edit.org.localhost")
    get("/publishing/info/org/entries", params: { ri: "jp" })
    token = Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("rt")
    get("/.well-known/jwks.json")
    jwks = JWT::JWK::Set.new(response.parsed_body)

    payload, = JWT.decode(
      token, nil, true, algorithms: ["ES384"], jwks: jwks, verify_iss: true,
                        iss: "https://edit.umaxica.org",
    )

    assert_equal "https://edit.umaxica.org", payload.fetch("iss")
    target = URI.parse(payload.fetch("url"))

    assert_equal "/oauth/authorize", target.path
    assert_equal "edit-org", Rack::Utils.parse_nested_query(target.query).fetch("client_id")
  end

  test "the Edit JWKS publishes only public keys with its explicit public cache opt-in" do
    host!("edit.org.localhost")

    get("/.well-known/jwks.json")

    assert_response :success
    assert_equal "max-age=3600, public", response.headers.fetch("Cache-Control")
    keys = response.parsed_body.fetch("keys")

    assert_predicate keys, :any?
    keys.each do |key|
      assert_equal "EC", key.fetch("kty")
      assert_equal "P-384", key.fetch("crv")
      assert_not key.key?("d"), "the JWKS must never publish the private scalar"
    end
  end
end
