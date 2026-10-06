# typed: false
# frozen_string_literal: true

require "test_helper"

class BrowserRpAuthenticationProbeController < ApplicationController
  include BrowserRpSafeRequestRefresh
  include BrowserRpUnsafeRequestRefresh

  protect_from_forgery with: :exception

  def show
    return unless authenticate_browser_rp! if params[:required] == "1"

    render plain: current_resource&.public_id.to_s
  end

  def update
    return unless authenticate_browser_rp!

    render plain: "mutated"
  end

  protected

  def browser_rp_client_id = "core-app"

  def browser_rp_resource_type = "client"

  def browser_rp_trusted_origins = [request.base_url]
end

class BrowserRpAuthenticationTest < ActionController::TestCase
  tests BrowserRpAuthenticationProbeController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "/probe" => "browser_rp_authentication_probe#show"
      patch "/probe" => "browser_rp_authentication_probe#update"
    end
    @client = clients(:one)
    @root_token = client_tokens(:one)
    @rp_session = ClientRpSession.create!(
      client_token: @root_token,
      oidc_client_id: "core-app",
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    @refresh_token = @rp_session.issue_refresh_token!
    @request.host = "core.app.localhost"
    @access_token = access_token_for(expires_at: 5.minutes.from_now)
  end

  test "a valid RP access cookie authenticates without reading refresh authority" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    OidcTokenExchangeCoordinator.stub(:call, ->(**) { raise "refresh must not run" }) do
      get :show, params: { required: "1" }
    end

    assert_response :success
    assert_equal @client.public_id, response.body
    assert_equal @root_token.public_id, @controller.current_session_public_id
    assert_equal @rp_session.public_id, @controller.browser_rp_session_public_id
  end

  test "an expired access cookie refreshes independently and replaces both RP cookies" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token_for(expires_at: 1.minute.ago)
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token
    response_access = access_token_for(expires_at: 5.minutes.from_now)
    result = OidcTokenExchangeCoordinator::Result.new(
      success: true,
      token_response: {
        access_token: response_access,
        refresh_token: "replacement-refresh",
        expires_in: 300,
        refresh_token_expires_in: 600,
      },
      error: nil,
      error_description: nil,
      access_expires_at: 5.minutes.from_now,
      refresh_expires_at: 10.minutes.from_now,
    )

    OidcTokenExchangeCoordinator.stub(:call, result) do
      get :show, params: { required: "1" }
    end

    assert_response :success
    assert_equal @client.public_id, response.body
    assert_equal "replacement-refresh", cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    assert_predicate response.headers["Set-Cookie"], :present?
  end

  test "an invalid refresh clears RP cookies and leaves a protected request unauthenticated" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "malformed"
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token
    result = OidcTokenExchangeCoordinator::Result.new(
      success: false,
      token_response: nil,
      error: "invalid_grant",
      error_description: "invalid refresh",
      access_expires_at: nil,
      refresh_expires_at: nil,
    )

    OidcTokenExchangeCoordinator.stub(:call, result) do
      get :show, params: { required: "1" }
    end

    assert_response :unauthorized
    cookie_header = Array(response.headers["Set-Cookie"]).join("\n")

    assert_match(/#{Regexp.escape(OidcRpBrowserCredentialContract::ACCESS_COOKIE)}=/, cookie_header)
    assert_match(/#{Regexp.escape(OidcRpBrowserCredentialContract::REFRESH_COOKIE)}=/, cookie_header)
  end

  test "dependency failure returns 503 and preserves RP cookies" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "expired"
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token
    result = OidcTokenExchangeCoordinator::Result.new(
      success: false,
      token_response: nil,
      error: "server_error",
      error_description: "temporarily unavailable",
      access_expires_at: nil,
      refresh_expires_at: nil,
    )

    OidcTokenExchangeCoordinator.stub(:call, result) do
      get :show, params: { required: "1" }
    end

    assert_response :service_unavailable
    assert_nil response.headers["Set-Cookie"]
  end

  test "unsafe requests reject an untrusted Origin before refresh" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "expired"
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token

    OidcTokenExchangeCoordinator.stub(:call, ->(**) { raise "refresh must not run" }) do
      @request.set_header("HTTP_ORIGIN", "https://attacker.example")
      @request.set_header("HTTP_SEC_FETCH_SITE", "cross-site")
      patch :update
    end

    assert_response :unprocessable_content
    assert_equal 0, @rp_session.reload.refresh_generation
    assert_equal @refresh_token, cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
  end

  private

  def access_token_for(expires_at:)
    client = OidcClientRegistry.find!("core-app")
    AuthenticationTokenService.encode(
      @client,
      host: request.host,
      resource_type: "client",
      session_public_id: @root_token.public_id,
      base_session_public_id: @root_token.public_id,
      oidc_sid: @rp_session.public_id,
      oidc_jti: @rp_session.oidc_jti,
      expires_at: expires_at,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_resource_type("client"),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(@client, resource_type: "client"),
      client_id: client.client_id,
    )
  end
end
