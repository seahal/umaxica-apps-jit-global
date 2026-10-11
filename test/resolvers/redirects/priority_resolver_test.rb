# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RedirectsPriorityResolverTest < ActiveSupport::TestCase
  Routes =
    Struct.new(:calls) do
      def auth_app_sign_in_check_path(ri:) = "/sign/in/check?ri=#{ri}"

      def auth_app_sign_in_path(ri:) = "/sign/in?ri=#{ri}"

      def base_app_root_path(ri:) = "/?ri=#{ri}"

      def auth_app_settings_path(ri:) = "/settings?ri=#{ri}"
    end

  test "explicit nt wins over signed pt" do
    result = resolve([{ kind: :nt, value: :dashboard }, { kind: :signed_pt, value: "/settings" }])

    assert_equal "/?ri=jp", result.value
  end

  test "signed nt wins over raw pt" do
    result = resolve([{ kind: :signed_nt, value: :checkpoint }, { kind: :pt, value: "/settings" }])

    assert_equal "/sign/in/check?ri=jp", result.value
  end

  test "signed pt wins over raw pt" do
    result = resolve([{ kind: :signed_pt, value: "/dashboard" }, { kind: :pt, value: "/settings" }])

    assert_equal "/dashboard", result.value
  end

  test "raw pt is used only when safe" do
    assert_equal "/settings", resolve([{ kind: :pt, value: "/settings" }]).value
    assert_not resolve([{ kind: :pt, value: "https://evil.example" }]).ok?
  end

  test "external is not part of internal priority chain" do
    result = resolve([{ kind: :external, value: :rp_app }, { kind: :pt, value: "/settings" }])

    assert_equal "/settings", result.value
  end

  test "default path is final explicit fallback" do
    assert_equal "/default", resolve([{ kind: :pt, value: "" }], default: "/default").value
  end

  private

  def resolve(priority, default: "/default")
    RedirectsPriorityResolver.call(
      priority: priority,
      routes: Routes.new,
      params: { ri: "jp", surface: "app" },
      default: default,
    )
  end
end

# DAMP local route helper aliases for former shared test support.
class RedirectsPriorityResolverTest
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
