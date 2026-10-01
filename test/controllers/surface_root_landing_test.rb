# typed: false
# frozen_string_literal: true

require "test_helper"

# Base Root is the anonymous Home. Auth Root is a public ceremony-service entry. Base Home
# resolves a missing or unrecognized region in place without redirecting
# (adr/home-dashboard-authentication-boundary.md).
class SurfaceRootLandingTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "base app root without a region renders Home without redirect" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get base_app_root_url(host: host), headers: { "Host" => host }

    assert_response :success
    assert_nil response.location
    assert_equal "base/app/roots/index", inertia_component
  end

  test "base app root with a region renders the control-plane home" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get base_app_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component
  end

  test "base com root with a region renders the control-plane home" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host

    get base_com_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
    assert_equal "base/com/roots/index", inertia_component
  end

  test "base org root with a region renders the control-plane home" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host

    get base_org_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
  end

  test "base app root with an unrecognized region renders Home without redirect" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get base_app_root_url(ri: "zz", host: host), headers: { "Host" => host }

    assert_response :success
    assert_nil response.location
    assert_equal "base/app/roots/index", inertia_component
  end

  test "auth app root with a region renders the ceremony-service entry" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    get auth_app_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
    assert_equal "auth/app/roots/index", inertia_component
  end

  test "auth com root with a region renders the ceremony-service entry" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    get auth_com_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
    assert_equal "auth/com/roots/index", inertia_component
  end

  test "auth org root with a region renders the ceremony-service entry" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    get auth_org_root_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
    assert_equal "auth/org/roots/index", inertia_component
  end
end
