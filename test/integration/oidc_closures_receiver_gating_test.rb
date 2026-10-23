# typed: false
# frozen_string_literal: true

require "test_helper"

# D-31 / D-118: the receiver lives at POST /oidc/closures, answers only on the RP's registered
# host, needs no browser or cookie, and the former path does not route.
class OidcClosuresReceiverGatingTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "the former back-channel logout path is not routable" do
    host = URI.parse(OidcClientStoresStaticClientStore.backchannel_logout_uri("core-app-jp")).host

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{host}/oidc/backchannel-logout", method: :post)
    end
  end

  test "a request without a browser User-Agent or cookies reaches the token check" do
    host! URI.parse(OidcClientStoresStaticClientStore.backchannel_logout_uri("core-app-jp")).host
    https!

    post "/oidc/closures", params: { logout_token: "not-a-jwt" }, headers: { "User-Agent" => "" }

    assert_response :bad_request
    assert_equal "no-store", response.headers["Cache-Control"]
  end
end
