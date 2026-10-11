# typed: false
# frozen_string_literal: true

require "test_helper"

# One request per canonical layout, checking that the layout actually reaches the
# browser with the brand site title. The full contract (root vs non-root shape,
# localization, the route sweep) lives in HtmlTitleContractTest.
class LayoutRenderedTitleSmokeTest < ActionDispatch::IntegrationTest
  BRAND = ENV.fetch("BRAND_NAME").upcase

  test "canonical layouts render the expected brand site title" do
    cases = [
      {
        host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
        path: -> { auth_app_sign_in_path(ri: "jp") },
        tld: "APP",
      },
      {
        host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost"),
        path: -> { auth_com_sign_in_path(ri: "jp") },
        tld: "COM",
      },
      {
        host: ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost"),
        path: -> { auth_org_sign_in_path(ri: "jp") },
        tld: "ORG",
      },
      {
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
        path: -> { base_app_root_path(ri: "jp") },
        tld: "APP",
      },
      {
        host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
        path: -> { base_com_root_path(ri: "jp") },
        tld: "COM",
      },
      {
        host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
        path: -> { base_org_root_path(ri: "jp") },
        tld: "ORG",
      },
      {
        host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"),
        path: -> { new_core_app_sign_out_path(ri: "jp") },
        tld: "APP",
      },
      {
        host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"),
        path: -> { new_core_com_sign_out_path(ri: "jp") },
        tld: "COM",
      },
      {
        host: ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost"),
        path: -> { new_core_org_sign_out_path(ri: "jp") },
        tld: "ORG",
      },
      {
        host: ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "wide.app.localhost"),
        path: -> { new_side_app_sign_out_path(ri: "jp") },
        tld: "APP",
      },
      {
        host: ENV.fetch("PUBLIC_SIDE_CORPORATE_URL", "wide.com.localhost"),
        path: -> { new_side_com_sign_out_path(ri: "jp") },
        tld: "COM",
      },
      {
        host: ENV.fetch("PUBLIC_SIDE_STAFF_URL", "wide.org.localhost"),
        path: -> { new_side_org_sign_out_path(ri: "jp") },
        tld: "ORG",
      },
      {
        host: ENV.fetch("PUBLIC_PALM_SERVICE_URL", "palm.app.localhost"),
        path: -> { palm_app_sign_out_path(ri: "jp") },
        tld: "APP",
      },
    ]

    cases.each do |entry|
      host! entry.fetch(:host)
      get instance_exec(&entry.fetch(:path))

      if response.redirect?
        location = URI.parse(response.location)

        assert_predicate location.host, :present?
      elsif response.not_found?
        assert_response :not_found
      else
        assert_response :success
        assert_select "title", /#{Regexp.escape("#{BRAND} (#{entry.fetch(:tld)})")}\z/
      end
    end
  end
end
