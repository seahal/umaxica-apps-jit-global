# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseOauthFreshnessE3Test < ActionDispatch::IntegrationTest
  include OidcAuthorizationResponseHelper

  setup { Rails.configuration.x.rate_limit.fetch(:store).clear }

  test "anonymous prompt=none returns login_required to the RP without starting a ceremony" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    get base_app_oauth_authorization_url(host: host, **authorize_params.merge(prompt: "none")),
        headers: { "Host" => host }

    assert_oidc_error_redirect(
      error: "login_required",
      redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
    )
  end

  test "prompt=login with an existing session starts a fresh ceremony" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)

    http_headers_1 =
      begin
        rp_headers = as_user_headers(user, host: host)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "app"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpAppGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpAppGrant.create!(
              authentication_epoch: 0,
              client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "client",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "client",
                                     ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    get base_app_oauth_authorization_url(host: host, **authorize_params.merge(prompt: "login")),
        headers: http_headers_1

    assert_response :success
    form = response.parsed_body.at_css("form#base-authorization-ceremony-start-form")

    assert_not_nil form
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    assert_difference("ClientOidcAuthorizationTransaction.count", 1) do
      post form["action"], params: fields, headers: http_headers_1.merge("Origin" => "http://#{host}")
    end
    assert_response :see_other
    assert_predicate response.location, :present?
  end

  test "stale max_age with an existing session starts a fresh ceremony" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: user, authentication_event_at: 1.hour.ago)

    http_headers_0 =
      begin
        rp_headers = as_user_headers(user, host: host, session_public_id: token.public_id)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "app"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpAppGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpAppGrant.create!(
              authentication_epoch: 0,
              client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "client",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "client",
                                     ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    get base_app_oauth_authorization_url(host: host, **authorize_params.merge(max_age: "60")),
        headers: http_headers_0

    assert_response :success
    form = response.parsed_body.at_css("form#base-authorization-ceremony-start-form")

    assert_not_nil form
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    assert_difference("ClientOidcAuthorizationTransaction.count", 1) do
      post form["action"], params: fields, headers: http_headers_0.merge("Origin" => "http://#{host}")
    end
    assert_response :see_other
    assert_predicate response.location, :present?
  end

  test "com anonymous prompt=none returns login_required" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    client = OidcClientRegistry.find!("core-com-jp")

    get base_com_oauth_authorization_url(
      host: host,
      response_type: "code",
      client_id: "core-com-jp",
      redirect_uri: client.redirect_uris_by_realm.fetch("visitor").first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
      prompt: "none",
    ), headers: { "Host" => host }

    assert_oidc_error_redirect(
      error: "login_required",
      redirect_uri: client.redirect_uris_by_realm.fetch("visitor").first,
    )
  end

  test "org anonymous prompt=none returns login_required" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    client = OidcClientRegistry.find!("core-org-jp")

    get base_org_oauth_authorization_url(
      host: host,
      response_type: "code",
      client_id: "core-org-jp",
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
      prompt: "none",
    ), headers: { "Host" => host }

    assert_oidc_error_redirect(
      error: "login_required",
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
    )
  end

  test "unsupported prompt is rejected as an invalid request" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    get base_app_oauth_authorization_url(host: host, **authorize_params.merge(prompt: "consent")),
        headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  private

  def authorize_params
    client = OidcClientRegistry.find!("core-app-jp")
    @client_callback_host = URI.parse(client.redirect_uris.first).host
    {
      response_type: "code",
      client_id: "core-app-jp",
      redirect_uri: client.redirect_uris.first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
  end
end
