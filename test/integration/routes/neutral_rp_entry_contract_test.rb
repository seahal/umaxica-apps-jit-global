# typed: false
# frozen_string_literal: true

require "test_helper"

class NeutralRpEntryContractTest < ActionDispatch::IntegrationTest
  setup do
    load_jump_rt_env!
  end

  RP_ROUTES = [
    {
      host: -> { ENV.fetch("PUBLIC_CORE_SERVICE_URL") },
      controller: "core/app/sign/entries",
      callback_controller: "core/app/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_CORE_CORPORATE_URL") },
      controller: "core/com/sign/entries",
      callback_controller: "core/com/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_CORE_STAFF_URL") },
      controller: "core/org/sign/entries",
      callback_controller: "core/org/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_WARP_SERVICE_URL") },
      controller: "warp/app/sign/entries",
      callback_controller: "warp/app/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_WARP_CORPORATE_URL") },
      controller: "warp/com/sign/entries",
      callback_controller: "warp/com/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_WARP_STAFF_URL") },
      controller: "warp/org/sign/entries",
      callback_controller: "warp/org/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_EDIT_STAFF_URL") },
      controller: "edit/org/sign/entries",
      callback_controller: "edit/org/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_BASE_SERVICE_URL") },
      controller: "base/app/sign/entries",
      callback_controller: "base/app/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_BASE_CORPORATE_URL") },
      controller: "base/com/sign/entries",
      callback_controller: "base/com/oidc/callbacks",
    },
    {
      host: -> { ENV.fetch("PUBLIC_BASE_STAFF_URL") },
      controller: "base/org/sign/entries",
      callback_controller: "base/org/oidc/callbacks",
    },
  ].freeze

  test "a revoked RP credential can start the neutral entry and preserves Root authority on every surface" do
    RP_ROUTES.each do |route|
      family, surface = route.fetch(:controller).split("/")
      model, owner_class, root_class, owner_key, root_key, resource_type = {
        "app" => [OpAppGrant, Client, ClientToken, :user, :client_token, "client"],
        "com" => [OpComGrant, Visitor, VisitorToken, :visitor, :visitor_token, "visitor"],
        "org" => [OpOrgGrant, Operator, OperatorToken, :staff, :operator_token, "operator"],
      }.fetch(surface)
      actor = owner_class.create!
      root = root_class.create!(owner_key => actor)
      rp_client_id =
        case family
        when "base" then "base-#{surface}-ww"
        when "edit" then "edit-org-ww"
        when "tech" then "tech-org-ww"
        else "#{family}-#{surface}-jp"
        end
      registered = OidcClientRegistry.find!(rp_client_id)
      rp_session = model.create!(
        root_key => root, :oidc_client_id => registered.client_id, :oidc_scope => "openid profile",
        :oidc_jti => SecureRandom.uuid, :oidc_auth_time => Time.current,
        :refresh_token_expires_at => 10.minutes.from_now,
      )
      host = route.fetch(:host).call
      access = AuthenticationTokenService.encode(
        actor, host: host, resource_type: resource_type, session_public_id: root.public_id,
               base_session_public_id: root.public_id, oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
               expires_at: 5.minutes.from_now, scopes: %w(openid profile), issuer: OidcIssuer.for_client(registered),
               audiences: [registered.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(registered),
               subject: OidcSubject.for(actor, resource_type: resource_type), client_id: registered.client_id,
      )
      rp_session.revoke!(status: "success")
      root_before = root.attributes
      reset!
      https!
      host! host
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
      destination = nil
      JumpRtIssuer.stub(
        :call, ->(**arguments) {
                 destination = arguments.fetch(:url)
                 "opaque-jump"
               },
      ) do
        RedirectsJumpGatewayUrl.stub(
          :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
        ) do
          assert_no_difference -> { root_class.count } do
            post "/sign", params: { ri: "jp" }
          end
        end
      end

      assert_response :see_other, route.fetch(:controller)
      assert_predicate rp_session.reload, :revoked?
      assert_equal root_before, root.reload.attributes
      assert_predicate cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s, :empty?
      assert_equal "/oauth/authorize", URI.parse(destination || response.location).path
    end
  end

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

  test "every first-party browser RP has its protocol callback at oidc callback" do
    RP_ROUTES.each do |rp|
      host = rp.fetch(:host).call

      assert_recognizes(
        { controller: rp.fetch(:callback_controller), action: "show" },
        { path: "http://#{host}/oidc/callback", method: :get },
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
      assert_select "h1", text: I18n.t("actions.continue")
      assert_select "input[type=submit][value=?]", I18n.t("actions.continue")
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
      logged = []
      Rails.logger.stub(:info, ->(message = nil, &block) { logged << (message.nil? ? block&.call : message).to_s }) do
        post(
          "/sign", params: {
            pt: "/dashboard",
            ri: "jp",
            authenticity_token: csrf_token,
          }, headers: host_headers(host),
        )
      end

      assert_response :redirect
      pending_event = logged.grep(/"event":"oidc\.sso\.pending_flow\.created"/).sole
      log_data = JSON.parse(pending_event).fetch("data")

      assert_empty log_data.keys.grep(/digest|nonce|verifier|\Apt(?:_|\z)/),
                   "OIDC initiation must not log state or return-target fingerprints"
      authorize_location = jump_rt_url_from_location(response.location)
      authorize_uri = URI.parse(authorize_location)
      authorize_query = Rack::Utils.parse_nested_query(authorize_uri.query.to_s)

      assert_equal "/oauth/authorize", authorize_uri.path
      assert_nil authorize_query["screen_hint"]
      assert_predicate authorize_query["state"], :present?
      assert_predicate authorize_query["nonce"], :present?
      assert_predicate authorize_query["code_challenge"], :present?
      assert_equal "S256", authorize_query["code_challenge_method"]
      assert_equal "/oidc/callback", URI.parse(authorize_query.fetch("redirect_uri")).path

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

  test "a root-cookie-only browser is unauthenticated for the RP entry" do
    host = RP_ROUTES.first.fetch(:host).call
    host!(host)

    authenticated_headers =
      begin
        rp_headers = as_user_headers(clients(:one), host: host)
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
              client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "client",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
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

    assert_response :redirect
    assert_predicate session.fetch("oidc_pending_flows"), :present?
  end

  test "an RP-authenticated browser receives a plain refusal instead of a new RP flow" do
    host = RP_ROUTES.first.fetch(:host).call
    host!(host)
    client = clients(:one)
    oidc_client = OidcClientRegistry.find!("core-app-jp")
    begin
      ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
      ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
      ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
      ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
    end
    root_token = ClientToken.create!(
      user: client,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
      authentication_event_at: Time.current,
    )
    rp_session = OpAppGrant.create!(
      client_token: root_token,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    access_token = AuthenticationTokenService.encode(
      client,
      host: OidcIssuer.host_for_resource_type("client"),
      resource_type: "client",
      session_public_id: root_token.public_id,
      base_session_public_id: root_token.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
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

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_equal "text/plain", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil response.location
    assert_nil session["oidc_pending_flows"]
  end

  test "an RP credential for another surface does not block the current RP" do
    host = RP_ROUTES.first.fetch(:host).call
    host!(host)
    visitor = visitors(:reserved_visitor)
    oidc_client = OidcClientRegistry.find!("core-com-jp")
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
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end
end
