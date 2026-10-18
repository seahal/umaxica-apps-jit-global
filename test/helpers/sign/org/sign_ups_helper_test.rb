# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignOrgSignUpsHelperTest < ActionView::TestCase
  setup do
    extend Auth::Org::SignUpsHelper
  end

  test "sign_org_recruit_contact_link uses safe configured direct message URL" do
    with_env("ORG_SIGN_UP_DIRECT_MESSAGE_URL" => "https://contact.example.test/recruit?team=org") do
      html = sign_org_recruit_contact_link

      assert_includes html, I18n.t("sign.org.ups.new.recruit_link_text")
      assert_includes html, "https://contact.example.test/recruit?team=org"
      assert_includes html, "font-semibold text-slate-900 underline"
    end
  end

  test "sign_org_recruit_contact_link falls back when configured direct message URL is unsafe" do
    define_singleton_method(:params) do
      ActionController::Parameters.new(ri: "jp", lx: "en")
    end
    define_singleton_method(:base_com_root_url) do |params|
      "https://com.example.test/?#{params.to_query}"
    end

    with_env(
      "ORG_SIGN_UP_DIRECT_MESSAGE_URL" => "javascript:alert(1)",
      "BASE_CORPORATE_URL" => "www.com.localhost",
    ) do
      html = sign_org_recruit_contact_link

      assert_includes html, "https://com.example.test/?host=www.umaxica.com&amp;lx=en&amp;ri=jp"
      assert_not_includes html, "javascript:alert"
    end
  end

  test "sign_org_recruit_contact_link falls back to corporate root with preference params" do
    define_singleton_method(:default_url_options) do
      { ct: "dr", lx: "en", ri: "jp", tz: "asia/tokyo", ignored: "value" }
    end
    define_singleton_method(:params) do
      ActionController::Parameters.new(default_url_options)
    end
    define_singleton_method(:base_com_root_url) do |params|
      "https://com.example.test/?#{params.to_query}"
    end

    with_env(
      "ORG_SIGN_UP_DIRECT_MESSAGE_URL" => nil,
      "BASE_CORPORATE_URL" => "www.com.localhost",
    ) do
      html = sign_org_recruit_contact_link

      assert_includes html, I18n.t("sign.org.ups.new.recruit_link_text")
      assert_includes html, "https://com.example.test/?host=www.umaxica.com&amp;lx=en&amp;ri=jp"
      assert_includes html, "font-semibold text-slate-900 underline"
      assert_not_includes html, "ignored"
      assert_not_includes html, "ct=dr"
      assert_not_includes html, "tz=asia%2Ftokyo"
    end
  end

  private

  def with_env(values)
    previous = {}
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

# DAMP local route helper aliases for former shared test support.
class SignOrgSignUpsHelperTest
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
