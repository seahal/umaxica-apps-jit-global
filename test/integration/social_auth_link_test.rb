# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Integration tests for social auth link intent
#
# These tests verify:
# - MANDATORY TEST 3: Linking a provider+uid already linked to another user -> 409
# - Link with duplicate user_id+provider -> 409
# - Successful link creates identity and associates with current user
class SocialAuthLinkTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  SOCIAL_FLOW_ID_SESSION_KEY = :social_auth_flow_id
  fixtures :clients,
           :client_statuses,
           :app_preference_chronicle_levels

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
    @base_host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
    @callback_headers = social_callback_headers(@host)

    # Create test users
    @user_one = clients(:one)
    @user_two = clients(:two)

    # Ensure no pre-existing social identities
    ClientGoogleIdentity.where(user: [@user_one, @user_two]).destroy_all
    ClientAppleIdentity.where(user: [@user_one, @user_two]).destroy_all
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  # ============================================================================
  # MANDATORY TEST 3: Link provider+uid already linked to another user -> 409
  # ============================================================================
  test "link Google identity already linked to another user returns 409 Conflict" do
    existing_uid = "google_owned_by_user_one"

    # First, create identity for user_one
    ClientGoogleIdentity.create!(
      user: @user_one,
      uid: existing_uid,
      provider: "google",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    # Setup mock auth with the same uid
    setup_google_mock_auth(uid: existing_uid)

    grant_session =
      begin
        fx0_provider = "google"
        fx0_user = @user_two
        fx0_ri = "jp"
        fx0_host = @host
        host!(fx0_host) if respond_to?(:host!)

        fx0_user_headers =
          begin
            f0_headers = as_user_headers(fx0_user, host: fx0_host)
            f0_host = f0_headers["Host"]
            f0_route =
              begin
                Rails.application.routes.recognize_path("https://#{f0_host}/") if f0_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f0_family, f0_surface = f0_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f0_family) && f0_surface == "app"
              f0_client_id =
                case f0_family
                when "base" then "base-#{f0_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f0_family}-#{f0_surface}"
                end
              f0_token = ClientToken.find_by!(public_id: f0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f0_client = OidcClientRegistry.find!(f0_client_id)
              f0_key = [f0_client.client_id, f0_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f0_key] && f0_token.currently_usable? &&
                  !(f0_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f0_token.device_session_id,
                    oidc_client_id: f0_client.client_id,
                    revoked_at: nil,
                  ))
                f0_token.rotate_refresh_token! unless f0_token.device_session_record.current_refresh_token_id
                f0_now = Time.current
                f0_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                  refresh_token_expires_at: f0_now + 10.minutes,
                )
                f0_access = AuthenticationTokenService.encode(
                  f0_token.actor_record, host: f0_host, resource_type: "client",
                                         session_public_id: f0_token.public_id,
                                         base_session_public_id: f0_token.public_id,
                                         oidc_sid: f0_session.public_id, oidc_jti: f0_session.oidc_jti,
                                         expires_at: f0_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f0_client), audiences: [f0_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                                         subject: OidcSubject.for(
                                           f0_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f0_client.client_id,
                )
                @base_browser_rp_credentials[f0_key] =
                  [f0_access, f0_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f0_key]
                f0_access, f0_refresh = @base_browser_rp_credentials.fetch(f0_key)
                f0_cookie = [
                  f0_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f0_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f0_refresh)}",
                ].join("; ")
                f0_headers = f0_headers.merge(
                  "Cookie" => f0_cookie,
                  "HTTP_COOKIE" => f0_cookie,
                )
              end
            end
            f0_headers
          end
        fx0_token_public_id = fx0_user_headers.fetch("X-TEST-SESSION-PUBLIC-ID")
        fx0_token = ClientToken.find_by(public_id: fx0_token_public_id)
        fx0_session_public_id = fx0_token&.device_session_record&.public_id.presence || fx0_token_public_id
        mark_token_step_up_satisfied_for_test(
          fx0_token,
          scope: SocialAuth::SOCIAL_LINK_SCOPE,
        ) if fx0_token

        fx0_issuance = IdentitySocialCeremonyGrantIssuer.issue!(
          surface: "app",
          actor_ref: fx0_user.public_id,
          session_ref: fx0_session_public_id,
          operation: "link",
          provider: fx0_provider,
        )

        fx0_normalized_provider = SocialIdentifiable.normalize_provider(fx0_provider)
        fx0_continue_path = public_send(
          :"auth_app_settings_#{fx0_normalized_provider}_path",
          ri: fx0_ri,
          social_ceremony_grant: fx0_issuance.grant,
        )

        fx0_headers = social_callback_headers(fx0_host).merge(fx0_user_headers)
        post(fx0_continue_path, headers: fx0_headers)
        fx0_rails_cookie_key = Rails.application.config.session_options.fetch(:key)
        fx0_rails_cookie = response.cookies.fetch(fx0_rails_cookie_key)
        decoded_session = ActionDispatch::Cookies::CookieJar.build(request, request.cookies)
        decoded_session[fx0_rails_cookie_key] = fx0_rails_cookie

        assert_match(
          /\A[A-Za-z0-9_-]{21}\z/,
          decoded_session.encrypted[fx0_rails_cookie_key].fetch("social_auth_flow_id"),
        )
        fx0_user_headers["Cookie"] = [
          fx0_user_headers.fetch("Cookie"),
          "#{fx0_rails_cookie_key}=#{Rack::Utils.escape(fx0_rails_cookie)}",
        ].join("; ")
        fx0_user_headers["HTTP_COOKIE"] = fx0_user_headers.fetch("Cookie")

        Struct.new(:state, :user_headers, :session_public_id, keyword_init: true).new(
          state: social_auth_state_from_response,
          user_headers: fx0_user_headers,
          session_public_id: fx0_session_public_id,
        )
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: grant_session.state },
        headers: @callback_headers.merge(grant_session.user_headers)
    form = response.parsed_body.at_css("form#social-completion-form")

    assert_not_nil form
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    cookie_key = Rails.application.config.session_options.fetch(:key)
    headers = grant_session.user_headers.merge(
      "Host" => @host, "Origin" => "https://#{@host}",
    )
    headers["Cookie"] = [
      headers.fetch("Cookie").split("; ").reject { |entry| entry.start_with?("#{cookie_key}=") },
      "#{cookie_key}=#{Rack::Utils.escape(response.cookies.fetch(cookie_key))}",
    ].flatten.join("; ")
    headers["HTTP_COOKIE"] = headers.fetch("Cookie")
    post form["action"], params: fields, headers: headers

    assert_response :conflict

    # Identity should still belong to user_one
    identity = ClientGoogleIdentity.find_by(uid: existing_uid)

    assert_equal @user_one.id, identity.user_id, "Identity should still belong to original user"
  end

  test "link Apple identity already linked to another user returns 409 Conflict" do
    existing_uid = "apple_owned_by_user_one"

    ClientAppleIdentity.create!(
      user: @user_one,
      uid: existing_uid,
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    grant_session =
      begin
        fx1_provider = "apple"
        fx1_user = @user_two
        fx1_ri = "jp"
        fx1_host = @host
        host!(fx1_host) if respond_to?(:host!)

        fx1_user_headers =
          begin
            f1_headers = as_user_headers(fx1_user, host: fx1_host)
            f1_host = f1_headers["Host"]
            f1_route =
              begin
                Rails.application.routes.recognize_path("https://#{f1_host}/") if f1_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f1_family, f1_surface = f1_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f1_family) && f1_surface == "app"
              f1_client_id =
                case f1_family
                when "base" then "base-#{f1_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f1_family}-#{f1_surface}"
                end
              f1_token = ClientToken.find_by!(public_id: f1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f1_client = OidcClientRegistry.find!(f1_client_id)
              f1_key = [f1_client.client_id, f1_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f1_key] && f1_token.currently_usable? &&
                  !(f1_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f1_token.device_session_id,
                    oidc_client_id: f1_client.client_id,
                    revoked_at: nil,
                  ))
                f1_token.rotate_refresh_token! unless f1_token.device_session_record.current_refresh_token_id
                f1_now = Time.current
                f1_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f1_token, oidc_client_id: f1_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f1_now,
                  refresh_token_expires_at: f1_now + 10.minutes,
                )
                f1_access = AuthenticationTokenService.encode(
                  f1_token.actor_record, host: f1_host, resource_type: "client",
                                         session_public_id: f1_token.public_id,
                                         base_session_public_id: f1_token.public_id,
                                         oidc_sid: f1_session.public_id, oidc_jti: f1_session.oidc_jti,
                                         expires_at: f1_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f1_client), audiences: [f1_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f1_client),
                                         subject: OidcSubject.for(
                                           f1_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f1_client.client_id,
                )
                @base_browser_rp_credentials[f1_key] =
                  [f1_access, f1_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f1_key]
                f1_access, f1_refresh = @base_browser_rp_credentials.fetch(f1_key)
                f1_cookie = [
                  f1_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f1_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f1_refresh)}",
                ].join("; ")
                f1_headers = f1_headers.merge(
                  "Cookie" => f1_cookie,
                  "HTTP_COOKIE" => f1_cookie,
                )
              end
            end
            f1_headers
          end
        fx1_token_public_id = fx1_user_headers.fetch("X-TEST-SESSION-PUBLIC-ID")
        fx1_token = ClientToken.find_by(public_id: fx1_token_public_id)
        fx1_session_public_id = fx1_token&.device_session_record&.public_id.presence || fx1_token_public_id
        mark_token_step_up_satisfied_for_test(
          fx1_token,
          scope: SocialAuth::SOCIAL_LINK_SCOPE,
        ) if fx1_token

        fx1_issuance = IdentitySocialCeremonyGrantIssuer.issue!(
          surface: "app",
          actor_ref: fx1_user.public_id,
          session_ref: fx1_session_public_id,
          operation: "link",
          provider: fx1_provider,
        )

        fx1_normalized_provider = SocialIdentifiable.normalize_provider(fx1_provider)
        fx1_continue_path = public_send(
          :"auth_app_settings_#{fx1_normalized_provider}_path",
          ri: fx1_ri,
          social_ceremony_grant: fx1_issuance.grant,
        )

        fx1_headers = social_callback_headers(fx1_host).merge(fx1_user_headers)
        post(fx1_continue_path, headers: fx1_headers)
        fx1_rails_cookie_key = Rails.application.config.session_options.fetch(:key)
        fx1_rails_cookie = response.cookies.fetch(fx1_rails_cookie_key)
        fx1_user_headers["Cookie"] = [
          fx1_user_headers.fetch("Cookie"),
          "#{fx1_rails_cookie_key}=#{Rack::Utils.escape(fx1_rails_cookie)}",
        ].join("; ")
        fx1_user_headers["HTTP_COOKIE"] = fx1_user_headers.fetch("Cookie")

        Struct.new(:state, :user_headers, :session_public_id, keyword_init: true).new(
          state: social_auth_state_from_response,
          user_headers: fx1_user_headers,
          session_public_id: fx1_session_public_id,
        )
      end
    setup_apple_mock_auth(uid: existing_uid)

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: grant_session.state },
        headers: @callback_headers.merge(grant_session.user_headers)
    form = response.parsed_body.at_css("form#social-completion-form")

    assert_not_nil form
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    cookie_key = Rails.application.config.session_options.fetch(:key)
    headers = grant_session.user_headers.merge(
      "Host" => @host, "Origin" => "https://#{@host}",
    )
    headers["Cookie"] = [
      headers.fetch("Cookie").split("; ").reject { |entry| entry.start_with?("#{cookie_key}=") },
      "#{cookie_key}=#{Rack::Utils.escape(response.cookies.fetch(cookie_key))}",
    ].flatten.join("; ")
    headers["HTTP_COOKIE"] = headers.fetch("Cookie")
    post form["action"], params: fields, headers: headers

    assert_response :conflict

    identity = ClientAppleIdentity.find_by(uid: existing_uid)

    assert_equal @user_one.id, identity.user_id
  end

  test "link Apple fails when flow context is missing" do
    uid = "apple_state_mismatch_#{SecureRandom.hex(4)}"
    # No connection request - nonce: nil is correct; state guard rejects before nonce is checked.
    setup_apple_mock_auth(uid: uid, nonce: nil)

    # Do not call /social/auth/:provider/continue to simulate missing link context
    # Use X-STRICT-SOCIAL-STATE to prevent test-mode state bypass
    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        headers: @callback_headers.merge(
          begin
            rp_headers = as_user_headers(@user_one, host: @host)
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
                                         session_public_id: rp_token.public_id,
                                         base_session_public_id: rp_token.public_id,
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
          end,
        )
          .merge("X-STRICT-SOCIAL-STATE" => "1")

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body

    identity = ClientAppleIdentity.find_by(uid: uid)

    assert_nil identity, "Identity should not be created on state mismatch"
  end

  test "link Google fails when flow context is missing" do
    uid = "google_state_mismatch_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: uid)

    get auth_app_social_google_callback_url(ri: "jp"),
        headers: @callback_headers.merge(
          begin
            rp_headers = as_user_headers(@user_one, host: @host)
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
                                         session_public_id: rp_token.public_id,
                                         base_session_public_id: rp_token.public_id,
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
          end,
        )
          .merge("X-STRICT-SOCIAL-STATE" => "1")

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_nil ClientGoogleIdentity.find_by(uid: uid)
  end

  test "link Apple fails when intent TTL exceeded" do
    uid = "apple_state_expired_#{SecureRandom.hex(4)}"

    http_headers_1 =
      begin
        fx2_user = @user_one
        fx2_headers =
          begin
            f2_headers = as_user_headers(fx2_user, host: @host)
            f2_host = f2_headers["Host"]
            f2_route =
              begin
                Rails.application.routes.recognize_path("https://#{f2_host}/") if f2_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f2_family, f2_surface = f2_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f2_family) && f2_surface == "app"
              f2_client_id =
                case f2_family
                when "base" then "base-#{f2_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f2_family}-#{f2_surface}"
                end
              f2_token = ClientToken.find_by!(public_id: f2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f2_client = OidcClientRegistry.find!(f2_client_id)
              f2_key = [f2_client.client_id, f2_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f2_key] && f2_token.currently_usable? &&
                  !(f2_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f2_token.device_session_id,
                    oidc_client_id: f2_client.client_id,
                    revoked_at: nil,
                  ))
                f2_token.rotate_refresh_token! unless f2_token.device_session_record.current_refresh_token_id
                f2_now = Time.current
                f2_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f2_token, oidc_client_id: f2_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f2_now,
                  refresh_token_expires_at: f2_now + 10.minutes,
                )
                f2_access = AuthenticationTokenService.encode(
                  f2_token.actor_record, host: f2_host, resource_type: "client",
                                         session_public_id: f2_token.public_id,
                                         base_session_public_id: f2_token.public_id,
                                         oidc_sid: f2_session.public_id, oidc_jti: f2_session.oidc_jti,
                                         expires_at: f2_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f2_client), audiences: [f2_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f2_client),
                                         subject: OidcSubject.for(
                                           f2_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f2_client.client_id,
                )
                @base_browser_rp_credentials[f2_key] =
                  [f2_access, f2_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f2_key]
                f2_access, f2_refresh = @base_browser_rp_credentials.fetch(f2_key)
                f2_cookie = [
                  f2_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f2_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f2_refresh)}",
                ].join("; ")
                f2_headers = f2_headers.merge(
                  "Cookie" => f2_cookie,
                  "HTTP_COOKIE" => f2_cookie,
                )
              end
            end
            f2_headers
          end
        fx2_token = ClientToken.find_by!(public_id: fx2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
        mark_token_step_up_satisfied_for_test(fx2_token, scope: SocialAuth::SOCIAL_LINK_SCOPE)
        fx2_headers
      end
    post auth_app_settings_apple_url(ri: "jp"),
         headers: http_headers_1

    assert_response :temporary_redirect
    assert_equal "/social/apple", URI.parse(response.location).path

    # Set up mock after connection POST so session nonce is available.
    setup_apple_mock_auth(uid: uid, nonce: session[:social_auth_nonce])

    travel_to 6.minutes.from_now do
      get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
          params: { state: social_auth_state_from_response },
          headers: @callback_headers.merge(
            begin
              rp_headers = as_user_headers(@user_one, host: @host)
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
                      device_session_id: rp_token.device_session_id,
                      oidc_client_id: rp_client.client_id,
                      revoked_at: nil,
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
                                           session_public_id: rp_token.public_id,
                                           base_session_public_id: rp_token.public_id,
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
            end,
          )
    end

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body

    identity = ClientAppleIdentity.find_by(uid: uid)

    assert_nil identity, "Identity should not be created when intent expired"
  end

  test "Google link callback stages evidence before a receiver-local POST creates one identity" do
    previous_forgery = ActionController::Base.allow_forgery_protection
    new_uid = "grantless_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)
    grant_session =
      begin
        fx3_provider = "google"
        fx3_user = @user_one
        fx3_ri = "jp"
        fx3_host = @host
        host!(fx3_host) if respond_to?(:host!)

        fx3_user_headers =
          begin
            f3_headers = as_user_headers(fx3_user, host: fx3_host)
            f3_host = f3_headers["Host"]
            f3_route =
              begin
                Rails.application.routes.recognize_path("https://#{f3_host}/") if f3_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f3_family, f3_surface = f3_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f3_family) && f3_surface == "app"
              f3_client_id =
                case f3_family
                when "base" then "base-#{f3_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f3_family}-#{f3_surface}"
                end
              f3_token = ClientToken.find_by!(public_id: f3_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f3_client = OidcClientRegistry.find!(f3_client_id)
              f3_key = [f3_client.client_id, f3_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f3_key] && f3_token.currently_usable? &&
                  !(f3_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f3_token.device_session_id,
                    oidc_client_id: f3_client.client_id,
                    revoked_at: nil,
                  ))
                f3_token.rotate_refresh_token! unless f3_token.device_session_record.current_refresh_token_id
                f3_now = Time.current
                f3_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f3_token, oidc_client_id: f3_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f3_now,
                  refresh_token_expires_at: f3_now + 10.minutes,
                )
                f3_access = AuthenticationTokenService.encode(
                  f3_token.actor_record, host: f3_host, resource_type: "client",
                                         session_public_id: f3_token.public_id,
                                         base_session_public_id: f3_token.public_id,
                                         oidc_sid: f3_session.public_id, oidc_jti: f3_session.oidc_jti,
                                         expires_at: f3_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f3_client), audiences: [f3_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f3_client),
                                         subject: OidcSubject.for(
                                           f3_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f3_client.client_id,
                )
                @base_browser_rp_credentials[f3_key] =
                  [f3_access, f3_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f3_key]
                f3_access, f3_refresh = @base_browser_rp_credentials.fetch(f3_key)
                f3_cookie = [
                  f3_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f3_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f3_refresh)}",
                ].join("; ")
                f3_headers = f3_headers.merge(
                  "Cookie" => f3_cookie,
                  "HTTP_COOKIE" => f3_cookie,
                )
              end
            end
            f3_headers
          end
        fx3_token_public_id = fx3_user_headers.fetch("X-TEST-SESSION-PUBLIC-ID")
        fx3_token = ClientToken.find_by(public_id: fx3_token_public_id)
        fx3_session_public_id = fx3_token&.device_session_record&.public_id.presence || fx3_token_public_id
        mark_token_step_up_satisfied_for_test(
          fx3_token,
          scope: SocialAuth::SOCIAL_LINK_SCOPE,
        ) if fx3_token

        fx3_issuance = IdentitySocialCeremonyGrantIssuer.issue!(
          surface: "app",
          actor_ref: fx3_user.public_id,
          session_ref: fx3_session_public_id,
          operation: "link",
          provider: fx3_provider,
        )

        fx3_normalized_provider = SocialIdentifiable.normalize_provider(fx3_provider)
        fx3_continue_path = public_send(
          :"auth_app_settings_#{fx3_normalized_provider}_path",
          ri: fx3_ri,
          social_ceremony_grant: fx3_issuance.grant,
        )

        fx3_headers = social_callback_headers(fx3_host).merge(fx3_user_headers)
        post(fx3_continue_path, headers: fx3_headers)
        fx3_rails_cookie_key = Rails.application.config.session_options.fetch(:key)
        fx3_rails_cookie = response.cookies.fetch(fx3_rails_cookie_key)
        fx3_user_headers["Cookie"] = [
          fx3_user_headers.fetch("Cookie"),
          "#{fx3_rails_cookie_key}=#{Rack::Utils.escape(fx3_rails_cookie)}",
        ].join("; ")
        fx3_user_headers["HTTP_COOKIE"] = fx3_user_headers.fetch("Cookie")

        Struct.new(:state, :user_headers, :session_public_id, keyword_init: true).new(
          state: social_auth_state_from_response,
          user_headers: fx3_user_headers,
          session_public_id: fx3_session_public_id,
        )
      end

    ActionController::Base.allow_forgery_protection = true
    assert_no_difference("ClientGoogleIdentity.count") do
      get(
        auth_app_social_google_callback_url(ri: "jp", protocol: "https"),
        params: { state: grant_session.state },
        headers: @callback_headers.merge(grant_session.user_headers),
      )
    end

    assert_response :success
    form = response.parsed_body.at_css("form#social-completion-form")

    assert_not_nil form
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    cookie_key = Rails.application.config.session_options.fetch(:key)
    grant_session.user_headers["Cookie"] = [
      grant_session.user_headers.fetch("Cookie").split("; ").reject { |entry| entry.start_with?("#{cookie_key}=") },
      "#{cookie_key}=#{Rack::Utils.escape(response.cookies.fetch(cookie_key))}",
    ].flatten.join("; ")
    grant_session.user_headers["HTTP_COOKIE"] = grant_session.user_headers.fetch("Cookie")
    local_headers = grant_session.user_headers.merge(
      "Host" => @host, "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "",
    )
    assert_no_difference("ClientGoogleIdentity.count") do
      post(form["action"], params: fields.except("authenticity_token"), headers: local_headers)
    end
    assert_response :unprocessable_content
    assert_no_difference("ClientGoogleIdentity.count") do
      post(form["action"], params: fields, headers: local_headers.merge("Origin" => "https://other.example"))
    end
    assert_response :unprocessable_content
    candidate = IdentitySocialCeremonyCandidate.find_by!(ref: fields.fetch("candidate_ref"))

    assert_nil candidate.consumed_at

    foreign_browser = open_session
    foreign_browser.host!(@host)
    foreign_browser.https!
    root_cookie = grant_session.user_headers.fetch("Cookie").split("; ").reject do |entry|
      entry.start_with?("#{cookie_key}=")
    end.join("; ")
    _merged_cookies = foreign_browser.cookies.merge(root_cookie, URI.parse("https://#{@host}/"))
    foreign_browser.get(auth_app_root_path(ri: "jp"))
    foreign_csrf = Nokogiri::HTML(foreign_browser.response.body).at_css('meta[name="csrf-token"]')["content"]
    assert_no_difference("ClientGoogleIdentity.count") do
      foreign_browser.post(
        form["action"], params: fields.merge("authenticity_token" => foreign_csrf),
                        headers: { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "" },
      )
    end
    assert_equal 401, foreign_browser.response.status
    assert_nil candidate.reload.consumed_at

    assert_difference("ClientGoogleIdentity.count", 1) do
      post(
        form["action"], params: fields,
                        headers: grant_session.user_headers.merge(
                          "Host" => @host, "Origin" => "https://#{@host}",
                        ),
      )
    end

    assert_redirected_to auth_app_settings_path(ri: "jp")
    assert_equal @user_one.id, ClientGoogleIdentity.find_by!(uid: new_uid).user_id
    link_token = ClientToken.find_by!(public_id: grant_session.user_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))

    assert_nil link_token.reload.last_step_up_at
    assert_not_includes response.body.to_s, "social-completion-form"
    assert_no_difference("ClientGoogleIdentity.count") do
      post(form["action"], params: fields, headers: local_headers)
    end
    # The first successful link spent this token's operation-scoped Step-Up evidence.
    assert_response :forbidden
    assert_not_nil candidate.reload.consumed_at
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery if defined?(previous_forgery)
  end

  test "guest cannot start Google linking" do
    setup_google_mock_auth(uid: "guest_google_#{SecureRandom.hex(4)}")

    post auth_app_settings_google_url(ri: "jp"),
         headers: host_headers(@host)

    assert_response :redirect
    assert_base_sign_handoff_redirect(response.location, surface: :app)
    assert_nil session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]
  end

  test "Sign-owned Apple link intent creates one social identity" do
    new_uid = "grantless_apple_#{SecureRandom.hex(4)}"
    grant_session =
      begin
        fx4_provider = "apple"
        fx4_user = @user_one
        fx4_ri = "jp"
        fx4_host = @host
        host!(fx4_host) if respond_to?(:host!)

        fx4_user_headers =
          begin
            f4_headers = as_user_headers(fx4_user, host: fx4_host)
            f4_host = f4_headers["Host"]
            f4_route =
              begin
                Rails.application.routes.recognize_path("https://#{f4_host}/") if f4_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f4_family, f4_surface = f4_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f4_family) && f4_surface == "app"
              f4_client_id =
                case f4_family
                when "base" then "base-#{f4_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f4_family}-#{f4_surface}"
                end
              f4_token = ClientToken.find_by!(public_id: f4_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f4_client = OidcClientRegistry.find!(f4_client_id)
              f4_key = [f4_client.client_id, f4_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f4_key] && f4_token.currently_usable? &&
                  !(f4_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f4_token.device_session_id,
                    oidc_client_id: f4_client.client_id,
                    revoked_at: nil,
                  ))
                f4_token.rotate_refresh_token! unless f4_token.device_session_record.current_refresh_token_id
                f4_now = Time.current
                f4_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f4_token, oidc_client_id: f4_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f4_now,
                  refresh_token_expires_at: f4_now + 10.minutes,
                )
                f4_access = AuthenticationTokenService.encode(
                  f4_token.actor_record, host: f4_host, resource_type: "client",
                                         session_public_id: f4_token.public_id,
                                         base_session_public_id: f4_token.public_id,
                                         oidc_sid: f4_session.public_id, oidc_jti: f4_session.oidc_jti,
                                         expires_at: f4_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f4_client), audiences: [f4_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f4_client),
                                         subject: OidcSubject.for(
                                           f4_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f4_client.client_id,
                )
                @base_browser_rp_credentials[f4_key] =
                  [f4_access, f4_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f4_key]
                f4_access, f4_refresh = @base_browser_rp_credentials.fetch(f4_key)
                f4_cookie = [
                  f4_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f4_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f4_refresh)}",
                ].join("; ")
                f4_headers = f4_headers.merge(
                  "Cookie" => f4_cookie,
                  "HTTP_COOKIE" => f4_cookie,
                )
              end
            end
            f4_headers
          end
        fx4_token_public_id = fx4_user_headers.fetch("X-TEST-SESSION-PUBLIC-ID")
        fx4_token = ClientToken.find_by(public_id: fx4_token_public_id)
        fx4_session_public_id = fx4_token&.device_session_record&.public_id.presence || fx4_token_public_id
        mark_token_step_up_satisfied_for_test(
          fx4_token,
          scope: SocialAuth::SOCIAL_LINK_SCOPE,
        ) if fx4_token

        fx4_issuance = IdentitySocialCeremonyGrantIssuer.issue!(
          surface: "app",
          actor_ref: fx4_user.public_id,
          session_ref: fx4_session_public_id,
          operation: "link",
          provider: fx4_provider,
        )

        fx4_normalized_provider = SocialIdentifiable.normalize_provider(fx4_provider)
        fx4_continue_path = public_send(
          :"auth_app_settings_#{fx4_normalized_provider}_path",
          ri: fx4_ri,
          social_ceremony_grant: fx4_issuance.grant,
        )

        fx4_headers = social_callback_headers(fx4_host).merge(fx4_user_headers)
        post(fx4_continue_path, headers: fx4_headers)
        fx4_rails_cookie_key = Rails.application.config.session_options.fetch(:key)
        fx4_rails_cookie = response.cookies.fetch(fx4_rails_cookie_key)
        fx4_user_headers["Cookie"] = [
          fx4_user_headers.fetch("Cookie"),
          "#{fx4_rails_cookie_key}=#{Rack::Utils.escape(fx4_rails_cookie)}",
        ].join("; ")
        fx4_user_headers["HTTP_COOKIE"] = fx4_user_headers.fetch("Cookie")

        Struct.new(:state, :user_headers, :session_public_id, keyword_init: true).new(
          state: social_auth_state_from_response,
          user_headers: fx4_user_headers,
          session_public_id: fx4_session_public_id,
        )
      end

    setup_apple_mock_auth(uid: new_uid)

    assert_difference("ClientAppleIdentity.count", 1) do
      perform_grant_backed_link(provider: "apple", grant_session: grant_session)
    end

    assert_redirected_to auth_app_settings_path(ri: "jp")
    assert_equal @user_one.id, ClientAppleIdentity.find_by!(uid: new_uid).user_id
  end

  test "guest cannot start Apple linking" do
    post auth_app_settings_apple_url(ri: "jp"),
         headers: host_headers(@host)

    assert_response :redirect
    assert_base_sign_handoff_redirect(response.location, surface: :app)
    assert_nil session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]
  end

  # ============================================================================
  # OPTIONAL: Client already has this provider linked (update case)
  # ============================================================================
  test "Sign link when user already has this provider updates existing identity" do
    old_uid = "old_google_uid"

    # Client one already has Google linked
    existing_identity = ClientGoogleIdentity.create!(
      user: @user_one,
      uid: old_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    headers =
      begin
        fx5_user = @user_one
        fx5_headers =
          begin
            f5_headers = as_user_headers(fx5_user, host: @host)
            f5_host = f5_headers["Host"]
            f5_route =
              begin
                Rails.application.routes.recognize_path("https://#{f5_host}/") if f5_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f5_family, f5_surface = f5_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f5_family) && f5_surface == "app"
              f5_client_id =
                case f5_family
                when "base" then "base-#{f5_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f5_family}-#{f5_surface}"
                end
              f5_token = ClientToken.find_by!(public_id: f5_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f5_client = OidcClientRegistry.find!(f5_client_id)
              f5_key = [f5_client.client_id, f5_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f5_key] && f5_token.currently_usable? &&
                  !(f5_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f5_token.device_session_id,
                    oidc_client_id: f5_client.client_id,
                    revoked_at: nil,
                  ))
                f5_token.rotate_refresh_token! unless f5_token.device_session_record.current_refresh_token_id
                f5_now = Time.current
                f5_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f5_token, oidc_client_id: f5_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f5_now,
                  refresh_token_expires_at: f5_now + 10.minutes,
                )
                f5_access = AuthenticationTokenService.encode(
                  f5_token.actor_record, host: f5_host, resource_type: "client",
                                         session_public_id: f5_token.public_id,
                                         base_session_public_id: f5_token.public_id,
                                         oidc_sid: f5_session.public_id, oidc_jti: f5_session.oidc_jti,
                                         expires_at: f5_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f5_client), audiences: [f5_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f5_client),
                                         subject: OidcSubject.for(
                                           f5_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f5_client.client_id,
                )
                @base_browser_rp_credentials[f5_key] =
                  [f5_access, f5_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f5_key]
                f5_access, f5_refresh = @base_browser_rp_credentials.fetch(f5_key)
                f5_cookie = [
                  f5_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f5_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f5_refresh)}",
                ].join("; ")
                f5_headers = f5_headers.merge(
                  "Cookie" => f5_cookie,
                  "HTTP_COOKIE" => f5_cookie,
                )
              end
            end
            f5_headers
          end
        fx5_token = ClientToken.find_by!(public_id: fx5_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
        mark_token_step_up_satisfied_for_test(fx5_token, scope: SocialAuth::SOCIAL_LINK_SCOPE)
        fx5_headers
      end

    post auth_app_settings_google_url(ri: "jp"), headers: headers

    assert_response :unprocessable_content
    existing_identity.reload

    assert_equal @user_one.id, existing_identity.user_id
  end

  test "successful Sign-owned Google link creates identity for current user" do
    new_uid = "brand_new_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    grant_session =
      begin
        fx6_provider = "google"
        fx6_user = @user_one
        fx6_ri = "jp"
        fx6_host = @host
        host!(fx6_host) if respond_to?(:host!)

        fx6_user_headers =
          begin
            f6_headers = as_user_headers(fx6_user, host: fx6_host)
            f6_host = f6_headers["Host"]
            f6_route =
              begin
                Rails.application.routes.recognize_path("https://#{f6_host}/") if f6_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f6_family, f6_surface = f6_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f6_family) && f6_surface == "app"
              f6_client_id =
                case f6_family
                when "base" then "base-#{f6_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f6_family}-#{f6_surface}"
                end
              f6_token = ClientToken.find_by!(public_id: f6_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f6_client = OidcClientRegistry.find!(f6_client_id)
              f6_key = [f6_client.client_id, f6_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f6_key] && f6_token.currently_usable? &&
                  !(f6_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f6_token.device_session_id,
                    oidc_client_id: f6_client.client_id,
                    revoked_at: nil,
                  ))
                f6_token.rotate_refresh_token! unless f6_token.device_session_record.current_refresh_token_id
                f6_now = Time.current
                f6_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f6_token, oidc_client_id: f6_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f6_now,
                  refresh_token_expires_at: f6_now + 10.minutes,
                )
                f6_access = AuthenticationTokenService.encode(
                  f6_token.actor_record, host: f6_host, resource_type: "client",
                                         session_public_id: f6_token.public_id,
                                         base_session_public_id: f6_token.public_id,
                                         oidc_sid: f6_session.public_id, oidc_jti: f6_session.oidc_jti,
                                         expires_at: f6_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f6_client), audiences: [f6_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f6_client),
                                         subject: OidcSubject.for(
                                           f6_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f6_client.client_id,
                )
                @base_browser_rp_credentials[f6_key] =
                  [f6_access, f6_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f6_key]
                f6_access, f6_refresh = @base_browser_rp_credentials.fetch(f6_key)
                f6_cookie = [
                  f6_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f6_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f6_refresh)}",
                ].join("; ")
                f6_headers = f6_headers.merge(
                  "Cookie" => f6_cookie,
                  "HTTP_COOKIE" => f6_cookie,
                )
              end
            end
            f6_headers
          end
        fx6_token_public_id = fx6_user_headers.fetch("X-TEST-SESSION-PUBLIC-ID")
        fx6_token = ClientToken.find_by(public_id: fx6_token_public_id)
        fx6_session_public_id = fx6_token&.device_session_record&.public_id.presence || fx6_token_public_id
        mark_token_step_up_satisfied_for_test(
          fx6_token,
          scope: SocialAuth::SOCIAL_LINK_SCOPE,
        ) if fx6_token

        fx6_issuance = IdentitySocialCeremonyGrantIssuer.issue!(
          surface: "app",
          actor_ref: fx6_user.public_id,
          session_ref: fx6_session_public_id,
          operation: "link",
          provider: fx6_provider,
        )

        fx6_normalized_provider = SocialIdentifiable.normalize_provider(fx6_provider)
        fx6_continue_path = public_send(
          :"auth_app_settings_#{fx6_normalized_provider}_path",
          ri: fx6_ri,
          social_ceremony_grant: fx6_issuance.grant,
        )

        fx6_headers = social_callback_headers(fx6_host).merge(fx6_user_headers)
        post(fx6_continue_path, headers: fx6_headers)
        fx6_rails_cookie_key = Rails.application.config.session_options.fetch(:key)
        fx6_rails_cookie = response.cookies.fetch(fx6_rails_cookie_key)
        fx6_user_headers["Cookie"] = [
          fx6_user_headers.fetch("Cookie"),
          "#{fx6_rails_cookie_key}=#{Rack::Utils.escape(fx6_rails_cookie)}",
        ].join("; ")
        fx6_user_headers["HTTP_COOKIE"] = fx6_user_headers.fetch("Cookie")

        Struct.new(:state, :user_headers, :session_public_id, keyword_init: true).new(
          state: social_auth_state_from_response,
          user_headers: fx6_user_headers,
          session_public_id: fx6_session_public_id,
        )
      end

    assert_difference("ClientGoogleIdentity.count", 1) do
      perform_grant_backed_link(provider: "google", grant_session: grant_session)
    end

    assert_redirected_to auth_app_settings_path(ri: "jp")

    # New identity created on Sign under the current user.
    identity = ClientGoogleIdentity.find_by(uid: new_uid)

    assert_not_nil identity
    assert_equal @user_one.id, identity.user_id, "Identity should belong to current user"
    assert_not_nil identity.last_authenticated_at, "last_authenticated_at should be set"
  end

  test "link intent requires authentication" do
    setup_google_mock_auth(uid: "unauthenticated_test")

    # Start without authentication headers
    post auth_app_settings_google_url(ri: "jp"),
         headers: { "Host" => @host }

    assert_response :redirect
    assert_base_sign_handoff_redirect(response.location, surface: :app)
  end

  test "link intent rejects resource-level step up without token-bound step up" do
    @user_one.update!(last_step_up_at: Time.current)

    http_headers_0 =
      begin
        rp_headers = as_user_headers(@user_one, host: @host)
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
    post auth_app_settings_google_url(ri: "jp"),
         headers: http_headers_0

    assert_response :see_other
    assert_match %r{\Ahttp://#{Regexp.escape(@host)}/verification\?}, response.location
    assert_includes response.location, "scope=social_link"
    assert_nil session[SOCIAL_FLOW_ID_SESSION_KEY]
  end

  test "link intent rejects token-bound step up for a different scope" do
    headers =
      begin
        rp_headers = as_user_headers(@user_one, host: @host)
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
    token = ClientToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")

    post auth_app_settings_google_url(ri: "jp"),
         headers: headers

    assert_response :see_other
    assert_match %r{\Ahttp://#{Regexp.escape(@host)}/verification\?}, response.location
    assert_includes response.location, "scope=social_link"
    assert_nil session[SOCIAL_FLOW_ID_SESSION_KEY]
  end

  # ============================================================================
  # Re-linking REVOKED identity (idempotency test)
  # ============================================================================
  test "re-link REVOKED Google identity reactivates it" do
    revoked_uid = "revoked_google_#{SecureRandom.hex(4)}"

    # Create a REVOKED identity for user_one
    revoked_identity = ClientGoogleIdentity.create!(
      user: @user_one,
      uid: revoked_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:revoked),
    )

    # Setup mock auth with the same uid but updated info
    setup_google_mock_auth(uid: revoked_uid)

    # Re-link through the Sign-owned settings ceremony.
    grant_session =
      begin
        fx7_provider = "google"
        fx7_user = @user_one
        fx7_ri = "jp"
        fx7_host = @host
        host!(fx7_host) if respond_to?(:host!)

        fx7_user_headers =
          begin
            f7_headers = as_user_headers(fx7_user, host: fx7_host)
            f7_host = f7_headers["Host"]
            f7_route =
              begin
                Rails.application.routes.recognize_path("https://#{f7_host}/") if f7_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f7_family, f7_surface = f7_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f7_family) && f7_surface == "app"
              f7_client_id =
                case f7_family
                when "base" then "base-#{f7_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f7_family}-#{f7_surface}"
                end
              f7_token = ClientToken.find_by!(public_id: f7_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f7_client = OidcClientRegistry.find!(f7_client_id)
              f7_key = [f7_client.client_id, f7_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f7_key] && f7_token.currently_usable? &&
                  !(f7_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f7_token.device_session_id,
                    oidc_client_id: f7_client.client_id,
                    revoked_at: nil,
                  ))
                f7_token.rotate_refresh_token! unless f7_token.device_session_record.current_refresh_token_id
                f7_now = Time.current
                f7_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f7_token, oidc_client_id: f7_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f7_now,
                  refresh_token_expires_at: f7_now + 10.minutes,
                )
                f7_access = AuthenticationTokenService.encode(
                  f7_token.actor_record, host: f7_host, resource_type: "client",
                                         session_public_id: f7_token.public_id,
                                         base_session_public_id: f7_token.public_id,
                                         oidc_sid: f7_session.public_id, oidc_jti: f7_session.oidc_jti,
                                         expires_at: f7_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f7_client), audiences: [f7_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f7_client),
                                         subject: OidcSubject.for(
                                           f7_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f7_client.client_id,
                )
                @base_browser_rp_credentials[f7_key] =
                  [f7_access, f7_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f7_key]
                f7_access, f7_refresh = @base_browser_rp_credentials.fetch(f7_key)
                f7_cookie = [
                  f7_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f7_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f7_refresh)}",
                ].join("; ")
                f7_headers = f7_headers.merge(
                  "Cookie" => f7_cookie,
                  "HTTP_COOKIE" => f7_cookie,
                )
              end
            end
            f7_headers
          end
        fx7_token_public_id = fx7_user_headers.fetch("X-TEST-SESSION-PUBLIC-ID")
        fx7_token = ClientToken.find_by(public_id: fx7_token_public_id)
        fx7_session_public_id = fx7_token&.device_session_record&.public_id.presence || fx7_token_public_id
        mark_token_step_up_satisfied_for_test(
          fx7_token,
          scope: SocialAuth::SOCIAL_LINK_SCOPE,
        ) if fx7_token

        fx7_issuance = IdentitySocialCeremonyGrantIssuer.issue!(
          surface: "app",
          actor_ref: fx7_user.public_id,
          session_ref: fx7_session_public_id,
          operation: "link",
          provider: fx7_provider,
        )

        fx7_normalized_provider = SocialIdentifiable.normalize_provider(fx7_provider)
        fx7_continue_path = public_send(
          :"auth_app_settings_#{fx7_normalized_provider}_path",
          ri: fx7_ri,
          social_ceremony_grant: fx7_issuance.grant,
        )

        fx7_headers = social_callback_headers(fx7_host).merge(fx7_user_headers)
        post(fx7_continue_path, headers: fx7_headers)
        fx7_rails_cookie_key = Rails.application.config.session_options.fetch(:key)
        fx7_rails_cookie = response.cookies.fetch(fx7_rails_cookie_key)
        fx7_user_headers["Cookie"] = [
          fx7_user_headers.fetch("Cookie"),
          "#{fx7_rails_cookie_key}=#{Rack::Utils.escape(fx7_rails_cookie)}",
        ].join("; ")
        fx7_user_headers["HTTP_COOKIE"] = fx7_user_headers.fetch("Cookie")

        Struct.new(:state, :user_headers, :session_public_id, keyword_init: true).new(
          state: social_auth_state_from_response,
          user_headers: fx7_user_headers,
          session_public_id: fx7_session_public_id,
        )
      end
    perform_grant_backed_link(provider: "google", grant_session: grant_session)

    assert_redirected_to auth_app_settings_path(ri: "jp")

    # Identity should be reactivated (status changed to ACTIVE)
    revoked_identity.reload

    assert_equal ClientGoogleIdentityStatus::ACTIVE, revoked_identity.status_id,
                 "Identity should be ACTIVE"
  end

  test "re-link REVOKED Apple identity reactivates it" do
    revoked_uid = "revoked_apple_#{SecureRandom.hex(4)}"

    revoked_identity = ClientAppleIdentity.create!(
      user: @user_one,
      uid: revoked_uid,
      provider: "apple",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:revoked),
    )

    grant_session =
      begin
        fx8_provider = "apple"
        fx8_user = @user_one
        fx8_ri = "jp"
        fx8_host = @host
        host!(fx8_host) if respond_to?(:host!)

        fx8_user_headers =
          begin
            f8_headers = as_user_headers(fx8_user, host: fx8_host)
            f8_host = f8_headers["Host"]
            f8_route =
              begin
                Rails.application.routes.recognize_path("https://#{f8_host}/") if f8_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f8_family, f8_surface = f8_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f8_family) && f8_surface == "app"
              f8_client_id =
                case f8_family
                when "base" then "base-#{f8_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f8_family}-#{f8_surface}"
                end
              f8_token = ClientToken.find_by!(public_id: f8_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f8_client = OidcClientRegistry.find!(f8_client_id)
              f8_key = [f8_client.client_id, f8_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f8_key] && f8_token.currently_usable? &&
                  !(f8_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f8_token.device_session_id,
                    oidc_client_id: f8_client.client_id,
                    revoked_at: nil,
                  ))
                f8_token.rotate_refresh_token! unless f8_token.device_session_record.current_refresh_token_id
                f8_now = Time.current
                f8_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f8_token, oidc_client_id: f8_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f8_now,
                  refresh_token_expires_at: f8_now + 10.minutes,
                )
                f8_access = AuthenticationTokenService.encode(
                  f8_token.actor_record, host: f8_host, resource_type: "client",
                                         session_public_id: f8_token.public_id,
                                         base_session_public_id: f8_token.public_id,
                                         oidc_sid: f8_session.public_id, oidc_jti: f8_session.oidc_jti,
                                         expires_at: f8_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f8_client), audiences: [f8_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f8_client),
                                         subject: OidcSubject.for(
                                           f8_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f8_client.client_id,
                )
                @base_browser_rp_credentials[f8_key] =
                  [f8_access, f8_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f8_key]
                f8_access, f8_refresh = @base_browser_rp_credentials.fetch(f8_key)
                f8_cookie = [
                  f8_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f8_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f8_refresh)}",
                ].join("; ")
                f8_headers = f8_headers.merge(
                  "Cookie" => f8_cookie,
                  "HTTP_COOKIE" => f8_cookie,
                )
              end
            end
            f8_headers
          end
        fx8_token_public_id = fx8_user_headers.fetch("X-TEST-SESSION-PUBLIC-ID")
        fx8_token = ClientToken.find_by(public_id: fx8_token_public_id)
        fx8_session_public_id = fx8_token&.device_session_record&.public_id.presence || fx8_token_public_id
        mark_token_step_up_satisfied_for_test(
          fx8_token,
          scope: SocialAuth::SOCIAL_LINK_SCOPE,
        ) if fx8_token

        fx8_issuance = IdentitySocialCeremonyGrantIssuer.issue!(
          surface: "app",
          actor_ref: fx8_user.public_id,
          session_ref: fx8_session_public_id,
          operation: "link",
          provider: fx8_provider,
        )

        fx8_normalized_provider = SocialIdentifiable.normalize_provider(fx8_provider)
        fx8_continue_path = public_send(
          :"auth_app_settings_#{fx8_normalized_provider}_path",
          ri: fx8_ri,
          social_ceremony_grant: fx8_issuance.grant,
        )

        fx8_headers = social_callback_headers(fx8_host).merge(fx8_user_headers)
        post(fx8_continue_path, headers: fx8_headers)
        fx8_rails_cookie_key = Rails.application.config.session_options.fetch(:key)
        fx8_rails_cookie = response.cookies.fetch(fx8_rails_cookie_key)
        fx8_user_headers["Cookie"] = [
          fx8_user_headers.fetch("Cookie"),
          "#{fx8_rails_cookie_key}=#{Rack::Utils.escape(fx8_rails_cookie)}",
        ].join("; ")
        fx8_user_headers["HTTP_COOKIE"] = fx8_user_headers.fetch("Cookie")

        Struct.new(:state, :user_headers, :session_public_id, keyword_init: true).new(
          state: social_auth_state_from_response,
          user_headers: fx8_user_headers,
          session_public_id: fx8_session_public_id,
        )
      end
    setup_apple_mock_auth(uid: revoked_uid)
    perform_grant_backed_link(provider: "apple", grant_session: grant_session)

    assert_redirected_to auth_app_settings_path(ri: "jp")

    revoked_identity.reload

    assert_equal ClientAppleIdentityStatus::ACTIVE, revoked_identity.status_id,
                 "Apple identity should be ACTIVE"
  end

  private

  def perform_grant_backed_link(provider:, grant_session:)
    url =
      (provider == "apple") ? auth_app_social_apple_callback_url(provider: "apple", ri: "jp") :
           auth_app_social_google_callback_url(ri: "jp")
    get(url, params: { state: grant_session.state }, headers: @callback_headers.merge(grant_session.user_headers))
    form = response.parsed_body.at_css("form#social-completion-form")

    assert_not_nil form
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    cookie_key = Rails.application.config.session_options.fetch(:key)
    headers = grant_session.user_headers.merge("Host" => @host, "Origin" => "https://#{@host}")
    headers["Cookie"] = [
      headers.fetch("Cookie").split("; ").reject { |entry| entry.start_with?("#{cookie_key}=") },
      "#{cookie_key}=#{Rack::Utils.escape(response.cookies.fetch(cookie_key))}",
    ].flatten.join("; ")
    headers["HTTP_COOKIE"] = headers.fetch("Cookie")
    post(form["action"], params: fields, headers: headers)
  end

  # IMPORTANT: Social login authenticates by provider+uid ONLY, NOT email
  # We deliberately omit email from mock_auth to test this requirement

  def setup_apple_mock_auth(uid:, nonce: session[:social_auth_nonce])
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: uid,
      info: {},
      credentials: {
        token: "apple_token_#{SecureRandom.hex(8)}",
        refresh_token: "apple_refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
      extra: { id_info: { nonce: nonce } },
    )
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class SocialAuthLinkTest
  private
end

# DAMP local helper copy for former shared test support.
class SocialAuthLinkTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
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

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
    )
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [
        {
          visitor_id: visitor_id,
          address: address,
          address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :com),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_attempts_count: 0,
          public_id: SecureRandom.alphanumeric(21),
          created_at: Time.current,
          updated_at: Time.current,
        },
      ],
    )
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

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def mark_token_step_up_satisfied_for_test(token, scope:)
    actor = token.actor_record
    token.rotate_refresh_token! unless token.device_session_record.current_refresh_token_id
    credential = actor.client_totp_credentials.find_by(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    ) || ClientTotpCredential.create_for_user!(
      user: actor, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: scope, allowed_methods: [:totp],
      phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
      ttl: 15.minutes, purpose: "step_up", audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement,
      return_to: (scope == "settings_email") ? "/identity/emails" : "/settings/google",
      base_browser_nonce: nonce, base_token: token,
    )
    transaction = issuance.transaction
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    digest = AuthAdmissionBinding.browser_digest(surface: "app", entry_ref: issuance.reference, nonce: nonce)
    binding.confirm_base!(base_token: token, browser_digest: digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "step_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    # This fixture exercises Social authorization; TOTP code verification has its own public-boundary tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: transaction.class.database_now, verified_credential_ref: credential.public_id,
    )
    proof = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction, ceremony_session_ref: admitted.id.to_s)
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: actor, token: token, transaction: transaction, requirement: requirement, result_reference: proof.reference,
    )
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
    else "step_up:app"
    end
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def signed_step_up_grant_for(actor:, token:, scope:, return_to:, surface:, methods: %i(email_otp totp passkey),
                               aal: "aal2")
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface.to_s,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope.to_s,
      required_aal: aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 15.minutes.from_now,
    ).grant
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

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def social_callback_headers(host)
    scheme = host.to_s.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence || begin
      uri = URI.parse(response.location.to_s)
      Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
    rescue URI::InvalidURIError
      nil
    end
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local social completion helpers for former shared test support.
class SocialAuthLinkTest
  private

  def submit_social_completion_if_present!
    target = URI.parse(response.location) if response.redirect?
    continuation = target&.path == "/social/authentication/completion"
    if continuation
      host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      host!(host)
      https!
      headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      get(target.request_uri, headers: headers)
      form = response.parsed_body.at_css("form")
      raise StandardError, "social completion continuation form missing" unless form

    else
      return unless response.media_type == "text/html" && response.body.include?("social-completion-form")

      assert_forms_submittable_under_policy
      form = response.parsed_body.at_css("form#social-completion-form")
      raise StandardError, "social completion form missing" unless form

      headers = {
        "Host" => URI.parse(form["action"]).host,
        "Origin" => "https://#{configured_host(:sign_service)}",
        "Sec-Fetch-Site" => "same-site",
      }
    end
    params = form.css("input").filter_map do |input|
      name = input["name"]
      [name, input["value"]] if continuation ? !name.nil? : name.present?
    end.to_h
    post(form["action"], params: params, headers: headers)
    cookies.to_hash.each_key { |key| cookies.delete(key) } unless continuation
  end
end

# DAMP local helper copy on the test class.
class SocialAuthLinkTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

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

  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences
    pub_key_for_stub = ->(_kid, **_options) { self.class::PREFERENCE_JWT_KEY }
    PreferenceJwtConfiguration.stub(:private_key, self.class::PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, self.class::PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, self.class::PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) { yield }
              end
            end
          end
        end
      end
    end
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

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
    )
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
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

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com", token: "google_token")
    OmniAuth.config.mock_auth[:google] =
      OmniAuth::AuthHash.new(
        provider: "google", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: token, refresh_token: "refresh_#{token}", expires_at: 1.hour.from_now.to_i },
      )
  end
end
