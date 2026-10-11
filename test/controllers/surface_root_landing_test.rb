# typed: false
# frozen_string_literal: true

require "test_helper"

# Control-plane Base Root is the authenticated home. Auth Root is a public ceremony-service
# entry. A missing region still normalizes first; a recognized region stays on the host.
class SurfaceRootLandingTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "base app root without a region is normalized to the default region" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get base_app_root_url(host: host), headers: { "Host" => host }

    assert_response :redirect
    assert_match(/\Ahttp:\/\/#{Regexp.escape(host)}\/\?ri=/, response.location)
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

  test "base app root leaves an unrecognized region to region normalization rather than redirecting" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get base_app_root_url(ri: "zz", host: host), headers: { "Host" => host }

    assert_response :redirect
    assert_not_equal RegionalRootUrlRegistry.url_for(surface: :app, region: "jp"), response.location
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
