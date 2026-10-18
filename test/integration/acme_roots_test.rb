# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SurfaceRootsControllerTest < ActionDispatch::IntegrationTest
  # Public www hosts share Base Root. Home resolves a missing region in place without redirecting
  # (adr/home-dashboard-authentication-boundary.md).
  test "acme app root without a region renders the control-plane home without redirect" do
    get "/", headers: { "Host" => ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost") }

    assert_response :success
    assert_nil response.location
    assert_equal "base/app/roots/index", inertia_component
  end

  test "acme app www root with a region renders the control-plane home" do
    get "/?ri=jp", headers: { "Host" => ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost") }

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component
  end

  test "acme com root without a region renders the control-plane home without redirect" do
    get "/", headers: { "Host" => ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "www.com.localhost") }

    assert_response :success
    assert_equal "base/com/roots/index", inertia_component
  end

  test "acme org root without a region renders the control-plane home without redirect" do
    get "/", headers: { "Host" => ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost") }

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
  end

  test "acme org www root with a region renders the control-plane home" do
    get "/?ri=jp", headers: { "Host" => ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost") }

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
  end
end

class SurfaceHealthEndpointTest < ActionDispatch::IntegrationTest
  test "acme app health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "acme com health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "www.com.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "acme org health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "sign app health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "sign org health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end
end
