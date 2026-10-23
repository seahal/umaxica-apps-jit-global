# typed: false
# frozen_string_literal: true

require "test_helper"

# Credential-management endpoints on the corporate and staff identity surfaces,
# plus the app MFA level page. The app's generic secret management route is retired.
class BaseIdentityCredentialManagementTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_email_statuses,
           :client_token_kinds, :client_token_statuses, :client_token_binding_methods,
           :client_token_dbsc_statuses, :client_chronicle_events, :client_chronicle_levels,
           :visitors, :visitor_statuses, :visitor_email_statuses,
           :visitor_token_kinds, :visitor_token_statuses,
           :visitor_token_binding_methods, :visitor_token_dbsc_statuses,
           :operators, :operator_statuses, :operator_secret_credential_kinds,
           :operator_secret_credential_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses, :operator_passkeys

  setup do
    https!
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "com secret credential removal discards the credential when another remains" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    visitor = visitors(:reserved_visitor)
    VisitorEmail.create!(
      visitor: visitor, address: "com_secret_removal_contact@example.com", confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    ).finalize_binding!
    visitor_passkey = visitor.visitor_passkeys.create!(webauthn_id: "com-management-passkey", public_key: "public-key")
    visitor_passkey.update!(uv_verified_at: Time.current)
    VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::ACTIVE)
    VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::DELETED)
    VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::LOGIN)
    removable, = VisitorSecretCredential.issue!(
      name: "removable", visitor_id: visitor.id,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN, uses: 10, status: :active,
    )
    VisitorSecretCredential.issue!(
      name: "keeper", visitor_id: visitor.id,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN, uses: 10, status: :active,
    )
    token = VisitorToken.create!(
      authentication_epoch: 0,
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
      root_login_established_at: Time.current,
      last_step_up_at: Time.current, last_step_up_scope: "settings_secret_credential",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:com",
      last_step_up_credential_ref: visitor_passkey.public_id,
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    token.update_columns(last_step_up_session_public_id: token.public_id)
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_purpose: "step_up", last_step_up_audience: "step_up:com",
      last_step_up_session_public_id: token.public_id, last_step_up_credential_ref: visitor_passkey.public_id,
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    begin
      rp_cookie_pairs =
        begin
          rp_host = host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-com-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpComGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpComGrant.create!(
                authentication_epoch: 0,
                visitor_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                visitor, host: rp_host, resource_type: "visitor",
                         session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                         oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                         expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                         issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                         subject: OidcSubject.for(visitor, resource_type: "visitor"), client_id: rp_client.client_id,
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
      visitor, host: host, session_public_id: token.public_id,
               resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
    begin
      rp_cookie_pairs =
        begin
          rp_host = host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-com-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpComGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpComGrant.create!(
                authentication_epoch: 0,
                visitor_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                visitor, host: rp_host, resource_type: "visitor",
                         session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                         oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                         expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                         issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                         subject: OidcSubject.for(visitor, resource_type: "visitor"), client_id: rp_client.client_id,
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
    post base_com_identity_secret_removal_url(removable.public_id, ri: "jp", host: host),
         headers: {
           "Authorization" => "Bearer #{access_token}",
           "Client-Agent" => "Mozilla/5.0",
           "Host" => host,
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         }

    assert_response :see_other
    assert_equal VisitorSecretCredential.status_id_for(:deleted),
                 removable.reload.visitor_secret_credential_status_id
  end

  test "org secret credential removal discards the credential when another remains" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)
    operator_passkey = operator.operator_passkeys.first!
    operator_passkey.update!(uv_verified_at: Time.current)
    OperatorSecretCredentialStatus.find_or_create_by!(id: OperatorSecretCredentialStatus::ACTIVE)
    OperatorSecretCredentialStatus.find_or_create_by!(id: OperatorSecretCredentialStatus::DELETED)
    OperatorSecretCredentialKind.find_or_create_by!(id: OperatorSecretCredentialKind::LOGIN)
    removable, = OperatorSecretCredential.issue!(
      name: "removable", staff_id: operator.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN, uses: 10, status: :active,
    )
    OperatorSecretCredential.issue!(
      name: "keeper", staff_id: operator.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN, uses: 10, status: :active,
    )
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
      root_login_established_at: Time.current,
      last_step_up_at: Time.current, last_step_up_scope: "settings_secret_credential",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
      last_step_up_credential_ref: operator_passkey.external_id,
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    token.update_columns(last_step_up_session_public_id: token.public_id)
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
      last_step_up_session_public_id: token.public_id, last_step_up_credential_ref: operator_passkey.external_id,
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
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
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
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

    post base_org_identity_secret_removal_url(removable.public_id, ri: "jp", host: host),
         headers: {
           "Authorization" => "Bearer #{access_token}",
           "Client-Agent" => "Mozilla/5.0",
           "Host" => host,
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         }

    assert_response :see_other
  end

  test "app MFA challenge page renders the current level for a stepped-up client" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    passkey = client.client_passkeys.create!(webauthn_id: "mfa-management-passkey", public_key: "public-key")
    token = ClientToken.create!(
      authentication_epoch: 0,
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
      root_login_established_at: Time.current,
    )
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
    _verification, raw_verification = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_mfa",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_credential_ref: passkey.public_id,
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
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

    get base_app_identity_mfa_challenge_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
  end
end
