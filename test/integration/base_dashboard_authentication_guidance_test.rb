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
      before = token.attributes.slice(
        "user_token_status_id", "visitor_token_status_id", "staff_token_status_id", "discard_at",
        "refresh_token_digest", "last_step_up_at",
      )
      cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
        actor, host: host, session_public_id: token.public_id,
               resource_type: { "app" => "client", "com" => "visitor", "org" => "operator" }.fetch(surface),
               jwt_issuer_id: "surface:BASE_#{surface.upcase}",
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
      assert_difference(-> { flow_model.count }, 1) do
        post(
          "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
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
      flow = flow_model.find_by!(public_id: query.fetch("entry_ref"))

      assert_nil flow.principal_id
      assert_nil flow.token_id
      # Simulate delivery of the verified outbound target, with a distinct Auth cookie jar.
      # This does not run the external gateway or its return-token verifier.
      auth_browser = open_session
      auth_browser.host!(auth_host)
      auth_browser.https!
      auth_browser.get(target.request_uri)

      assert_equal 200, auth_browser.response.status
      assert_includes auth_browser.response.body, 'name="authenticity_token"'
      assert_nil flow.reload.token_id
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
