# typed: false
# frozen_string_literal: true

require "test_helper"

class AppWithdrawalStepUpEnforcerTest < ActionDispatch::IntegrationTest
  fixtures :client_totp_credential_statuses

  setup do
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)

    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @client = Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
    @token = ClientToken.create!(
      authentication_epoch: 0,
      user: @client,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    BaseSelectorAuthority.prepare(surface: :app, principal: @client, session: @token)
  end

  test "app withdrawal destructive action requires fresh step-up" do
    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" },
          headers: authenticated_headers

    assert_response :redirect
    assert_equal "/sign", URI.parse(response.location).path
  end

  test "an OP-root session without an RP-local session cannot perform withdrawal" do
    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" },
          headers: authenticated_headers

    assert_response :redirect
    assert_equal "/sign", URI.parse(response.location).path
  end

  test "token-bound OP freshness does not replace the RP-local session" do
    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" },
          headers: authenticated_headers

    assert_response :redirect
    assert_equal "/sign", URI.parse(response.location).path
  end

  private

  def authenticated_headers
    rp_cookie =
      begin
        fixture_root = @token
        fixture_actor = @client
        fixture_host = @host
        fixture_root.rotate_refresh_token! unless fixture_root.device_session.current_refresh_token_id
        fixture_client = OidcClientRegistry.find!("base-app-ww")
        @base_rp_fixture_credentials ||= {}
        fixture_key = [fixture_client.client_id, fixture_root.public_id]
        unless @base_rp_fixture_credentials[fixture_key]
          fixture_now = OpAppGrant.database_now
          fixture_rp = OpAppGrant.create!(
            authentication_epoch: 0,
            client_token: fixture_root, oidc_client_id: fixture_client.client_id,
            oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
            oidc_nonce: SecureRandom.hex(16), oidc_auth_time: fixture_now,
            refresh_token_expires_at: fixture_now + 1.hour,
          )
          fixture_access = AuthenticationTokenService.encode(
            fixture_actor, host: fixture_host, resource_type: "client",
                           session_public_id: fixture_root.public_id, base_session_public_id: fixture_root.public_id,
                           oidc_sid: fixture_rp.public_id, oidc_jti: fixture_rp.oidc_jti,
                           expires_at: fixture_now + 1.hour, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(fixture_client), audiences: [fixture_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fixture_client),
                           subject: OidcSubject.for(
                             fixture_actor,
                             resource_type: "client",
                           ), client_id: fixture_client.client_id,
          )
          fixture_refresh = fixture_rp.issue_refresh_token!
          @base_rp_fixture_credentials[fixture_key] = [
            "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(fixture_access)}",
            "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(fixture_refresh)}",
          ].join("; ")
        end
        @base_rp_fixture_credentials.fetch(fixture_key)
      end
    { "Host" => @host, "Cookie" => rp_cookie, "Accept" => "text/html" }
  end

  def access_token
    AuthenticationToken.encode(
      @client,
      host: @host,
      session_public_id: @token.public_id,
      resource_type: "client",
      jwt_issuer_id: "surface:BASE_APP",
    )
  end
end
