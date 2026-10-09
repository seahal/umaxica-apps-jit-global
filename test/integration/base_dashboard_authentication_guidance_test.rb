# frozen_string_literal: true

require "test_helper"

class BaseDashboardAuthenticationGuidanceTest < ActionDispatch::IntegrationTest
  [
    ["app", "PUBLIC_BASE_SERVICE_URL", ClientSignInFlow, ClientToken, :user_id,
     :user_token_kind_id, ClientTokenKind::BROWSER_WEB,],
    ["com", "PUBLIC_BASE_CORPORATE_URL", VisitorSignInFlow, VisitorToken, :visitor_id,
     :visitor_token_kind_id, VisitorTokenKind::BROWSER_WEB,],
    ["org", "PUBLIC_BASE_STAFF_URL", OperatorSignInFlow, OperatorToken, :staff_id,
     :staff_token_kind_id, OperatorTokenKind::BROWSER_WEB,],
  ].each do |surface, host_key, flow_model, token_model, owner_key, kind_key, kind|
    test "#{surface} authenticated Sign GET and HEAD are passive while new POST is terminally refused" do
      previous = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      host = ENV.fetch(host_key)
      host!(host)
      actor =
        case surface
        when "app" then clients(:one)
        when "com" then visitors(:reserved_visitor)
        when "org" then operators(:one)
        end
      token = token_model.create!(owner_key => actor.id, kind_key => kind)
      # Base UI is a Browser RP of itself: only its RP credential makes the browser authenticated.
      begin
        rp_cookie_pairs =
          begin
            rp_client_id = { "app" => "base-app-ww",
                             "com" => "base-com-ww",
                             "org" => "base-org-ww", }.fetch(surface)
            rp_surface = surface
            rp_host = host
            rp_actor = actor
            rp_token = token
            @base_browser_rp_credentials ||= {}
            rp_key = [rp_client_id, rp_token.public_id]
            rp_client = OidcClientRegistry.find!(rp_client_id)
            rp_resource_type = { "app" => "client",
                                 "com" => "visitor",
                                 "org" => "operator", }.fetch(rp_surface)
            rp_model = { "app" => ClientRpSession,
                         "com" => VisitorRpSession,
                         "org" => OperatorRpSession, }.fetch(rp_surface)
            rp_token_key = { "app" => :client_token,
                             "com" => :visitor_token,
                             "org" => :operator_token, }.fetch(rp_surface)
            if @base_browser_rp_credentials[rp_key] ||
                (rp_token.currently_usable? &&
                  !(rp_token.device_session_id && rp_model.exists?(
                    device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                  )))
              unless @base_browser_rp_credentials[rp_key]
                rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
                rp_now = Time.current
                rp_session = rp_model.create!(
                  rp_token_key => rp_token,
                  :oidc_client_id => rp_client.client_id,
                  :oidc_scope => "openid profile",
                  :oidc_jti => SecureRandom.uuid,
                  :oidc_nonce => SecureRandom.hex(16),
                  :oidc_auth_time => rp_now,
                  :refresh_token_expires_at => rp_now + 10.minutes,
                )
                rp_access = AuthenticationTokenService.encode(
                  rp_actor,
                  host: rp_host, resource_type: rp_resource_type,
                  session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                  oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                  expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                  issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                  jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                  subject: OidcSubject.for(rp_actor, resource_type: rp_resource_type), client_id: rp_client.client_id,
                )
                @base_browser_rp_credentials[rp_key] =
                  [rp_access, rp_session.issue_refresh_token!]
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
      token.reload
      before = token.attributes.slice(
        "user_token_status_id", "visitor_token_status_id", "staff_token_status_id", "discard_at",
        "refresh_token_digest", "last_step_up_at",
      )
      assert_no_difference(-> { flow_model.count }) do
        get("/sign", params: { ri: "jp" })

        assert_response :success
        assert_select 'form[method="post"][action="/sign?ri=jp"]', count: 1
        csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        head "/sign", params: { ri: "jp" }

        assert_response :success
        assert_empty response.body
        post(
          "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
            "Origin" => "http://#{host}", "Sec-Fetch-Site" => "same-origin",
          },
        )

        assert_response :forbidden
        assert_nil response.location
        assert_not_includes response.body, "<form"
      end
      assert_equal before, token.reload.attributes.slice(*before.keys)
    ensure
      ActionController::Base.allow_forgery_protection = previous
    end
  end

  [
    ["app", "PUBLIC_BASE_SERVICE_URL", ClientSignInFlow],
    ["com", "PUBLIC_BASE_CORPORATE_URL", VisitorSignInFlow],
    ["org", "PUBLIC_BASE_STAFF_URL", OperatorSignInFlow],
  ].each do |surface, host_key, flow_model|
    test "#{surface} explicit anonymous Sign POST issues one real signed Jump to the matching Auth entry" do
      previous = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      host = ENV.fetch(host_key)
      host!(host)
      https!
      get("/sign", params: { ri: "jp" })
      csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      # The RP start and the plain authorization GET mint nothing; only the receiver-local
      # ceremony start POST creates the sign-in flow and its browser binding (D-82).
      assert_no_difference(-> { flow_model.count }) do
        post(
          "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
            "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
          },
        )

        assert_response :see_other
        # The RP start reaches its own authorization endpoint through the signed Jump gateway.
        start_issuer = JitSecurityJwtRegistry.surface("BASE_#{surface.upcase}")
        start_payload, = JWT.decode(
          Rack::Utils.parse_query(URI.parse(response.location).query).fetch("rt"),
          JitSecurityJwtRegistry.public_key_for(start_issuer.id, start_issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        authorization = URI.parse(start_payload.fetch("url"))

        assert_equal [host, "/oauth/authorize"], [authorization.host, authorization.path]
        authorization_query = Rack::Utils.parse_query(authorization.query)

        assert_equal "base-#{surface}-ww", authorization_query.fetch("client_id")
        assert_equal "S256", authorization_query.fetch("code_challenge_method")
        get(authorization.request_uri)

        assert_response :success
        assert_select 'form[method="post"] input[name="ceremony_action"][value="start"]', count: 1
      end
      start_form = response.parsed_body.at_css('form[method="post"]')
      start_params = start_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      binding_model =
        { "app" => ClientAuthAdmissionBinding,
          "com" => VisitorAuthAdmissionBinding,
          "org" => OperatorAuthAdmissionBinding, }.fetch(surface)
      assert_difference(-> { binding_model.count }, 1) do
        post(
          start_form["action"], params: start_params, headers: {
            "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
          },
        )
      end

      assert_response :see_other
      gateway = URI.parse(response.location)
      configured_gateway = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin)

      assert_equal configured_gateway.host, gateway.host
      assert_equal "https", gateway.scheme
      rt = Rack::Utils.parse_query(gateway.query).fetch("rt")
      issuer = JitSecurityJwtRegistry.surface("BASE_#{surface.upcase}")
      payload, header = JWT.decode(
        rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )

      assert_equal issuer.current_kid, header.fetch("kid")
      assert_equal "jump-redirect", payload.fetch("sub")
      target = URI.parse(payload.fetch("url"))
      auth_host = ENV.fetch(
        {
          "app" => "PUBLIC_AUTH_SERVICE_URL",
          "com" => "PUBLIC_AUTH_CORPORATE_URL",
          "org" => "PUBLIC_AUTH_STAFF_URL",
        }.fetch(surface),
      )

      assert_equal auth_host, target.host
      assert_equal "/sign/in", target.path
      query = Rack::Utils.parse_query(target.query)

      assert_equal "jp", query.fetch("ri")
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: surface, reference: query.fetch("entry_ref"),
      )

      # The OIDC start binds its authorization transaction, not an authenticated actor or session.
      assert_predicate binding.authorization_transaction_id, :present?
      assert_nil binding.base_token_id
      assert_nil binding.redeemed_at
      # Simulate delivery of the verified outbound target, with a distinct Auth cookie jar.
      # This does not run the external gateway or its return-token verifier.
      auth_browser = open_session
      auth_browser.host!(auth_host)
      auth_browser.https!
      auth_browser.get(target.request_uri)

      assert_equal 200, auth_browser.response.status
      assert_includes auth_browser.response.body, 'name="authenticity_token"'
      assert_nil binding.reload.redeemed_at
    ensure
      ActionController::Base.allow_forgery_protection = previous
    end

    test "#{surface} anonymous Sign POST without CSRF never issues an admission" do
      previous = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      host!(ENV.fetch(host_key))
      assert_no_difference(-> { flow_model.count }) do
        post("/sign", params: { ri: "jp" }, headers: { "Sec-Fetch-Site" => "cross-site" })

        assert_response :unprocessable_content
        assert_nil response.location
      end
    ensure
      ActionController::Base.allow_forgery_protection = previous
    end

    test "#{surface} anonymous HTML Dashboard reaches passive Sign without issuing an admission" do
      host! ENV.fetch(host_key)
      assert_no_difference(-> { flow_model.count }) do
        get "/dashboard", params: { ri: "jp" }

        assert_response :redirect
        destination = URI.parse(response.location)

        assert_equal "/sign", destination.path
        assert_includes [nil, ENV.fetch(host_key)], destination.host
        assert_equal "jp", Rack::Utils.parse_query(destination.query).fetch("ri")
        assert_not_includes destination.query.to_s, "entry_ref"
        follow_redirect!

        assert_response :success
        assert_select "form[method=post]"
      end
    end

    test "#{surface} anonymous JSON Dashboard refuses access without login HTML" do
      host! ENV.fetch(host_key)
      assert_no_difference(-> { flow_model.count }) do
        get "/dashboard", params: { ri: "jp" }, headers: { "Accept" => "application/json" }

        assert_response :unauthorized
        assert_nil response.location
        assert_equal "application/json", response.media_type
      end
    end

    test "#{surface} anonymous Inertia Dashboard uses the existing location response" do
      host! ENV.fetch(host_key)
      assert_no_difference(-> { flow_model.count }) do
        get "/dashboard", params: { ri: "jp" }, headers: {
          "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version,
        }

        assert_response :conflict
        assert_equal "/sign", URI.parse(response.headers.fetch("X-Inertia-Location")).path
      end
    end

    test "#{surface} anonymous HEAD Dashboard has no body and starts no admission" do
      host! ENV.fetch(host_key)
      assert_no_difference(-> { flow_model.count }) do
        head "/dashboard", params: { ri: "jp" }

        assert_response :redirect
        assert_equal "/sign", URI.parse(response.location).path
        assert_empty response.body
      end
    end
  end
end
