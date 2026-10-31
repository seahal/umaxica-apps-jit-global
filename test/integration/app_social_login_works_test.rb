# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AppSocialLoginWorksTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @previous_omniauth_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = false
  end

  teardown do
    OmniAuth.config.test_mode = @previous_omniauth_test_mode
  end

  test "POST /social/google on app host redirects to Google OAuth" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL")

    post "/social/google"

    assert_response :redirect
    assert_equal "accounts.google.com", URI.parse(response.location).host
    callback = URI.parse(Rack::Utils.parse_nested_query(URI.parse(response.location).query.to_s).fetch("redirect_uri"))
    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), callback.host
    assert_equal "/social/google/callback", callback.path
    assert_equal "https", callback.scheme
  end

  test "POST /social for org Google provider on app host is not registered" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL")

    post "/social/google_#{"org"}"

    assert_response :not_found
  end

  test "POST /social/apple on app host redirects to Apple Sign In" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL")

    post "/social/apple"

    assert_response :redirect
    assert_equal "appleid.apple.com", URI.parse(response.location).host
    callback = URI.parse(Rack::Utils.parse_nested_query(URI.parse(response.location).query.to_s).fetch("redirect_uri"))
    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), callback.host
    assert_equal "/social/apple/callback", callback.path
    assert_equal "https", callback.scheme
  end
end
