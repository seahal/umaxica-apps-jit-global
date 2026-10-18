# typed: false
# frozen_string_literal: true

require "test_helper"

# Base starts its own RP authorization from the neutral entry; Auth remains a separate ceremony.
class BaseLocalAuthenticationEntryTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      name: "app",
      host_env: "PUBLIC_BASE_SERVICE_URL",
      auth_host_env: "PUBLIC_AUTH_SERVICE_URL",
      root_path: :base_app_root_path,
      sign_path: :base_app_sign_show_path,
      auth_path: :auth_app_sign_in_path,
    },
    {
      name: "com",
      host_env: "PUBLIC_BASE_CORPORATE_URL",
      auth_host_env: "PUBLIC_AUTH_CORPORATE_URL",
      root_path: :base_com_root_path,
      sign_path: :base_com_sign_show_path,
      auth_path: :auth_com_sign_in_path,
    },
    {
      name: "org",
      host_env: "PUBLIC_BASE_STAFF_URL",
      auth_host_env: "PUBLIC_AUTH_STAFF_URL",
      root_path: :base_org_root_path,
      sign_path: :base_org_sign_show_path,
      auth_path: :auth_org_sign_in_path,
    },
  ].freeze

  test "the anonymous root offers one neutral link to GET sign and no sign up choice" do
    SURFACES.each do |surface|
      host! ENV.fetch(surface.fetch(:host_env))

      get public_send(surface.fetch(:root_path), ri: "jp")

      assert_response :success, surface.fetch(:name)
      assert_equal public_send(surface.fetch(:sign_path), ri: "jp"), inertia_props.fetch("sign_in").fetch("href")
      assert_nil inertia_props["sign_up"], surface.fetch(:name)
    end
  end

  test "GET sign renders one POST form and issues no admission" do
    SURFACES.each do |surface|
      host! ENV.fetch(surface.fetch(:host_env))

      BaseAuthAdmissionCoordinator.stub(:issue_local_entry!, ->(**) { flunk("GET /sign must not issue") }) do
        get public_send(surface.fetch(:sign_path), ri: "jp")
      end

      assert_response :success, surface.fetch(:name)
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_includes response.body, %(action="#{public_send(surface.fetch(:sign_path), ri: "jp")}")
      assert_includes response.body, %(method="post")
      assert_not_includes response.body, "sign_up"
    end
  end

  test "POST sign starts Base self-RP authorization with PKCE and ignores a sign up intent" do
    SURFACES.each do |surface|
      base_host = ENV.fetch(surface.fetch(:host_env))
      host! base_host

      target_url = nil
      JumpRtIssuer.stub(
        :call, ->(**args) {
                 target_url = args.fetch(:url)
                 "signed-jump-token"
               },
      ) do
        RedirectsJumpGatewayUrl.stub(
          :call,
          ->(_token) { RedirectsTargetResult.ok(kind: :external, source: :test, value: target_url) },
        ) do
          post public_send(surface.fetch(:sign_path), ri: "jp"), params: { intent: "sign_up" }
        end
      end

      assert_response :see_other, surface.fetch(:name)
      location = URI.parse(response.location)

      assert_equal base_host, location.host
      assert_equal "/oauth/authorize", location.path
      query = Rack::Utils.parse_nested_query(location.query)

      assert_equal "base-#{surface.fetch(:name)}-ww", query["client_id"]
      assert_equal "https://#{base_host}/oidc/callback", query["redirect_uri"]
      assert_equal "code", query["response_type"]
      assert_equal "S256", query["code_challenge_method"]
      assert_match(/\A[A-Za-z0-9_-]{43}\z/, query.fetch("code_challenge"))
      assert_predicate query["state"], :present?
      assert_predicate query["nonce"], :present?
      assert_nil query["entry_ref"]
      assert_nil query["intent"]
      assert_nil query["screen_hint"]
    end
  end

  test "POST sign without the form authenticity token is rejected" do
    with_forgery_protection do
      host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

      post base_app_sign_show_path(ri: "jp"), headers: { "Sec-Fetch-Site" => "cross-site" }

      assert_response :unprocessable_entity
      assert_nil response.location
    end
  end

  test "POST sign from an authenticated browser is refused with a plain 403 and issues nothing" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    actor = clients(:one)
    headers = as_user_headers(actor, host: host)
    token = ClientToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    token.rotate_refresh_token!
    rp_client = OidcClientRegistry.find!("base-app-ww")
    rp_session = OpAppGrant.create!(
      client_token: token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.current,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    access = AuthenticationTokenService.encode(
      actor, host: host, resource_type: "client", session_public_id: token.public_id,
             base_session_public_id: token.public_id, oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
             expires_at: 10.minutes.from_now, scopes: %w(openid profile), issuer: OidcIssuer.for_client(rp_client),
             audiences: [rp_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
             subject: OidcSubject.for(actor, resource_type: "client"), client_id: rp_client.client_id,
    )
    cookie = [
      headers.fetch("Cookie"),
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access)}",
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_session.issue_refresh_token!)}",
    ].join("; ")
    headers = headers.merge("Cookie" => cookie, "HTTP_COOKIE" => cookie)

    BaseAuthAdmissionCoordinator.stub(:issue_local_entry!, ->(**) { flunk("must not issue") }) do
      post base_app_sign_show_path(ri: "jp"), headers: headers
    end

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil response.location
  end

  test "the old root POST is not routable" do
    SURFACES.each do |surface|
      host = ENV.fetch(surface.fetch(:host_env))

      assert_raises(ActionController::RoutingError, surface.fetch(:name)) do
        Rails.application.routes.recognize_path("https://#{host}/", method: :post)
      end
    end
  end

  private

  def with_forgery_protection
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
