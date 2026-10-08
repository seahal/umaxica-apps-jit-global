# typed: false
# frozen_string_literal: true

require "test_helper"

# Wired like a production Browser RP controller: the shared authentication concern, then the two
# refresh orchestrators in the same callback positions.
class BrowserRpAuthenticationProbeController < ApplicationController
  include BrowserRpAuthentication
  include BrowserRpSafeRequestRefresh
  include BrowserRpUnsafeRequestRefresh

  protect_from_forgery with: :exception
  before_action :authenticate_browser_rp_safe_request!
  prepend_before_action :authenticate_browser_rp_unsafe_request!

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
    OidcTokenExchangeCoordinator.stub(:call, ->(**) { raise RuntimeError, "refresh must not run" }) do
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

    OidcTokenExchangeCoordinator.stub(:call, ->(**) { raise RuntimeError, "refresh must not run" }) do
      @request.set_header("HTTP_ORIGIN", "https://attacker.example")
      @request.set_header("HTTP_SEC_FETCH_SITE", "cross-site")
      patch :update
    end

    assert_response :unprocessable_content
    assert_equal 0, @rp_session.reload.refresh_generation
    assert_equal @refresh_token, cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
  end

  # --- Access credential: issuer, audience, client, realm, shape (RP3) ---------------------------

  test "a request without any RP credential is unauthenticated and consults no refresh authority" do
    OidcTokenExchangeCoordinator.stub(:call, ->(**) { raise RuntimeError, "refresh must not run" }) do
      get :show, params: { required: "1" }
    end

    assert_response :unauthorized
    assert_nil response.headers["Set-Cookie"]
  end

  {
    "another issuer" => { issuer: "https://issuer.invalid" },
    "another audience" => { audiences: ["https://audience.invalid"] },
    "another client" => { client_id: "warp-app" },
    "another subject" => { subject: "client:another-subject" },
    "another Browser Session" => { base_session_public_id: "another-root-session" },
  }.each do |label, overrides|
    test "an access credential for #{label} is refused and detached" do
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
        access_token_for(expires_at: 5.minutes.from_now, **overrides)

      get :show, params: { required: "1" }

      assert_response :unauthorized
      assert_empty response.body.scan(@client.public_id)
      assert_match(
        /#{Regexp.escape(OidcRpBrowserCredentialContract::ACCESS_COOKIE)}=;/,
        Array(response.headers["Set-Cookie"]).join("\n"),
      )
    end
  end

  ["malformed", ".", "a.b", "a.b.c.d", "!!!.@@@.###", "0", "a" * 4000].each do |value|
    test "a malformed access credential #{value[0, 12].inspect} of #{value.bytesize} bytes is refused" do
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = value

      get :show, params: { required: "1" }

      assert_response :unauthorized
    end
  end

  test "a root access credential in the RP cookie does not authenticate" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationToken.encode(
      @client, host: @request.host, session_public_id: @root_token.public_id, resource_type: "client",
    )

    get :show, params: { required: "1" }

    assert_response :unauthorized
  end

  test "the root cookie family alone does not authenticate a Browser RP request" do
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
      @client, host: @request.host, session_public_id: @root_token.public_id, resource_type: "client",
    )

    get :show, params: { required: "1" }

    assert_response :unauthorized
  end

  # JWT expiry is checked as `exp <= now - leeway`, so the last accepted instant is one second
  # before `exp + leeway`.
  [[-1, :success], [0, :unauthorized], [1, :unauthorized]].each do |offset, expected|
    test "an access credential #{offset} second(s) from exp plus leeway answers #{expected}" do
      freeze_time
      expires_at = 5.minutes.from_now
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token_for(expires_at: expires_at)
      travel_to(expires_at + AuthenticationJwtConfiguration.leeway_seconds.seconds + offset.seconds)

      get :show, params: { required: "1" }

      assert_response expected
    end
  end

  # --- Live parent state: a revoked or missing parent ends the credential at once ---------------

  test "an access credential stops authenticating as soon as its RP Session is revoked" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    @rp_session.update_columns(revoked_at: ClientRpSession.database_now)

    get :show, params: { required: "1" }

    assert_response :unauthorized
  end

  test "an access credential stops authenticating as soon as its Browser Session is revoked" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    @root_token.device_session.revoke!(reason: "rp-authentication-test")

    get :show, params: { required: "1" }

    assert_response :unauthorized
  end

  test "an access credential whose RP Session row no longer exists does not authenticate" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      access_token_for(expires_at: 5.minutes.from_now, oidc_sid: "missing-rp-session")

    get :show, params: { required: "1" }

    assert_response :unauthorized
  end

  test "a revoked Browser Session cannot issue a new RP refresh credential" do
    @root_token.device_session.revoke!(reason: "rp-authentication-test")

    assert_raises(RpSession::IssuanceRejected) { @rp_session.reload.issue_refresh_token! }
  end

  test "an access credential stops authenticating as soon as its root token is revoked" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    @root_token.revoke!

    get :show, params: { required: "1" }

    assert_response :unauthorized
  end

  test "an access credential stops authenticating once the Browser Session points at another root token" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    replacement = ClientToken.create!(user: @client)
    @root_token.device_session.update_columns(current_refresh_token_id: replacement.id)

    get :show, params: { required: "1" }

    assert_response :unauthorized
  end

  test "a deactivated actor is answered withdrawal_required and keeps the credential" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    @client.update_columns(
      withdrawal_started_at: 2.hours.ago, deactivated_at: 1.hour.ago, purge_eligible_at: 31.days.from_now,
    )

    get :show, params: { required: "1" }, format: :json

    assert_response :forbidden
    assert_equal "withdrawal_required", response.parsed_body.fetch("error_code")
    assert_nil response.headers["Set-Cookie"]
  end

  test "a deactivated actor is not identified on a page that does not require authentication" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    @client.update_columns(
      withdrawal_started_at: 2.hours.ago, deactivated_at: 1.hour.ago, purge_eligible_at: 31.days.from_now,
    )

    get :show

    assert_response :success
    assert_empty response.body
  end

  # No fallback to cryptographic-only verification: when live state cannot be read the request
  # fails closed and the credentials are left for the retry.
  test "a database failure while reading live state answers 503 and keeps the cookies" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token

    ClientRpSession.stub(:find_by, ->(*) { raise ActiveRecord::ConnectionNotEstablished, "injected" }) do
      OidcTokenExchangeCoordinator.stub(:call, ->(**) { raise RuntimeError, "refresh must not run" }) do
        get :show, params: { required: "1" }
      end
    end

    assert_response :service_unavailable
    assert_not_includes response.body, @client.public_id
    assert_nil response.headers["Set-Cookie"]
  end

  test "a visitor-realm credential does not authenticate a client-realm controller" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    visitor_token = VisitorToken.create!(visitor: visitor)
    visitor_token.rotate_refresh_token!
    visitor_client = OidcClientRegistry.find!("core-com")
    visitor_rp_session = VisitorRpSession.create!(
      visitor_token: visitor_token, oidc_client_id: visitor_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_auth_time: 1.minute.ago, refresh_token_expires_at: 10.minutes.from_now,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      visitor,
      host: request.host, resource_type: "visitor", session_public_id: visitor_token.public_id,
      base_session_public_id: visitor_token.public_id, oidc_sid: visitor_rp_session.public_id,
      oidc_jti: visitor_rp_session.oidc_jti, expires_at: 5.minutes.from_now, scopes: %w(openid profile),
      issuer: OidcIssuer.for_resource_type("visitor"), audiences: [visitor_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(visitor_client),
      subject: OidcSubject.for(visitor, resource_type: "visitor"), client_id: visitor_client.client_id,
    )

    get :show, params: { required: "1" }

    assert_response :unauthorized
  end

  # One authenticated request reads each link of the live chain once: RP Session, Browser Session,
  # actor, current root token, and the database clock. More than that is a repeated or N+1 read.
  test "live validation reads the chain once per request" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    statements = []
    subscriber =
      lambda do |_name, _start, _finish, _id, payload|
        statements << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:cached]
      end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      get :show, params: { required: "1" }
    end

    assert_response :success
    assert_equal 5, statements.size, statements.join("\n")
    %w(client_rp_sessions client_device_sessions clients client_tokens).each do |table|
      assert_equal 1, statements.count { |sql| sql.include?(%("#{table}")) }, table
    end
  end

  # --- Refresh credential values (RP3) -----------------------------------------------------------

  ["", " ", "\t", "a\u0000b", " padded "].each do |value|
    test "a refresh credential of #{value.inspect} is treated as absent and never presented" do
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token_for(expires_at: 1.minute.ago)
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = value

      OidcTokenExchangeCoordinator.stub(:call, ->(**) { raise RuntimeError, "refresh must not run" }) do
        get :show, params: { required: "1" }
      end

      assert_response :unauthorized
    end
  end

  ["0", "malformed", "a" * 4000].each do |value|
    test "a refresh credential #{value[0, 12].inspect} of #{value.bytesize} bytes is decided by the authority" do
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token_for(expires_at: 1.minute.ago)
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = value
      presented = []
      refusal = OidcTokenExchangeCoordinator::Result.new(
        success: false, token_response: nil, error: "invalid_grant", error_description: "invalid refresh",
        access_expires_at: nil, refresh_expires_at: nil,
      )

      OidcTokenExchangeCoordinator.stub(:call, ->(**kwargs) { presented << kwargs.fetch(:refresh_token); refusal }) do
        get :show, params: { required: "1" }
      end

      assert_equal [value], presented
      assert_response :unauthorized
    end
  end

  # --- Unsafe requests: provenance and CSRF before refresh, then exactly one mutation (RP4) -----

  test "an unsafe request without a valid CSRF token causes no rotation and no mutation" do
    with_real_forgery_protection do
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token_for(expires_at: 1.minute.ago)
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token

      OidcTokenExchangeCoordinator.stub(:call, ->(**) { raise RuntimeError, "refresh must not run" }) do
        patch :update, params: { authenticity_token: "forged" }
      end

      assert_response :unprocessable_content
      assert_not_equal "mutated", response.body
      assert_equal 0, @rp_session.reload.refresh_generation
    end
  end

  test "an unsafe request with Origin null causes no rotation and no mutation" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token_for(expires_at: 1.minute.ago)
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token

    OidcTokenExchangeCoordinator.stub(:call, ->(**) { raise RuntimeError, "refresh must not run" }) do
      @request.set_header("HTTP_ORIGIN", "null")
      patch :update
    end

    assert_response :unprocessable_content
    assert_not_equal "mutated", response.body
  end

  test "an unsafe request with an expired access credential refreshes once and performs one mutation" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token_for(expires_at: 1.minute.ago)
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token
    calls = 0
    success = OidcTokenExchangeCoordinator::Result.new(
      success: true,
      token_response: {
        access_token: access_token_for(expires_at: 5.minutes.from_now),
        refresh_token: "replacement-refresh",
        expires_in: 300,
        refresh_token_expires_in: 600,
      },
      error: nil, error_description: nil,
      access_expires_at: 5.minutes.from_now, refresh_expires_at: 10.minutes.from_now,
    )

    OidcTokenExchangeCoordinator.stub(:call, ->(**) { calls += 1; success }) do
      @request.set_header("HTTP_SEC_FETCH_SITE", "same-origin")
      patch :update
    end

    assert_response :success
    assert_equal "mutated", response.body
    assert_equal 1, calls
  end

  test "an unsafe request whose refresh is refused performs no mutation" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token_for(expires_at: 1.minute.ago)
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token
    refusal = OidcTokenExchangeCoordinator::Result.new(
      success: false, token_response: nil, error: "invalid_grant", error_description: "invalid refresh",
      access_expires_at: nil, refresh_expires_at: nil,
    )

    OidcTokenExchangeCoordinator.stub(:call, refusal) do
      @request.set_header("HTTP_SEC_FETCH_SITE", "same-origin")
      patch :update
    end

    assert_response :unauthorized
    assert_not_equal "mutated", response.body
  end

  test "an access-valid GET takes no refresh lock and rotates nothing" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token

    OidcTokenExchangeCoordinator.stub(:call, ->(**) { raise RuntimeError, "refresh must not run" }) do
      get :show, params: { required: "1" }
    end

    assert_response :success
    assert_equal 0, @rp_session.reload.refresh_generation
  end

  private

  # CSRF is verified by real Rails forgery protection for this test only (D-113).
  def with_real_forgery_protection
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  def access_token_for(expires_at:, issuer: nil, audiences: nil, client_id: nil, subject: nil,
                       base_session_public_id: nil, oidc_sid: nil)
    client = OidcClientRegistry.find!("core-app")
    AuthenticationTokenService.encode(
      @client,
      host: request.host,
      resource_type: "client",
      session_public_id: @root_token.public_id,
      base_session_public_id: base_session_public_id || @root_token.public_id,
      oidc_sid: oidc_sid || @rp_session.public_id,
      oidc_jti: @rp_session.oidc_jti,
      expires_at: expires_at,
      scopes: %w(openid profile),
      issuer: issuer || OidcIssuer.for_resource_type("client"),
      audiences: audiences || [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: subject || OidcSubject.for(@client, resource_type: "client"),
      client_id: client_id || client.client_id,
    )
  end
end
