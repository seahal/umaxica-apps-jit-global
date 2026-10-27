# frozen_string_literal: true

require "test_helper"
require_relative "../support/oidc_rp_logout_hint_helper"

class OidcRpLogoutRegisteredRpMatrixTest < ActionDispatch::IntegrationTest
  include OidcRpLogoutHintHelper

  fixtures :clients, :visitors, :operators, :client_token_kinds, :visitor_token_kinds, :operator_token_kinds

  INERTIA_COMPLETION_CLIENT_IDS = %w(
    base-app-ww base-com-ww base-org-ww warp-app-jp warp-com-jp warp-org-jp
  ).freeze
  CLEAR_SITE_DATA_COMPLETION_CLIENT_IDS = %w(edit-org-ww palm-app-jp).freeze

  test "each first-party RP clears local credentials without stopping its grant and redirects with its stored hint" do
    actor_data = create_actor_sessions
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    expected_op_hosts = {
      "client" => hosts.visa_service.host,
      "visitor" => hosts.visa_corporate.host,
      "operator" => hosts.visa_staff.host,
    }

    AuthBoundaryAuthorityMap::FIRST_PARTY_RP_CLIENT_IDS.each do |client_id|
      face = AuthBoundaryAuthorityMap.rp_faces.fetch(client_id)
      actor, root_token = actor_data.fetch(face.fetch(:actor))
      client = OidcClientRegistry.find!(client_id)
      grant = create_rp_grant(client, actor, root_token, face.fetch(:actor))
      store_oidc_rp_logout_hint!(grant, actor, client)
      request_host = host_for(face.fetch(:surface), face.fetch(:face))
      browser = open_session
      browser.host!(request_host)
      browser.https!
      install_rp_credentials!(browser, grant, actor, root_token, client, request_host, face.fetch(:actor))
      stop_class = { "client" => OpAppAuthorityStop,
                     "visitor" => OpComAuthorityStop,
                     "operator" => OpOrgAuthorityStop, }.fetch(face.fetch(:actor))
      stops_before = stop_class.count
      OutboundHttp::Connection.stub(:build, ->(**) { flunk("RP logout must not call an OP endpoint") }) do
        browser.post(sign_out_path(face.fetch(:surface), face.fetch(:face), ri: "jp"))
      end

      assert_equal 303, browser.response.status, client_id
      location = URI.parse(browser.response.location)
      query = Rack::Utils.parse_nested_query(location.query.to_s)
      callback =
        client.post_logout_redirect_uris.find do |candidate|
          uri = URI.parse(candidate)
          uri.host == request_host && uri.path == AuthBoundaryAuthorityMap::CANONICAL_RP_SIGN_OUT_PATH &&
            Rack::Utils.parse_nested_query(uri.query.to_s) == { "ri" => "jp" }
        end

      assert_equal expected_op_hosts.fetch(face.fetch(:actor)), location.host, client_id
      assert_equal "/oidc/logout", location.path, client_id
      assert_equal client_id, query.fetch("client_id"), client_id
      stored_hint_matches = grant.logout_hint.id_token == query.fetch("id_token_hint")

      assert stored_hint_matches, "#{client_id} sign-out must send its stored hint"
      state_length = query.fetch("state").length

      assert_operator state_length, :>, 0, "#{client_id} sign-out must bind the completion with state"
      assert_equal callback, query.fetch("post_logout_redirect_uri"), client_id
      assert_nil query["logout_challenge"], client_id
      access_cookie_length = browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.length

      assert_equal 0, access_cookie_length, "#{client_id} access cookie must be cleared"
      refresh_cookie_length = browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.length

      assert_equal 0, refresh_cookie_length, "#{client_id} refresh cookie must be cleared"
      grant_active = grant.reload.active?

      assert grant_active, "#{client_id} grant stays active until Visa confirmation"
      assert_equal stops_before, stop_class.count, "#{client_id} must not write OP authority"
      assert_predicate root_token.reload, :currently_usable?, client_id

      callback_uri = URI.parse(query.fetch("post_logout_redirect_uri"))
      callback_query = Rack::Utils.parse_nested_query(callback_uri.query.to_s)
      callback_query["state"] = query.fetch("state")
      callback_uri.query = callback_query.to_query
      browser.host!(callback_uri.host)
      writes = []
      observer =
        ->(_name, _start, _finish, _id, payload) do
          writes << payload.fetch(:sql) if payload.fetch(:sql).match?(/\A\s*(INSERT|UPDATE|DELETE)\b/i)
        end
      ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
        browser.get(callback_uri.request_uri)
      end

      assert_empty writes, "#{client_id} completion must not write database records"

      assert_includes [200, 303], browser.response.status, "#{client_id} state-bound completion"
      if browser.response.redirect?
        assert_equal "/?ri=jp", URI.parse(browser.response.location).request_uri, client_id
        browser.get(browser.response.location)
        browser.get(browser.response.location) while browser.response.redirect?
      end
      if INERTIA_COMPLETION_CLIENT_IDS.include?(client_id)
        assert_equal 200, browser.response.status, "#{client_id} completion page"
        page = Nokogiri::HTML(response_body_for(browser)).at_css("script[data-page='app']")

        assert page, "#{client_id} completion must render an Inertia page object"
        clear_history = JSON.parse(page.text).fetch("clearHistory")

        assert_instance_of TrueClass, clear_history, "#{client_id} clearHistory must be boolean true"
      elsif CLEAR_SITE_DATA_COMPLETION_CLIENT_IDS.include?(client_id)
        assert_includes browser.response.headers.fetch("Clear-Site-Data"), '"storage"', client_id
      end
      browser.get(callback_uri.request_uri)

      assert_equal 404, browser.response.status, "#{client_id} completion notice is single use"
    end
  end

  test "an old return refuses a wrong state and cannot disrupt a new RP session" do
    actor_data = create_actor_sessions
    operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    actor_data["operator"] = [operator, OperatorToken.create!(authentication_epoch: 0, staff: operator)]
    new_roots = {}
    AuthBoundaryAuthorityMap::FIRST_PARTY_RP_CLIENT_IDS.each do |client_id|
      face = AuthBoundaryAuthorityMap.rp_faces.fetch(client_id)
      actor, old_root = actor_data.fetch(face.fetch(:actor))
      client = OidcClientRegistry.find!(client_id)
      old_grant = create_rp_grant(client, actor, old_root, face.fetch(:actor))
      store_oidc_rp_logout_hint!(old_grant, actor, client)
      request_host = host_for(face.fetch(:surface), face.fetch(:face))
      browser = open_session
      browser.host!(request_host)
      browser.https!
      install_rp_credentials!(browser, old_grant, actor, old_root, client, request_host, face.fetch(:actor))
      browser.post(sign_out_path(face.fetch(:surface), face.fetch(:face), ri: "jp"))

      assert_equal 303, browser.response.status, client_id
      query = Rack::Utils.parse_nested_query(URI.parse(browser.response.location).query.to_s)
      callback = URI.parse(query.fetch("post_logout_redirect_uri"))
      callback_query = Rack::Utils.parse_nested_query(callback.query.to_s)
      callback_query["state"] = "wrong-state"
      callback.query = callback_query.to_query
      browser.get(callback.request_uri)

      assert_equal 404, browser.response.status, "#{client_id} wrong state"
      new_root = new_roots[face.fetch(:actor)] ||=
        case face.fetch(:actor)
        when "client" then ClientToken.create!(authentication_epoch: 0, user: actor)
        when "visitor" then VisitorToken.create!(authentication_epoch: 0, visitor: actor)
        when "operator" then OperatorToken.create!(authentication_epoch: 0, staff: actor)
        end
      new_grant = create_rp_grant(client, actor, new_root, face.fetch(:actor))
      install_rp_credentials!(browser, new_grant, actor, new_root, client, request_host, face.fetch(:actor))
      access_before = browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
      refresh_before = browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
      callback_query["state"] = query.fetch("state")
      callback.query = callback_query.to_query
      browser.get(callback.request_uri)

      assert_equal 404, browser.response.status, "#{client_id} active session"
      assert_equal access_before, browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE], client_id
      assert_equal refresh_before, browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE], client_id
      assert_predicate new_grant.reload, :active?, client_id
      assert_predicate old_root.reload, :currently_usable?, client_id
      assert_predicate new_root.reload, :currently_usable?, client_id
    end
  end

  test "A14-18 old completion cannot destroy an APP RP sign-in established through the callback" do
    actor = clients(:one)
    ClientIdentityState.ensure_defaults!
    ClientIdentity.create!(
      issuer: OidcIssuer.for_resource_type("client"), subject: OidcSubject.for(actor, resource_type: "client"),
      audience: "base-app-ww", source_record_id: actor.id, status_id: ClientIdentityState::ACTIVE,
    )
    root = ClientToken.create!(authentication_epoch: 0, user: actor)
    client = OidcClientRegistry.find!("core-app-jp")
    host = Rails.configuration.x.boot_config.fetch(:hosts).core_service.host
    browser = open_session
    browser.host!(host)
    browser.https!
    old_grant = create_rp_grant(client, actor, root, "client")
    store_oidc_rp_logout_hint!(old_grant, actor, client)
    install_rp_credentials!(browser, old_grant, actor, root, client, host, "client")
    browser.post("/sign/out?ri=jp")

    assert_equal 303, browser.response.status
    logout_query = Rack::Utils.parse_nested_query(URI.parse(browser.response.location).query.to_s)
    old_return = URI.parse(logout_query.fetch("post_logout_redirect_uri"))
    old_return.query = Rack::Utils.parse_nested_query(old_return.query.to_s)
      .merge("state" => logout_query.fetch("state")).to_query
    browser.get("/sign?ri=jp")

    assert_equal 200, browser.response.status
    browser.post("/sign?ri=jp", params: { target_link_uri: "/" })

    assert_equal 303, browser.response.status
    authorize = Rack::Utils.parse_nested_query(
      URI.parse(jump_rt_url_from_location_for_test(browser.response.location)).query.to_s,
    )
    state = authorize.fetch("state")
    flow = browser.request.session.fetch(OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY)
      .fetch(OidcStateTestSupport.jti(state))
    new_root = ClientToken.create!(authentication_epoch: 0, user: actor)
    code = OidcAuthorizationCodeIssuer.call(
      client: client, params: authorize.symbolize_keys, resource: actor, session_token: new_root,
      authentication_event_at: Time.current,
    )
    exchange = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code", code: code.code, redirect_uri: code.redirect_uri,
      client_id: client.client_id, client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: OidcClientAssertionJwt.issue(
        client_id: client.client_id, token_url: OidcIssuer.token_endpoint("client"),
      ),
      token_endpoint_uri: OidcIssuer.token_endpoint("client"),
      code_verifier: flow.fetch("code_verifier"), expected_resource_type: "client",
    )

    assert_predicate exchange, :success?
    token_result = OidcOpTokenClient::Result.new(outcome: :success, token_response: exchange.token_response, error: nil)
    userinfo = OidcOpUserInfoClient::Result.new(
      success: true, claims: { "sub" => OidcSubject.for(actor, resource_type: "client") },
      error: nil, dependency_failure: false,
    )
    failures = []
    Rails.logger.stub(:info, ->(*messages) { failures.concat(messages.grep(/oidc\.rp\.callback\.failed/)) }) do
      OidcOpTokenClient.stub(:authorization_code, token_result) do
        OidcOpUserInfoClient.stub(:call, userinfo) do
          browser.get("/oidc/callback", params: { code: code.code, state: state, iss: OidcIssuer.for_client(client) })
        end
      end
    end

    assert_empty failures
    assert_equal "/", URI.parse(browser.response.location).path
    assert_equal 302, browser.response.status
    access = browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    refresh = browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]

    assert_predicate access, :present?
    assert_predicate refresh, :present?
    browser.get(old_return.request_uri)

    assert_equal 404, browser.response.status
    assert_equal access, browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    assert_equal refresh, browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    assert_predicate new_root.reload, :currently_usable?
  end

  private

  def response_body_for(browser)
    browser.response.body
  end

  def create_actor_sessions
    client = clients(:one)
    visitor = visitors(:reserved_visitor)
    operator = operators(:one)

    {
      "client" => [client, ClientToken.create!(
        authentication_epoch: 0,
        user: client,
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      ),],
      "visitor" => [visitor, VisitorToken.create!(
        authentication_epoch: 0,
        visitor: visitor,
        visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      ),],
      "operator" => [operator, OperatorToken.create!(
        authentication_epoch: 0,
        staff: operator,
        staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      ),],
    }
  end

  def create_rp_grant(client, _actor, root_token, actor_type)
    attributes = {
      authentication_epoch: 0,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    }

    case actor_type
    when "client"
      OpAppGrant.create!(**attributes, client_token: root_token)
    when "visitor"
      OpComGrant.create!(**attributes, visitor_token: root_token)
    when "operator"
      OpOrgGrant.create!(**attributes, operator_token: root_token)
    else
      raise ArgumentError, "unsupported first-party RP actor type: #{actor_type.inspect}"
    end
  end

  def install_rp_credentials!(browser, grant, actor, root_token, client, host, actor_type)
    resource_type = actor_type
    access_token = AuthenticationTokenService.encode(
      actor,
      host:,
      resource_type:,
      session_public_id: root_token.public_id,
      base_session_public_id: root_token.public_id,
      oidc_sid: grant.public_id,
      oidc_jti: grant.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(actor, resource_type:),
      client_id: client.client_id,
    )

    browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = grant.issue_refresh_token!
  end

  def host_for(surface, face)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    host_key =
      case surface
      when "edit" then "edit_staff"
      when "palm" then "palm_service"
      when "tech" then "tech_staff"
      else
        role = { "app" => "service", "com" => "corporate", "org" => "staff" }.fetch(face)
        "#{surface}_#{role}"
      end

    hosts.public_send(host_key).host
  end

  def sign_out_path(surface, face, **query)
    public_send("#{surface}_#{face}_sign_out_path", **query)
  end
end
