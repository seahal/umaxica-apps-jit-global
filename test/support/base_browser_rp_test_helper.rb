# frozen_string_literal: true

# Installs the browser RP access and refresh cookies required by Base's unsafe
# request boundary. Authorization headers alone intentionally do not satisfy
# that boundary.
module BaseBrowserRpTestHelper
  private

  def install_base_browser_rp_credentials!(surface:, host:, actor:, token:, cookie_jar: cookies)
    @base_browser_rp_credentials ||= {}
    key = [surface, token.public_id]
    client_id = { "app" => "base-app-ww", "com" => "base-com-ww", "org" => "base-org-ww" }.fetch(surface)
    client = OidcClientRegistry.find!(client_id)
    resource_type = { "app" => "client", "com" => "visitor", "org" => "operator" }.fetch(surface)
    model = { "app" => ClientRpSession, "com" => VisitorRpSession, "org" => OperatorRpSession }.fetch(surface)
    token_key = { "app" => :client_token, "com" => :visitor_token, "org" => :operator_token }.fetch(surface)

    unless @base_browser_rp_credentials[key]
      token.rotate_refresh_token! unless token.device_session.current_refresh_token_id
      now = Time.current
      rp_session = model.create!(
        token_key => token,
        :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile",
        :oidc_jti => SecureRandom.uuid,
        :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => now,
        :refresh_token_expires_at => now + 10.minutes,
      )
      access_token = AuthenticationTokenService.encode(
        actor,
        host: host,
        resource_type: resource_type,
        session_public_id: token.public_id,
        base_session_public_id: token.public_id,
        oidc_sid: rp_session.public_id,
        oidc_jti: rp_session.oidc_jti,
        expires_at: now + 10.minutes,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(client),
        audiences: [client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
        subject: OidcSubject.for(actor, resource_type: resource_type),
        client_id: client.client_id,
      )
      @base_browser_rp_credentials[key] = [access_token, rp_session.issue_refresh_token!]
    end

    access_token, refresh_token = @base_browser_rp_credentials.fetch(key)
    cookie_jar.merge(
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access_token)}",
      URI.parse("https://#{host}/"),
    )
    cookie_jar.merge(
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(refresh_token)}",
      URI.parse("https://#{host}/"),
    )
  end
end
