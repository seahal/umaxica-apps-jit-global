# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/oidc_auth_admission_test_helper"

class GoogleOauthSessionStateTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  include OidcAuthAdmissionTestHelper

  setup do
    @previous_omniauth_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = false
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @private_auth_host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
    bootstrap_auth_sign_in_admission!(surface: "app", region: "jp", target_link_uri: "/dashboard")
  end

  teardown do
    OmniAuth.config.test_mode = @previous_omniauth_test_mode
  end

  test "Google OAuth state survives the Auth session cookie round trip to a cross-site callback" do
    token = google_button_token

    assert_predicate token, :present?, "sign-in page carries no authenticity token for Google"

    fields = { authenticity_token: token, ri: "jp" }
    same_origin_headers = {
      "Host" => @host,
      "Origin" => "https://#{@host}",
      "Sec-Fetch-Site" => "same-origin",
    }

    with_forgery_protection do
      post auth_app_social_google_session_path, params: fields, headers: same_origin_headers
    end

    assert_response :temporary_redirect
    assert_equal "/social/google", URI.parse(response.location).path
    session_id_before_request_phase = session.id.to_s

    # A browser follows the 307 with the same method, form body and current Auth cookies.
    with_forgery_protection do
      post "/social/google", params: fields, headers: same_origin_headers
    end

    assert_response :redirect
    authorization_uri = URI.parse(response.location)

    assert_equal "accounts.google.com", authorization_uri.host
    authorization_params = Rack::Utils.parse_nested_query(authorization_uri.query)
    oauth_state = authorization_params.fetch("state")
    callback_uri = URI.parse(authorization_params.fetch("redirect_uri"))

    assert_equal [@host, "/social/google/callback"], [callback_uri.host, callback_uri.path]
    assert_equal oauth_state, session.fetch("omniauth.state")
    session_id_after_request_phase = session.id.to_s

    assert_equal session_id_before_request_phase, session_id_after_request_phase
    session_cookie_key = JitSessionCookieConfig.cookie_key(
      force_secure: JitSessionCookieConfig.force_secure?,
    )

    assert_predicate cookies[session_cookie_key], :present?, "Auth session cookie was not issued by the request phase"
    session_cookie =
      response.headers["Set-Cookie"].to_s.lines.find do |line|
        line.start_with?("#{session_cookie_key}=")
      end

    assert session_cookie, "request phase did not set the Auth session cookie"
    assert_match(/;\s*path=\//i, session_cookie)
    assert_match(/;\s*httponly(?:;|\s|$)/i, session_cookie)
    assert_match(/;\s*samesite=lax(?:;|\s|$)/i, session_cookie)
    assert_no_match(/;\s*domain=/i, session_cookie)
    assert_equal JitSessionCookieConfig.force_secure?, session_cookie.match?(/;\s*secure(?:;|\s|$)/i)

    # Provider denial avoids token exchange while exercising OmniAuth's real callback state check.
    get callback_uri.path, params: { state: oauth_state, error: "access_denied" }, headers: {
      "Host" => @host,
      "Sec-Fetch-Site" => "cross-site",
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
    }

    assert_response :redirect
    failure_uri = URI.parse(response.location)

    assert_equal "/social/failure", failure_uri.path
    assert_equal "access_denied", Rack::Utils.parse_query(failure_uri.query).fetch("message")
    assert_equal "google", Rack::Utils.parse_query(failure_uri.query).fetch("strategy")
    assert_equal session_id_after_request_phase, session.id.to_s
    assert_nil session["omniauth.state"]
  end

  test "Google request phase refuses a non-canonical browser Origin before contacting Google" do
    browser = open_session
    browser.host!(@private_auth_host)
    browser.https!

    browser.post(
      "/social/google", params: { authenticity_token: "invalid" }, headers: {
        "Host" => @private_auth_host,
        "Origin" => "https://#{@private_auth_host}",
        "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_equal 403, browser.response.status
    assert_no_match(/accounts\.google\.com/, browser.response.body)
    assert_match(/no-cache|no-store/, browser.response.headers["Cache-Control"])
  end

  private

  def google_button_token
    entry =
      inertia_props.fetch("social_providers").find do |provider|
        provider.fetch("action") == auth_app_social_google_session_path(ri: "jp")
      end
    entry&.fetch("authenticity_token")
  end

  def with_forgery_protection
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
