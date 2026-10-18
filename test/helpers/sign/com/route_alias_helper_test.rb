# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignComRouteAliasHelperViewTest < ActionView::TestCase
  test "defines sign app route aliases that delegate to sign com routes" do
    url_helpers = Rails.application.routes.url_helpers
    helper_methods = %i(sign_app_sample_path sign_com_sample_path)
    helper = Object.new
    url_helpers.stub(:public_instance_methods, helper_methods) do
      url_helpers.stub(:public_method_defined?, ->(name) { helper_methods.include?(name) }) do
        helper.extend SignComRouteAliasHelper
      end
    end

    helper.define_singleton_method(:sign_com_sample_path) do |id, **options|
      "/com/#{id}?#{options.to_query}"
    end

    assert_equal "/com/42?ri=jp", helper.sign_app_sample_path(42, ri: "jp")
  end

  test "defines acme app route aliases that delegate to acme com routes" do
    url_helpers = Rails.application.routes.url_helpers
    helper_methods = %i(acme_app_sample_url acme_com_sample_url)
    helper = Object.new
    url_helpers.stub(:public_instance_methods, helper_methods) do
      url_helpers.stub(:public_method_defined?, ->(name) { helper_methods.include?(name) }) do
        helper.extend SignComRouteAliasHelper
      end
    end

    helper.define_singleton_method(:acme_com_sample_url) do |**options|
      "https://com.example.test/?#{options.to_query}"
    end

    assert_equal "https://com.example.test/?lx=en", helper.acme_app_sample_url(lx: "en")
  end
end

# DAMP local route helper aliases for former shared test support.
class SignComRouteAliasHelperViewTest
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
