# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::App::SwitchersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "unauthenticated identity cannot access switcher" do
    get base_app_switcher_url(host: @host), headers: host_headers(@host), as: :json

    assert_response :unauthorized
  end

  test "selector-only identity cannot access switcher" do
    get base_app_switcher_url(host: @host, ri: "jp"), headers: as_user_headers(@user, host: @host)

    assert_redirected_to base_app_selector_path(ri: "jp")
  end

  test "authenticated identity can access switcher show" do
    select_token!
    get base_app_switcher_url(host: @host), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    ), as: :json

    assert_response :success
    assert_equal "ok", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "authenticated identity can access switcher update" do
    select_token!
    candidate = BaseSwitcherAuthority.new(
      surface: :app, principal: @user,
      session: @token,
    ).send(:selectable_candidates).first
    patch base_app_switcher_url(host: @host), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    ), params: candidate.fetch(:public), as: :json

    assert_response :success
    assert_equal "switched", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "switcher update follows html redirect on success" do
    select_token!
    candidate = BaseSwitcherAuthority.new(
      surface: :app, principal: @user,
      session: @token,
    ).send(:selectable_candidates).first

    patch base_app_switcher_url(host: @host, ri: "jp"), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    ), params: candidate.fetch(:public)

    assert_redirected_to base_app_dashboard_path(ri: "jp")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "switcher update renders invalid switch error as json" do
    select_token!
    current_context = current_context_snapshot

    patch base_app_switcher_url(host: @host), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    ), params: invalid_switch_params, as: :json

    assert_response :unprocessable_content
    assert_equal "invalid_switch", response.parsed_body.fetch("status")
    assert_context_unchanged!(current_context)
  end

  test "switcher update renders invalid switch error as html" do
    select_token!
    current_context = current_context_snapshot

    patch base_app_switcher_url(host: @host, ri: "jp"), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    ), params: invalid_switch_params

    assert_response :unprocessable_content
    assert_equal "base/app/switchers/show", inertia_component
    assert_predicate inertia_props.fetch("error"), :present?
    assert_context_unchanged!(current_context)
  end

  test "switcher show renders the inertia page as html" do
    select_token!

    get base_app_switcher_url(host: @host, ri: "jp"), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    )

    assert_response :success
    assert_equal "base/app/switchers/show", inertia_component
    assert_equal "Switcher", inertia_props.fetch("title")
    assert_equal I18n.t("actions.up", locale: :ja), inertia_props.dig("up_link", "label")
    assert_equal base_app_dashboard_path(ri: "jp"), inertia_props.dig("up_link", "href")
  end

  private

  def select_token!
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
  end

  def current_context_snapshot
    @token.reload.slice(
      "selected_account_public_id",
      "selected_collective_public_id",
      "selected_collective_unit_public_id",
      "selected_avatar_public_id",
    )
  end

  def assert_context_unchanged!(current_context)
    @token.reload

    assert_equal current_context["selected_account_public_id"], @token.selected_account_public_id
    assert_equal current_context["selected_collective_public_id"], @token.selected_collective_public_id
    assert_equal current_context["selected_collective_unit_public_id"], @token.selected_collective_unit_public_id
    assert_equal current_context["selected_avatar_public_id"], @token.selected_avatar_public_id
  end

  def invalid_switch_params
    candidate = BaseSwitcherAuthority.new(
      surface: :app, principal: @user,
      session: @token,
    ).send(:selectable_candidates).first

    candidate.fetch(:public).merge(avatar_public_id: "unknown-avatar")
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

# DAMP auth header helpers for this test class.
class Base::App::SwitchersControllerTest
  private
end

# DAMP: authenticated header helpers that attach a real JWT access cookie so the
# Base RP authentication pipeline recognizes the logged-in session instead of
# redirecting to /oauth/authorize. This final reopening overrides any earlier
# helper definitions in this file so every "logged in" request carries a valid
# access token cookie for the correct actor and surface.
class Base::App::SwitchersControllerTest
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
