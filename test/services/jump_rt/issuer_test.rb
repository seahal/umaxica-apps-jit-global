# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "ostruct"

class JumpRtIssuerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  HostSet = Struct.new(:sign_service)
  Origin =
    Data.define(:host) do
      def to_s = "https://#{host}"
    end
  BootConfig =
    Struct.new(:hosts, :jump) do
      def fetch(key) = public_send(key)
    end

  setup do
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
  end

  test "issues ES384 jump rt jwt with expected claims" do
    with_env(
      "JWT_AUTH_APP_ACTIVE_KID" => "sign-app-es384-test-a",
      "PRIVATE_AUTH_SERVICE_URL" => "sign.example.test",
    ) do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "AUTH_APP",
          url: "https://target.example/path?ok=1",
          dst: "internal",
          now: Time.zone.at(1_800_000_000),
          jti: "jti-test",
        )
        JWT.decode(
          token, @private_key.public_key, true, algorithms: ["ES384"], verify_iat: false,
                                                verify_expiration: false, verify_not_before: false,
        )
        payload, header = JWT.decode(token, nil, false)

        assert_equal "JWT", header["typ"]
        assert_equal "ES384", header["alg"]
        assert_equal JitSecurityJwtRegistry.surface("AUTH_APP").current_kid, header["kid"]
        assert_equal 1, payload["schema"]
        assert_equal "jump-redirect", payload["sub"]
        assert_equal "internal", payload["dst"]
        assert_equal "reuse", payload["rpl"]
        assert_equal "https://target.example/path?ok=1", payload["url"]
        assert_equal "jti-test", payload["jti"]
      end
    end
  end

  test "rejects a case-variant algorithm header" do
    assert_not SecurityJwtJumpRtTokenCodec.valid_header?(
      { "typ" => "JWT", "alg" => "eS384", "kid" => "kid-1" },
    )
  end

  test "returns nil for url with invalid percent encoding" do
    with_env(
      "JWT_AUTH_APP_ACTIVE_KID" => "sign-app-es384-test-a",
    ) do
      JumpRtKeyring.stub(:private_key, @private_key) do
        result = JumpRtIssuer.call(
          namespace: "AUTH_APP",
          url: "http://example.com/%gg",
          dst: "internal",
        )

        assert_nil result
      end
    end
  end

  # Rack once raised on this query, which refused issuance by accident. Under the WHATWG contract
  # it is two ordinary pairs, so it is signed in order like any other query.
  test "signs a query whose bracketed keys Rack would treat as conflicting shapes" do
    with_env("JWT_AUTH_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "AUTH_APP",
          url: "https://target.example/?a=scalar&a[b]=nested",
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal "https://target.example/?a=scalar&a%5Bb%5D=nested", payload["url"]
      end
    end
  end

  test "callers cannot choose a replay policy" do
    %w(reuse once).each do |policy|
      assert_raises(ArgumentError, policy) do
        JumpRtIssuer.call(namespace: "AUTH_APP", url: "https://target.example/path", replay_policy: policy)
      end
    end
  end

  test "every schema 1 token issued by each Jump issuer carries rpl reuse" do
    JumpRtSurface::ISSUER_NAMESPACES.each do |namespace|
      token = JumpRtIssuer.call(namespace: namespace, url: "https://target.example/path")
      payload, = JWT.decode(token, nil, false)

      assert_equal 1, payload.fetch("schema"), namespace
      assert_equal "reuse", payload.fetch("rpl"), namespace
      assert_equal "https://jump.umaxica.net", payload.fetch("aud"), namespace
    end
  end

  test "codec issue payload fixes rpl to reuse" do
    payload = SecurityJwtJumpRtTokenCodec.build_issue_payload(
      issuer: "https://auth.umaxica.app", normalized_url: "https://www.umaxica.app/", dst: "internal",
      ttl: 30, now: Time.zone.at(1_800_000_000), jti: "jti", audience: "https://jump.umaxica.net",
    )

    assert_equal "reuse", payload.fetch(:rpl)
    assert_raises(ArgumentError) do
      SecurityJwtJumpRtTokenCodec.build_issue_payload(
        issuer: "https://auth.umaxica.app", normalized_url: "https://www.umaxica.app/", dst: "internal",
        replay_policy: "once", ttl: 30, now: Time.zone.at(1_800_000_000), jti: "jti",
        audience: "https://jump.umaxica.net",
      )
    end
  end

  test "uses environment configured ttl when ttl is omitted" do
    hosts = HostSet.new(Origin.new(host: "sign.example.test"))
    boot_config = BootConfig.new(hosts, OpenStruct.new(ttl_seconds: 30, audience: "https://jump.umaxica.net"))

    with_env("JWT_AUTH_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      Rails.configuration.x.stub(:boot_config, boot_config) do
        JumpRtKeyring.stub(:private_key, @private_key) do
          token = JumpRtIssuer.call(
            namespace: "AUTH_APP",
            url: "https://target.example/path",
            now: Time.zone.at(1_800_000_000),
            jti: "jti-test",
          )
          payload, = JWT.decode(token, nil, false)

          assert_equal 1_800_000_000, payload["iat"]
          assert_equal 1_800_000_030, payload["exp"]
        end
      end
    end
  end

  test "refuses invalid destination kind" do
    with_env("JWT_AUTH_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(namespace: "AUTH_APP", url: "https://target.example/", dst: "unknown")

        assert_nil token
      end
    end
  end

  test "refuses unsafe destination urls" do
    with_env("JWT_AUTH_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        assert_nil JumpRtIssuer.call(namespace: "AUTH_APP", url: "javascript:alert(1)")
        assert_nil JumpRtIssuer.call(namespace: "AUTH_APP", url: "https://user:pass@target.example/")
        assert_nil JumpRtIssuer.call(namespace: "AUTH_APP", url: "https://target.example/#fragment")
        assert_nil JumpRtIssuer.call(namespace: "AUTH_APP", url: "https://target.example/\n")
      end
    end
  end

  test "strips redirect-target query keys before signing the url" do
    with_env(
      "JWT_AUTH_APP_ACTIVE_KID" => "sign-app-es384-test-a",
      "PRIVATE_AUTH_SERVICE_URL" => "sign.example.test",
    ) do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "AUTH_APP",
          url: "https://target.example/path?ok=1&pt=/evil&rt=stale&xt=foo&keep=2",
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal "https://target.example/path?ok=1&keep=2", payload["url"]
      end
    end
  end

  test "strips redirect uri by default before signing the url" do
    with_env("JWT_AUTH_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "AUTH_APP",
          url: "https://target.example/path?redirect_uri=https%3A%2F%2Fwww.example.com%2Fauth%2Fcallback&ok=1",
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal "https://target.example/path?ok=1", payload["url"]
      end
    end
  end

  test "preserves explicitly allowed redirect uri inside the signed url" do
    with_env("JWT_AUTH_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "AUTH_APP",
          url: "https://target.example/path?redirect_uri=https%3A%2F%2Fwww.example.com%2Fauth%2Fcallback&rt=stale&ok=1",
          preserve_query_keys: ["redirect_uri"],
        )
        payload, = JWT.decode(token, nil, false)
        query = Rack::Utils.parse_nested_query(URI.parse(payload["url"]).query)

        assert_equal "https://www.example.com/auth/callback", query["redirect_uri"]
        assert_equal "1", query["ok"]
        assert_not query.key?("rt")
      end
    end
  end

  test "keeps the order and repeated pairs of the remaining query when signing the url" do
    with_env("JWT_AUTH_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "AUTH_APP",
          url: "https://target.example/path?tag=b&rt=stale&tag=a&q=a%2Bb&s=a+b",
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal "https://target.example/path?tag=b&tag=a&q=a%2Bb&s=a+b", payload["url"]
      end
    end
  end

  test "strips nested and percent-encoded forms of redirect-target keys before signing the url" do
    with_env("JWT_AUTH_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "AUTH_APP",
          url: "https://target.example/path?ok=1&rt%5B%5D=x&next[x]=evil&%72t=y&redirect_uri%5Ba%5D=z",
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal "https://target.example/path?ok=1", payload["url"]
      end
    end
  end

  test "a preserved key keeps its position among the remaining pairs" do
    with_env("JWT_AUTH_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "AUTH_APP",
          url: "https://target.example/path?ok=1&redirect_uri=https%3A%2F%2Fwww.example.com%2Fcb&rt=stale&z=2",
          preserve_query_keys: ["redirect_uri"],
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal "https://target.example/path?ok=1&redirect_uri=https%3A%2F%2Fwww.example.com%2Fcb&z=2",
                     payload["url"]
      end
    end
  end

  test "drops query entirely when only redirect-target keys are present" do
    with_env("JWT_AUTH_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "AUTH_APP",
          url: "https://target.example/path?rt=stale&pt=/evil",
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal "https://target.example/path", payload["url"]
      end
    end
  end

  test "raises a configuration error when the active key id or private key is missing" do
    JumpRtKeyring.stub(:active_kid, nil) do
      error =
        assert_raises(JumpRtConfigurationError) do
          JumpRtIssuer.call(namespace: "AUTH_APP", url: "https://target.example/")
        end

      assert_match(/Jump RT signing key configuration/, error.message)
    end

    JumpRtKeyring.stub(:private_key, nil) do
      error =
        assert_raises(JumpRtConfigurationError) do
          JumpRtIssuer.call(namespace: "AUTH_APP", url: "https://target.example/")
        end

      assert_match(/Jump RT signing key configuration/, error.message)
    end
  end

  test "refuses unsupported issuer surface" do
    ["JUMP_APP", nil, ""].each do |namespace|
      assert_raises(JumpRtConfigurationError, namespace.inspect) do
        JumpRtIssuer.call(namespace: namespace, url: "https://target.example/")
      end
    end
  end

  test "resolves issuer namespace from controller class name" do
    assert_equal "AUTH_APP", JumpRtSurface.namespace_for_controller("Auth::App::DashboardsController")
    assert_equal "AUTH_COM", JumpRtSurface.namespace_for_controller("Auth::Com::DashboardsController")
    assert_equal "AUTH_ORG", JumpRtSurface.namespace_for_controller("Auth::Org::DashboardsController")
    assert_equal "BASE_APP", JumpRtSurface.namespace_for_controller("Base::App::RootsController")
    assert_equal "CORE_ORG", JumpRtSurface.namespace_for_controller("Core::Org::RootsController")
    assert_equal "BASE_COM", JumpRtSurface.namespace_for_controller("Base::Com::RootsController")
    assert_raises(JumpRtConfigurationError) do
      JumpRtSurface.namespace_for_controller("Jump::App::RootsController")
    end
  end

  test "retired Sign controllers and issuer identities have no compatibility mapping" do
    %w(App Com Org).each do |surface|
      assert_raises(JumpRtConfigurationError) do
        JumpRtSurface.namespace_for_controller("Sign::#{surface}::DashboardsController")
      end
      assert_raises(JumpRtConfigurationError) do
        JumpRtSurface.issuer_origin("SIGN_#{surface.upcase}")
      end
    end
  end

  test "Core and Palm issuer origins match their public JWKS origins" do
    %w(APP COM ORG).each do |tld|
      assert_equal "https://jp.umaxica.#{tld.downcase}", JumpRtSurface.issuer_origin("CORE_#{tld}")
    end
    assert_equal "PALM_APP", JumpRtSurface.namespace_for_controller("Palm::App::Sign::OutsController")
    assert_equal "https://palm-jp.umaxica.app", JumpRtSurface.issuer_origin("PALM_APP")
    assert_raises(JumpRtConfigurationError) do
      JumpRtSurface.namespace_for_controller("Palm::Com::RootsController")
    end
  end

  test "Warp uses independent Jump RT issuers while OIDC side client identifiers remain fixed" do
    assert_equal "WARP_APP", JumpRtSurface.namespace_for_controller("Warp::App::RootsController")
    assert_equal "WARP_COM", JumpRtSurface.namespace_for_controller("Warp::Com::RootsController")
    assert_equal "WARP_ORG", JumpRtSurface.namespace_for_controller("Warp::Org::RootsController")
    assert_equal "https://www-jp.umaxica.app", JumpRtSurface.issuer_origin("WARP_APP")
    assert_equal "https://www-jp.umaxica.com", JumpRtSurface.issuer_origin("WARP_COM")
    assert_equal "https://www-jp.umaxica.org", JumpRtSurface.issuer_origin("WARP_ORG")
    warp_app = OidcClientStoresStaticClientStore::FIRST_PARTY_RP_SPECS.fetch("side-app")

    assert_equal "side-app", warp_app.fetch(:aud)
    assert_equal "SIDE_APP", warp_app.fetch(:jwt_namespace)
  end

  test "Edit has no Jump issuer while its OIDC private key client remains configured" do
    %w(Info::Org Docs::App Docs::Com).each do |publishing_surface|
      assert_raises(JumpRtConfigurationError) do
        JumpRtSurface.namespace_for_controller("Edit::Org::Publishing::#{publishing_surface}::EntriesController")
      end
    end
    assert_raises(JumpRtConfigurationError) do
      JumpRtIssuer.call(namespace: "EDIT_ORG", url: "https://www.umaxica.org/oauth/authorize")
    end
    assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
      JitSecurityJwtRegistry.surface("EDIT_ORG")
    end
    assert_equal "EDIT_ORG", JitSecurityJwtRegistry.oidc_client("EDIT_ORG").namespace
    assert_equal "edit-org", OidcClientRegistry.find!("edit-org").client_id
  end

  test "normalizes unsupported issuer surface names by raising" do
    error =
      assert_raises(JumpRtConfigurationError) do
        JumpRtSurface.normalize_namespace("jump_app")
      end

    assert_match(/unsupported Jump RT issuer surface/, error.message)
  end

  test "normalizes host by stripping scheme and path" do
    assert_equal "example.com", JumpRtSurface.normalize_host("https://example.com/path")
    assert_equal "example.com", JumpRtSurface.normalize_host("http://example.com")
    assert_equal "example.com", JumpRtSurface.normalize_host("example.com")
    assert_equal "example.com:3000", JumpRtSurface.normalize_host("https://example.com:3000/path")
  end

  test "production Jump refuses localhost and private destinations including HTTPS" do
    %w(
      http://localhost/ http://base.app.localhost/ https://base.app.localhost/
      https://localhost./ https://base.app.localhost./ https://service.internal./
      https://primary/ https://service.internal/ https://127.0.0.1/ https://10.0.0.1/
      https://172.16.0.1/ https://192.168.1.1/ https://169.254.1.1/ https://[::1]/
      https://[::ffff:192.168.1.1]/ https://[fd00::1]/
    ).each do |url|
      assert_nil JumpRtIssuer.call(namespace: "AUTH_APP", url: url), url
    end
  end

  test "development issuance signs as the canonical PUBLIC_* issuer origin" do
    token =
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
        JumpRtIssuer.call(namespace: "AUTH_APP", url: "https://www.umaxica.app/")
      end

    assert_equal "https://auth.umaxica.app", JWT.decode(token, nil, false).first.fetch("iss")
  end

  test "issuance fails closed when the PUBLIC_* issuer origin is unsafe" do
    with_env("PUBLIC_AUTH_SERVICE_URL" => "auth.app.localhost") do
      assert_raises(JumpRtConfigurationError) do
        JumpRtIssuer.call(namespace: "AUTH_APP", url: "https://www.umaxica.app/")
      end
    end
  end

  private

  def with_env(values)
    previous = values.transform_values { |_value| nil }
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
