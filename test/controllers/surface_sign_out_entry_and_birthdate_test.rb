# typed: false
# frozen_string_literal: true

require "test_helper"

# Two per-surface endpoints that repeat across the auth and core surfaces: the
# sign-out entry redirect and its confirmation page, plus the step-up-gated
# birthdate page on the corporate and staff identity surfaces.
class SurfaceSignOutEntryAndBirthdateTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses

  test "core org sign-out confirmation page renders for an anonymous operator" do
    host = ENV.fetch("PUBLIC_CORE_STAFF_URL")
    host! host

    get edit_core_org_sign_out_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
  end

  test "org birthdate page shows the operator's stored birthdate behind a fresh step-up" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)
    operator.update!(birthdate: "1985-03-04")
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    _verification, raw_verification = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_birthdate",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
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

    get base_org_identity_birthdate_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
  end
end
