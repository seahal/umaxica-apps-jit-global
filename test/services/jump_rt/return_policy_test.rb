# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class JumpRtReturnPolicyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "normalize_origin returns nil for invalid URI" do
    assert_nil JumpRtReturnPolicy.normalize_origin("not a url")
  end

  test "normalize_origin returns nil for non-http scheme" do
    assert_nil JumpRtReturnPolicy.normalize_origin("ftp://example.com")
  end

  test "normalize_origin returns nil for URI with userinfo" do
    assert_nil JumpRtReturnPolicy.normalize_origin("https://user:pass@www.umaxica.app")
  end

  test "normalize_origin normalizes https origin" do
    result = JumpRtReturnPolicy.normalize_origin("https://www.umaxica.app")

    assert_equal "https://www.umaxica.app", result
  end

  test "normalize_origin normalizes http origin" do
    result = JumpRtReturnPolicy.normalize_origin("http://example.com")

    assert_equal "http://example.com", result
  end

  test "normalize_origin downcases host" do
    result = JumpRtReturnPolicy.normalize_origin("https://WWW.UMAXICA.APP")

    assert_equal "https://www.umaxica.app", result
  end

  test "normalize_origin includes non-default port" do
    result = JumpRtReturnPolicy.normalize_origin("https://www.umaxica.app:8443")

    assert_equal "https://www.umaxica.app:8443", result
  end

  test "normalize_origin omits default https port" do
    result = JumpRtReturnPolicy.normalize_origin("https://www.umaxica.app:443")

    assert_equal "https://www.umaxica.app", result
  end

  test "normalize_origin omits default http port" do
    result = JumpRtReturnPolicy.normalize_origin("http://example.com:80")

    assert_equal "http://example.com", result
  end

  test "normalize_origin returns nil for blank host" do
    assert_nil JumpRtReturnPolicy.normalize_origin("https://")
  end

  test "allowed_source returns true for valid source matching destination" do
    assert JumpRtReturnPolicy.allowed_source?(
      destination_origin: "https://www.umaxica.app",
      source: "https://auth.umaxica.app",
    )
  end

  test "allowed_source returns false for unauthorized source" do
    assert_not JumpRtReturnPolicy.allowed_source?(
      destination_origin: "https://www.umaxica.app",
      source: "https://evil.example.com",
    )
  end

  test "allowed_source returns false when destination origin is unknown" do
    assert_not JumpRtReturnPolicy.allowed_source?(
      destination_origin: "https://unknown.example.com",
      source: "https://auth.umaxica.app",
    )
  end

  test "default_port_for returns 443 for https" do
    assert_equal 443, JumpRtReturnPolicy.default_port_for("https")
  end

  test "default_port_for returns 80 for http" do
    assert_equal 80, JumpRtReturnPolicy.default_port_for("http")
  end

  test "allowed_sources lists the auth jump rt issuing origin for the base destination" do
    sources = JumpRtReturnPolicy.allowed_sources

    assert_includes sources.keys, "https://www.umaxica.app"
    assert_includes sources["https://www.umaxica.app"], "https://auth.umaxica.app"
  end

  test "only the approved same TLD directed graph is allowed" do
    origins = {
      "auth-app-ww" => "https://auth.umaxica.app",
      "auth-com-ww" => "https://auth.umaxica.com",
      "auth-org-ww" => "https://auth.umaxica.org",
      "base-app-ww" => "https://www.umaxica.app",
      "base-com-ww" => "https://www.umaxica.com",
      "base-org-ww" => "https://www.umaxica.org",
      "core-app-jp" => "https://jp.umaxica.app",
      "core-com-jp" => "https://jp.umaxica.com",
      "core-org-jp" => "https://jp.umaxica.org",
      "palm-app-jp" => "https://palm-jp.umaxica.app",
      "warp-app-jp" => "https://www-jp.umaxica.app",
      "warp-com-jp" => "https://www-jp.umaxica.com",
      "warp-org-jp" => "https://www-jp.umaxica.org",
    }
    edges = [
      ["auth-app-ww", "base-app-ww"],
      ["auth-com-ww", "base-com-ww"],
      ["auth-org-ww", "base-org-ww"],
      ["base-app-ww", "auth-app-ww"],
      ["base-app-ww", "core-app-jp"],
      ["base-app-ww", "palm-app-jp"],
      ["base-app-ww", "warp-app-jp"],
      ["base-com-ww", "auth-com-ww"],
      ["base-com-ww", "core-com-jp"],
      ["base-com-ww", "warp-com-jp"],
      ["base-org-ww", "auth-org-ww"],
      ["base-org-ww", "core-org-jp"],
      ["base-org-ww", "warp-org-jp"],
      ["core-app-jp", "base-app-ww"],
      ["core-com-jp", "base-com-ww"],
      ["core-org-jp", "base-org-ww"],
      ["palm-app-jp", "base-app-ww"],
      ["warp-app-jp", "base-app-ww"],
      ["warp-com-jp", "base-com-ww"],
      ["warp-org-jp", "base-org-ww"],
    ]
    assert_equal 20, edges.size
    observed = JumpRtReturnPolicy.allowed_sources.flat_map do |destination, sources|
      sources.map { |source| [source, destination] }
    end
    assert_equal edges.map { |source, destination| [origins.fetch(source), origins.fetch(destination)] }.sort,
                 observed.sort
    origins.keys.product(origins.keys).each do |source, destination|
      assert_equal edges.include?([source, destination]),
                   JumpRtReturnPolicy.allowed_source?(destination_origin: origins.fetch(destination),
                                                      source: origins.fetch(source)),
                   "#{source} -> #{destination}"
    end
  end

  test "unregistered stale private and sentinel origins are denied in either direction" do
    [nil, "", "https://zzzz.umaxica.app", "https://www.umaxica.zzz",
     "https://www-zz.umaxica.app", "https://www.jp.umaxica.app", "https://jpx.umaxica.app",
     "https://palm.jp.umaxica.app", "https://edit.umaxica.org", "http://base.app.localhost",
     "https://base.app.localhost", "https://127.0.0.1",].each do |origin|
      assert_not JumpRtReturnPolicy.allowed_source?(destination_origin: "https://www.umaxica.app", source: origin)
      assert_not JumpRtReturnPolicy.allowed_source?(destination_origin: origin, source: "https://www.umaxica.app")
    end
  end

  test "retired logical ceremony issuer is not a jump return source" do
    %w(app com org).each do |tld|
      assert_not JumpRtReturnPolicy.allowed_source?(
        destination_origin: "https://www.umaxica.#{tld}",
        source: "https://log.umaxica.#{tld}",
      ), tld
      assert_not JumpRtReturnPolicy.allowed_source?(
        destination_origin: "https://www.jp.umaxica.#{tld}",
        source: "https://log.umaxica.#{tld}",
      ), tld
    end
  end

  def with_env(values)
    saved = {}
    values.each_key { |key| saved[key.to_s] = ENV[key.to_s] }
    values.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    values.each_key do |key|
      if saved[key.to_s].nil?
        ENV.delete(key)
      else
        ENV[key] = saved[key.to_s]
      end
    end
  end
end
