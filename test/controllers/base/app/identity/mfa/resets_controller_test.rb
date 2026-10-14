# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::Identity::Mfa::ResetsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @client = clients(:one)
    @client.update!(mfa_level_id: ClientMfaLevel::FULL, mfa_level_enabled: true)
    @headers =
      begin
        rp_headers = as_user_headers(@client, host: @host)
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
    @token = ClientToken.find_by!(public_id: @headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
  end

  test "show is a GET-only unavailable placeholder that leaves security state unchanged" do
    before = security_state

    get base_app_identity_mfa_reset_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_predicate inertia_props.fetch("reset_unavailable"), :present?
    assert_equal before, security_state
  end

  test "mutation verbs are not routes and change no security state" do
    before = security_state
    path = base_app_identity_mfa_reset_url(ri: "jp", host: @host)

    %i(post patch put delete).each do |method|
      process(method, path, headers: @headers)

      assert_response :not_found, method.to_s
    end

    assert_equal before, security_state
  end

  private

  def security_state
    {
      client: @client.reload.attributes,
      session: @token.reload.attributes,
      credentials: [
        @client.client_secret_credentials.count,
        @client.client_totp_credentials.count,
        @client.client_passkeys.count,
      ],
      chronicles: [
        Chronicle.where(actor_type: "Client", actor_id: @client.id).count,
        Chronicle.where(subject_type: "Client", subject_id: @client.id).count,
        ClientChronicle.where(actor_type: "Client", actor_id: @client.id).count,
        ClientChronicle.where(subject_type: "Client", subject_id: @client.id.to_s).count,
      ],
    }
  end
end
