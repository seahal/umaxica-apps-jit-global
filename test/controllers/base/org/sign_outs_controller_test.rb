# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../support/rp_cell_sign_out_helper"
# require "helpers/global_test_support"

class Base::Org::SignOutsControllerTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper
  include RpCellSignOutHelper

  fixtures :operators, :operator_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @staff = operators(:one)
    host! @host
    https!
    # Completion redirects through the jump gateway, which needs signing keys loaded.
    load_jump_rt_env!
  end

  test "edit sign out renders confirmation without mutation" do
    token = OperatorToken.create!(authentication_epoch: 0, staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    token.update!(last_used_at: 10.minutes.ago)
    last_used_at = token.reload.last_used_at

    get edit_base_org_sign_out_url(host: @host, ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_equal "strict-origin", response.headers["Referrer-Policy"]
    assert_equal "base/org/sign_outs/edit", inertia_component
    assert_equal I18n.t("sign.shared.sign_out.confirm_description"), inertia_props.fetch("description")
    assert_includes inertia_props.fetch("form").fetch("action"), base_org_sign_out_path
    assert_equal I18n.t("actions.cancel"), inertia_props.dig("back_link", "label")
    assert_equal base_org_dashboard_path(ri: "jp"), inertia_props.dig("back_link", "href")
    assert_nil inertia_props["home_link"]
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.home_link")
    assert_predicate token.reload, :currently_usable?
    assert_equal last_used_at, token.reload.last_used_at
  end

  test "edit does not rotate a refresh token when the access cookie is absent" do
    token = OperatorToken.create!(authentication_epoch: 0, staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    refresh_plain = token.rotate_refresh_token!
    refresh_digest = token.refresh_token_digest
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = refresh_plain

    get edit_base_org_sign_out_url(host: @host, ri: "jp")

    assert_response :success
    assert_equal refresh_digest, token.reload.refresh_token_digest
    assert_equal refresh_plain, cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
  end

  test "RP logout revokes its local session and redirects to Visa without an ID Token hint" do
    token = OperatorToken.create!(authentication_epoch: 0, staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    authenticate_rp_cell_for_sign_out!(client_id: "base-org-ww", actor: @staff, root_token: token)
    csrf_token = fetch_csrf_token(edit_base_org_sign_out_url(host: @host, ri: "jp"), headers: { "Host" => @host })
    post_rp_cell_sign_out(
      base_org_sign_out_url(host: @host, ri: "jp"), headers: {
        "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf_token,
      },
    )

    assert_rp_cell_sign_out_handoff!(client_id: "base-org-ww", region: "jp")
    assert_predicate token.reload, :currently_usable?
  end

  test "sign out without an RP session refuses authority mutation" do
    post base_org_sign_out_url(host: @host, ri: "jp")

    assert_response :unauthorized
    assert_nil response.location
    get base_org_root_url(host: @host, ri: "jp")

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
  end

  private

  def session_headers(token)
    authenticate_rp_cell_for_sign_out!(client_id: "base-org-ww", actor: @staff, root_token: token)
    { "Host" => @host }
  end
end

# DAMP local helper copy on the test class.
class Base::Org::SignOutsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
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

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG ACME_APP ACME_ORG CORE_APP CORE_ORG BASE_APP BASE_ORG).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def fetch_csrf_token(path, headers: {})
    with_forgery_protection do
      get(path, headers: headers)
      csrf_token = response.body[/<meta name="csrf-token" content="([^"]+)"/, 1] ||
        response.body[/name="authenticity_token" value="([^"]+)"/, 1]

      assert_predicate csrf_token, :present?, "expected a CSRF token in the response"
      csrf_token
    end
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end

# DAMP: authenticated header helpers that attach a real JWT access cookie so the
# Base RP authentication pipeline recognizes the logged-in session instead of
# redirecting to /oauth/authorize. This final reopening overrides any earlier
# helper definitions in this file so every "logged in" request carries a valid
# access token cookie for the correct actor and surface.
class Base::Org::SignOutsControllerTest
  private

  # Derive the issuer id from the test host. Base RP hosts (www.umaxica.app/.org)
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
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end
end
