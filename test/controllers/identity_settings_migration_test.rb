# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentitySettingsMigrationTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @sign_host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
    @acme_host = ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "sign settings root remains limited to retained credential settings" do
    get sign_app_settings_url(ri: "jp"), headers: sign_headers

    assert_response :redirect
  end

  test "moved sign get routes are unroutable" do
    assert_unroutable_auth_settings_path("/settings/emails", :get)
    assert_unroutable_auth_settings_path("/settings/birthdate", :get)
    assert_unroutable_auth_settings_path("/settings/activities", :get)
  end

  test "moved sign mutation routes are unroutable" do
    assert_unroutable_auth_settings_path("/settings/emails/missing", :patch)
    assert_unroutable_auth_settings_path("/settings/emails/missing", :delete)
    assert_unroutable_auth_settings_path("/settings/mfa/reset", :post)
  end

  test "sign passkey route still exists" do
    get sign_app_settings_passkeys_url(ri: "jp"), headers: sign_headers

    assert_response :ok
  end

  test "acme identity routes exist and authenticate" do
    get acme_app_identity_url(ri: "jp"), headers: acme_headers_with_session

    assert_response :success

    get acme_app_identity_emails_url(ri: "jp"), headers: acme_headers_with_session

    assert_response :success

    get acme_app_identity_sessions_url(ri: "jp"), headers: acme_headers_with_session

    assert_response :success
  end

  test "acme identity does not depend on sign settings path in overview" do
    get acme_app_identity_url(ri: "jp"), headers: acme_headers_with_session

    assert_response :success
    assert_no_match(/\/settings(?!\/passkeys|\/totps|\/google|\/apple)/, response.body)
  end

  private

  def sign_headers
    bearer_headers(
      AuthenticationToken.encode(
        @user, host: @sign_host, session_public_id: @token.public_id, resource_type: "client",
               jwt_issuer_id: "surface:AUTH_APP",
      ),
      host: @sign_host,
    )
  end

  def acme_headers
    bearer_headers(
      AuthenticationToken.encode(
        @user, host: @acme_host, session_public_id: @token.public_id, resource_type: "client",
               jwt_issuer_id: "surface:BASE_APP",
      ),
      host: @acme_host,
    )
  end

  def bearer_headers(token, host: nil, headers: {})
    base = host.present? ? { "Host" => host } : {}
    base.merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def acme_headers_with_session
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
    acme_headers
  end

  def assert_unroutable_auth_settings_path(path, method)
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{@sign_host}#{path}",
        method: method,
      )
    end
  end
end

# DAMP local route helper aliases for former shared test support.
class IdentitySettingsMigrationTest
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
