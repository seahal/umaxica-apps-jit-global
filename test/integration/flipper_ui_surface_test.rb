# typed: false
# frozen_string_literal: true

require "test_helper"

# Flipper::UI is mounted on its own dedicated host only (config/routes/flipper.rb).
# Two independent controls apply: the surface boundary (the mount exists on no other
# host) and an application-level Rack::Auth::Basic guard. Cloudflare Access fronts the
# host in production, but the mount must not depend on the edge alone - Flipper::UI
# inherits none of this application's authorization stack, so a request that reached
# the origin directly would otherwise get unauthenticated feature-flag read/write.
class FlipperUiSurfaceTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  DEVELOPER_HOST = "flipper.core.dev.localhost"
  MOUNT_PATH = "/"
  TEST_USER = "flipper-test-user"
  TEST_PASSWORD = "flipper-test-password"

  test "developer host serves the Flipper feature list to an authenticated operator" do
    with_flipper_ui_credentials do
      host! DEVELOPER_HOST
      # The mount root redirects to its features index.
      get MOUNT_PATH, headers: basic_auth_headers(TEST_USER, TEST_PASSWORD)

      assert_redirected_to "http://#{DEVELOPER_HOST}/features"
      follow_redirect!(headers: basic_auth_headers(TEST_USER, TEST_PASSWORD))

      assert_response :success
      assert_match(/Features/, response.body)
    end
  end

  test "developer host rejects an unauthenticated request" do
    with_flipper_ui_credentials do
      host! DEVELOPER_HOST
      get MOUNT_PATH

      assert_response :unauthorized
      assert_match(/Basic/, response.headers["WWW-Authenticate"].to_s)
    end
  end

  test "developer host rejects a wrong password" do
    with_flipper_ui_credentials do
      host! DEVELOPER_HOST
      get MOUNT_PATH, headers: basic_auth_headers(TEST_USER, "not-the-password")

      assert_response :unauthorized
    end
  end

  # A guard that falls open when its credentials are unset is worse than no guard,
  # because it reads as protection in review.
  test "developer host rejects every request when credentials are not configured" do
    host! DEVELOPER_HOST
    get MOUNT_PATH, headers: basic_auth_headers(TEST_USER, TEST_PASSWORD)

    assert_response :unauthorized
  end

  test "no other surface routes the Flipper mount" do
    ["base.app.localhost", "base.com.localhost", "base.org.localhost", "base.net.localhost",
     "base.dev.localhost", "core.dev.localhost", "mission.core.dev.localhost",].each do |host|
      assert_raises(ActionController::RoutingError, "#{host} must not route #{MOUNT_PATH}") do
        Rails.application.routes.recognize_path("http://#{host}/features", method: :get)
      end
    end
  end

  # Flipper::UI sets its own Content-Security-Policy (Flipper::UI::Action::CONTENT_SECURITY_POLICY)
  # and the Rails policy middleware leaves an existing header alone. Without that, the application
  # policy's `script-src 'strict-dynamic'` would block the engine's own nonce-less script tags.
  test "Flipper responses carry the engine policy, not the strict-dynamic application policy" do
    with_flipper_ui_credentials do
      host! DEVELOPER_HOST
      get "/features", headers: basic_auth_headers(TEST_USER, TEST_PASSWORD)

      policy = response.headers["Content-Security-Policy"]

      assert_match(/script-src 'report-sample' 'self';/, policy)
      assert_not_includes policy, "strict-dynamic"
    end
  end

  test "application surfaces keep the strict-dynamic script policy" do
    host! "base.app.localhost"
    get "/health"

    assert_includes response.headers["Content-Security-Policy"], "strict-dynamic"
  end

  private

  def basic_auth_headers(user, password)
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(user, password) }
  end

  def with_flipper_ui_credentials(&)
    real_creds = Rails.app.creds
    fake_creds = Object.new
    fake_creds.define_singleton_method(:option) do |key, **options|
      case key.to_sym
      when :FLIPPER_UI_USER then TEST_USER
      when :FLIPPER_UI_PASSWORD then TEST_PASSWORD
      else real_creds.option(key, **options)
      end
    end
    fake_creds.define_singleton_method(:require) { |key| real_creds.require(key) }

    Rails.app.stub(:creds, fake_creds, &)
  end
end
