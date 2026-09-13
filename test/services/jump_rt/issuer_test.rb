# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "ostruct"

class JumpRtIssuerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  HostSet = Struct.new(:sign_service)
  BootConfig = Struct.new(:hosts, :jump)

  setup do
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
  end

  test "issues ES384 jump rt jwt with expected claims" do
    with_env(
      "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a",
      "PRIVATE_AUTH_SERVICE_URL" => "sign.example.test",
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
    ) do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "SIGN_APP",
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
        assert_equal JitSecurityJwtRegistry.surface("SIGN_APP").current_kid, header["kid"]
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
      "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a",
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
    ) do
      JumpRtKeyring.stub(:private_key, @private_key) do
        result = JumpRtIssuer.call(
          namespace: "SIGN_APP",
          url: "http://example.com/%gg",
          dst: "internal",
        )

        assert_nil result
      end
    end
  end

  test "can mark issued jump rt as one-time replay policy" do
    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "SIGN_APP",
          url: "https://target.example/path",
          replay_policy: "once",
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal "once", payload["rpl"]
      end
    end
  end

  test "refuses invalid replay policy" do
    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "SIGN_APP",
          url: "https://target.example/path",
          replay_policy: "single",
        )

        assert_nil token
      end
    end
  end

  test "uses environment configured ttl when ttl is omitted" do
    hosts = HostSet.new(OpenStruct.new(host: "sign.example.test"))
    boot_config = BootConfig.new(hosts, OpenStruct.new(ttl_seconds: 30, audience: "https://jump.umaxica.net"))

    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      Rails.configuration.x.stub(:boot_config, boot_config) do
        JumpRtKeyring.stub(:private_key, @private_key) do
          token = JumpRtIssuer.call(
            namespace: "SIGN_APP",
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
    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(namespace: "SIGN_APP", url: "https://target.example/", dst: "unknown")

        assert_nil token
      end
    end
  end

  test "refuses unsafe destination urls" do
    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        assert_nil JumpRtIssuer.call(namespace: "SIGN_APP", url: "javascript:alert(1)")
        assert_nil JumpRtIssuer.call(namespace: "SIGN_APP", url: "https://user:pass@target.example/")
        assert_nil JumpRtIssuer.call(namespace: "SIGN_APP", url: "https://target.example/#fragment")
        assert_nil JumpRtIssuer.call(namespace: "SIGN_APP", url: "https://target.example/\n")
      end
    end
  end

  test "strips redirect-target query keys before signing the url" do
    with_env(
      "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a",
      "PRIVATE_AUTH_SERVICE_URL" => "sign.example.test",
    ) do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "SIGN_APP",
          url: "https://target.example/path?ok=1&pt=/evil&rt=stale&xt=foo&keep=2",
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal "https://target.example/path?ok=1&keep=2", payload["url"]
      end
    end
  end

  test "strips redirect uri by default before signing the url" do
    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "SIGN_APP",
          url: "https://target.example/path?redirect_uri=https%3A%2F%2Fwww.example.com%2Fauth%2Fcallback&ok=1",
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal "https://target.example/path?ok=1", payload["url"]
      end
    end
  end

  test "preserves explicitly allowed redirect uri inside the signed url" do
    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "SIGN_APP",
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

  test "drops query entirely when only redirect-target keys are present" do
    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, @private_key) do
        token = JumpRtIssuer.call(
          namespace: "SIGN_APP",
          url: "https://target.example/path?rt=stale&pt=/evil",
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal "https://target.example/path", payload["url"]
      end
    end
  end

  test "refuses missing key material" do
    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRtKeyring.stub(:private_key, nil) do
        assert_nil JumpRtIssuer.call(namespace: "SIGN_APP", url: "https://target.example/")
      end
    end
  end

  test "refuses unsupported issuer surface" do
    assert_raises(ArgumentError) do
      JumpRtIssuer.call(namespace: "JUMP_APP", url: "https://target.example/")
    end
  end

  test "resolves issuer namespace from controller class name" do
    assert_equal "SIGN_APP", JumpRtSurface.namespace_for_controller("Sign::App::DashboardsController")
    assert_equal "SIGN_COM", JumpRtSurface.namespace_for_controller("Sign::Com::DashboardsController")
    assert_equal "SIGN_ORG", JumpRtSurface.namespace_for_controller("Sign::Org::DashboardsController")
    assert_equal "ACME_APP", JumpRtSurface.namespace_for_controller("Acme::App::RootsController")
    assert_equal "BASE_APP", JumpRtSurface.namespace_for_controller("Base::App::RootsController")
    assert_equal "CORE_ORG", JumpRtSurface.namespace_for_controller("Core::Org::RootsController")
    assert_equal "BASE_COM", JumpRtSurface.namespace_for_controller("Base::Com::RootsController")
    assert_nil JumpRtSurface.namespace_for_controller("Jump::App::RootsController")
  end

  test "normalizes unsupported issuer surface names by raising" do
    error =
      assert_raises(ArgumentError) do
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
