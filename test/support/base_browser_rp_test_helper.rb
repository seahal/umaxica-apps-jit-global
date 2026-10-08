# frozen_string_literal: true

# Installs the browser RP access and refresh cookies required by Base's unsafe
# request boundary. Authorization headers alone intentionally do not satisfy
# that boundary.
module BaseBrowserRpTestHelper
  private

  BROWSER_RP_RESOURCE_TYPES = { "app" => "client", "com" => "visitor", "org" => "operator" }.freeze
  BROWSER_RP_CLIENT_FAMILIES = %w(base warp core edit).freeze

  def install_base_browser_rp_credentials!(surface:, host:, actor:, token:, cookie_jar: cookies)
    client_id = { "app" => "base-app-ww", "com" => "base-com-ww", "org" => "base-org-ww" }.fetch(surface)
    cookie_jar.merge(
      browser_rp_cookie_pairs(client_id: client_id, surface: surface, host: host, actor: actor, token: token),
      URI.parse("https://#{host}/"),
    )
  end

  # The Browser RP client that serves +host+, or nil for a host no Browser RP owns (Auth, Palm,
  # content surfaces). Derived from routing so the harness cannot drift from the served surface.
  def browser_rp_client_for_host(host)
    family, surface = Rails.application.routes.recognize_path("https://#{host}/").fetch(:controller).split("/")
    return unless BROWSER_RP_CLIENT_FAMILIES.include?(family) && BROWSER_RP_RESOURCE_TYPES.key?(surface)

    client_id =
      case family
      when "base" then "base-#{surface}-ww"
      when "edit" then (surface == "org") ? "edit-org" : nil
      else "#{family}-#{surface}"
      end
    client_id && { client_id: client_id, surface: surface }
  rescue ActionController::RoutingError
    nil
  end

  def browser_rp_cookie_pairs(client_id:, surface:, host:, actor:, token:)
    @base_browser_rp_credentials ||= {}
    key = [client_id, token.public_id]
    client = OidcClientRegistry.find!(client_id)
    resource_type = BROWSER_RP_RESOURCE_TYPES.fetch(surface)
    model = { "app" => ClientRpSession, "com" => VisitorRpSession, "org" => OperatorRpSession }.fetch(surface)
    token_key = { "app" => :client_token, "com" => :visitor_token, "org" => :operator_token }.fetch(surface)

    # An unusable Browser Session cannot parent an RP Session, so it yields no RP credential.
    return [] unless @base_browser_rp_credentials[key] || token.currently_usable?

    # One Browser Session and one RP hold at most one unrevoked RP Session. A test that established
    # its own owns those cookies; issuing a second here would only collide with it.
    return [] if !@base_browser_rp_credentials[key] && token.device_session_id &&
      model.exists?(device_session_id: token.device_session_id, oidc_client_id: client.client_id, revoked_at: nil)

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
    [
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access_token)}",
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(refresh_token)}",
    ]
  end
end
