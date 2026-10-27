# typed: false
# frozen_string_literal: true

require "test_helper"

# Global ActionController::API endpoints that sit under no surface ApplicationController or
# BareController are their own DefaultNoStore policy roots
# (adr/global-and-publishing-default-no-store-policy.md), so error responses carry
# `Cache-Control: no-store` too, and existing protocol headers stay in place.
class DefaultNoStoreStandaloneEndpointsTest < ActionDispatch::IntegrationTest
  # The token endpoint moved from Base to the Visa OP host (WU-02).
  test "Visa OAuth token endpoint error response is no-store and keeps Pragma no-cache" do
    host!(ENV.fetch("PUBLIC_VISA_SERVICE_URL"))

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
end
