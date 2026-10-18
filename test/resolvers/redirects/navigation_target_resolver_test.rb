# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RedirectsNavigationTargetResolverTest < ActiveSupport::TestCase
  Routes =
    Struct.new(:calls) do
      def auth_app_sign_in_check_path(ri:) = "/sign/in/check?ri=#{ri}"

      def auth_app_sign_in_path(ri:) = "/sign/in?ri=#{ri}"

      def base_app_root_path(ri:) = "/?ri=#{ri}"

      def auth_app_settings_path(ri:) = "/settings?ri=#{ri}"
    end

  test "resolves registered navigation keys" do
    assert_equal "/sign/in/check?ri=jp", resolve(:checkpoint).value
    assert_equal "/sign/in?ri=jp", resolve(:selector).value
    assert_equal "/?ri=jp", resolve(:dashboard).value
    assert_equal "/settings?ri=jp", resolve(:settings_security, scope: :settings).value
  end

  test "rejects unknown raw url and raw path keys" do
    assert_not resolve(:missing).ok?
    assert_not resolve("https://evil.example").ok?
    assert_not resolve("/dashboard").ok?
  end

  test "enforces flow scope" do
    result = resolve(:settings_security, scope: :authentication)

    assert_not result.ok?
    assert_equal "scope_denied", result.failure_reason
  end

  test "resolves signed out and home targets with default app surface" do
    signed_out = resolve(:signed_out, params: { ri: "jp" })
    home = resolve(:home, params: { ri: "jp" })
    string_key = RedirectsNavigationTargetResolver.call(
      "dashboard",
      routes: Routes.new,
      params: { ri: "jp", surface: "app" },
      source: :test,
    )

    assert_predicate signed_out, :ok?
    assert_equal "/sign/out?ri=jp", signed_out.value

    assert_predicate home, :ok?
    assert_equal "/?ri=jp", home.value

    assert_predicate string_key, :ok?
    assert_equal "/?ri=jp", string_key.value
  end

  test "does not resolve external urls from registry" do
    routes = Class.new do
      def base_app_root_path(**) = "https://evil.example"
    end.new
    result = RedirectsNavigationTargetResolver.call(
      :dashboard,
      routes: routes,
      params: { ri: "jp", surface: "app" },
      source: :test,
    )

    assert_not result.ok?
    assert_equal "invalid_registered_path", result.failure_reason
  end

  private

  def resolve(key, scope: nil, params: { ri: "jp", surface: "app" })
    RedirectsNavigationTargetResolver.call(
      key,
      routes: Routes.new,
      params: params,
      scope: scope,
      source: :test,
    )
  end
end

# DAMP local route helper aliases for former shared test support.
class RedirectsNavigationTargetResolverTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end
