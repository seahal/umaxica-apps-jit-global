# frozen_string_literal: true

require "test_helper"

# A sign-out that ends on an Inertia page must make that page drop the signed-in history: the key
# that decrypts the history entries lives in the tab's sessionStorage, out of reach of
# reset_session and cookie deletion. Each case drives the real Browser RP ceremony through the
# origin launch, the Base authority confirmation, the origin cleanup and the completion page.
class SignOutInertiaHistoryClearTest < ActionDispatch::IntegrationTest
  INERTIA_RP_FACES = {
    "warp-app-jp" => {
      origin_env: "PUBLIC_WARP_SERVICE_URL", base_env: "PUBLIC_BASE_SERVICE_URL", actor: "client", completion: :inertia,
    },
    "warp-com-jp" => {
      origin_env: "PUBLIC_WARP_CORPORATE_URL",
      base_env: "PUBLIC_BASE_CORPORATE_URL",
      actor: "visitor",
      completion: :inertia,
    },
    "warp-org-jp" => {
      origin_env: "PUBLIC_WARP_STAFF_URL", base_env: "PUBLIC_BASE_STAFF_URL", actor: "operator", completion: :inertia,
    },
    # Palm completes on a plain HTML page. inertia_rails drops the session flag on any non-redirect
    # response, so the page instead clears the tab storage, history key included, with
    # Clear-Site-Data.
    "palm-app-jp" => {
      origin_env: "PUBLIC_PALM_SERVICE_URL",
      base_env: "PUBLIC_BASE_SERVICE_URL",
      actor: "client",
      completion: :clear_site_data,
    },
  }.freeze

  setup { https! }

  INERTIA_RP_FACES.each do |client_id, face|
    test "#{client_id}: the page that completes sign-out clears Inertia history" do
      origin_host = ENV.fetch(face.fetch(:origin_env))
      base_host = ENV.fetch(face.fetch(:base_env))
      resource_type = face.fetch(:actor)
      client = OidcClientRegistry.find!(client_id)
      grant_attributes = {
        oidc_client_id: client.client_id,
        oidc_scope: "openid profile",
        oidc_jti: SecureRandom.uuid,
        oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: 1.minute.ago,
        refresh_token_expires_at: 10.minutes.from_now,
      }
      case resource_type
      when "client"
        actor = clients(:one)
        root = ClientToken.create!(
          authentication_epoch: 0,
          user: actor, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
          user_token_status_id: ClientTokenStatus::ACTIVE,
        )
        rp_session = OpAppGrant.create!(authentication_epoch: 0, client_token: root, **grant_attributes)
      when "visitor"
        actor = visitors(:reserved_visitor)
        root = VisitorToken.create!(
          authentication_epoch: 0,
          visitor: actor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
          visitor_token_status_id: VisitorTokenStatus::ACTIVE,
        )
        rp_session = OpComGrant.create!(authentication_epoch: 0, visitor_token: root, **grant_attributes)
      when "operator"
        actor = operators(:one)
        # Operators allow two concurrent sessions; start from no live session.
        AuthenticationSessionRevoker.tokens_for(actor).find_each(&:revoke!)
        root = OperatorToken.create!(
          authentication_epoch: 0,
          staff: actor, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
          staff_token_status_id: OperatorTokenStatus::ACTIVE,
        )
        rp_session = OpOrgGrant.create!(authentication_epoch: 0, operator_token: root, **grant_attributes)
      end

      host!(origin_host)
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
        actor,
        host: origin_host,
        resource_type: resource_type,
        session_public_id: root.public_id,
        base_session_public_id: root.public_id,
        oidc_sid: rp_session.public_id,
        oidc_jti: rp_session.oidc_jti,
        expires_at: 10.minutes.from_now,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(client),
        audiences: [client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
        subject: OidcSubject.for(actor, resource_type: resource_type),
        client_id: client.client_id,
      )
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_session.issue_refresh_token!
      post "/sign/out", params: { ri: "jp" },
                        headers: { "Origin" => "https://#{origin_host}", "Sec-Fetch-Site" => "same-origin" }

      assert_response :see_other
      authority = URI.parse(response.location)

      assert_equal base_host, authority.host
      challenge = Rack::Utils.parse_nested_query(authority.query.to_s).fetch("logout_challenge")

      host!(base_host)
      device_session = root.device_session_record
      base_access = AuthenticationToken.encode(
        actor,
        host: base_host,
        session_public_id: device_session.public_id,
        oidc_sid: device_session.public_id,
        oidc_jti: root.oidc_jti,
        resource_type: resource_type,
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
        authentication_context: root.authentication_context_value.to_s,
      )
      # The Cookie header replaces the jar, so it carries the domain-wide Rails session the origin
      # wrote, as the browser would; without it Base would overwrite the origin's sign-out proof.
      session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      base_cookie = [
        "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(base_access)}",
        "#{session_key}=#{Rack::Utils.escape(cookies.to_hash.fetch(session_key))}",
      ].join("; ")
      post authority.path, params: { logout_challenge: challenge, ri: "jp" }, headers: {
        "Cookie" => base_cookie,
        "HTTP_COOKIE" => base_cookie,
        "Origin" => "https://#{origin_host}",
        "Sec-Fetch-Site" => "same-site",
      }

      assert_response :see_other
      cleanup = URI.parse(response.location)

      assert_equal origin_host, cleanup.host
      assert_not_predicate root.reload, :currently_usable?

      host!(origin_host)
      get cleanup.request_uri

      assert_response :success
      case face.fetch(:completion)
      when :inertia
        form = inertia_props.fetch("form")
        action = form.fetch("action")
        fields = form.slice("logout_challenge", "logout_intent_proof").merge("ri" => "jp")
      when :clear_site_data
        form = response.parsed_body.at_css('form[method="post"]')
        action = form["action"]
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      end
      post action, params: fields,
                   headers: { "Origin" => "https://#{origin_host}", "Sec-Fetch-Site" => "same-origin" }

      assert_response :see_other
      follow_redirect! while response.redirect?

      assert_response :success
      assert_predicate rp_session.reload, :revoked?
      case face.fetch(:completion)
      when :inertia

        assert inertia_page.fetch("clearHistory")
      when :clear_site_data

        assert_includes response.headers.fetch("Clear-Site-Data"), '"storage"'
      end
    end
  end

  BASE_RP_FACES = {
    "base-app-ww" => { base_env: "PUBLIC_BASE_SERVICE_URL", actor: "client" },
    "base-com-ww" => { base_env: "PUBLIC_BASE_CORPORATE_URL", actor: "visitor" },
    "base-org-ww" => { base_env: "PUBLIC_BASE_STAFF_URL", actor: "operator" },
  }.freeze

  BASE_RP_FACES.each do |client_id, face|
    test "#{client_id}: a failed Base origin cleanup after the parent COMMIT clears Inertia history" do
      base_host = ENV.fetch(face.fetch(:base_env))
      resource_type = face.fetch(:actor)
      client = OidcClientRegistry.find!(client_id)
      grant_attributes = {
        oidc_client_id: client.client_id,
        oidc_scope: "openid profile",
        oidc_jti: SecureRandom.uuid,
        oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: 1.minute.ago,
        refresh_token_expires_at: 10.minutes.from_now,
      }
      case resource_type
      when "client"
        actor = clients(:one)
        root = ClientToken.create!(
          authentication_epoch: 0,
          user: actor, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
          user_token_status_id: ClientTokenStatus::ACTIVE,
        )
        rp_session = OpAppGrant.create!(authentication_epoch: 0, client_token: root, **grant_attributes)
      when "visitor"
        actor = visitors(:reserved_visitor)
        root = VisitorToken.create!(
          authentication_epoch: 0,
          visitor: actor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
          visitor_token_status_id: VisitorTokenStatus::ACTIVE,
        )
        rp_session = OpComGrant.create!(authentication_epoch: 0, visitor_token: root, **grant_attributes)
      when "operator"
        actor = operators(:one)
        # Operators allow two concurrent sessions; start from no live session.
        AuthenticationSessionRevoker.tokens_for(actor).find_each(&:revoke!)
        root = OperatorToken.create!(
          authentication_epoch: 0,
          staff: actor, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
          staff_token_status_id: OperatorTokenStatus::ACTIVE,
        )
        rp_session = OpOrgGrant.create!(authentication_epoch: 0, operator_token: root, **grant_attributes)
      end

      host!(base_host)
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
        actor,
        host: base_host,
        resource_type: resource_type,
        session_public_id: root.public_id,
        base_session_public_id: root.public_id,
        oidc_sid: rp_session.public_id,
        oidc_jti: rp_session.oidc_jti,
        expires_at: 10.minutes.from_now,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(client),
        audiences: [client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
        subject: OidcSubject.for(actor, resource_type: resource_type),
        client_id: client.client_id,
      )
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_session.issue_refresh_token!
      post "/sign/out", params: { ri: "jp" },
                        headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }

      assert_response :see_other
      authority = URI.parse(response.location)
      challenge = Rack::Utils.parse_nested_query(authority.query.to_s).fetch("logout_challenge")
      device_session = root.device_session_record
      base_access = AuthenticationToken.encode(
        actor,
        host: base_host,
        session_public_id: device_session.public_id,
        oidc_sid: device_session.public_id,
        oidc_jti: root.oidc_jti,
        resource_type: resource_type,
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
        authentication_context: root.authentication_context_value.to_s,
      )
      # The Cookie header replaces the jar, so it carries the Rails session holding the sign-out
      # proof, as the browser would.
      session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      base_cookie = [
        "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(base_access)}",
        "#{session_key}=#{Rack::Utils.escape(cookies.to_hash.fetch(session_key))}",
      ].join("; ")
      post authority.path, params: { logout_challenge: challenge, ri: "jp" }, headers: {
        "Cookie" => base_cookie,
        "HTTP_COOKIE" => base_cookie,
        "Origin" => "https://#{base_host}",
        "Sec-Fetch-Site" => "same-origin",
      }

      assert_response :see_other
      assert_not_predicate root.reload, :currently_usable?
      get URI.parse(response.location).request_uri

      assert_response :success
      form = inertia_props.fetch("form")
      failed_revoke = RpSessionRevoker::Result.new(success: false, revoked_count: 0)

      RpSessionRevoker.stub(:call, ->(**) { failed_revoke }) do
        post form.fetch("action"),
             params: form.slice("logout_challenge", "logout_intent_proof").merge("ri" => "jp"),
             headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
      end

      assert_response :ok
      assert_includes response.body, I18n.t("sign.shared.sign_out.cleanup_incomplete_description")
      assert inertia_page.fetch("clearHistory")
    end
  end
end
