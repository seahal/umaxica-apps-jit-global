# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthBoosterTest < ActionDispatch::IntegrationTest
  class DummyAuthController < ApplicationController
    include AuthenticationBase

    class ClientAudit
      def self.create!(*args)
      end
    end

    def resource_class
      Client
    end

    def token_class
      ClientToken
    end

    def audit_class
      ClientAudit
    end

    def resource_type
      "client"
    end

    def resource_foreign_key
      :user_id
    end

    def sign_in_url_with_pt(return_to)
      "/login?pt=#{return_to}"
    end

    def sign_app_edge_v0_token_dbsc_path
      "/dummy/dbsc"
    end

    def auth_app_edge_v0_token_dbsc_path
      "/dummy/dbsc"
    end

    def login_action
      user = Client.first
      result = log_in(user, record_login_audit: false, token_kind_id: "BROWSER_WEB", require_totp_check: false)
      render json: result
    end

    def logout_action
      log_out
      render plain: "ok"
    end

    def transparent_refresh_action
      transparent_refresh_access_token
      render plain: current_resource ? "ok" : "fail"
    end

    def check_auth
      authenticate!
      render plain: "ok" if performed? == false
    end

    def reject_logged
      reject_logged_in_session
      render plain: "ok" if performed? == false
    end

    def ensure_not_logged
      ensure_not_logged_in
      render plain: "ok" if performed? == false
    end

    def test_session_helpers
      # store_authentication_session
      store_authentication_session(:test_key, 123)

      # validate_session_expiry
      data1 = { "expires_at" => 1.hour.from_now.to_i }
      data2 = { "expires_at" => 1.hour.ago.to_i }
      valid1 = validate_session_expiry(data1)
      valid2 = validate_session_expiry(data2)

      # clear_authentication_session
      clear_authentication_session(:test_key)

      render json: {
        valid1: valid1,
        valid2: valid2,
        session_cleared: session[:test_key].nil?,
      }
    end

    def test_load_session_record
      session[:user_id] = Client.first&.id
      record1 = load_session_record(:user_id, Client, custom: ->(_u) { true })
      record2 = load_session_record(:user_id, Client, custom: ->(_u) { false })

      render json: {
        record1_present: record1.present?,
        record2_present: record2.present?,
      }
    end

    def test_validate_session_with_expiry
      session[:user_id] = Client.first&.id
      load_authentication_session(:user_id, Client, "/login", "auth.unauthorized") do |u|
        u.present?
      end

      session[:user_id] = 999_999
      load_authentication_session(:user_id, Client, "/login", "auth.unauthorized") do |u|
        u.present?
      end unless performed?

      render plain: "ok" unless performed?
    end
  end

  setup do
    host! "id.com.localhost"
    Rails.application.routes.draw do
      post "test_auth_login" => "auth_booster_test/dummy_auth#login_action"
      post "test_auth_logout" => "auth_booster_test/dummy_auth#logout_action"
      post "test_auth_refresh" => "auth_booster_test/dummy_auth#transparent_refresh_action"
      get "test_auth_check" => "auth_booster_test/dummy_auth#check_auth"
      get "test_auth_reject" => "auth_booster_test/dummy_auth#reject_logged"
      get "test_auth_ensure" => "auth_booster_test/dummy_auth#ensure_not_logged"
      get "test_session_helpers" => "auth_booster_test/dummy_auth#test_session_helpers"
      get "test_load_session_record" => "auth_booster_test/dummy_auth#test_load_session_record"
      get "test_validate_session_with_expiry" => "auth_booster_test/dummy_auth#test_validate_session_with_expiry"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "session helpers" do
    get "/test_session_helpers"

    assert_response :success
    data = response.parsed_body

    assert data["valid1"]
    assert_not data["valid2"]
    assert data["session_cleared"]
  end

  test "load session record" do
    ClientStatus.find_or_create_by!(id: 1)
    Client.create!(id: 1, status_id: 1) unless Client.exists?(1)
    get "/test_load_session_record"

    assert_response :success
    data = response.parsed_body

    assert data["record1_present"]
    assert_not data["record2_present"]
  end

  test "validate session with expiry" do
    ClientStatus.find_or_create_by!(id: 1)
    Client.create!(id: 1, status_id: 1) unless Client.exists?(1)
    get "/test_validate_session_with_expiry"

    assert_response :redirect
    assert_equal I18n.t("auth.unauthorized"), flash[:notice]
  end

  test "login creates session and sets cookies" do
    ClientStatus.find_or_create_by!(id: 1)
    Client.create!(id: 1, status_id: 1) unless Client.exists?(1)
    post "/test_auth_login"

    assert_response :success
    assert response.cookies.key?(AuthenticationCookieName.access)
    assert response.cookies.key?(AuthenticationCookieName.refresh)
  end

  test "logout clears cookies" do
    ClientStatus.find_or_create_by!(id: 1)
    Client.create!(id: 1, status_id: 1) unless Client.exists?(1)
    post "/test_auth_login"
    post "/test_auth_logout"

    assert_response :success
    assert_predicate response.cookies[AuthenticationCookieName.access], :blank?
    assert_predicate response.cookies[AuthenticationCookieName.refresh], :blank?
  end

  test "transparent refresh" do
    ClientStatus.find_or_create_by!(id: 1)
    Client.create!(id: 1, status_id: 1) unless Client.exists?(1)
    post "/test_auth_login"

    # We need to simulate the request with cookies set
    response.cookies[AuthenticationCookieName.access]
    refresh_cookie = response.cookies[AuthenticationCookieName.refresh]
    cookies[AuthenticationCookieName.refresh] = refresh_cookie

    # Intentionally don't set access cookie so it triggers transparent refresh
    post "/test_auth_refresh"

    assert_response :success
    assert_equal "ok", response.body
  end

  test "check auth blocks unauthenticated" do
    get "/test_auth_check"

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal "/login", uri.path
    assert_empty Rack::Utils.parse_nested_query(uri.query)["pt"].to_s
  end

  test "check auth allows authenticated" do
    ClientStatus.find_or_create_by!(id: 1)
    Client.create!(id: 1, status_id: 1) unless Client.exists?(1)
    post "/test_auth_login"

    access_cookie = response.cookies[AuthenticationCookieName.access]
    cookies[AuthenticationCookieName.access] = access_cookie

    get "/test_auth_check"

    assert_response :success
  end

  test "reject logged in session" do
    ClientStatus.find_or_create_by!(id: 1)
    Client.create!(id: 1, status_id: 1) unless Client.exists?(1)
    post "/test_auth_login"

    access_cookie = response.cookies[AuthenticationCookieName.access]
    cookies[AuthenticationCookieName.access] = access_cookie

    get "/test_auth_reject"

    assert_response :unauthorized
    assert_equal I18n.t("errors.messages.already_authenticated"), response.body
  end

  test "ensure not logged in" do
    ClientStatus.find_or_create_by!(id: 1)
    Client.create!(id: 1, status_id: 1) unless Client.exists?(1)
    post "/test_auth_login"

    access_cookie = response.cookies[AuthenticationCookieName.access]
    cookies[AuthenticationCookieName.access] = access_cookie

    get "/test_auth_ensure"

    assert_response :unauthorized
  end
end

# DAMP local route helper aliases for former shared test support.
class AuthBoosterTest
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
