# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  test "renders the control-plane root for a regional request" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    get base_org_root_url(ri: "jp")

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
    assert_equal "Base Org", inertia_props.fetch("heading")
  end

  test "renders the control-plane root for the us region" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    get base_org_root_url(ri: "us")

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
  end

  test "keeps extra request context on the control-plane root instead of leaving the host" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    get base_org_root_url(ri: "jp", ct: "dr", lx: "en", tz: "asia/tokyo")

    assert_response :success
    assert_nil response.location
  end

  test "renders Home for an unknown region without redirect" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    get base_org_root_url(ri: "xx")

    assert_response :success
    assert_nil response.location
    assert_equal "base/org/roots/index", inertia_component
  end

  test "renders Home for a missing region without redirect" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    get "/"

    assert_response :success
    assert_nil response.location
    assert_equal "base/org/roots/index", inertia_component
  end

  test "renders the control-plane root when extra preference params are supplied" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    get base_org_root_url(ct: "dr", lx: "en", ri: "us", tz: "asia/tokyo")

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
  end

  test "authenticated Home returns 404 without redirect" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    staff = operators(:one)

    get base_org_root_url(ri: "jp"),
        headers: as_staff_headers(staff, host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"))

    assert_not_equal 301, response.status
    assert_not_equal "https://jp.umaxica.org/", response.location
    assert_response :not_found
    assert_nil response.location
  end
  test "authenticated Home answers 404 as a rendered response, not a raised exception" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    host! host
    controller_exception =
      capture_controller_exception do
        get(base_org_root_url(ri: "jp"), headers: as_staff_headers(operators(:one), host: host))
      end

    assert_response :not_found
    assert_nil controller_exception
    assert_nil response.location
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  # The anonymous Dashboard contract supersedes the former rendered 404.
  test "anonymous Dashboard redirects to the passive same-surface Sign entry" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    get base_org_dashboard_url(ri: "jp")

    assert_response :redirect
    assert_equal "/sign", URI.parse(response.location).path
    assert_equal "no-store", response.headers["Cache-Control"]
  end
  private

  # The controller's own instrumentation reports an exception that escaped the action; the 404
  # boundary is ordinary control flow and must not depend on the exceptions app.
  def capture_controller_exception(&)
    captured = nil
    callback = ->(*, payload) { captured = payload[:exception] if payload.key?(:exception) }
    ActiveSupport::Notifications.subscribed(callback, "process_action.action_controller", &)
    captured
  end

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

# DAMP auth header helpers for this test class.
class Base::Org::RootsControllerTest
  private
end

# DAMP: authenticated header helpers that attach a real JWT access cookie so the
# Base RP authentication pipeline recognizes the logged-in session instead of
# redirecting to /oauth/authorize. This final reopening overrides any earlier
# helper definitions in this file so every "logged in" request carries a valid
# access token cookie for the correct actor and surface.
class Base::Org::RootsControllerTest
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
