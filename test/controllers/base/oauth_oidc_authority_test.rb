# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
# require "helpers/auth_helpers"

class BaseOauthOidcAuthorityTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
  # include AuthHelpers

  TokenResult =
    Struct.new(:success, :token_response, :error, :error_description, keyword_init: true) do
      def success? = success
    end

  AuthResult =
    Struct.new(:success, :payload, :token, :resource, :error, keyword_init: true) do
      def success? = success
    end

  RevocationResult =
    Struct.new(:success, :error, :error_description, keyword_init: true) do
      def success? = success
    end

  test "base app well-known discovery advertises base issuer and protocol endpoints" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    get base_app_well_known_openid_configuration_url(host: host)

    assert_response :ok
    body = response.parsed_body
    issuer = OidcIssuer.for_resource_type("client")

    assert_equal issuer, body["issuer"]
    assert_equal "#{issuer}/oauth/authorize", body["authorization_endpoint"]
    assert_equal "#{issuer}/oauth/token", body["token_endpoint"]
    assert_equal "#{issuer}/oauth/userinfo", body["userinfo_endpoint"]
    assert_equal "#{issuer}/oauth/revoke", body["revocation_endpoint"]
    assert_equal "#{issuer}/oidc/logout", body["end_session_endpoint"]
    assert_equal "#{issuer}/.well-known/jwks.json", body["jwks_uri"]
  end

  test "base com and org well-known discovery advertise surface-specific base issuers" do
    get base_com_well_known_openid_configuration_url(host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"))

    assert_response :ok
    assert_equal OidcIssuer.for_resource_type("visitor"), response.parsed_body["issuer"]

    get base_org_well_known_openid_configuration_url(host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"))

    assert_response :ok
    assert_equal OidcIssuer.for_resource_type("operator"), response.parsed_body["issuer"]
  end

  test "sign discovery route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")}/.well-known/openid-configuration",
        method: :get,
      )
    end
  end

  test "sign jwks remains public compatibility metadata only" do
    get sign_app_well_known_jwks_url(host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"))

    assert_response :ok
    response.parsed_body.fetch("keys").each do |key|
      assert_equal "ES384", key.fetch("alg")
      assert_not key.key?("d"), "private key material must not be exposed"
    end
  end

  test "oidc issuer uses base hosts and signing namespaces" do
    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"), OidcIssuer.host_for_resource_type("client")
    assert_equal ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
                 OidcIssuer.host_for_resource_type("visitor")
    assert_equal ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"), OidcIssuer.host_for_resource_type("operator")
    assert_equal "surface:BASE_APP", OidcIssuer.jwt_issuer_id_for_resource_type("client")
    assert_equal "surface:BASE_COM", OidcIssuer.jwt_issuer_id_for_resource_type("visitor")
    assert_equal "surface:BASE_ORG", OidcIssuer.jwt_issuer_id_for_resource_type("operator")
  end

  test "base token endpoint delegates exchange with base endpoint binding" do
    captured = nil
    result = TokenResult.new(
      success: true,
      token_response: { access_token: "access", refresh_token: "refresh", token_type: "Bearer" },
    )

    OidcTokenExchangeCoordinator.stub(:call, ->(**kwargs) { captured = kwargs; result }) do
      post base_app_oauth_token_url(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")),
           params: {
             grant_type: "authorization_code",
             code: "code",
             redirect_uri: "https://client.example/callback",
             client_id: "core-next-rp",
             client_secret: "secret",
             code_verifier: "verifier",
           },
           headers: { "DPoP" => "proof" }
    end

    assert_response :ok
    assert_equal "proof", captured[:dpop_proof]
    assert_equal "POST", captured[:request_method]
    assert_includes captured[:token_endpoint_uri], "/oauth/token"
    assert_includes captured[:token_endpoint_uri], ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "no-cache", response.headers["Pragma"]
  end

  test "base token endpoint rejects missing csrf metadata with oauth json error instead of csrf 422" do
    result = TokenResult.new(
      success: false,
      error: "invalid_grant",
      error_description: "invalid_code",
    )

    OidcTokenExchangeCoordinator.stub(:call, ->(**) { result }) do
      post base_app_oauth_token_url(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")),
           params: {
             grant_type: "authorization_code",
             code: "bad-code",
             redirect_uri: "https://client.example/callback",
             client_id: "core-next-rp",
             client_secret: "secret",
             code_verifier: "verifier",
           }
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
    assert_equal "invalid_code", response.parsed_body["error_description"]
  end

  test "sign token endpoint is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")}/oauth/token",
        method: :post,
      )
    end
  end

  test "base well-known discovery uses the external openid configuration path" do
    assert_recognizes_base_route(
      ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      "/.well-known/openid-configuration",
      :get,
      "base/app/well_known/discoveries",
      "show",
    )
    assert_recognizes_base_route(
      ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
      "/.well-known/openid-configuration",
      :get,
      "base/com/well_known/discoveries",
      "show",
    )
    assert_recognizes_base_route(
      ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      "/.well-known/openid-configuration",
      :get,
      "base/org/well_known/discoveries",
      "show",
    )
  end

  test "base token endpoint rejects get" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")}/oauth/token",
        method: :get,
      )
    end
  end

  test "base authorize endpoint uses request windows and ignores old token history" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    Rails.configuration.x.rate_limit.fetch(:store).clear

    create_old_client_tokens(count: 25)

    get base_app_oauth_authorization_url(
      host: host,
      **oidc_authorize_params(scope: "openid"),
    ), headers: { "Host" => host }

    assert_response :redirect
    assert_not_equal 429, response.status
  end

  test "base authorize endpoint rate limits repeated requests and sets retry after" do
    profile_set = RateLimitProfiles::AuthorizeProfileSet.new(
      ip_surface: RateLimitProfiles::Profile.new(to: 1, within: 1.minute, retry_after: 60),
      browser_client: RateLimitProfiles::Profile.new(to: 100, within: 1.minute, retry_after: 60),
      client_redirect_host: RateLimitProfiles::Profile.new(to: 100, within: 10.minutes, retry_after: 600),
    )

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    Rails.configuration.x.rate_limit.fetch(:store).clear

    logs = []
    Rails.logger.stub(:info, ->(*args, &_block) { logs << args.first if args.first.present? }) do
      RateLimitProfiles.stub(:oauth_authorize, profile_set) do
        get base_app_oauth_authorization_url(
          host: host,
          **oidc_authorize_params(scope: "openid"),
        ), headers: { "Host" => host }

        assert_response :redirect

        get base_app_oauth_authorization_url(
          host: host,
          **oidc_authorize_params(scope: "openid"),
        ), headers: { "Host" => host }

        assert_response :too_many_requests
        assert_equal "rails", response.headers["X-RateLimit-Layer"]
        assert_equal "oauth_authorize_ip_surface", response.headers["X-RateLimit-Rule"]
        assert_equal "60", response.headers["Retry-After"]
      end
    end

    assert logs.any? { |message| message.include?("oidc.authorize.rate_limited") }
  end

  test "base userinfo authenticates against base request binding" do
    captured = nil
    result = AuthResult.new(success: false, error: "invalid_token")

    OidcAccessTokenAuthenticator.stub(:call, ->(**kwargs) { captured = kwargs; result }) do
      get base_app_oauth_userinfo_url(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")),
          headers: { "Authorization" => "Bearer access", "DPoP" => "proof" }
    end

    assert_response :unauthorized
    assert_equal "client", captured[:resource_type]
    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"), captured[:host]
    assert_equal "Bearer", captured[:authorization_scheme]
    assert_equal "proof", captured[:dpop_proof]
  end

  # Each surface serves userinfo for its own principal type, and the subject it
  # answers with is derived from that type. A surface that serialised against the
  # wrong type would hand one tenant's subject identifier to another.
  {
    "app" => [:base_app_oauth_userinfo_url, "PUBLIC_BASE_SERVICE_URL", "client"],
    "com" => [:base_com_oauth_userinfo_url, "PUBLIC_BASE_CORPORATE_URL", "visitor"],
    "org" => [:base_org_oauth_userinfo_url, "PUBLIC_BASE_STAFF_URL", "operator"],
  }.each do |surface, (helper, host_env, resource_type)|
    test "base #{surface} userinfo serialises the authenticated principal for its own type" do
      host = ENV.fetch(host_env)
      resource = Struct.new(:id, :public_id, :name, :email).new(1, "principal-1", "Sample Name", "sample@example.com")
      payload = { "act" => resource_type,
                  "scp" => %w(openid profile email),
                  "acr" => "aal1",
                  "auth_time" => 1_756_000_000, }
      result = AuthResult.new(success: true, resource: resource, payload: payload)

      OidcAccessTokenAuthenticator.stub(:call, ->(**) { result }) do
        get public_send(helper, host: host), headers: { "Authorization" => "Bearer access" }
      end

      assert_response :ok
      body = response.parsed_body

      assert_equal OidcSubject.for(resource, resource_type: resource_type), body["sub"]
      assert_equal "aal1", body["acr"]
      assert_equal "Sample Name", body["name"]
      assert_equal "sample@example.com", body["email"]
      assert body["email_verified"]
    end
  end

  test "base userinfo returns bearer challenge headers on invalid token and insufficient scope" do
    invalid_result = AuthResult.new(success: false, error: "invalid_token")
    insufficient_result = AuthResult.new(success: false, error: "insufficient_scope")

    OidcAccessTokenAuthenticator.stub(:call, ->(**) { invalid_result }) do
      get base_app_oauth_userinfo_url(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"))

      assert_response :unauthorized
      assert_equal 'Bearer error="invalid_token"', response.headers["WWW-Authenticate"]
    end

    OidcAccessTokenAuthenticator.stub(:call, ->(**) { insufficient_result }) do
      get base_app_oauth_userinfo_url(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"))

      assert_response :forbidden
      assert_equal 'Bearer error="insufficient_scope", scope="openid"', response.headers["WWW-Authenticate"]
    end
  end

  test "sign userinfo endpoint is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")}/oauth/userinfo",
        method: :get,
      )
    end
  end

  test "base revocation delegates with base host binding" do
    captured = nil
    result = RevocationResult.new(success: true)

    OidcTokenRevoker.stub(:call, ->(**kwargs) { captured = kwargs; result }) do
      post base_app_oauth_revocation_url(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")),
           params: {
             token: "refresh",
             client_id: "core-next-rp",
             client_secret: "secret",
             token_type_hint: "refresh_token",
           }
    end

    assert_response :ok
    assert_equal "refresh", captured[:token]
    assert_equal "core-next-rp", captured[:client_id]
    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"), captured[:host]
  end

  test "base com revocation delegates with com host binding" do
    captured = nil
    result = RevocationResult.new(success: true)
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")

    OidcTokenRevoker.stub(:call, ->(**kwargs) { captured = kwargs; result }) do
      post base_com_oauth_revocation_url(host: host),
           params: {
             token: "refresh",
             client_id: "core-next-rp",
             client_secret: "secret",
             token_type_hint: "refresh_token",
           }
    end

    assert_response :ok
    assert_equal "refresh", captured[:token]
    assert_equal "core-next-rp", captured[:client_id]
    assert_equal host, captured[:host]
  end

  test "base com revocation returns unauthorized when the revoker fails" do
    result = RevocationResult.new(success: false, error: "invalid_client", error_description: "bad secret")
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")

    OidcTokenRevoker.stub(:call, ->(**) { result }) do
      post base_com_oauth_revocation_url(host: host),
           params: {
             token: "refresh",
             client_id: "core-next-rp",
             client_secret: "wrong",
           }
    end

    assert_response :unauthorized
    assert_equal "invalid_client", response.parsed_body.fetch("error")
    assert_equal "bad secret", response.parsed_body.fetch("error_description")
  end

  test "sign revocation endpoint is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")}/oauth/revoke",
        method: :post,
      )
    end
  end

  test "base edge token refresh is post only and does not accept url-only mutation" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")}/edge/v0/token/refresh",
        method: :get,
      )
    end

    assert_equal(
      "base/app/edge/v0/token/refreshes#create",
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")}/edge/v0/token/refresh",
        method: :post,
      ).values_at(:controller, :action).join("#"),
    )
  end

  test "base app token check authenticates a valid client session" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    token_record = ClientToken.create!(user: user)
    token_record.rotate_refresh_token!
    access_token = AuthenticationToken.encode(
      user,
      host: host,
      session_public_id: token_record.device_session.public_id,
      oidc_jti: token_record.oidc_jti,
      resource_type: "client",
      jwt_issuer_id: "surface:BASE_APP",
    )

    host!(host)

    get "/edge/v0/token/check",
        headers: { "Host" => host, "Accept" => "application/json", "Authorization" => "Bearer #{access_token}" },
        as: :json

    assert_response :ok
    assert response.parsed_body["authenticated"]
    assert_equal "client", response.parsed_body["type"]
    assert_equal user.id, response.parsed_body["id"]
    assert_equal token_record.device_session.public_id, response.parsed_body["sid"]
  end

  test "base org token check authenticates a valid operator session" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    staff = operators(:one)
    token_record = OperatorToken.create!(staff: staff)
    token_record.rotate_refresh_token!
    access_token = AuthenticationToken.encode(
      staff,
      host: host,
      session_public_id: token_record.device_session.public_id,
      oidc_jti: token_record.oidc_jti,
      resource_type: "operator",
      jwt_issuer_id: "surface:BASE_ORG",
    )

    host!(host)

    get "/edge/v0/token/check",
        headers: { "Host" => host, "Accept" => "application/json", "Authorization" => "Bearer #{access_token}" },
        as: :json

    assert_response :ok
    assert response.parsed_body["authenticated"]
    assert_equal "operator", response.parsed_body["type"]
    assert_equal staff.id, response.parsed_body["id"]
    assert_equal token_record.device_session.public_id, response.parsed_body["sid"]
  end

  test "base app token check without credentials returns unauthorized" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")

    host!(host)
    get "/edge/v0/token/check", headers: { "Host" => host, "Accept" => "application/json" }, as: :json

    assert_response :unauthorized
    assert_equal({ "authenticated" => false }, response.parsed_body)
  end

  test "base edge token refresh rejects missing refresh token without rotation" do
    AcmeRefreshTokenIssuer.stub(:call, ->(**) { flunk("refresh rotation must not run without a token") }) do
      post base_app_edge_v0_token_refresh_url(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")),
           as: :json
    end

    assert_response :bad_request
    assert_equal "missing_refresh_token", response.parsed_body["error_code"]
  end

  test "refresh authority source uses base service not sign refresh service" do
    source = Rails.root.join("app/controllers/concerns/authentication_base.rb").read

    assert_includes source, "AcmeRefreshTokenIssuer.call"
    assert_not_includes source, "SignRefreshTokenIssuer.call"

    %w(app com org).each do |surface|
      assert_not Rails.root.join("app/controllers/sign/#{surface}/edge/v0/token/refreshes_controller.rb").exist?
    end
  end

  test "base oidc logout consumes signed request and completes on base sign out" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    ensure_user_token_reference_records!
    token = ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    logout_request = OidcLogoutRequest.issue(client_id: "base-rails-rp", ri: "jp")

    get(
      base_app_oidc_logout_url(host: host),
      params: {
        client_id: "base-rails-rp",
        logout_request: logout_request,
        ri: "jp",
      },
      headers: as_user_headers(user, host: host, session_public_id: token.public_id),
    )

    assert_response :ok
    assert_not_predicate token.reload, :revoked?

    post(
      base_app_oidc_logout_url(host: host),
      params: {
        client_id: "base-rails-rp",
        logout_request: logout_request,
        ri: "jp",
      },
      headers: as_user_headers(user, host: host, session_public_id: token.public_id),
    )

    assert_response :success
    assert_not_predicate token.reload, :revoked?
    assert_includes response.body, I18n.t("sign.shared.sign_out.title")
    assert_match(
      /#{Regexp.escape(I18n.t("sign.shared.sign_out.confirm_description"))}|すでにサインアウトしています。/,
      response.body,
    )
  end

  test "base oauth authorize starts sign in ceremony on unauthenticated requests" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host!(host)

    get "/oauth/authorize", params: oidc_authorize_params, headers: browser_headers

    assert_response :redirect
    uri = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), uri.host
    assert_equal "/sign/in", uri.path
    assert_predicate query["login_challenge"], :present?

    transaction = ClientOidcAuthorizationTransaction.find_by!(login_challenge: query["login_challenge"])

    assert_equal "app", transaction.surface
    assert_equal "sign_in", transaction.intent
    assert_equal "openid profile", transaction.scope
  end

  test "base oauth authorize issues a code immediately for an already authenticated browser session" do
    [
      {
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
        actor: clients(:one),
        token: ->(actor) do
          ensure_user_token_reference_records!
          ClientToken.create!(
            user: actor,
            user_token_kind_id: ClientTokenKind::BROWSER_WEB,
            user_token_status_id: ClientTokenStatus::ACTIVE,
            user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
            user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
          )
        end,
        transaction_class: ClientOidcAuthorizationTransaction,
        resource_type: "client",
        header_builder: ->(actor, host:, session_public_id:) do
          as_user_headers(actor, host: host, session_public_id: session_public_id)
        end,
      },
      {
        host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
        actor: operators(:one),
        token: ->(actor) do
          ensure_staff_token_reference_records!
          OperatorToken.create!(
            staff: actor,
            staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
            staff_token_status_id: OperatorTokenStatus::ACTIVE,
            staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
            staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
          )
        end,
        transaction_class: OperatorOidcAuthorizationTransaction,
        resource_type: "operator",
        header_builder: ->(actor, host:, session_public_id:) do
          as_staff_headers(actor, host: host, session_public_id: session_public_id)
        end,
      },
      {
        host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
        actor: create_visitor!,
        token: ->(actor) do
          ensure_visitor_token_reference_records!
          VisitorToken.create!(
            visitor: actor,
            visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
            visitor_token_status_id: VisitorTokenStatus::ACTIVE,
            visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
            visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
          )
        end,
        transaction_class: VisitorOidcAuthorizationTransaction,
        resource_type: "visitor",
        header_builder: ->(actor, host:, session_public_id:) do
          as_visitor_headers(actor, host: host, session_public_id: session_public_id)
        end,
      },
    ].each do |surface|
      host = surface.fetch(:host)
      actor = surface.fetch(:actor)
      token = surface.fetch(:token).call(actor)
      headers = surface.fetch(:header_builder).call(actor, host: host, session_public_id: token.public_id)

      host!(host)

      assert_no_difference -> { surface.fetch(:transaction_class).pending.count } do
        get "/oauth/authorize", params: oidc_authorize_params(resource_type: surface.fetch(:resource_type)),
                                headers: headers
      end

      assert_response :redirect
      uri = URI.parse(response.location)
      callback_uri = URI.parse(jump_rt_url_from_location(response.location))
      query = Rack::Utils.parse_nested_query(callback_uri.query.to_s)

      assert_equal "jump.umaxica.net", uri.host
      assert_equal "/oidc/callback", callback_uri.path
      assert_predicate query["code"], :present?
      assert_equal oidc_authorize_params[:state], query["state"]
      assert_not_includes callback_uri.query.to_s, "login_challenge"
    end
  end

  test "base oauth authorize starts sign up ceremony when screen_hint requests signup" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host!(host)

    get "/oauth/authorize", params: oidc_authorize_params(screen_hint: "signup"), headers: browser_headers

    assert_response :redirect
    uri = URI.parse(jump_rt_url_from_location(response.location))

    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), uri.host
    assert_equal "/sign/up", uri.path
  end

  test "base oauth authorize rejects requests without openid scope" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host!(host)

    assert_no_difference "ClientOidcAuthorizationTransaction.count" do
      get "/oauth/authorize", params: oidc_authorize_params(scope: "profile email"), headers: browser_headers
    end

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
    assert_equal "scope must include openid", response.parsed_body["error_description"]
  end

  test "base oauth authorize rejects scopes outside the client allowlist" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host!(host)

    assert_no_difference "ClientOidcAuthorizationTransaction.count" do
      get "/oauth/authorize", params: oidc_authorize_params(scope: "openid palm.read"), headers: browser_headers
    end

    assert_response :bad_request
    assert_equal "invalid_scope", response.parsed_body["error"]
  end

  test "base oauth authorize consumes login challenge once" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host!(host)
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in",
      params: oidc_authorize_params,
    )

    OidcAuthorizationTransactionCoordinator.register_result!(
      surface: "app",
      login_challenge: issuance.transaction.login_challenge,
      actor: clients(:one),
      session_ref: "session-1",
      auth_method: "passkey",
    )

    get "/oauth/authorize", params: { login_challenge: issuance.transaction.login_challenge }, headers: browser_headers

    assert_response :redirect
    uri = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_predicate query["code"], :present?
    assert_equal oidc_authorize_params[:state], query["state"]
    assert_predicate issuance.transaction.reload, :consumed?

    get "/oauth/authorize", params: { login_challenge: issuance.transaction.login_challenge }, headers: browser_headers

    assert_response :bad_request
    assert_equal "authorization transaction already consumed", response.parsed_body["error_description"]
  end

  test "base oauth authorize rejects expired login challenge" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host!(host)
    issuance =
      OidcAuthorizationTransactionCoordinator.issue!(
        surface: "app",
        intent: "sign_in",
        params: oidc_authorize_params,
        login_challenge_ttl: 1.second,
        now: Time.current,
      )

    travel 2.seconds do
      get "/oauth/authorize", params: { login_challenge: issuance.transaction.login_challenge },
                              headers: browser_headers
    end

    assert_response :bad_request
    assert_equal "authorization transaction expired", response.parsed_body["error_description"]
  end

  private

  def oidc_authorize_params(screen_hint: nil, scope: "openid profile", resource_type: "client")
    params = {
      response_type: "code",
      client_id: "core-next-rp",
      redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris_by_realm.fetch(resource_type).first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: scope,
    }
    params[:screen_hint] = screen_hint if screen_hint.present?
    params
  end

  def create_old_client_tokens(count:)
    user = clients(:one)

    OrgTicketRecord.connected_to(role: :writing) do
      count.times do |index|
        token = ClientToken.new(
          user: user,
          user_token_status_id: ClientTokenStatus::ACTIVE,
          created_at: (count + index + 1).hours.ago,
          updated_at: (count + index + 1).hours.ago,
        )
        token.send(:skip_session_limit_check=, true)
        token.save!
      end
    end
  end

  def assert_recognizes_base_route(host, path, method, controller_name, action)
    route = Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)

    assert_equal controller_name, route.fetch(:controller)
    assert_equal action, route.fetch(:action)
  end

  def create_visitor!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    Visitor.create!
  end
  private
end

# DAMP auth header helpers for this test class.
class BaseOauthOidcAuthorityTest
  private
end

# DAMP local route helper aliases for former shared test support.
class BaseOauthOidcAuthorityTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end

# DAMP local helper copy on the test class.
class BaseOauthOidcAuthorityTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences
    pub_key_for_stub = ->(_kid, **_options) { self.class::PREFERENCE_JWT_KEY }
    PreferenceJwtConfiguration.stub(:private_key, self.class::PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, self.class::PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, self.class::PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) { yield }
              end
            end
          end
        end
      end
    end
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    ensure_user_token_reference_records!
    token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
    token ||= ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    access_token = jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
    cookie_name = AuthenticationCookieName.access
    cookies[cookie_name] = access_token if respond_to?(:cookies, true)
    base.merge(
      "Authorization" => "Bearer #{access_token}",
      "HTTP_AUTHORIZATION" => "Bearer #{access_token}",
      "Cookie" => "#{cookie_name}=#{access_token}",
      "HTTP_COOKIE" => "#{cookie_name}=#{access_token}",
    )
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    ensure_staff_token_reference_records!
    token = session_public_id.present? ? OperatorToken.find_by(public_id: session_public_id) : nil
    token ||= OperatorToken.where(staff_id: staff.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= OperatorToken.create!(
      staff_id: staff.id, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    access_token = jwt_access_token_for(
      staff, host: host, session_public_id: token.public_id,
             resource_type: "operator",
    )
    cookie_name = AuthenticationCookieName.access
    cookies[cookie_name] = access_token if respond_to?(:cookies, true)
    base.merge(
      "Authorization" => "Bearer #{access_token}",
      "HTTP_AUTHORIZATION" => "Bearer #{access_token}",
      "Cookie" => "#{cookie_name}=#{access_token}",
      "HTTP_COOKIE" => "#{cookie_name}=#{access_token}",
    )
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    ensure_visitor_token_reference_records!
    token = session_public_id.present? ? VisitorToken.find_by(public_id: session_public_id) : nil
    token ||= VisitorToken.where(visitor_id: visitor.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= VisitorToken.create!(
      visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    access_token = jwt_access_token_for(
      visitor, host: host, session_public_id: token.public_id,
               resource_type: "visitor",
    )
    cookie_name = AuthenticationCookieName.access
    cookies[cookie_name] = access_token if respond_to?(:cookies, true)
    base.merge(
      "Authorization" => "Bearer #{access_token}",
      "HTTP_AUTHORIZATION" => "Bearer #{access_token}",
      "Cookie" => "#{cookie_name}=#{access_token}",
      "HTTP_COOKIE" => "#{cookie_name}=#{access_token}",
    )
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(SIGN_APP SIGN_ORG SIGN_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
