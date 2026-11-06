# typed: false
# frozen_string_literal: true

require "test_helper"

# A protected RP resource returns the RFC 9470 challenge only after its resource policy allows the
# request. Full-document requests get an explicit entry link; scripted requests get localized text.
class StepUpRequiredResponseShapeTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  STEP_UP_CHALLENGE_HEADER = 'Bearer error="insufficient_user_authentication", ' \
                             'error_description="step-up authentication is required", ' \
                             'acr_values="https://visa.umaxica.app/acr/reauthentication", max_age="300"'

  setup do
    @test_client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
      birthdate: Date.new(1990, 1, 1),
    )
    ClientPasskey.create!(
      user: @test_client,
      webauthn_id: "step-up-response-client-#{SecureRandom.hex(8)}",
      public_key: "step-up-response-client-public-key",
      sign_count: 0,
      description: "Step-up response test Passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    @test_operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    2.times do |index|
      OperatorPasskey.create!(
        staff: @test_operator,
        webauthn_id: "step-up-response-#{index}-#{SecureRandom.hex(8)}",
        external_id: SecureRandom.uuid,
        public_key: "step-up-response-public-key-#{index}",
        sign_count: 0,
        description: "Step-up response test Passkey #{index + 1}",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
  end

  test "an authorized app document request receives the challenge and an explicit entry link" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = @test_client
    token = ClientToken.create!(
      authentication_epoch: 0,
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    token.update!(root_login_established_at: ClientToken.database_now, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    begin
      rp_cookie_pairs =
        begin
          rp_host = host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-app-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpAppGrant.create!(
                authentication_epoch: 0,
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                client, host: rp_host, resource_type: "client",
                        session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                        oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                        expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                        issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                        subject: OidcSubject.for(client, resource_type: "client"), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    passkey = client.client_passkeys.active.sole
    get base_app_identity_passkey_url(SecureRandom.alphanumeric(21), ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "Accept" => "text/html",
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Dest" => "document",
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :not_found
    assert_nil response.headers["WWW-Authenticate"]

    get base_app_identity_passkey_url(passkey.public_id, ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "Accept" => "text/html",
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Dest" => "document",
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :unauthorized
    assert_equal STEP_UP_CHALLENGE_HEADER, response.headers.fetch("WWW-Authenticate")
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
    assert_equal "text/html", response.media_type
    assert_select "h1", I18n.t("auth.step_up.challenge.title")
    assert_select "p", I18n.t("auth.step_up.challenge.description")
    assert_select "a[href=?]", base_app_verification_path(
      return_target: base_app_identity_passkey_path(passkey.public_id), ri: "jp",
    ), I18n.t("actions.continue")
    assert_nil response.headers["X-Inertia-Location"]
  end

  test "an app Inertia request receives a challenge without an external-location response" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = @test_client
    token = ClientToken.create!(
      authentication_epoch: 0,
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    token.update!(root_login_established_at: ClientToken.database_now, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    begin
      rp_cookie_pairs =
        begin
          rp_host = host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-app-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpAppGrant.create!(
                authentication_epoch: 0,
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                client, host: rp_host, resource_type: "client",
                        session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                        oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                        expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                        issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                        subject: OidcSubject.for(client, resource_type: "client"), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    passkey = client.client_passkeys.active.sole
    get base_app_identity_passkey_url(passkey.public_id, ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "Accept" => "text/html",
          "X-Inertia" => "true",
          "X-Inertia-Version" => InertiaRails.configuration.version,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :unauthorized
    assert_equal "text/plain", response.media_type
    assert_equal I18n.t("auth.step_up.challenge.description"), response.body
    assert_equal STEP_UP_CHALLENGE_HEADER, response.headers.fetch("WWW-Authenticate")
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
    assert_nil response.headers["X-Inertia-Location"]
  end

  test "an authorized org document request receives the challenge and an explicit entry link" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = @test_operator
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    token.update!(root_login_established_at: OperatorToken.database_now, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    begin
      rp_cookie_pairs =
        begin
          rp_host = host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-org-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpOrgGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpOrgGrant.create!(
                authentication_epoch: 0,
                operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                operator, host: rp_host, resource_type: "operator",
                          session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                          oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                          expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                          issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                          subject: OidcSubject.for(operator, resource_type: "operator"), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    access_token = AuthenticationToken.encode(
      operator, host: host, session_public_id: token.public_id,
                resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    passkey = operator.staff_passkeys.active.order(:id).first!
    get base_org_identity_passkey_url(SecureRandom.uuid, ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "Accept" => "text/html",
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Dest" => "document",
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :not_found
    assert_nil response.headers["WWW-Authenticate"]

    get base_org_identity_passkey_url(passkey.external_id, ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "Accept" => "text/html",
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Dest" => "document",
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :unauthorized
    assert_equal STEP_UP_CHALLENGE_HEADER, response.headers.fetch("WWW-Authenticate")
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
    assert_select "h1", I18n.t("auth.step_up.challenge.title")
    assert_select "p", I18n.t("auth.step_up.challenge.description")
    assert_select "a[href=?]", base_org_verification_path(
      return_target: base_org_identity_passkey_path(passkey.external_id), ri: "jp",
    ), I18n.t("actions.continue")
    assert_nil response.headers["X-Inertia-Location"]
  end

  test "an org scripted request receives localized plain text and the challenge" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = @test_operator
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    token.update!(root_login_established_at: OperatorToken.database_now, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    begin
      rp_cookie_pairs =
        begin
          rp_host = host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-org-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpOrgGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpOrgGrant.create!(
                authentication_epoch: 0,
                operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                operator, host: rp_host, resource_type: "operator",
                          session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                          oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                          expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                          issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                          subject: OidcSubject.for(operator, resource_type: "operator"), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    access_token = AuthenticationToken.encode(
      operator, host: host, session_public_id: token.public_id,
                resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    passkey = operator.staff_passkeys.active.order(:id).first!
    get base_org_identity_passkey_url(passkey.external_id, ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "Accept" => "application/json",
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :unauthorized
    assert_equal "text/plain", response.media_type
    assert_equal I18n.t("auth.step_up.challenge.description"), response.body
    assert_equal STEP_UP_CHALLENGE_HEADER, response.headers.fetch("WWW-Authenticate")
    assert_equal "private, no-store", response.headers.fetch("Cache-Control")
  end
  test "an org JSON request from an Emergency Access session is refused with 403 instead of a step-up prompt" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = @test_operator
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    token.update!(root_login_established_at: OperatorToken.database_now, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    begin
      rp_cookie_pairs =
        begin
          rp_host = host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-org-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpOrgGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpOrgGrant.create!(
                authentication_epoch: 0,
                operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                operator, host: rp_host, resource_type: "operator",
                          session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                          oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                          expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                          issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                          subject: OidcSubject.for(operator, resource_type: "operator"), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    access_token = AuthenticationToken.encode(
      operator, host: host, session_public_id: token.public_id,
                resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    assert_no_difference("OperatorEmail.count") do
      post base_org_identity_emails_registration_url(ri: "jp", host: host),
           params: { staff_email: { raw_address: "org_step_up_emergency_json@example.com" } }, as: :json,
           headers: {
             "Authorization" => "Bearer #{access_token}",
             "Client-Agent" => "Mozilla/5.0",
             "Host" => host,
             "Accept" => "application/json",
             "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
           }
    end

    assert_response :forbidden
    assert_equal I18n.t("auth.step_up.emergency_unavailable"), response.parsed_body.fetch("error")
  end

  test "an app JSON request from a client with no step-up method asks to register one" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
    )
    token = ClientToken.create!(
      authentication_epoch: 0,
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    token.update!(root_login_established_at: ClientToken.database_now, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    begin
      rp_cookie_pairs =
        begin
          rp_host = host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-app-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpAppGrant.create!(
                authentication_epoch: 0,
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                client, host: rp_host, resource_type: "client",
                        session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                        oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                        expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                        issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                        subject: OidcSubject.for(client, resource_type: "client"), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    patch base_app_identity_withdrawal_url(ri: "jp", host: host),
          params: { ack_schedule_purge: "1" }, as: :json,
          headers: {
            "Authorization" => "Bearer #{access_token}",
            "Client-Agent" => "Mozilla/5.0",
            "Host" => host,
            "Accept" => "application/json",
            "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
          }

    assert_response :unprocessable_content
    assert_equal I18n.t("auth.step_up.register_methods_required"), response.parsed_body.fetch("error")
    assert_not ClientWithdrawalFlow.exists?(client_id: client.id)
  end
end
