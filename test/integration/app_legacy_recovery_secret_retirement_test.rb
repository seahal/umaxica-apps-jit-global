# frozen_string_literal: true

require "test_helper"

class AppLegacyRecoverySecretRetirementTest < ActionDispatch::IntegrationTest
  test "retired app recovery reveal has no anonymous GET HEAD or OPTIONS entry" do
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))

    get "/identity/recovery-secret?ri=jp", env: { "action_dispatch.show_exceptions" => :all }

    assert_response :not_found

    head "/identity/recovery-secret?ri=jp", env: { "action_dispatch.show_exceptions" => :all }

    assert_response :not_found
    assert_empty response.body

    options "/identity/recovery-secret?ri=jp", env: { "action_dispatch.show_exceptions" => :all }

    assert_response :not_found
  end

  test "an existing app reveal receipt cannot be consumed through the retired URL" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)
    actor = clients(:one)
    headers =
      begin
        rp_headers = as_user_headers(actor, host: host)
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
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = ClientRpSession.create!(
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
    reveal = IdentityOneTimeReveal.issue!(
      actor: actor, session_nonce: actor.public_id,
      value: ["synthetic-retired-recovery-value"], purpose: "client.recovery_secret_credential",
    )
    receipt = SecurityOneTimeReveal.find_by!(
      actor_type: "Client", actor_id: actor.id, purpose: "client.recovery_secret_credential",
      consumed_at: nil,
    )

    get(
      "/identity/recovery-secret",
      params: { ri: "jp", token: reveal.token }, headers: headers,
      env: { "action_dispatch.show_exceptions" => :all },
    )

    assert_response :not_found
    assert_not_includes response.body, "synthetic-retired-recovery-value"
    assert_nil receipt.reload.consumed_at
    assert_not_nil receipt.encrypted_payload
  end
end
