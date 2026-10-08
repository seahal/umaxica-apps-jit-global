# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::App::WelcomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "welcome sequence redirects to the configured after welcome path" do
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)

    get base_app_welcome_url(ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host, session_public_id: @token.public_id)

    assert_redirected_to base_app_dashboard_path(ri: "jp")
  end

  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# The self-RP Welcome page is reachable only after the root sign-in completed. Its one-shot gate
# decides whether the page renders, and "Next" returns to the page the browser was heading to only
# when a path-target token issued by this browser session's own sign-in for this surface says so.
class Base::App::WelcomeReturnTargetControllerTest < ActionController::TestCase
  tests Base::App::WelcomesController

  DASHBOARD = "/dashboard?ri=jp"
  SESSION_NONCE = "welcome-return-target-nonce"

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
    @request.host = @host
    browser_rp_cookie_pairs(
      client_id: "base-app-ww", surface: "app", host: @host, actor: @user, token: @token,
    ).each do |pair|
      name, value = pair.split("=", 2)
      @request.cookies[name] = Rack::Utils.unescape(value)
    end
    @request.session[:app_sign_in_welcome] = {
      "remaining" => 5,
      "issued_at" => Time.current.to_i,
      "expires_at" => 10.minutes.from_now.to_i,
      "sequence_id" => nil,
    }
    @request.session[:authentication_pt_nonce] = SESSION_NONCE
    @request.headers["X-Inertia"] = "true"
    @request.headers["X-Inertia-Version"] = InertiaRails.configuration.version
  end

  test "Next returns to the verified pre-sign-in page" do
    get :show, params: { ri: "jp", pt: path_target("/identity?ri=jp") }

    assert_response :success
    assert_equal "/identity?ri=jp", next_href
  end

  test "Next goes to the Dashboard when no return target was carried" do
    get :show, params: { ri: "jp" }

    assert_response :success
    assert_equal DASHBOARD, next_href
  end

  test "a tampered return target is ignored" do
    token = path_target("/identity?ri=jp")

    get :show, params: { ri: "jp", pt: "#{token[0...-2]}xx" }

    assert_equal DASHBOARD, next_href
  end

  test "a return target issued for another surface is ignored" do
    get :show, params: { ri: "jp", pt: path_target("/identity?ri=jp", surface: "com") }

    assert_equal DASHBOARD, next_href
  end

  test "a return target issued for another flow is ignored" do
    get :show, params: { ri: "jp", pt: path_target("/identity?ri=jp", flow: "step_up") }

    assert_equal DASHBOARD, next_href
  end

  test "a return target bound to another browser session is ignored" do
    get :show, params: { ri: "jp", pt: path_target("/identity?ri=jp", session_nonce: "another-browser") }

    assert_equal DASHBOARD, next_href
  end

  test "a return target is ignored when this browser session carries no nonce" do
    token = path_target("/identity?ri=jp")
    @request.session.delete(:authentication_pt_nonce)

    get :show, params: { ri: "jp", pt: token }

    assert_equal DASHBOARD, next_href
  end

  # MessageVerifier accepts a token strictly before its expiry instant.
  [[-1, "/identity?ri=jp"], [0, DASHBOARD], [1, DASHBOARD]].each do |offset, expected|
    test "a return target #{offset} second(s) from its expiry resolves to #{expected}" do
      freeze_time
      token = path_target("/identity?ri=jp", expires_in: 60.seconds)
      travel 60.seconds + offset.seconds

      get :show, params: { ri: "jp", pt: token }

      assert_equal expected, next_href
    end
  end

  ["/welcome?ri=jp", "/sign?ri=jp", "/sign/out?ri=jp"].each do |destination|
    test "a return target of #{destination} cannot make Next loop" do
      get :show, params: { ri: "jp", pt: path_target(destination) }

      assert_equal DASHBOARD, next_href
    end
  end

  ["https://evil.example/", "//evil.example/x", "/\\evil.example", "", " ", "/a\u0000b"].each do |destination|
    test "a signed return target of #{destination.inspect} is not an internal path" do
      get :show, params: { ri: "jp", pt: path_target(destination) }

      assert_equal DASHBOARD, next_href
    end
  end

  [nil, "", " ", "0", %w(a b), { "k" => "v" }].each do |value|
    test "a return target parameter of #{value.inspect} falls back to the Dashboard" do
      get :show, params: { ri: "jp", pt: value }

      assert_response :success
      assert_equal DASHBOARD, next_href
    end
  end

  test "without the gate the page is skipped and no return target is followed" do
    @request.session.delete(:app_sign_in_welcome)

    get :show, params: { ri: "jp", pt: path_target("/identity?ri=jp") }

    assert_redirected_to "/dashboard?ri=jp"
  end

  test "the gate is spent one use at a time and never extended" do
    get :show, params: { ri: "jp" }

    assert_equal 4, session[:app_sign_in_welcome]["remaining"]
  end

  private

  def next_href
    response.parsed_body.dig("props", "next_link", "href")
  end

  def path_target(destination, surface: "app", flow: "authentication", session_nonce: SESSION_NONCE,
                  expires_in: 5.minutes)
    ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key(AuthenticationRedirects::PATH_TARGET_TOKEN_SALT, 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    ).generate(
      { "flow" => flow, "surface" => surface, "session_nonce" => session_nonce, "pt" => destination },
      purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE, expires_in: expires_in,
    )
  end
end

# DAMP auth header helpers for this test class.
class Base::App::WelcomesControllerTest
  private
end

# DAMP: authenticated header helpers that attach a real JWT access cookie so the
# Base RP authentication pipeline recognizes the logged-in session instead of
# redirecting to /oauth/authorize. This final reopening overrides any earlier
# helper definitions in this file so every "logged in" request carries a valid
# access token cookie for the correct actor and surface.
class Base::App::WelcomesControllerTest
  private

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  # Derive the issuer id from the test host. Base RP hosts (www.umaxica.app/.org/.com)
  # must resolve to surface:BASE_* so the access token issuer matches the surface the
  # controller validates against.
  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service =
      if normalized.include?("acme")
        "ACME"
      elsif normalized.include?("core")
        "CORE"
      elsif normalized.include?("auth") || normalized.include?("sign") || normalized.include?("log.umaxica")
        "AUTH"
      else
        "BASE"
      end
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end
end
