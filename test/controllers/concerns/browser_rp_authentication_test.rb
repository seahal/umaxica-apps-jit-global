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
    if (params[:required] == "1") && !authenticate_browser_rp!
      return
    end

    render plain: current_resource&.public_id.to_s
  end

  def update
    return unless authenticate_browser_rp!

    render plain: "mutated"
  end

  protected

  def browser_rp_client_id = "core-app-jp"

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
    @rp_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: @root_token,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    @refresh_token = @rp_session.issue_refresh_token!
    @request.host = "core.app.localhost"
    @access_token =
      begin
        fv5116 = { expires_at: 5.minutes.from_now }
        fv5113 = fv5116.fetch(:expires_at)
        fv5112 = fv5116.fetch(:issuer) { nil }
        fv5111 = fv5116.fetch(:audiences) { nil }
        fv5109 = fv5116.fetch(:client_id) { nil }
        fv5110 = fv5116.fetch(:subject) { nil }
        fv5115 = fv5116.fetch(:base_session_public_id) { nil }
        fv5114 = fv5116.fetch(:oidc_sid) { nil }
        fv5108 = OidcClientRegistry.find!("core-app-jp")
        AuthenticationTokenService.encode(
          @client,
          host: request.host,
          resource_type: "client",
          session_public_id: @root_token.public_id,
          base_session_public_id: fv5115 || @root_token.public_id,
          oidc_sid: fv5114 || @rp_session.public_id,
          oidc_jti: @rp_session.oidc_jti,
          expires_at: fv5113,
          scopes: %w(openid profile),
          issuer: fv5112 || OidcIssuer.for_resource_type("client"),
          audiences: fv5111 || [fv5108.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5108),
          subject: fv5110 || OidcSubject.for(@client, resource_type: "client"),
          client_id: fv5109 || fv5108.client_id,
        )
      end
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
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      begin
        fv5107 = { expires_at: 1.minute.ago }
        fv5104 = fv5107.fetch(:expires_at)
        fv5103 = fv5107.fetch(:issuer) { nil }
        fv5102 = fv5107.fetch(:audiences) { nil }
        fv5100 = fv5107.fetch(:client_id) { nil }
        fv5101 = fv5107.fetch(:subject) { nil }
        fv5106 = fv5107.fetch(:base_session_public_id) { nil }
        fv5105 = fv5107.fetch(:oidc_sid) { nil }
        fv5099 = OidcClientRegistry.find!("core-app-jp")
        AuthenticationTokenService.encode(
          @client,
          host: request.host,
          resource_type: "client",
          session_public_id: @root_token.public_id,
          base_session_public_id: fv5106 || @root_token.public_id,
          oidc_sid: fv5105 || @rp_session.public_id,
          oidc_jti: @rp_session.oidc_jti,
          expires_at: fv5104,
          scopes: %w(openid profile),
          issuer: fv5103 || OidcIssuer.for_resource_type("client"),
          audiences: fv5102 || [fv5099.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5099),
          subject: fv5101 || OidcSubject.for(@client, resource_type: "client"),
          client_id: fv5100 || fv5099.client_id,
        )
      end
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token
    response_access =
      begin
        fv5098 = { expires_at: 5.minutes.from_now }
        fv5095 = fv5098.fetch(:expires_at)
        fv5094 = fv5098.fetch(:issuer) { nil }
        fv5093 = fv5098.fetch(:audiences) { nil }
        fv5091 = fv5098.fetch(:client_id) { nil }
        fv5092 = fv5098.fetch(:subject) { nil }
        fv5097 = fv5098.fetch(:base_session_public_id) { nil }
        fv5096 = fv5098.fetch(:oidc_sid) { nil }
        fv5090 = OidcClientRegistry.find!("core-app-jp")
        AuthenticationTokenService.encode(
          @client,
          host: request.host,
          resource_type: "client",
          session_public_id: @root_token.public_id,
          base_session_public_id: fv5097 || @root_token.public_id,
          oidc_sid: fv5096 || @rp_session.public_id,
          oidc_jti: @rp_session.oidc_jti,
          expires_at: fv5095,
          scopes: %w(openid profile),
          issuer: fv5094 || OidcIssuer.for_resource_type("client"),
          audiences: fv5093 || [fv5090.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5090),
          subject: fv5092 || OidcSubject.for(@client, resource_type: "client"),
          client_id: fv5091 || fv5090.client_id,
        )
      end
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

  test "missing RP credentials log the Browser RP refusal vocabulary and controller metadata" do
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output)
    @request.set_header("HTTP_SEC_FETCH_SITE", "cross-site")

    Rails.stub(:logger, logger) { get :show, params: { required: "1" } }

    assert_response :unauthorized
    events =
      output.string.lines.filter_map do |line|
        next unless line.start_with?("{")

        event = JSON.parse(line)
        event if event["event"] == "auth.session.authentication_required"
      end

    assert_equal 1, events.length
    data = events.fetch(0).fetch("data")

    assert_equal "access_credential_missing", data.fetch("failure_reason")
    assert_equal "BrowserRpAuthenticationProbeController", data.fetch("controller")
    assert_equal "show", data.fetch("action")
    assert_equal [false, false], data.values_at("access_credential_presented", "refresh_credential_presented")
    assert_equal "cross-site", data.fetch("fetch_site")
    assert_in_delta Time.current.to_f, Time.iso8601(data.fetch("occurred_at")).to_f, 5
    assert_equal %w(action access_credential_presented controller failure_reason fetch_site occurred_at
                    refresh_credential_presented).sort, data.keys.sort
  end

  test "invalid RP credentials log presence without either credential value" do
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output)
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "invalid-access-credential-sensitive"
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token
    refusal = OidcTokenExchangeCoordinator::Result.new(
      success: false, token_response: nil, error: "invalid_grant", error_description: "invalid refresh",
      access_expires_at: nil, refresh_expires_at: nil,
    )

    Rails.stub(:logger, logger) do
      OidcTokenExchangeCoordinator.stub(:call, refusal) { get :show, params: { required: "1" } }
    end

    assert_response :unauthorized
    event = output.string.lines.filter_map do |line|
      next unless line.start_with?("{")

      parsed = JSON.parse(line)
      parsed if parsed["event"] == "auth.session.authentication_required"
    end.fetch(0)

    assert_equal "access_credential_invalid", event.fetch("data").fetch("failure_reason")
    assert_equal [true, true],
                 event.fetch("data").values_at("access_credential_presented", "refresh_credential_presented")
    assert_not_includes output.string, "invalid-access-credential-sensitive"
    assert_not_includes output.string, @refresh_token
  end

  test "RP refusal fetch-site metadata preserves known classifications and omits missing empty or unsupported values" do
    [nil, "", "credential-like-fetch-site-value", "same-origin", "same-site", "cross-site", "none"].each do |value|
      output = StringIO.new
      logger = ActiveSupport::Logger.new(output)
      @request.set_header("HTTP_SEC_FETCH_SITE", value)

      Rails.stub(:logger, logger) { get :show, params: { required: "1" } }

      assert_response :unauthorized
      event = output.string.lines.filter_map do |line|
        next unless line.start_with?("{")

        parsed = JSON.parse(line)
        parsed if parsed["event"] == "auth.session.authentication_required"
      end.fetch(0)
      if %w(same-origin same-site cross-site none).include?(value)
        assert_equal value, event.fetch("data").fetch("fetch_site")
      else
        assert_not event.fetch("data").key?("fetch_site")
      end

      assert_not_includes output.string, "credential-like-fetch-site-value"
    end
  end

  {
    "another issuer" => { issuer: "https://issuer.invalid" },
    "another audience" => { audiences: ["https://audience.invalid"] },
    "another client" => { client_id: "warp-app-jp" },
    "another subject" => { subject: "client:another-subject" },
    "another Browser Session" => { base_session_public_id: "another-root-session" },
    "a context different from the root session" => {
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    },
  }.each do |label, overrides|
    test "an access credential for #{label} is refused and detached" do
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
        begin
          fv5089 = { expires_at: 5.minutes.from_now, **overrides }
          fv5086 = fv5089.fetch(:expires_at)
          fv5085 = fv5089.fetch(:issuer) { nil }
          fv5084 = fv5089.fetch(:audiences) { nil }
          fv5082 = fv5089.fetch(:client_id) { nil }
          fv5083 = fv5089.fetch(:subject) { nil }
          fv5088 = fv5089.fetch(:base_session_public_id) { nil }
          fv5087 = fv5089.fetch(:oidc_sid) { nil }
          fv5081 = OidcClientRegistry.find!("core-app-jp")
          AuthenticationTokenService.encode(
            @client,
            host: request.host,
            resource_type: "client",
            session_public_id: @root_token.public_id,
            base_session_public_id: fv5088 || @root_token.public_id,
            oidc_sid: fv5087 || @rp_session.public_id,
            oidc_jti: @rp_session.oidc_jti,
            expires_at: fv5086,
            scopes: %w(openid profile),
            issuer: fv5085 || OidcIssuer.for_resource_type("client"),
            audiences: fv5084 || [fv5081.aud],
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5081),
            subject: fv5083 || OidcSubject.for(@client, resource_type: "client"),
            client_id: fv5082 || fv5081.client_id,
            authentication_context: overrides.fetch(:authentication_context, nil),
          )
        end

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
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
        begin
          fv5080 = { expires_at: expires_at }
          fv5077 = fv5080.fetch(:expires_at)
          fv5076 = fv5080.fetch(:issuer) { nil }
          fv5075 = fv5080.fetch(:audiences) { nil }
          fv5073 = fv5080.fetch(:client_id) { nil }
          fv5074 = fv5080.fetch(:subject) { nil }
          fv5079 = fv5080.fetch(:base_session_public_id) { nil }
          fv5078 = fv5080.fetch(:oidc_sid) { nil }
          fv5072 = OidcClientRegistry.find!("core-app-jp")
          AuthenticationTokenService.encode(
            @client,
            host: request.host,
            resource_type: "client",
            session_public_id: @root_token.public_id,
            base_session_public_id: fv5079 || @root_token.public_id,
            oidc_sid: fv5078 || @rp_session.public_id,
            oidc_jti: @rp_session.oidc_jti,
            expires_at: fv5077,
            scopes: %w(openid profile),
            issuer: fv5076 || OidcIssuer.for_resource_type("client"),
            audiences: fv5075 || [fv5072.aud],
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5072),
            subject: fv5074 || OidcSubject.for(@client, resource_type: "client"),
            client_id: fv5073 || fv5072.client_id,
          )
        end
      travel_to(expires_at + AuthenticationJwtConfiguration.leeway_seconds.seconds + offset.seconds)

      get :show, params: { required: "1" }

      assert_response expected
    end
  end

  # --- Live parent state: a revoked or missing parent ends the credential at once ---------------

  test "an access credential stops authenticating as soon as its RP Session is revoked" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    @rp_session.update_columns(revoked_at: OpAppGrant.database_now)

    get :show, params: { required: "1" }

    assert_response :unauthorized
  end

  test "an access credential stops authenticating as soon as its Browser Session is revoked" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    @root_token.device_session_record.revoke!(reason: "rp-authentication-test")

    get :show, params: { required: "1" }

    assert_response :unauthorized
  end

  test "an access credential whose RP Session row no longer exists does not authenticate" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      begin
        fv5071 = { expires_at: 5.minutes.from_now, oidc_sid: "missing-rp-session" }
        fv5068 = fv5071.fetch(:expires_at)
        fv5067 = fv5071.fetch(:issuer) { nil }
        fv5066 = fv5071.fetch(:audiences) { nil }
        fv5064 = fv5071.fetch(:client_id) { nil }
        fv5065 = fv5071.fetch(:subject) { nil }
        fv5070 = fv5071.fetch(:base_session_public_id) { nil }
        fv5069 = fv5071.fetch(:oidc_sid) { nil }
        fv5063 = OidcClientRegistry.find!("core-app-jp")
        AuthenticationTokenService.encode(
          @client,
          host: request.host,
          resource_type: "client",
          session_public_id: @root_token.public_id,
          base_session_public_id: fv5070 || @root_token.public_id,
          oidc_sid: fv5069 || @rp_session.public_id,
          oidc_jti: @rp_session.oidc_jti,
          expires_at: fv5068,
          scopes: %w(openid profile),
          issuer: fv5067 || OidcIssuer.for_resource_type("client"),
          audiences: fv5066 || [fv5063.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5063),
          subject: fv5065 || OidcSubject.for(@client, resource_type: "client"),
          client_id: fv5064 || fv5063.client_id,
        )
      end

    get :show, params: { required: "1" }

    assert_response :unauthorized
  end

  test "a revoked Browser Session cannot issue a new RP refresh credential" do
    @root_token.device_session_record.revoke!(reason: "rp-authentication-test")

    assert_raises(RpSession::IssuanceRejected) { @rp_session.reload.issue_refresh_token! }
  end

  test "a safe request cannot refresh credentials after its parent Browser Session is revoked" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "expired"
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token
    RpSessionRevoker.call(scope: :browser_session, record: @root_token)
    refresh_digest = @rp_session.reload.refresh_token_digest
    refresh_generation = @rp_session.refresh_generation

    get :show, params: { required: "1" }

    assert_response :unauthorized
    assert_equal refresh_digest, @rp_session.reload.refresh_token_digest
    assert_equal refresh_generation, @rp_session.refresh_generation
  end

  test "an access credential stops authenticating as soon as its root token is revoked" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    @root_token.revoke!

    get :show, params: { required: "1" }

    assert_response :unauthorized
  end

  test "an access credential stops authenticating as soon as its root token is historically restricted" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    @root_token.update!(user_token_status_id: ClientTokenStatus::RESTRICTED)

    get :show, params: { required: "1" }

    assert_response :unauthorized
  end

  test "an access credential stops authenticating once the Browser Session points at another root token" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    replacement = ClientToken.create!(authentication_epoch: 0, user: @client)
    @root_token.device_session_record.update_columns(current_refresh_token_id: replacement.id)

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

    OpAppGrant.stub(:includes, ->(*) { raise ActiveRecord::ConnectionNotEstablished, "injected" }) do
      OidcTokenExchangeCoordinator.stub(:call, ->(**) { raise RuntimeError, "refresh must not run" }) do
        get :show, params: { required: "1" }
      end
    end

    assert_response :service_unavailable
    assert_not_includes response.body, @client.public_id
    assert_nil response.headers["Set-Cookie"]
  end

  # A connection pool that cannot serve the state read is the same dependency failure.
  test "an exhausted connection pool while reading live state answers 503 and keeps the cookies" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token

    OpAppGrant.stub(:includes, ->(*) { raise ActiveRecord::ConnectionTimeoutError, "injected" }) do
      get :show, params: { required: "1" }
    end

    assert_response :service_unavailable
    assert_nil response.headers["Set-Cookie"]
  end

  # Revocation applies to the next request after it commits; the request before it was served.
  test "a request before revocation is served and the request after it is refused" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token

    get :show, params: { required: "1" }

    assert_response :success

    @root_token.device_session_record.revoke!(reason: "rp-authentication-test")
    get :show, params: { required: "1" }

    assert_response :unauthorized
  end

  test "a visitor-realm credential does not authenticate a client-realm controller" do
    visitor = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
    visitor_token = VisitorToken.create!(authentication_epoch: 0, visitor: visitor)
    visitor_token.rotate_refresh_token!
    visitor_client = OidcClientRegistry.find!("core-com-jp")
    op_com_grant = OpComGrant.create!(
      authentication_epoch: 0,
      visitor_token: visitor_token, oidc_client_id: visitor_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_auth_time: 1.minute.ago, refresh_token_expires_at: 10.minutes.from_now,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      visitor,
      host: request.host, resource_type: "visitor", session_public_id: visitor_token.public_id,
      base_session_public_id: visitor_token.public_id, oidc_sid: op_com_grant.public_id,
      oidc_jti: op_com_grant.oidc_jti, expires_at: 5.minutes.from_now, scopes: %w(openid profile),
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
    %w(op_app_grants client_device_sessions clients client_tokens).each do |table|
      assert_equal 1, statements.count { |sql| sql.include?(%("#{table}")) }, table
    end
  end

  # --- Refresh credential values (RP3) -----------------------------------------------------------

  ["", " ", "\t", "a\u0000b", " padded "].each do |value|
    test "a refresh credential of #{value.inspect} is treated as absent and never presented" do
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
        begin
          fv5062 = { expires_at: 1.minute.ago }
          fv5059 = fv5062.fetch(:expires_at)
          fv5058 = fv5062.fetch(:issuer) { nil }
          fv5057 = fv5062.fetch(:audiences) { nil }
          fv5055 = fv5062.fetch(:client_id) { nil }
          fv5056 = fv5062.fetch(:subject) { nil }
          fv5061 = fv5062.fetch(:base_session_public_id) { nil }
          fv5060 = fv5062.fetch(:oidc_sid) { nil }
          fv5054 = OidcClientRegistry.find!("core-app-jp")
          AuthenticationTokenService.encode(
            @client,
            host: request.host,
            resource_type: "client",
            session_public_id: @root_token.public_id,
            base_session_public_id: fv5061 || @root_token.public_id,
            oidc_sid: fv5060 || @rp_session.public_id,
            oidc_jti: @rp_session.oidc_jti,
            expires_at: fv5059,
            scopes: %w(openid profile),
            issuer: fv5058 || OidcIssuer.for_resource_type("client"),
            audiences: fv5057 || [fv5054.aud],
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5054),
            subject: fv5056 || OidcSubject.for(@client, resource_type: "client"),
            client_id: fv5055 || fv5054.client_id,
          )
        end
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = value

      OidcTokenExchangeCoordinator.stub(:call, ->(**) { raise RuntimeError, "refresh must not run" }) do
        get :show, params: { required: "1" }
      end

      assert_response :unauthorized
    end
  end

  ["0", "malformed", "a" * 4000].each do |value|
    test "a refresh credential #{value[0, 12].inspect} of #{value.bytesize} bytes is decided by the authority" do
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
        begin
          fv5053 = { expires_at: 1.minute.ago }
          fv5050 = fv5053.fetch(:expires_at)
          fv5049 = fv5053.fetch(:issuer) { nil }
          fv5048 = fv5053.fetch(:audiences) { nil }
          fv5046 = fv5053.fetch(:client_id) { nil }
          fv5047 = fv5053.fetch(:subject) { nil }
          fv5052 = fv5053.fetch(:base_session_public_id) { nil }
          fv5051 = fv5053.fetch(:oidc_sid) { nil }
          fv5045 = OidcClientRegistry.find!("core-app-jp")
          AuthenticationTokenService.encode(
            @client,
            host: request.host,
            resource_type: "client",
            session_public_id: @root_token.public_id,
            base_session_public_id: fv5052 || @root_token.public_id,
            oidc_sid: fv5051 || @rp_session.public_id,
            oidc_jti: @rp_session.oidc_jti,
            expires_at: fv5050,
            scopes: %w(openid profile),
            issuer: fv5049 || OidcIssuer.for_resource_type("client"),
            audiences: fv5048 || [fv5045.aud],
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5045),
            subject: fv5047 || OidcSubject.for(@client, resource_type: "client"),
            client_id: fv5046 || fv5045.client_id,
          )
        end
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = value
      presented = []
      refusal = OidcTokenExchangeCoordinator::Result.new(
        success: false, token_response: nil, error: "invalid_grant", error_description: "invalid refresh",
        access_expires_at: nil, refresh_expires_at: nil,
      )

      OidcTokenExchangeCoordinator.stub(
        :call, ->(**kwargs) {
                 presented << kwargs.fetch(:refresh_token)
                 refusal
               },
      ) do
        get :show, params: { required: "1" }
      end

      assert_equal [value], presented
      assert_response :unauthorized
    end
  end

  # --- Unsafe requests: provenance and CSRF before refresh, then exactly one mutation (RP4) -----

  test "an unsafe request without a valid CSRF token causes no rotation and no mutation" do
    begin
      previous_forgery_protection = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
        begin
          fv5044 = { expires_at: 1.minute.ago }
          fv5041 = fv5044.fetch(:expires_at)
          fv5040 = fv5044.fetch(:issuer) { nil }
          fv5039 = fv5044.fetch(:audiences) { nil }
          fv5037 = fv5044.fetch(:client_id) { nil }
          fv5038 = fv5044.fetch(:subject) { nil }
          fv5043 = fv5044.fetch(:base_session_public_id) { nil }
          fv5042 = fv5044.fetch(:oidc_sid) { nil }
          fv5036 = OidcClientRegistry.find!("core-app-jp")
          AuthenticationTokenService.encode(
            @client,
            host: request.host,
            resource_type: "client",
            session_public_id: @root_token.public_id,
            base_session_public_id: fv5043 || @root_token.public_id,
            oidc_sid: fv5042 || @rp_session.public_id,
            oidc_jti: @rp_session.oidc_jti,
            expires_at: fv5041,
            scopes: %w(openid profile),
            issuer: fv5040 || OidcIssuer.for_resource_type("client"),
            audiences: fv5039 || [fv5036.aud],
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5036),
            subject: fv5038 || OidcSubject.for(@client, resource_type: "client"),
            client_id: fv5037 || fv5036.client_id,
          )
        end
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token

      OidcTokenExchangeCoordinator.stub(:call, ->(**) { raise RuntimeError, "refresh must not run" }) do
        patch(:update, params: { authenticity_token: "forged" })
      end

      assert_response :unprocessable_content
      assert_not_equal "mutated", response.body
      assert_equal 0, @rp_session.reload.refresh_generation
    ensure
      ActionController::Base.allow_forgery_protection = previous_forgery_protection
    end
  end

  test "an unsafe request with Origin null causes no rotation and no mutation" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      begin
        fv5035 = { expires_at: 1.minute.ago }
        fv5032 = fv5035.fetch(:expires_at)
        fv5031 = fv5035.fetch(:issuer) { nil }
        fv5030 = fv5035.fetch(:audiences) { nil }
        fv5028 = fv5035.fetch(:client_id) { nil }
        fv5029 = fv5035.fetch(:subject) { nil }
        fv5034 = fv5035.fetch(:base_session_public_id) { nil }
        fv5033 = fv5035.fetch(:oidc_sid) { nil }
        fv5027 = OidcClientRegistry.find!("core-app-jp")
        AuthenticationTokenService.encode(
          @client,
          host: request.host,
          resource_type: "client",
          session_public_id: @root_token.public_id,
          base_session_public_id: fv5034 || @root_token.public_id,
          oidc_sid: fv5033 || @rp_session.public_id,
          oidc_jti: @rp_session.oidc_jti,
          expires_at: fv5032,
          scopes: %w(openid profile),
          issuer: fv5031 || OidcIssuer.for_resource_type("client"),
          audiences: fv5030 || [fv5027.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5027),
          subject: fv5029 || OidcSubject.for(@client, resource_type: "client"),
          client_id: fv5028 || fv5027.client_id,
        )
      end
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token

    OidcTokenExchangeCoordinator.stub(:call, ->(**) { raise RuntimeError, "refresh must not run" }) do
      @request.set_header("HTTP_ORIGIN", "null")
      patch :update
    end

    assert_response :unprocessable_content
    assert_not_equal "mutated", response.body
  end

  test "an unsafe request with an expired access credential refreshes once and performs one mutation" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      begin
        fv5026 = { expires_at: 1.minute.ago }
        fv5023 = fv5026.fetch(:expires_at)
        fv5022 = fv5026.fetch(:issuer) { nil }
        fv5021 = fv5026.fetch(:audiences) { nil }
        fv5019 = fv5026.fetch(:client_id) { nil }
        fv5020 = fv5026.fetch(:subject) { nil }
        fv5025 = fv5026.fetch(:base_session_public_id) { nil }
        fv5024 = fv5026.fetch(:oidc_sid) { nil }
        fv5018 = OidcClientRegistry.find!("core-app-jp")
        AuthenticationTokenService.encode(
          @client,
          host: request.host,
          resource_type: "client",
          session_public_id: @root_token.public_id,
          base_session_public_id: fv5025 || @root_token.public_id,
          oidc_sid: fv5024 || @rp_session.public_id,
          oidc_jti: @rp_session.oidc_jti,
          expires_at: fv5023,
          scopes: %w(openid profile),
          issuer: fv5022 || OidcIssuer.for_resource_type("client"),
          audiences: fv5021 || [fv5018.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5018),
          subject: fv5020 || OidcSubject.for(@client, resource_type: "client"),
          client_id: fv5019 || fv5018.client_id,
        )
      end
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @refresh_token
    calls = 0
    success = OidcTokenExchangeCoordinator::Result.new(
      success: true,
      token_response: {
        access_token: begin
          fv5017 = { expires_at: 5.minutes.from_now }
          fv5014 = fv5017.fetch(:expires_at)
          fv5013 = fv5017.fetch(:issuer) { nil }
          fv5012 = fv5017.fetch(:audiences) { nil }
          fv5010 = fv5017.fetch(:client_id) { nil }
          fv5011 = fv5017.fetch(:subject) { nil }
          fv5016 = fv5017.fetch(:base_session_public_id) { nil }
          fv5015 = fv5017.fetch(:oidc_sid) { nil }
          fv5009 = OidcClientRegistry.find!("core-app-jp")
          AuthenticationTokenService.encode(
            @client,
            host: request.host,
            resource_type: "client",
            session_public_id: @root_token.public_id,
            base_session_public_id: fv5016 || @root_token.public_id,
            oidc_sid: fv5015 || @rp_session.public_id,
            oidc_jti: @rp_session.oidc_jti,
            expires_at: fv5014,
            scopes: %w(openid profile),
            issuer: fv5013 || OidcIssuer.for_resource_type("client"),
            audiences: fv5012 || [fv5009.aud],
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5009),
            subject: fv5011 || OidcSubject.for(@client, resource_type: "client"),
            client_id: fv5010 || fv5009.client_id,
          )
        end,
        refresh_token: "replacement-refresh",
        expires_in: 300,
        refresh_token_expires_in: 600,
      },
      error: nil,
      error_description: nil,
      access_expires_at: 5.minutes.from_now,
      refresh_expires_at: 10.minutes.from_now,
    )

    OidcTokenExchangeCoordinator.stub(
      :call, ->(**) {
               calls += 1
               success
             },
    ) do
      @request.set_header("HTTP_SEC_FETCH_SITE", "same-origin")
      patch :update
    end

    assert_response :success
    assert_equal "mutated", response.body
    assert_equal 1, calls
  end

  test "an unsafe request whose refresh is refused performs no mutation" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      begin
        fv5008 = { expires_at: 1.minute.ago }
        fv5005 = fv5008.fetch(:expires_at)
        fv5004 = fv5008.fetch(:issuer) { nil }
        fv5003 = fv5008.fetch(:audiences) { nil }
        fv5001 = fv5008.fetch(:client_id) { nil }
        fv5002 = fv5008.fetch(:subject) { nil }
        fv5007 = fv5008.fetch(:base_session_public_id) { nil }
        fv5006 = fv5008.fetch(:oidc_sid) { nil }
        fv5000 = OidcClientRegistry.find!("core-app-jp")
        AuthenticationTokenService.encode(
          @client,
          host: request.host,
          resource_type: "client",
          session_public_id: @root_token.public_id,
          base_session_public_id: fv5007 || @root_token.public_id,
          oidc_sid: fv5006 || @rp_session.public_id,
          oidc_jti: @rp_session.oidc_jti,
          expires_at: fv5005,
          scopes: %w(openid profile),
          issuer: fv5004 || OidcIssuer.for_resource_type("client"),
          audiences: fv5003 || [fv5000.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5000),
          subject: fv5002 || OidcSubject.for(@client, resource_type: "client"),
          client_id: fv5001 || fv5000.client_id,
        )
      end
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
end

class BrowserRpUnauthenticatedBasePasskeyTest < ActionDispatch::IntegrationTest
  test "Base passkey management without a session reaches the authentication gate in every realm" do
    [
      ["app", new_base_app_identity_passkey_path(ri: "jp", format: :json)],
      ["com", new_base_com_identity_passkey_path(ri: "jp", format: :json)],
      ["org", new_base_org_identity_passkey_path(ri: "jp", format: :json)],
    ].each do |realm, path|
      client = OidcClientRegistry.find!("base-#{realm}-ww")
      browser = open_session
      browser.https!
      browser.host!(URI.parse(client.redirect_uris.first).host)
      output = StringIO.new
      logger = ActiveSupport::Logger.new(output)
      request_id = "unauthenticated-base-passkeys-#{realm}"

      Rails.stub(:logger, logger) do
        browser.get(path, headers: { "Sec-Fetch-Site" => "same-origin", "X-Request-ID" => request_id })
      end

      assert_equal 401, browser.response.status, "#{realm}: #{browser.response.body.first(100)}"
      assert_equal({ "error" => "Unauthorized" }, JSON.parse(browser.response.body))
      event = output.string.lines.filter_map do |line|
        next unless line.start_with?("{")

        parsed = JSON.parse(line)
        parsed if parsed["event"] == "auth.session.authentication_required"
      end.fetch(0)

      assert_equal request_id, event.fetch("data").fetch("request_id")
      assert_equal request_id, browser.response.headers.fetch("X-Request-ID")
    end
  end
end
