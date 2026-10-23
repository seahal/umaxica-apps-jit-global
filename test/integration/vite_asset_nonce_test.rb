# typed: false
# frozen_string_literal: true

require "test_helper"

# `script-src` carries `'strict-dynamic'`, which makes the browser ignore every host and scheme
# source in that directive. A nonce is therefore the only thing that admits an asset tag, including
# the `<link rel="modulepreload">` tags `vite_javascript_tag` emits alongside the entrypoint script.
#
# Rails resolves `nonce: true` inside `javascript_include_tag` and `stylesheet_link_tag`, but
# vite_rails builds the preload links with `tag.link` and forwards the option untouched, so
# `nonce: true` renders the literal string "true" and the preload is refused. The layouts pass
# `content_security_policy_nonce` for that reason; this test is what keeps them from drifting back.
class ViteAssetNonceTest < ActionDispatch::IntegrationTest
  setup do
    @host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
    @user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @token = ClientToken.create!(authentication_epoch: 0, user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
  end

  test "every Vite asset tag on an Inertia page carries the response nonce" do
    # vite_rails emits dev-server URLs and no preload links whenever it can reach a running
    # Vite dev server, so with one up on the test port this test silently stops exercising
    # the built-asset path it exists to guard. Pin the probe rather than let an unrelated
    # process running on the machine decide what is verified.
    ViteRuby.instance.stub(:dev_server_running?, false) do
      http_headers_0 =
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
        end
      get(
        base_app_groups_url(ri: "jp", host: @host), headers: http_headers_0,
      )
    end

    assert_response :success

    nonce = response_nonce

    assert_predicate nonce, :present?

    tags = asset_tags

    assert_operator tags.count { |tag| tag["rel"] == "modulepreload" }, :>=, 1,
                    "expected the entrypoint to emit modulepreload links, otherwise this test proves nothing"

    tags.each do |tag|
      assert_equal nonce, tag["nonce"],
                   "#{tag.name} tag for #{tag["src"] || tag["href"]} does not carry the response CSP nonce"
    end
  end

  private

  def response_nonce
    response.headers["Content-Security-Policy"][/script-src[^;]*'nonce-([^']+)'/, 1]
  end

  def asset_tags
    document = response.parsed_body

    document.css("script[src], link[rel='modulepreload'], link[rel='stylesheet']").to_a
  end
end
