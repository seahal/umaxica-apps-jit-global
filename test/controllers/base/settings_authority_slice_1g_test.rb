# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseSettingsAuthoritySlice1GTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :client_statuses, :client_token_kinds, :client_token_statuses,
           :client_chronicle_events, :client_chronicle_levels

  test "base app settings shell route is removed" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")}/settings",
        method: :get,
      )
    end
  end

  test "base app activities list only current user entries" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    user = clients(:one)
    other_user = clients(:two)
    ChronicleRecord.connected_to(role: :writing) { ClientChronicle.delete_all }
    create_user_audit(user: user, tag: "my-login-event")
    create_user_audit(user: user, tag: "own-failed-event", event_id: ClientChronicleEvent::LOGIN_FAILED)
    create_user_audit(user: user, tag: "refresh-internal", event_id: ClientChronicleEvent::TOKEN_REFRESHED)
    create_user_audit(user: other_user, tag: "other-login-event")

    token = create_user_token!(user)
    select_token!(surface: :app, principal: user, token: token)

    get base_app_identity_activities_url(ri: "jp", host: host), headers: app_session_headers(host, token, user)

    assert_response :success
    rows = inertia_props.fetch("activities")
    assert_equal 2, rows.size
    assert_equal ["サインインに失敗", "サインイン"], rows.map { |row| row.fetch("activity") }
    assert_equal ["中", "低"], rows.map { |row| row.fetch("risk") }
    assert_equal %w(occurred_at activity device source risk risk_rank), rows.first.keys
    assert_not_includes response.body, "my-login-event"
    assert_not_includes response.body, "own-failed-event"
    assert_not_includes response.body, "refresh-internal"
    assert_not_includes response.body, "other-login-event"
  end

  test "base com and org settings shell routes are removed" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")}/settings",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")}/settings",
        method: :get,
      )
    end
  end

  test "base com identity owns non-ceremony identity settings" do
    helper_names = Rails.application.routes.named_routes.helper_names.map(&:to_s)

    %w(
      base_com_identity_email
      base_com_identity_telephone
      base_com_identity_birthdate
      base_com_identity_secret
      base_com_identity_session
      base_com_identity_activit
      base_com_identity_withdrawal
    ).each do |prefix|
      assert helper_names.any? { |name| name.start_with?(prefix) }, "#{prefix} must exist"
    end

    assert_includes helper_names, "new_base_com_identity_withdrawal_path"
    assert_includes helper_names, "edit_base_com_identity_withdrawal_path"
  end

  test "base org identity owns non-ceremony identity settings" do
    helper_names = Rails.application.routes.named_routes.helper_names.map(&:to_s)

    %w(
      base_org_identity_email
      base_org_identity_telephone
      base_org_identity_birthdate
      base_org_identity_secret
      base_org_identity_session
      base_org_identity_activit
      base_org_identity_withdrawal
    ).each do |prefix|
      assert helper_names.any? { |name| name.start_with?(prefix) }, "#{prefix} must exist"
    end
  end

  test "base com withdrawal has the same self service route shape as app" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")

    assert_equal(
      { controller: "base/com/identity/withdrawals", action: "new" },
      Rails.application.routes.recognize_path("http://#{host}/identity/withdrawal/new", method: :get),
    )
    assert_equal(
      { controller: "base/com/identity/withdrawals", action: "edit" },
      Rails.application.routes.recognize_path("http://#{host}/identity/withdrawal/edit", method: :get),
    )
    assert_equal(
      { controller: "base/com/identity/withdrawals", action: "create" },
      Rails.application.routes.recognize_path("http://#{host}/identity/withdrawal", method: :post),
    )
    assert_equal(
      { controller: "base/com/identity/withdrawals", action: "update" },
      Rails.application.routes.recognize_path("http://#{host}/identity/withdrawal", method: :patch),
    )
    assert_equal(
      { controller: "base/com/identity/withdrawals", action: "destroy" },
      Rails.application.routes.recognize_path("http://#{host}/identity/withdrawal", method: :delete),
    )
  end

  test "base org withdrawal is informational get only" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")

    assert_equal(
      { controller: "base/org/identity/withdrawals", action: "show" },
      Rails.application.routes.recognize_path("http://#{host}/identity/withdrawal", method: :get),
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{host}/identity/withdrawal", method: :patch)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{host}/identity/withdrawal", method: :delete)
    end
  end

  test "base com identity routes load controllers" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
    host! host

    get base_com_identity_emails_url(ri: "jp", host: host)

    assert_not_equal 404, response.status
  end

  test "base org identity routes load controllers" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    host! host

    get base_org_identity_emails_url(ri: "jp", host: host)

    assert_not_equal 404, response.status
  end

  private

  def create_user_token!(user)
    token = ClientToken.new(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    token.send(:skip_session_limit_check=, true)
    token.save!
    token
  end

  def select_token!(surface:, principal:, token:)
    BaseSelectorBootstrapAuthority.call(surface: surface, principal: principal)
    BaseSelectorAuthority.prepare(surface: surface, principal: principal, session: token)
  end

  def app_session_headers(host, token, user)
    bearer_headers(
      jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client"),
      host: host,
    )
  end

  def host_headers(host = nil)
    host.present? ? { "Host" => host } : {}
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_access_token_for(resource, host: nil, session_public_id: nil, resource_type: nil)
    AuthenticationToken.encode(
      resource, host: host, session_public_id: session_public_id, resource_type: resource_type,
                jwt_issuer_id: jwt_issuer_id_for_test_host(host, resource_type),
    )
  end

  # Base shares its production origin with Acme (both `https://www.umaxica.<tld>`), so the
  # issuer namespace cannot be inferred from a host substring like "base". Match against the
  # actual configured Base hosts first; fall back to substring heuristics for surfaces whose
  # hosts are texually distinct (acme/core/sign).
  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    base_hosts = {
      "APP" => ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      "ORG" => ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      "COM" => ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
    }
    return "surface:BASE_#{base_hosts.key(normalized)}" if base_hosts.value?(normalized)

    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "SIGN")
    surface =
      if service == "SIGN"
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

  def create_user_audit(user:, tag:, event_id: ClientChronicleEvent::LOGGED_IN)
    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicle.create!(
        subject_id: user.id,
        subject_type: "Client",
        event_id: event_id,
        context: { tag: tag },
        occurred_at: Time.current,
      )
    end
  end
end

# DAMP local route helper aliases for former shared test support.
class BaseSettingsAuthoritySlice1GTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end
