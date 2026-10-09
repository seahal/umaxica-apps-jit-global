# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"

# Integration tests for social auth unlink functionality
#
# These tests verify:
# - Unlink when only 1 login method returns an error
# - Successful unlink removes identity
# - Unlink requires authentication
class SocialAuthUnlinkTest < ActionDispatch::IntegrationTest
  fixtures :client_email_statuses,
           :client_statuses, :client_totp_credential_statuses

  setup do
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    @host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
    @base_host = ENV.fetch("PRIVATE_BASE_SERVICE_URL")
    @public_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    @user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "unlink_test_#{SecureRandom.hex(4)}",
    )
    ClientEmail.create!(
      user: @user,
      address: "unlink-test-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )
    ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )
    @headers =
      begin
        rp_headers = as_user_headers(@user, host: @host)
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
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && ClientRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
            rp_now = Time.current
            rp_session = ClientRpSession.create!(
              client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.user, host: rp_host, resource_type: "client",
                             session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                             oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                             expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                             issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                             subject: OidcSubject.for(
                               rp_token.user,
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
    @token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "unlink Google requires recent step_up" do
    google_identity = ClientGoogleIdentity.create!(
      user: @user,
      uid: "step_up_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    ClientToken.create!(
      user_id: @user.id,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      created_at: 2.hours.ago,
      updated_at: 2.hours.ago,
    )

    http_headers_11 =
      begin
        fx0_token = ClientToken.where(user_id: @user.id).order(created_at: :asc).last

        begin
          f0_headers = as_user_headers(@user, host: @host, session_public_id: fx0_token.public_id)
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
              when "edit" then "edit-org"
              else "#{f0_family}-#{f0_surface}"
              end
            f0_token = ClientToken.find_by!(public_id: f0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f0_client = OidcClientRegistry.find!(f0_client_id)
            f0_key = [f0_client.client_id, f0_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f0_key] && f0_token.currently_usable? &&
                !(f0_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f0_token.device_session_id,
                  oidc_client_id: f0_client.client_id,
                  revoked_at: nil,
                ))
              f0_token.rotate_refresh_token! unless f0_token.device_session.current_refresh_token_id
              f0_now = Time.current
              f0_session = ClientRpSession.create!(
                client_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                refresh_token_expires_at: f0_now + 10.minutes,
              )
              f0_access = AuthenticationTokenService.encode(
                f0_token.user, host: f0_host, resource_type: "client",
                               session_public_id: f0_token.public_id, base_session_public_id: f0_token.public_id,
                               oidc_sid: f0_session.public_id, oidc_jti: f0_session.oidc_jti,
                               expires_at: f0_now + 10.minutes, scopes: %w(openid profile),
                               issuer: OidcIssuer.for_client(f0_client), audiences: [f0_client.aud],
                               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                               subject: OidcSubject.for(
                                 f0_token.user,
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
      end
    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: http_headers_11

    assert_response :unauthorized
    google_identity.reload

    assert_equal ClientGoogleIdentityStatus::ACTIVE, google_identity.status_id
  end

  test "unlink Apple requires recent step_up" do
    apple_identity = ClientAppleIdentity.create!(
      user: @user,
      uid: "step_up_apple_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    ClientToken.create!(
      user_id: @user.id,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      created_at: 2.hours.ago,
      updated_at: 2.hours.ago,
    )

    http_headers_10 =
      begin
        fx1_token = ClientToken.where(user_id: @user.id).order(created_at: :asc).last

        begin
          f1_headers = as_user_headers(@user, host: @host, session_public_id: fx1_token.public_id)
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
              when "edit" then "edit-org"
              else "#{f1_family}-#{f1_surface}"
              end
            f1_token = ClientToken.find_by!(public_id: f1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f1_client = OidcClientRegistry.find!(f1_client_id)
            f1_key = [f1_client.client_id, f1_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f1_key] && f1_token.currently_usable? &&
                !(f1_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f1_token.device_session_id,
                  oidc_client_id: f1_client.client_id,
                  revoked_at: nil,
                ))
              f1_token.rotate_refresh_token! unless f1_token.device_session.current_refresh_token_id
              f1_now = Time.current
              f1_session = ClientRpSession.create!(
                client_token: f1_token, oidc_client_id: f1_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f1_now,
                refresh_token_expires_at: f1_now + 10.minutes,
              )
              f1_access = AuthenticationTokenService.encode(
                f1_token.user, host: f1_host, resource_type: "client",
                               session_public_id: f1_token.public_id, base_session_public_id: f1_token.public_id,
                               oidc_sid: f1_session.public_id, oidc_jti: f1_session.oidc_jti,
                               expires_at: f1_now + 10.minutes, scopes: %w(openid profile),
                               issuer: OidcIssuer.for_client(f1_client), audiences: [f1_client.aud],
                               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f1_client),
                               subject: OidcSubject.for(
                                 f1_token.user,
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
      end
    delete auth_app_settings_apple_url(ri: "jp", host: @host),
           headers: http_headers_10

    assert_response :unauthorized
    apple_identity.reload

    assert_equal ClientAppleIdentityStatus::ACTIVE, apple_identity.status_id
  end

  # ============================================================================
  # Unlink last login method returns error
  # ============================================================================
  test "unlink last Google identity returns 422 LastIdentityError" do
    # Client has only one identity (Google)
    google_identity = ClientGoogleIdentity.create!(
      user: @user,
      uid: "last_google_identity_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    http_headers_9 =
      begin
        satisfy_user_verification(@token)
        mark_token_step_up_satisfied_for_test(@token, scope: "social_unlink")
        begin
          f2_headers = as_user_headers(@user, host: @host, session_public_id: @token.public_id)
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
              when "edit" then "edit-org"
              else "#{f2_family}-#{f2_surface}"
              end
            f2_token = ClientToken.find_by!(public_id: f2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f2_client = OidcClientRegistry.find!(f2_client_id)
            f2_key = [f2_client.client_id, f2_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f2_key] && f2_token.currently_usable? &&
                !(f2_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f2_token.device_session_id,
                  oidc_client_id: f2_client.client_id,
                  revoked_at: nil,
                ))
              f2_token.rotate_refresh_token! unless f2_token.device_session.current_refresh_token_id
              f2_now = Time.current
              f2_session = ClientRpSession.create!(
                client_token: f2_token, oidc_client_id: f2_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f2_now,
                refresh_token_expires_at: f2_now + 10.minutes,
              )
              f2_access = AuthenticationTokenService.encode(
                f2_token.user, host: f2_host, resource_type: "client",
                               session_public_id: f2_token.public_id, base_session_public_id: f2_token.public_id,
                               oidc_sid: f2_session.public_id, oidc_jti: f2_session.oidc_jti,
                               expires_at: f2_now + 10.minutes, scopes: %w(openid profile),
                               issuer: OidcIssuer.for_client(f2_client), audiences: [f2_client.aud],
                               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f2_client),
                               subject: OidcSubject.for(
                                 f2_token.user,
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
      end
    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: http_headers_9

    assert_response :unprocessable_content

    # Identity should still exist
    assert ClientGoogleIdentity.exists?(id: google_identity.id), "Last identity should NOT be deleted"
  end

  def prepare_step_up_method!
    ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )
    satisfy_user_verification(@token)
  end

  test "unlink last Apple identity returns 422 LastIdentityError" do
    apple_identity = ClientAppleIdentity.create!(
      user: @user,
      uid: "last_apple_identity_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    http_headers_8 =
      begin
        satisfy_user_verification(@token)
        mark_token_step_up_satisfied_for_test(@token, scope: "social_unlink")
        begin
          f3_headers = as_user_headers(@user, host: @host, session_public_id: @token.public_id)
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
              when "edit" then "edit-org"
              else "#{f3_family}-#{f3_surface}"
              end
            f3_token = ClientToken.find_by!(public_id: f3_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f3_client = OidcClientRegistry.find!(f3_client_id)
            f3_key = [f3_client.client_id, f3_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f3_key] && f3_token.currently_usable? &&
                !(f3_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f3_token.device_session_id,
                  oidc_client_id: f3_client.client_id,
                  revoked_at: nil,
                ))
              f3_token.rotate_refresh_token! unless f3_token.device_session.current_refresh_token_id
              f3_now = Time.current
              f3_session = ClientRpSession.create!(
                client_token: f3_token, oidc_client_id: f3_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f3_now,
                refresh_token_expires_at: f3_now + 10.minutes,
              )
              f3_access = AuthenticationTokenService.encode(
                f3_token.user, host: f3_host, resource_type: "client",
                               session_public_id: f3_token.public_id, base_session_public_id: f3_token.public_id,
                               oidc_sid: f3_session.public_id, oidc_jti: f3_session.oidc_jti,
                               expires_at: f3_now + 10.minutes, scopes: %w(openid profile),
                               issuer: OidcIssuer.for_client(f3_client), audiences: [f3_client.aud],
                               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f3_client),
                               subject: OidcSubject.for(
                                 f3_token.user,
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
      end
    delete auth_app_settings_apple_url(ri: "jp", host: @host),
           headers: http_headers_8

    assert_response :unprocessable_content
    assert ClientAppleIdentity.exists?(id: apple_identity.id), "Last identity should NOT be deleted"
  end

  # ============================================================================
  # Success case: Unlink when user has multiple auth methods
  # ============================================================================
  test "unlink Google succeeds when user has another auth method" do
    # D-85 permits only one effective social binding per Client. A verified
    # email is the second allowed method for this unlink operation.
    google_identity = ClientGoogleIdentity.create!(
      user: @user,
      uid: "google_to_unlink_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    begin
      fv5003 = "google-backup-#{SecureRandom.hex(4)}@example.com"
      insert_verified_user_email!(user_id: @user.id, address: fv5003)
    end

    http_headers_7 =
      begin
        satisfy_user_verification(@token)
        mark_token_step_up_satisfied_for_test(@token, scope: "social_unlink")
        begin
          f4_headers = as_user_headers(@user, host: @host, session_public_id: @token.public_id)
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
              when "edit" then "edit-org"
              else "#{f4_family}-#{f4_surface}"
              end
            f4_token = ClientToken.find_by!(public_id: f4_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f4_client = OidcClientRegistry.find!(f4_client_id)
            f4_key = [f4_client.client_id, f4_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f4_key] && f4_token.currently_usable? &&
                !(f4_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f4_token.device_session_id,
                  oidc_client_id: f4_client.client_id,
                  revoked_at: nil,
                ))
              f4_token.rotate_refresh_token! unless f4_token.device_session.current_refresh_token_id
              f4_now = Time.current
              f4_session = ClientRpSession.create!(
                client_token: f4_token, oidc_client_id: f4_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f4_now,
                refresh_token_expires_at: f4_now + 10.minutes,
              )
              f4_access = AuthenticationTokenService.encode(
                f4_token.user, host: f4_host, resource_type: "client",
                               session_public_id: f4_token.public_id, base_session_public_id: f4_token.public_id,
                               oidc_sid: f4_session.public_id, oidc_jti: f4_session.oidc_jti,
                               expires_at: f4_now + 10.minutes, scopes: %w(openid profile),
                               issuer: OidcIssuer.for_client(f4_client), audiences: [f4_client.aud],
                               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f4_client),
                               subject: OidcSubject.for(
                                 f4_token.user,
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
      end
    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: http_headers_7

    assert_response :redirect

    assert_not ClientExternalIdentity.effective_binding.exists?(id: google_identity.id),
               "Google identity should be released"
    assert_not_nil google_identity.reload.released_at
  end

  test "unlink Apple succeeds when a verified email remains available" do
    apple_identity = ClientAppleIdentity.create!(
      user: @user,
      uid: "apple_to_unlink_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )
    begin
      fv5002 = "apple-backup-#{SecureRandom.hex(4)}@example.com"
      insert_verified_user_email!(user_id: @user.id, address: fv5002)
    end

    http_headers_6 =
      begin
        satisfy_user_verification(@token)
        mark_token_step_up_satisfied_for_test(@token, scope: "social_unlink")
        begin
          f5_headers = as_user_headers(@user, host: @host, session_public_id: @token.public_id)
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
              when "edit" then "edit-org"
              else "#{f5_family}-#{f5_surface}"
              end
            f5_token = ClientToken.find_by!(public_id: f5_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f5_client = OidcClientRegistry.find!(f5_client_id)
            f5_key = [f5_client.client_id, f5_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f5_key] && f5_token.currently_usable? &&
                !(f5_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f5_token.device_session_id,
                  oidc_client_id: f5_client.client_id,
                  revoked_at: nil,
                ))
              f5_token.rotate_refresh_token! unless f5_token.device_session.current_refresh_token_id
              f5_now = Time.current
              f5_session = ClientRpSession.create!(
                client_token: f5_token, oidc_client_id: f5_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f5_now,
                refresh_token_expires_at: f5_now + 10.minutes,
              )
              f5_access = AuthenticationTokenService.encode(
                f5_token.user, host: f5_host, resource_type: "client",
                               session_public_id: f5_token.public_id, base_session_public_id: f5_token.public_id,
                               oidc_sid: f5_session.public_id, oidc_jti: f5_session.oidc_jti,
                               expires_at: f5_now + 10.minutes, scopes: %w(openid profile),
                               issuer: OidcIssuer.for_client(f5_client), audiences: [f5_client.aud],
                               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f5_client),
                               subject: OidcSubject.for(
                                 f5_token.user,
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
      end
    delete auth_app_settings_apple_url(ri: "jp", host: @host),
           headers: http_headers_6

    assert_response :redirect

    assert_not ClientExternalIdentity.effective_binding.exists?(id: apple_identity.id),
               "Apple identity should be released"
    assert_not_nil apple_identity.reload.released_at
  end

  test "unlink Google succeeds when passkey exists without verified telephone" do
    google_identity = ClientGoogleIdentity.create!(
      user: @user,
      uid: "google_only_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    email = ClientEmail.create!(
      user: @user,
      address: "passkey_tmp_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    ClientPasskey.create!(
      user: @user,
      webauthn_id: Base64.urlsafe_encode64("passkey_#{SecureRandom.hex(4)}", padding: false),
      public_key: "public_key_#{SecureRandom.hex(4)}",
      sign_count: 0,
      description: "Test Passkey",
    )

    email.destroy!

    http_headers_5 =
      begin
        satisfy_user_verification(@token)
        mark_token_step_up_satisfied_for_test(@token, scope: "social_unlink")
        begin
          f6_headers = as_user_headers(@user, host: @host, session_public_id: @token.public_id)
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
              when "edit" then "edit-org"
              else "#{f6_family}-#{f6_surface}"
              end
            f6_token = ClientToken.find_by!(public_id: f6_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f6_client = OidcClientRegistry.find!(f6_client_id)
            f6_key = [f6_client.client_id, f6_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f6_key] && f6_token.currently_usable? &&
                !(f6_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f6_token.device_session_id,
                  oidc_client_id: f6_client.client_id,
                  revoked_at: nil,
                ))
              f6_token.rotate_refresh_token! unless f6_token.device_session.current_refresh_token_id
              f6_now = Time.current
              f6_session = ClientRpSession.create!(
                client_token: f6_token, oidc_client_id: f6_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f6_now,
                refresh_token_expires_at: f6_now + 10.minutes,
              )
              f6_access = AuthenticationTokenService.encode(
                f6_token.user, host: f6_host, resource_type: "client",
                               session_public_id: f6_token.public_id, base_session_public_id: f6_token.public_id,
                               oidc_sid: f6_session.public_id, oidc_jti: f6_session.oidc_jti,
                               expires_at: f6_now + 10.minutes, scopes: %w(openid profile),
                               issuer: OidcIssuer.for_client(f6_client), audiences: [f6_client.aud],
                               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f6_client),
                               subject: OidcSubject.for(
                                 f6_token.user,
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
      end
    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: http_headers_5

    assert_response :redirect
    assert_not ClientExternalIdentity.effective_binding.exists?(id: google_identity.id)
    assert_not_nil google_identity.reload.released_at
  end

  test "unlink Google succeeds with passkey and verified telephone" do
    google_identity = ClientGoogleIdentity.create!(
      user: @user,
      uid: "google_with_passkey_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    ClientTelephone.create!(
      user: @user,
      number: "+15551234567",
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    ClientPasskey.create!(
      user: @user,
      webauthn_id: Base64.urlsafe_encode64("passkey_tel_#{SecureRandom.hex(4)}", padding: false),
      public_key: "public_key_#{SecureRandom.hex(4)}",
      sign_count: 0,
      description: "Test Passkey",
    )

    http_headers_4 =
      begin
        satisfy_user_verification(@token)
        mark_token_step_up_satisfied_for_test(@token, scope: "social_unlink")
        begin
          f7_headers = as_user_headers(@user, host: @host, session_public_id: @token.public_id)
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
              when "edit" then "edit-org"
              else "#{f7_family}-#{f7_surface}"
              end
            f7_token = ClientToken.find_by!(public_id: f7_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f7_client = OidcClientRegistry.find!(f7_client_id)
            f7_key = [f7_client.client_id, f7_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f7_key] && f7_token.currently_usable? &&
                !(f7_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f7_token.device_session_id,
                  oidc_client_id: f7_client.client_id,
                  revoked_at: nil,
                ))
              f7_token.rotate_refresh_token! unless f7_token.device_session.current_refresh_token_id
              f7_now = Time.current
              f7_session = ClientRpSession.create!(
                client_token: f7_token, oidc_client_id: f7_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f7_now,
                refresh_token_expires_at: f7_now + 10.minutes,
              )
              f7_access = AuthenticationTokenService.encode(
                f7_token.user, host: f7_host, resource_type: "client",
                               session_public_id: f7_token.public_id, base_session_public_id: f7_token.public_id,
                               oidc_sid: f7_session.public_id, oidc_jti: f7_session.oidc_jti,
                               expires_at: f7_now + 10.minutes, scopes: %w(openid profile),
                               issuer: OidcIssuer.for_client(f7_client), audiences: [f7_client.aud],
                               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f7_client),
                               subject: OidcSubject.for(
                                 f7_token.user,
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
      end
    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: http_headers_4

    assert_response :redirect
    assert_not ClientExternalIdentity.effective_binding.exists?(id: google_identity.id)
    assert_not_nil google_identity.reload.released_at
  end

  # ============================================================================
  # Error cases
  # ============================================================================
  test "unlink non-existent identity is idempotent" do
    # Client has no Google identity but tries to unlink
    ClientAppleIdentity.create!(
      user: @user,
      uid: "apple_only_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    http_headers_3 =
      begin
        satisfy_user_verification(@token)
        mark_token_step_up_satisfied_for_test(@token, scope: "social_unlink")
        begin
          f8_headers = as_user_headers(@user, host: @host, session_public_id: @token.public_id)
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
              when "edit" then "edit-org"
              else "#{f8_family}-#{f8_surface}"
              end
            f8_token = ClientToken.find_by!(public_id: f8_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f8_client = OidcClientRegistry.find!(f8_client_id)
            f8_key = [f8_client.client_id, f8_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f8_key] && f8_token.currently_usable? &&
                !(f8_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f8_token.device_session_id,
                  oidc_client_id: f8_client.client_id,
                  revoked_at: nil,
                ))
              f8_token.rotate_refresh_token! unless f8_token.device_session.current_refresh_token_id
              f8_now = Time.current
              f8_session = ClientRpSession.create!(
                client_token: f8_token, oidc_client_id: f8_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f8_now,
                refresh_token_expires_at: f8_now + 10.minutes,
              )
              f8_access = AuthenticationTokenService.encode(
                f8_token.user, host: f8_host, resource_type: "client",
                               session_public_id: f8_token.public_id, base_session_public_id: f8_token.public_id,
                               oidc_sid: f8_session.public_id, oidc_jti: f8_session.oidc_jti,
                               expires_at: f8_now + 10.minutes, scopes: %w(openid profile),
                               issuer: OidcIssuer.for_client(f8_client), audiences: [f8_client.aud],
                               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f8_client),
                               subject: OidcSubject.for(
                                 f8_token.user,
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
      end
    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: http_headers_3

    assert_response :redirect
    assert_predicate ClientAppleIdentity, :exists?
  end

  test "unlink removes inactive legacy identity" do
    identity = ClientGoogleIdentity.create!(
      user: @user,
      uid: "revoked_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:revoked),
    )

    http_headers_2 =
      begin
        satisfy_user_verification(@token)
        mark_token_step_up_satisfied_for_test(@token, scope: "social_unlink")
        begin
          f9_headers = as_user_headers(@user, host: @host, session_public_id: @token.public_id)
          f9_host = f9_headers["Host"]
          f9_route =
            begin
              Rails.application.routes.recognize_path("https://#{f9_host}/") if f9_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f9_family, f9_surface = f9_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f9_family) && f9_surface == "app"
            f9_client_id =
              case f9_family
              when "base" then "base-#{f9_surface}-ww"
              when "edit" then "edit-org"
              else "#{f9_family}-#{f9_surface}"
              end
            f9_token = ClientToken.find_by!(public_id: f9_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f9_client = OidcClientRegistry.find!(f9_client_id)
            f9_key = [f9_client.client_id, f9_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f9_key] && f9_token.currently_usable? &&
                !(f9_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f9_token.device_session_id,
                  oidc_client_id: f9_client.client_id,
                  revoked_at: nil,
                ))
              f9_token.rotate_refresh_token! unless f9_token.device_session.current_refresh_token_id
              f9_now = Time.current
              f9_session = ClientRpSession.create!(
                client_token: f9_token, oidc_client_id: f9_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f9_now,
                refresh_token_expires_at: f9_now + 10.minutes,
              )
              f9_access = AuthenticationTokenService.encode(
                f9_token.user, host: f9_host, resource_type: "client",
                               session_public_id: f9_token.public_id, base_session_public_id: f9_token.public_id,
                               oidc_sid: f9_session.public_id, oidc_jti: f9_session.oidc_jti,
                               expires_at: f9_now + 10.minutes, scopes: %w(openid profile),
                               issuer: OidcIssuer.for_client(f9_client), audiences: [f9_client.aud],
                               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f9_client),
                               subject: OidcSubject.for(
                                 f9_token.user,
                                 resource_type: "client",
                               ), client_id: f9_client.client_id,
              )
              @base_browser_rp_credentials[f9_key] =
                [f9_access, f9_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f9_key]
              f9_access, f9_refresh = @base_browser_rp_credentials.fetch(f9_key)
              f9_cookie = [
                f9_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f9_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f9_refresh)}",
              ].join("; ")
              f9_headers = f9_headers.merge(
                "Cookie" => f9_cookie,
                "HTTP_COOKIE" => f9_cookie,
              )
            end
          end
          f9_headers
        end
      end
    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: http_headers_2

    assert_response :unprocessable_content
    assert ClientGoogleIdentity.exists?(identity.id)
  end

  test "unlink requires authentication" do
    # No auth header
    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: { "Host" => @host }

    assert_response :redirect
    assert_base_sign_handoff_redirect(response.location, surface: :app)
  end

  test "unlink succeeds when user has only inactive legacy social identity and an active email" do
    inactive_google = ClientGoogleIdentity.create!(
      user: @user,
      uid: "revoked_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:revoked),
      released_at: Time.current,
    )

    begin
      fv5001 = "active-#{SecureRandom.hex(4)}@example.com"
      insert_verified_user_email!(user_id: @user.id, address: fv5001)
    end

    # A released legacy row is not an effective social binding and is already
    # idempotently unlinked; the effective email remains available.
    http_headers_1 =
      begin
        satisfy_user_verification(@token)
        mark_token_step_up_satisfied_for_test(@token, scope: "social_unlink")
        begin
          f10_headers = as_user_headers(@user, host: @host, session_public_id: @token.public_id)
          f10_host = f10_headers["Host"]
          f10_route =
            begin
              Rails.application.routes.recognize_path("https://#{f10_host}/") if f10_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f10_family, f10_surface = f10_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f10_family) && f10_surface == "app"
            f10_client_id =
              case f10_family
              when "base" then "base-#{f10_surface}-ww"
              when "edit" then "edit-org"
              else "#{f10_family}-#{f10_surface}"
              end
            f10_token = ClientToken.find_by!(public_id: f10_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f10_client = OidcClientRegistry.find!(f10_client_id)
            f10_key = [f10_client.client_id, f10_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f10_key] && f10_token.currently_usable? &&
                !(f10_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f10_token.device_session_id,
                  oidc_client_id: f10_client.client_id,
                  revoked_at: nil,
                ))
              f10_token.rotate_refresh_token! unless f10_token.device_session.current_refresh_token_id
              f10_now = Time.current
              f10_session = ClientRpSession.create!(
                client_token: f10_token, oidc_client_id: f10_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f10_now,
                refresh_token_expires_at: f10_now + 10.minutes,
              )
              f10_access = AuthenticationTokenService.encode(
                f10_token.user,
                host: f10_host,
                resource_type: "client",
                session_public_id: f10_token.public_id,
                base_session_public_id: f10_token.public_id,
                oidc_sid: f10_session.public_id,
                oidc_jti: f10_session.oidc_jti,
                expires_at: f10_now + 10.minutes,
                scopes: %w(openid profile),
                issuer: OidcIssuer.for_client(f10_client),
                audiences: [f10_client.aud],
                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f10_client),
                subject: OidcSubject.for(
                  f10_token.user,
                  resource_type: "client",
                ),
                client_id: f10_client.client_id,
              )
              @base_browser_rp_credentials[f10_key] =
                [f10_access, f10_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f10_key]
              f10_access, f10_refresh = @base_browser_rp_credentials.fetch(f10_key)
              f10_cookie = [
                f10_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f10_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f10_refresh)}",
              ].join("; ")
              f10_headers = f10_headers.merge(
                "Cookie" => f10_cookie,
                "HTTP_COOKIE" => f10_cookie,
              )
            end
          end
          f10_headers
        end
      end
    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: http_headers_1

    assert_response :redirect
    assert ClientGoogleIdentity.exists?(inactive_google.id)
    assert_not ClientExternalIdentity.effective_binding.exists?(id: inactive_google.id)
  end

  test "unlink fails when only active identity is social and others are REVOKED" do
    # D-85 permits only one binding row per Client, so the other methods are
    # represented by the unverified email/TOTP fixtures rather than a second
    # social row.
    google_identity = ClientGoogleIdentity.create!(
      user: @user,
      uid: "only_active_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    # Try to unlink Google - should fail because it's the only ACTIVE identity
    http_headers_0 =
      begin
        satisfy_user_verification(@token)
        mark_token_step_up_satisfied_for_test(@token, scope: "social_unlink")
        begin
          f11_headers = as_user_headers(@user, host: @host, session_public_id: @token.public_id)
          f11_host = f11_headers["Host"]
          f11_route =
            begin
              Rails.application.routes.recognize_path("https://#{f11_host}/") if f11_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f11_family, f11_surface = f11_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f11_family) && f11_surface == "app"
            f11_client_id =
              case f11_family
              when "base" then "base-#{f11_surface}-ww"
              when "edit" then "edit-org"
              else "#{f11_family}-#{f11_surface}"
              end
            f11_token = ClientToken.find_by!(public_id: f11_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f11_client = OidcClientRegistry.find!(f11_client_id)
            f11_key = [f11_client.client_id, f11_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f11_key] && f11_token.currently_usable? &&
                !(f11_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: f11_token.device_session_id,
                  oidc_client_id: f11_client.client_id,
                  revoked_at: nil,
                ))
              f11_token.rotate_refresh_token! unless f11_token.device_session.current_refresh_token_id
              f11_now = Time.current
              f11_session = ClientRpSession.create!(
                client_token: f11_token, oidc_client_id: f11_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f11_now,
                refresh_token_expires_at: f11_now + 10.minutes,
              )
              f11_access = AuthenticationTokenService.encode(
                f11_token.user,
                host: f11_host,
                resource_type: "client",
                session_public_id: f11_token.public_id,
                base_session_public_id: f11_token.public_id,
                oidc_sid: f11_session.public_id,
                oidc_jti: f11_session.oidc_jti,
                expires_at: f11_now + 10.minutes,
                scopes: %w(openid profile),
                issuer: OidcIssuer.for_client(f11_client),
                audiences: [f11_client.aud],
                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f11_client),
                subject: OidcSubject.for(
                  f11_token.user,
                  resource_type: "client",
                ),
                client_id: f11_client.client_id,
              )
              @base_browser_rp_credentials[f11_key] =
                [f11_access, f11_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f11_key]
              f11_access, f11_refresh = @base_browser_rp_credentials.fetch(f11_key)
              f11_cookie = [
                f11_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f11_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f11_refresh)}",
              ].join("; ")
              f11_headers = f11_headers.merge(
                "Cookie" => f11_cookie,
                "HTTP_COOKIE" => f11_cookie,
              )
            end
          end
          f11_headers
        end
      end
    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: http_headers_0

    assert_response :unprocessable_content

    # Google should still be ACTIVE (not unlinked)
    google_identity.reload

    assert_equal ClientGoogleIdentityStatus::ACTIVE, google_identity.status_id
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class SocialAuthUnlinkTest
  private
end

# DAMP local helper copy for former shared test support.
class SocialAuthUnlinkTest
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
    base_hosts = {
      "APP" => [
        ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
        ENV.fetch("PRIVATE_BASE_SERVICE_URL"),
      ],
      "ORG" => [
        ENV.fetch("PUBLIC_BASE_STAFF_URL"),
        ENV.fetch("PRIVATE_BASE_STAFF_URL"),
      ],
      "COM" => [
        ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
        ENV.fetch("PRIVATE_BASE_CORPORATE_URL"),
      ],
    }
    base_surface = base_hosts.find { |_surface, hosts| hosts.include?(normalized) }&.first
    return "surface:BASE_#{base_surface}" if base_surface

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
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
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
    user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    ).tap { |email| email.finalize_binding! }
  end

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [
        {
          visitor_id: visitor_id,
          address: address,
          address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :com),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_private_key: SecureRandom.base64(24),
          otp_counter: "",
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

  def seed_social_auth_session(provider:, intent: "login", user: nil, entry: nil, ri: "jp", rt: nil, referer: nil)
    host = configured_host(:sign_service)
    host!(host) if respond_to?(:host!)
    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    continue_path =
      if intent.to_s == "link"
        public_send(:"auth_app_settings_#{normalized_provider}_path", ri: ri)
      elsif entry.to_s == "sign_up"
        public_send(:"auth_app_social_#{normalized_provider}_registration_path", ri: ri, rt: rt)
      else
        public_send(:"auth_app_social_#{normalized_provider}_session_path", ri: ri, rt: rt)
      end
    headers = social_callback_headers(host)
    headers["Referer"] = referer if referer.present?
    if user
      user_headers =
        as_user_headers(user, host: host)
      token = ClientToken.find_by(public_id: user_headers["X-TEST-SESSION-PUBLIC-ID"])
      mark_token_step_up_satisfied_for_test(
        token,
        scope: SocialAuth::SOCIAL_LINK_SCOPE,
      ) if intent.to_s == "link" && token
      headers = headers.merge(user_headers)
    end
    post(continue_path, headers: headers)
    social_auth_state_from_response
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

# DAMP local helper copy on the test class.
class SocialAuthUnlinkTest
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
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      {
        last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
        last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
        last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
        last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
        last_step_up_audience: (step_up_test_audience_for_token(token) if token.respond_to?(:last_step_up_audience)),
        last_step_up_credential_ref: ("test-step-up-credential" if token.respond_to?(:last_step_up_credential_ref)),
        last_step_up_phishing_resistant: (false if token.respond_to?(:last_step_up_phishing_resistant)),
        last_step_up_user_verified: (true if token.respond_to?(:last_step_up_user_verified)),
        last_step_up_full_reauthentication: (false if token.respond_to?(:last_step_up_full_reauthentication)),
        updated_at: Time.current,
      }.compact,
    )
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

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
