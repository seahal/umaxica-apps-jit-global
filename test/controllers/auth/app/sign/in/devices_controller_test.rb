# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::In::DevicesControllerTest < ActionDispatch::IntegrationTest
  test "guest GET renders a read-only placeholder without authentication or emergency mutation" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    credentials = ClientSecretCredential.order(:id).map(&:attributes)
    assert_no_difference ["ClientToken.count", "ClientDeviceSession.count", "ClientEmergencySignInOperation.count",
                          "ClientSecretCredential.count",] do
      get auth_app_sign_in_device_path(ri: "jp")
    end
    assert_response :ok
    assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
    assert_equal I18n.t("sign.app.authentication.device.placeholder"), response.body
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal credentials, ClientSecretCredential.order(:id).map(&:attributes)
    assert_nil session[:oidc_authorization_login_challenge]
    assert_nil session["oidc_pending_flows"]
    auth_cookies = response.headers["Set-Cookie"].to_s

    assert_not_includes auth_cookies, AuthenticationCookieName.access
    assert_not_includes auth_cookies, AuthenticationCookieName.refresh
  end

  test "authenticated app client is refused by the existing guest-only contract" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    client = clients(:one)
    token = ClientToken.create!(user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id, resource_type: "client",
              jwt_issuer_id: "surface:SIGN_APP",
    )
    credentials = ClientSecretCredential.order(:id).map(&:attributes)
    assert_no_difference ["ClientToken.count", "ClientDeviceSession.count", "ClientEmergencySignInOperation.count"] do
      get auth_app_sign_in_device_path(ri: "jp"), headers: { "Authorization" => "Bearer #{access_token}" }
    end
    assert_response :conflict
    assert_equal "Sign-in is unavailable while authenticated.", response.body
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal credentials, ClientSecretCredential.order(:id).map(&:attributes)
  end
end
