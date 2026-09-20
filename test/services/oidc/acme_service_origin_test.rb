# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Oidc::AcmeServiceOriginTest < ActiveSupport::TestCase
  test "normalizes public bare host into a https origin without inventing a port" do
    origin = build_origin("www.umaxica.app", default_scheme: "https")

    assert_equal "https", origin.scheme
    assert_equal "www.umaxica.app", origin.host
    assert_nil origin.port
    assert_equal "https://www.umaxica.app", origin.origin
    assert_equal "https://www.umaxica.app/oauth/authorize", origin.authorization_endpoint
    assert_equal "https://www.umaxica.app/oauth/token", origin.token_endpoint
  end

  test "normalizes host and scheme variants with default ports" do
    origin = build_origin("www.umaxica.app:443", default_scheme: "https")
    explicit = build_origin("https://www.umaxica.app", default_scheme: "https")

    assert_equal "www.umaxica.app", origin.host
    assert_nil origin.port
    assert_equal explicit.origin, origin.origin
    assert_equal explicit.authorization_endpoint(query: { client_id: "base-rails-rp" }),
                 origin.authorization_endpoint(query: { client_id: "base-rails-rp" })
  end

  test "normalizes explicit https origins with default ports" do
    origin = build_origin("https://www.umaxica.app:443", default_scheme: "https")
    explicit = build_origin("https://www.umaxica.app", default_scheme: "https")

    assert_equal explicit.scheme, origin.scheme
    assert_equal explicit.host, origin.host
    assert_nil origin.port
    assert_equal explicit.origin, origin.origin
    assert_equal explicit.token_endpoint, origin.token_endpoint
  end

  test "normalizes localhost origins with explicit ports" do
    origin = build_origin("http://www.app.localhost:3000", default_scheme: "http")

    assert_equal "http", origin.scheme
    assert_equal "www.app.localhost", origin.host
    assert_equal 3000, origin.port
    assert_equal "http://www.app.localhost:3000", origin.origin
    assert_equal "http://www.app.localhost:3000/oauth/authorize", origin.authorization_endpoint
    assert_equal "http://www.app.localhost:3000/oauth/token", origin.token_endpoint
  end

  test "preserves localhost ports and does not invent 3000 for bare hosts" do
    origin = build_origin("www.app.localhost:3001", default_scheme: "http")

    assert_equal "http", origin.scheme
    assert_equal "www.app.localhost", origin.host
    assert_equal 3001, origin.port
    assert_equal "http://www.app.localhost:3001", origin.origin
  end

  test "bare localhost host keeps the host without inventing port 3000" do
    origin = build_origin("www.app.localhost", default_scheme: "http")

    assert_equal "http", origin.scheme
    assert_equal "www.app.localhost", origin.host
    assert_nil origin.port
    assert_equal "http://www.app.localhost", origin.origin
    assert_not_includes origin.origin, ":3000"
  end

  test "rejects invalid origin input" do
    assert_raises(ArgumentError) { build_origin("", default_scheme: "https") }
    assert_raises(ArgumentError) { build_origin("javascript:alert(1)", default_scheme: "https") }
    assert_raises(ArgumentError) { build_origin("https://example.com/path", default_scheme: "https") }
    assert_raises(ArgumentError) { build_origin("https://example.com?x=1", default_scheme: "https") }
  end

  test "directs same-site browser authorize requests and rejects mismatches by reason" do
    origin = build_origin("www.umaxica.app", default_scheme: "https")
    request = test_request(host: "log.umaxica.app", scheme: "https")
    authorize_url =
      origin.authorization_endpoint(
        query: {
          client_id: "base-rails-rp",
          redirect_uri: "https://log.umaxica.app/oidc/callback",
          response_type: "code",
        },
      )

    decision = origin.decision_for_authorize_url(authorize_url, request: request)

    assert_predicate decision, :direct?
    assert_equal "direct_same_site_acme_authorize", decision.reason_code
    assert decision.same_site
    assert_equal "www.umaxica.app", decision.target_host
    assert_nil decision.target_port

    host_mismatch = origin.decision_for_authorize_url(
      "https://evil.example/oauth/authorize?client_id=base-rails-rp",
      request: request,
    )

    assert_equal :jump, host_mismatch.kind
    assert_equal "host_mismatch", host_mismatch.reason_code

    default_port = origin.decision_for_authorize_url(
      "https://www.umaxica.app:443/oauth/authorize?client_id=base-rails-rp",
      request: request,
    )

    assert_predicate default_port, :direct?
    assert_equal "direct_same_site_acme_authorize", default_port.reason_code

    path_mismatch = origin.decision_for_authorize_url(
      "https://www.umaxica.app/oauth/token?client_id=base-rails-rp",
      request: request,
    )

    assert_equal :jump, path_mismatch.kind
    assert_equal "not_acme_authorize", path_mismatch.reason_code

    invalid = origin.decision_for_authorize_url("not-a-url", request: request)

    assert_equal :rejected, invalid.kind
    assert_equal "invalid_url", invalid.reason_code
  end

  test "normalizes same-site authorize URLs across host and port forms" do
    origin = build_origin("www.app.localhost:3000", default_scheme: "http")
    request = test_request(host: "id.app.localhost", scheme: "http")

    assert origin.same_site_authorize_url?(
      "http://www.app.localhost:3000/oauth/authorize?client_id=base-rails-rp",
      request: request,
    )
    assert_not origin.same_site_authorize_url?(
      "http://www.app.localhost/oauth/authorize?client_id=base-rails-rp",
      request: request,
    )
    assert_equal "port_mismatch",
                 origin.same_site_rejection_reason(
                   "http://www.app.localhost/oauth/authorize?client_id=base-rails-rp",
                   request: request,
                 )
  end

  test "decision predicates identify jump and rejected outcomes" do
    attributes = {
      reason_code: "test",
      same_site: false,
      request_host: nil,
      request_scheme: nil,
      target_scheme: nil,
      target_host: nil,
      target_port: nil,
      target_path: nil,
      acme_scheme: "https",
      acme_host: "www.umaxica.app",
      acme_port: nil,
    }

    assert_predicate Oidc::AcmeServiceOrigin::Decision.new(kind: :jump, **attributes), :jump?
    assert_predicate Oidc::AcmeServiceOrigin::Decision.new(kind: :rejected, **attributes), :rejected?
  end

  test "host and authorize parsing return safe outcomes for malformed URLs" do
    assert_nil Oidc::AcmeServiceOrigin.host_from("http://[")
    assert_nil Oidc::AcmeServiceOrigin.host_from("   ")
    assert_nil Oidc::AcmeServiceOrigin.host_from("https://user:pass@www.umaxica.app")
    assert_nil Oidc::AcmeServiceOrigin.host_from("https://www.umaxica.app/path")
    assert_nil Oidc::AcmeServiceOrigin.host_from("https://www.umaxica.app?q=1")
    assert_nil Oidc::AcmeServiceOrigin.host_from("https://www.umaxica.app#frag")

    origin = build_origin("www.umaxica.app", default_scheme: "https")
    decision = origin.decision_for_authorize_url(
      "http://[",
      request: test_request(host: "log.umaxica.app", scheme: "https"),
    )

    assert_predicate decision, :rejected?
    assert_equal "invalid_url", decision.reason_code

    native = origin.decision_for_authorize_url(
      "umaxica://authorize",
      request: test_request(host: "log.umaxica.app", scheme: "https"),
    )

    assert_predicate native, :jump?
    assert_equal "native_custom_scheme", native.reason_code

    other_path = origin.decision_for_authorize_url(
      "https://www.umaxica.app/not-authorize",
      request: test_request(host: "log.umaxica.app", scheme: "https"),
    )

    assert_equal "not_acme_authorize", other_path.reason_code
    assert_nil origin.same_site_rejection_reason(
      "https://www.umaxica.app/oauth/authorize",
      request: test_request(host: "www.umaxica.app", scheme: "https"),
    )
  end

  test "refuses an origin whose default scheme is not http or https" do
    error =
      assert_raises(ArgumentError) do
        Oidc::AcmeServiceOrigin.from("www.umaxica.app", default_scheme: "ftp")
      end

    assert_equal "invalid origin", error.message
  end

  test "refuses an origin that carries a scheme but no host" do
    error =
      assert_raises(ArgumentError) do
        Oidc::AcmeServiceOrigin.from("https://", default_scheme: "https")
      end

    assert_equal "invalid origin", error.message
  end

  test "host_from returns nil rather than raising for an unusable origin" do
    assert_nil Oidc::AcmeServiceOrigin.host_from("https://")
    assert_nil Oidc::AcmeServiceOrigin.host_from("  ")
    assert_equal "www.umaxica.app", Oidc::AcmeServiceOrigin.host_from("https://WWW.Umaxica.App")
  end

  test "a rejected decision reports no target attributes at all" do
    origin = build_origin("www.umaxica.app", default_scheme: "https")
    request = test_request(host: "log.umaxica.app", scheme: "https")

    decision = origin.decision_for_authorize_url("oauth/authorize", request: request)

    assert_predicate decision, :rejected?
    assert_equal "invalid_url", decision.reason_code
    assert_not decision.same_site
    assert_nil decision.target_scheme
    assert_nil decision.target_host
    assert_nil decision.target_port
    assert_nil decision.target_path
    assert_equal "log.umaxica.app", decision.request_host
    assert_equal "www.umaxica.app", decision.acme_host
  end

  test "a scheme mismatch jumps and keeps the target scheme it saw" do
    origin = build_origin("www.umaxica.app", default_scheme: "https")
    request = test_request(host: "log.umaxica.app", scheme: "https")

    decision = origin.decision_for_authorize_url(
      "http://www.umaxica.app/oauth/authorize?client_id=base-rails-rp",
      request: request,
    )

    assert_predicate decision, :jump?
    assert_equal "scheme_mismatch", decision.reason_code
    assert_equal "http", decision.target_scheme
    assert decision.same_site
  end

  test "a non-default target port is reported verbatim on a port mismatch" do
    origin = build_origin("www.umaxica.app", default_scheme: "https")
    request = test_request(host: "log.umaxica.app", scheme: "https")

    decision = origin.decision_for_authorize_url(
      "https://www.umaxica.app:8443/oauth/authorize?client_id=base-rails-rp",
      request: request,
    )

    assert_predicate decision, :jump?
    assert_equal "port_mismatch", decision.reason_code
    assert_equal 8443, decision.target_port
    assert_equal "www.umaxica.app", decision.target_host
  end

  test "a cross-site request to the acme origin jumps instead of going direct" do
    origin = build_origin("www.umaxica.app", default_scheme: "https")
    request = test_request(host: "log.example.com", scheme: "https")

    decision = origin.decision_for_authorize_url(
      "https://www.umaxica.app/oauth/authorize?client_id=base-rails-rp",
      request: request,
    )

    assert_predicate decision, :jump?
    assert_equal "site_mismatch", decision.reason_code
    assert_not decision.same_site
  end

  test "single label hosts compare as their own site" do
    origin = build_origin("http://localhost:3000", default_scheme: "http")
    request = test_request(host: "localhost", scheme: "http")

    decision = origin.decision_for_authorize_url(
      "http://localhost:3000/oauth/authorize?client_id=base-rails-rp",
      request: request,
    )

    assert_predicate decision, :direct?
    assert decision.same_site
    assert_equal 3000, decision.target_port
  end

  private

  def build_origin(value, default_scheme:)
    Oidc::AcmeServiceOrigin.from(value, default_scheme: default_scheme)
  end

  def test_request(host:, scheme:)
    env = {
      "HTTP_HOST" => host,
      "HTTPS" => ((scheme == "https") ? "on" : "off"),
      "rack.url_scheme" => scheme,
    }
    ActionDispatch::TestRequest.create(env)
  end
end
