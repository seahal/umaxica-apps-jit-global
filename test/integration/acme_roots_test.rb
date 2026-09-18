# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SurfaceRootsControllerTest < ActionDispatch::IntegrationTest
  # Public www hosts share Base Root. A missing region still normalizes; a recognized region
  # stays on the control-plane home.
  test "acme app root normalizes the region then renders the control-plane home" do
    get "/", headers: { "Host" => ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost") }

    assert_response :found
    follow_redirect!

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component
  end

  test "acme app www root with a region renders the control-plane home" do
    get "/?ri=jp", headers: { "Host" => ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost") }

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component
  end

  test "acme com root normalizes the region then renders the control-plane home" do
    get "/", headers: { "Host" => ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "www.com.localhost") }
    follow_redirect! if response.redirect? && response.status == 302

    assert_response :success
    assert_equal "base/com/roots/index", inertia_component
  end

  test "acme org root normalizes the region then renders the control-plane home" do
    get "/", headers: { "Host" => ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost") }
    follow_redirect! if response.redirect? && response.status == 302

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
