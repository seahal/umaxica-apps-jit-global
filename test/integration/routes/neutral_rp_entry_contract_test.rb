# typed: false
# frozen_string_literal: true

require "test_helper"

class NeutralRpEntryContractTest < ActionDispatch::IntegrationTest
  setup do
    load_jump_rt_env!
  end

  RP_ROUTES = [
    {
      host: -> { ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost") },
      controller: "core/app/sign/entries",
      callback_controller: "core/app/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost") },
      controller: "core/com/sign/entries",
      callback_controller: "core/com/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost") },
      controller: "core/org/sign/entries",
      callback_controller: "core/org/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_WARP_SERVICE_URL", "warp.app.localhost") },
      controller: "warp/app/sign/entries",
      callback_controller: "warp/app/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_WARP_CORPORATE_URL", "warp.com.localhost") },
      controller: "warp/com/sign/entries",
      callback_controller: "warp/com/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_WARP_STAFF_URL", "warp.org.localhost") },
      controller: "warp/org/sign/entries",
      callback_controller: "warp/org/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_EDIT_STAFF_URL", "edit.org.localhost") },
      controller: "edit/org/sign/entries",
      callback_controller: "edit/org/oidc/callbacks",
    },
  ].freeze

  test "every first-party browser RP has neutral GET and POST sign entry routes" do
    RP_ROUTES.each do |rp|
      host = rp.fetch(:host).call

      assert_recognizes(
        { controller: rp.fetch(:controller), action: "show" },
        { path: "http://#{host}/sign", method: :get },
      )
      assert_recognizes(
        { controller: rp.fetch(:controller), action: "create" },
        { path: "http://#{host}/sign", method: :post },
      )
    end
  end

  test "every first-party browser RP has a protocol callback at sign callback" do
    RP_ROUTES.each do |rp|
      host = rp.fetch(:host).call

      assert_recognizes(
        { controller: rp.fetch(:callback_controller), action: "show" },
        { path: "http://#{host}/sign/callback", method: :get },
      )
    end
  end

  test "first-party browser RPs have no obsolete OIDC authorization controller" do
    files = %w(
      app/controllers/core/app/oidc/authorizations_controller.rb
      app/controllers/core/com/oidc/authorizations_controller.rb
      app/controllers/core/org/oidc/authorizations_controller.rb
      app/controllers/warp/app/oidc/authorizations_controller.rb
      app/controllers/warp/com/oidc/authorizations_controller.rb
      app/controllers/warp/org/oidc/authorizations_controller.rb
      app/controllers/edit/org/oidc/authorizations_controller.rb
    )

    offenders = files.select { |path| Rails.root.join(path).exist? }

    assert_empty offenders
  end

  test "the core browser RPs still do not own a dashboard page" do
    RP_ROUTES.first(3).each do |rp|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{rp.fetch(:host).call}/dashboard",
          method: :get,
        )
      end
    end
  end

  test "GET sign renders one neutral action without creating an OIDC transaction" do
    RP_ROUTES.each do |rp|
      host = rp.fetch(:host).call
      host!(host)

      get "/sign?ri=jp", headers: host_headers(host)

      assert_response :success
      forms = css_select("form")

      assert_equal 1, forms.length
      assert_equal "/sign", URI.parse(forms.first["action"]).path
      assert_equal "post", forms.first["method"]
      assert_select "input[name='screen_hint']", count: 0
      assert_no_match %r{/oauth/authorize}, response.body
      assert_nil session["oidc_pending_flows"]
      assert_nil session[:oidc_state]
      assert_nil session[:oidc_code_verifier]
    end
  end

  test "POST sign rejects a request without the Rails CSRF token" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    RP_ROUTES.each do |rp|
      host = rp.fetch(:host).call
      host!(host)

      post(
        "/sign", params: { pt: "/" }, headers: host_headers(host).merge(
          "Accept" => "text/html",
          "Origin" => "https://attacker.example",
          "Sec-Fetch-Site" => "cross-site",
        ),
      )

      assert_response :unprocessable_content
    end
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "POST sign creates a neutral state-indexed PKCE flow" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    RP_ROUTES.first(3).each do |rp|
      host = rp.fetch(:host).call
      host!(host)
      https!

      get("/sign?ri=jp", headers: host_headers(host))
      csrf_token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]

      assert_predicate csrf_token, :present?
      post(
        "/sign", params: {
          pt: "/dashboard",
          ri: "jp",
          authenticity_token: csrf_token,
        }, headers: host_headers(host),
      )

      assert_response :redirect
      authorize_location = jump_rt_url_from_location(response.location)
      authorize_uri = URI.parse(authorize_location)
      authorize_query = Rack::Utils.parse_nested_query(authorize_uri.query.to_s)

      assert_equal "/oauth/authorize", authorize_uri.path
      assert_nil authorize_query["screen_hint"]
      assert_predicate authorize_query["state"], :present?
      assert_predicate authorize_query["nonce"], :present?
      assert_predicate authorize_query["code_challenge"], :present?
      assert_equal "S256", authorize_query["code_challenge_method"]
      assert_equal "/sign/callback", URI.parse(authorize_query.fetch("redirect_uri")).path

      pending_flow = session.fetch("oidc_pending_flows").fetch(authorize_query.fetch("state"))

      assert_equal "/dashboard", pending_flow.fetch("pt")
      assert_equal authorize_query.fetch("nonce"), pending_flow.fetch("nonce")
      assert_predicate pending_flow.fetch("code_verifier"), :present?
      assert_nil session[:oidc_state]
      assert_nil session[:oidc_nonce]
      assert_nil session[:oidc_code_verifier]
    end
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "an authenticated browser receives a plain refusal instead of a new RP flow" do
    host = RP_ROUTES.first.fetch(:host).call
    host!(host)

    authenticated_headers = as_user_headers(clients(:one), host: host)
    session_public_id = authenticated_headers.fetch("X-TEST-SESSION-PUBLIC-ID")
    access_token = AuthenticationToken.encode(
      clients(:one),
      host: host,
      session_public_id: session_public_id,
      resource_type: "client",
      jwt_issuer_id: "surface:CORE_APP",
    )
    authenticated_headers.delete("Authorization")
    authenticated_headers["Cookie"] = "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}"
    authenticated_headers["HTTP_COOKIE"] = authenticated_headers["Cookie"]

    post "/sign", params: { pt: "/" }, headers: authenticated_headers

    assert_response :conflict
    assert_equal AlreadyAuthenticatedError::MESSAGE, response.body
    assert_equal "text/plain", response.media_type
  end

  test "an RP-authenticated browser receives a plain refusal instead of a new RP flow" do
    host = RP_ROUTES.first.fetch(:host).call
    host!(host)
    client = clients(:one)
    oidc_client = OidcClientRegistry.find!("core-app")
    access_token = AuthenticationTokenService.encode(
      client,
      host: host,
      resource_type: "client",
      session_public_id: "rp-entry-contract-session",
      oidc_sid: "rp-entry-contract-session",
      oidc_jti: SecureRandom.uuid,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(oidc_client),
      audiences: [oidc_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(client, resource_type: "client"),
      client_id: oidc_client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token

    post "/sign", params: { pt: "/" }, headers: host_headers(host)

    assert_response :conflict
    assert_equal AlreadyAuthenticatedError::MESSAGE, response.body
    assert_equal "text/plain", response.media_type
    assert_nil session["oidc_pending_flows"]
  end

  test "an RP credential for another surface does not block the current RP" do
    host = RP_ROUTES.first.fetch(:host).call
    host!(host)
    visitor = visitors(:reserved_visitor)
    oidc_client = OidcClientRegistry.find!("core-com")
    access_token = AuthenticationTokenService.encode(
      visitor,
      host: host,
      resource_type: "visitor",
      session_public_id: "cross-surface-rp-entry-session",
      oidc_sid: "cross-surface-rp-entry-session",
      oidc_jti: SecureRandom.uuid,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(oidc_client),
      audiences: [oidc_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(oidc_client),
      subject: OidcSubject.for(visitor, resource_type: "visitor"),
      client_id: oidc_client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token

    post "/sign", params: { pt: "/" }, headers: host_headers(host)

    assert_response :redirect
    assert_predicate session.fetch("oidc_pending_flows"), :present?
  end

  private

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    payload, = JWT.decode(token, nil, false)
    payload.fetch("url")
  end

  def load_jump_rt_env!
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end
end
