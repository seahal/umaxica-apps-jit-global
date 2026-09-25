# typed: false
# frozen_string_literal: true

require "test_helper"

class WarpSsoStartContractTest < ActionDispatch::IntegrationTest
  SURFACES = {
    "app" => {
      host: "PUBLIC_WARP_SERVICE_URL",
      client_id: "side-app",
      issuer: "https://www-jp.umaxica.app",
    },
    "com" => {
      host: "PUBLIC_WARP_CORPORATE_URL",
      client_id: "side-com",
      issuer: "https://www-jp.umaxica.com",
    },
    "org" => {
      host: "PUBLIC_WARP_STAFF_URL",
      client_id: "side-org",
      issuer: "https://www-jp.umaxica.org",
    },
  }.freeze

  test "cross-site sign-in starts issue a surface-bound Jump RT on app com and org" do
    previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    begin
      SURFACES.each do |surface, contract|
        reset!
        https!
        host!(ENV.fetch(contract.fetch(:host)))

        get("/sign", params: { ri: "jp" })

        assert_response :success, "#{surface} sign-in entry must render before the POST"
        csrf_token = response.body[/name="authenticity_token"[^>]+value="([^"]+)"/, 1]

        assert_predicate csrf_token, :present?, "#{surface} sign-in entry must carry Rails CSRF proof"

        post(
          "/sign",
          params: { ri: "jp", pt: "/dashboard?ri=jp", authenticity_token: csrf_token },
          headers: { "Sec-Fetch-Site" => "same-origin" },
        )

        assert_response :redirect, "#{surface} SSO start must not return the historical 422"
        gateway = URI.parse(response.location)
        gateway_origin = ConfigValues::JumpGatewayValues.build(
          env: ENV,
          production: Rails.env.production?,
        ).origin

        assert_equal [gateway_origin.scheme, gateway_origin.host, gateway_origin.port],
                     [gateway.scheme, gateway.host, gateway.port]
        assert_equal "/", gateway.path

        query = Rack::Utils.parse_query(gateway.query)

        assert_equal ["rt"], query.keys
        payload, header = JWT.decode(query.fetch("rt"), nil, false)

        assert_equal contract.fetch(:issuer), payload.fetch("iss")
        assert_equal JitSecurityJwtRegistry.surface("WARP_#{surface.upcase}").current_kid, header.fetch("kid")

        authorization = URI.parse(payload.fetch("url"))
        authorization_query = Rack::Utils.parse_query(authorization.query)

        assert_equal contract.fetch(:client_id), authorization_query.fetch("client_id")
        registered_client = OidcClientRegistry.find!(contract.fetch(:client_id))

        assert_includes registered_client.redirect_uris, authorization_query.fetch("redirect_uri")
        assert_equal "jp", authorization_query.fetch("ri")
      end
    ensure
      ActionController::Base.allow_forgery_protection = previous_forgery_protection
    end
  end

  test "missing Jump RT signing keys raise a configuration failure on app com and org" do
    previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    begin
      SURFACES.each do |surface, contract|
        reset!
        https!
        host!(ENV.fetch(contract.fetch(:host)))

        get("/sign", params: { ri: "jp" })

        assert_response :success, "#{surface} sign-in entry must render before the POST"
        csrf_token = response.body[/name="authenticity_token"[^>]+value="([^"]+)"/, 1]

        assert_predicate csrf_token, :present?, "#{surface} sign-in entry must carry Rails CSRF proof"

        JumpRtKeyring.stub(:active_kid, nil) do
          error =
            assert_raises(JumpRtConfigurationError, surface) do
              post(
                "/sign",
                params: { ri: "jp", pt: "/dashboard?ri=jp", authenticity_token: csrf_token },
                headers: { "Sec-Fetch-Site" => "same-origin" },
              )
            end

          assert_match(/signing key/, error.message)
        end
      end
    ensure
      ActionController::Base.allow_forgery_protection = previous_forgery_protection
    end
  end
end
