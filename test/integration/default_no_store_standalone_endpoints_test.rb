# typed: false
# frozen_string_literal: true

require "test_helper"

# Global ActionController::API endpoints that sit under no surface ApplicationController or
# BareController are their own DefaultNoStore policy roots
# (adr/global-and-publishing-default-no-store-policy.md), so error responses carry
# `Cache-Control: no-store` too, and existing protocol headers stay in place.
class DefaultNoStoreStandaloneEndpointsTest < ActionDispatch::IntegrationTest
  test "Base OAuth token endpoint error response is no-store and keeps Pragma no-cache" do
    host!("base.app.localhost")

    post("/oauth/token", params: { grant_type: "unsupported" })

    assert_response :bad_request
    assert_equal "no-store", response.headers.fetch("Cache-Control")
    assert_equal "no-cache", response.headers.fetch("Pragma")
  end

  test "Apple server notification rejected by media type is no-store" do
    host!("auth.app.localhost")

    post("/apple/notifications", params: "payload", headers: { "CONTENT_TYPE" => "text/plain" })

    assert_response :unsupported_media_type
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Edit OIDC back-channel logout with an invalid logout token is no-store" do
    host!("edit.org.localhost")

    post("/oidc/backchannel/logout", params: { logout_token: "not-a-jwt" })

    assert_response :bad_request
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end
end
