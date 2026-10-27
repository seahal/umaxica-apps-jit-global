# frozen_string_literal: true

# Exact localized refusal text is part of the public contract.
# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

require_relative "../support/oidc_rp_logout_hint_helper"

class OidcCurrentDeviceLogoutTest < ActionDispatch::IntegrationTest
  include OidcRpLogoutHintHelper

  fixtures :clients, :visitors, :operators, :client_token_kinds, :visitor_token_kinds, :operator_token_kinds

  CASES = {
    "app" => {
      token: ClientToken,
      grant: OpAppGrant,
      stop: OpAppAuthorityStop,
      participant: OpAppAuthorityStopParticipant,
      target: OpAppAuthorityStopRootTarget,
      owner: :user,
      root: :client_token,
      kind: :user_token_kind_id,
      kind_value: ClientTokenKind::BROWSER_WEB,
      resource_type: "client",
      visa_host: :visa_service,
      core_host: :core_service,
      warp_host: :warp_service,
    },
    "com" => {
      token: VisitorToken,
      grant: OpComGrant,
      stop: OpComAuthorityStop,
      participant: OpComAuthorityStopParticipant,
      target: OpComAuthorityStopRootTarget,
      owner: :visitor,
      root: :visitor_token,
      kind: :visitor_token_kind_id,
      kind_value: VisitorTokenKind::BROWSER_WEB,
      resource_type: "visitor",
      visa_host: :visa_corporate,
      core_host: :core_corporate,
      warp_host: :warp_corporate,
    },
    "org" => {
      token: OperatorToken,
      grant: OpOrgGrant,
      stop: OpOrgAuthorityStop,
      participant: OpOrgAuthorityStopParticipant,
      target: OpOrgAuthorityStopRootTarget,
      owner: :staff,
      root: :operator_token,
      kind: :staff_token_kind_id,
      kind_value: OperatorTokenKind::BROWSER_WEB,
      resource_type: "operator",
      visa_host: :visa_staff,
      core_host: :core_staff,
      warp_host: :warp_staff,
    },
  }.freeze

  test "APP RP logout leaves signed-in COM and ORG browsers usable on their next request" do
    app_config = CASES.fetch("app")
    actor = clients(:one)
    root = create_root(app_config, actor)
    origin = create_grant(app_config, actor, root, "core-app-jp")
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    browser = open_session
    install_credentials(browser, origin, actor, root, hosts.core_service.host, app_config)
    other_browsers = []
    [["com", hosts.warp_corporate.host], ["org", hosts.warp_staff.host]].each do |realm, host|
      config = CASES.fetch(realm)
      other_actor = actor_for(realm)
      other_root = create_root(config, other_actor)
      grant = create_grant(config, other_actor, other_root, "warp-#{realm}-jp")
      other_browser = open_session
      install_credentials(other_browser, grant, other_actor, other_root, host, config)
      other_browser.get("/dashboard?ri=jp")

      assert_equal 200, other_browser.response.status, realm
      other_browsers << other_browser
    end
    browser.post("/sign/out?ri=jp")

    assert_equal 303, browser.response.status
    target = URI.parse(browser.response.location)
    browser.host!(hosts.visa_service.host)
    cookie = visa_access(actor, root, hosts.visa_service.host, app_config)
    browser.cookies << Rack::Test::Cookie.new(
      "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(cookie)}",
      URI.parse("https://#{hosts.visa_service.host}/"),
    )
    browser.get(target.request_uri)
    3.times do
      break unless browser.response.redirect?

      browser.get(jump_rt_url_from_location_for_test(browser.response.location))
    end

    assert_equal 200, browser.response.status
    browser.post("/oidc/logout/confirmation?ri=jp")

    assert_equal 303, browser.response.status
    assert_predicate root.reload, :revoked?
    other_browsers.each do |other_browser|
      other_browser.get("/dashboard?ri=jp")

      assert_equal 200, other_browser.response.status
    end
  end

  CASES.each do |realm, config|
    test "#{realm} authorization coordinator failure without redirect renders JSON" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      browser = visa_browser(config, actor, root)
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      failure = OidcAuthorizeCoordinator::Result.new(
        success: false, redirect_url: nil, redirect_uri: nil,
        error: "server_error", error_description: "authorization unavailable",
      )
      OidcAuthorizeCoordinator.stub(:call, failure) do
        browser.get(
          "/oauth/authorize", params: {
            response_type: "code",
            client_id: client.client_id,
            redirect_uri: client.redirect_uris_by_realm.fetch(config.fetch(:resource_type)).first,
            code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
            code_challenge_method: "S256",
            scope: "openid",
            state: "state",
            nonce: "nonce",
          },
        )
      end

      assert_equal 400, browser.response.status
      assert_nil browser.response.location
      assert_equal(
        { "error" => "server_error", "error_description" => "authorization unavailable" },
        browser.response.parsed_body,
      )
      assert_predicate root.reload, :currently_usable?
    end

    test "#{realm} logout confirmation posts to its separate confirmation endpoint" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      [nil, "jp"].each do |region|
        browser = visa_browser(config, actor, root)
        browser.get("/oidc/logout", params: region ? { ri: region } : {})
        if region.nil?
          assert_equal 302, browser.response.status
          redirected = URI.parse(browser.response.location)
          region = Rack::Utils.parse_nested_query(redirected.query).fetch("ri")
          browser.get(redirected.request_uri)
        end

        assert_equal 200, browser.response.status
        page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")

        assert page
        props = JSON.parse(page.text).fetch("props")

        assert_equal "/oidc/logout/confirmation?#{{ ri: region }.to_query}", props.fetch("form").fetch("action")
      end
    end

    test "#{realm} validates hint signature issuer audience and accepts an expired hint" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      grant = create_grant(config, actor, root, "core-#{realm}-jp")
      client = OidcClientRegistry.find!(grant.oidc_client_id)
      foreign = OidcIdTokenIssuer.call(
        resource: actor, client: client, nonce: "nonce", issuer: "https://foreign.example",
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(config.fetch(:resource_type)),
        subject: OidcSubject.for(actor, resource_type: config.fetch(:resource_type)), sid: grant.public_id,
      )
      invalids = [
        ["#{grant.logout_hint.id_token}x", client.client_id],
        [foreign, client.client_id],
        [grant.logout_hint.id_token, "warp-#{realm}-jp"],
      ]
      invalids.each do |token, client_id|
        browser = visa_browser(config, actor, root)
        request_hint(browser, grant, locale: "en", token: token, client_id: client_id)

        assert_equal 400, browser.response.status
        assert_nil browser.response.location
        assert_nil browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
        assert_not_includes browser.response.body, I18n.t("sign.shared.sign_out.completed_description", locale: :en)
        assert_not_predicate root.reload, :revoked?
        assert_predicate grant.reload, :active?
      end

      expired = OidcIdTokenIssuer.call(
        resource: actor, client: client, nonce: "nonce", issued_at: 10.minutes.ago, expires_at: 1.minute.ago,
        issuer: OidcIssuer.for_resource_type(config.fetch(:resource_type)),
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(config.fetch(:resource_type)),
        subject: OidcSubject.for(actor, resource_type: config.fetch(:resource_type)), sid: grant.public_id,
      )
      browser = visa_browser(config, actor, root)
      request_hint(browser, grant, locale: "en", token: expired)

      assert_equal 303, browser.response.status
      pending = browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]

      assert_equal root.device_session.public_id, pending.fetch("device_session_public_id")
      assert_equal grant.public_id, pending.fetch("grant_public_id")
      assert_not_predicate root.reload, :revoked?
      assert_predicate grant.reload, :active?
    end

    test "#{realm} invalid hint displays a localized public error" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      grant = create_grant(config, actor, root, "core-#{realm}-jp")
      %w(en ja).each do |locale|
        browser = visa_browser(config, actor, root)
        request_hint(browser, grant, locale: locale, token: "invalid-hint")

        assert_equal 400, browser.response.status
        assert_equal I18n.t("sign.shared.sign_out.invalid_request", locale: locale), browser.response.body
        assert_not_predicate root.reload, :revoked?
        assert_predicate grant.reload, :active?
      end
    end

    test "#{realm} invalid hint preserves the protocol error in JSON" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      browser = visa_browser(config, actor, root)
      browser.get(
        "/oidc/logout", params: { id_token_hint: "invalid-hint", ri: "jp" },
                        headers: { "Accept" => "application/json" },
      )

      assert_equal 400, browser.response.status
      assert_equal "invalid_request", browser.response.parsed_body.fetch("error")
      assert_equal "id_token_hint is invalid", browser.response.parsed_body.fetch("error_description")
      assert_not_predicate root.reload, :revoked?
    end

    test "#{realm} an unregistered return URI is refused even without a hint" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      browser = visa_browser(config, actor, root)
      browser.get(
        "/oidc/logout", params: {
          client_id: "core-#{realm}-jp", post_logout_redirect_uri: "https://attacker.example/return", ri: "jp",
        },
      )

      assert_equal 400, browser.response.status
      assert_nil browser.response.location
      assert_nil browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
      assert_not_predicate root.reload, :revoked?
    end

    test "#{realm} retry after an unknown uncommitted stop ends the same device" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      browser = visa_browser(config, actor, root)
      stage_no_hint(browser)
      AuthenticationLogoutCurrentSession.stub(:new, ->(**) { UncommittedUnknown.new }) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end

      assert_equal 503, browser.response.status
      assert_not_predicate root.reload, :revoked?
      assert_predicate browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY], :present?
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 303, browser.response.status
      assert_predicate root.reload, :revoked?
    end

    test "#{realm} a new pending request supersedes the previous completion marker" do
      actor = actor_for(realm)
      old_root = create_root(config, actor)
      new_root = create_root(config, actor)
      browser = visa_browser(config, actor, old_root)
      stage_no_hint(browser)
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 303, browser.response.status
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      cookie = visa_access(actor, new_root, host, config)
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(cookie)}", URI.parse("https://#{host}/"),
      )
      stage_no_hint(browser)
      travel 5.minutes
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 422, browser.response.status
      assert_predicate new_root.reload, :currently_usable?
    end

    test "#{realm} an old confirmation after a new sign-in cannot end the new device" do
      actor = actor_for(realm)
      old_root = create_root(config, actor)
      new_root = create_root(config, actor)
      browser = visa_browser(config, actor, old_root)
      stage_no_hint(browser)
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 303, browser.response.status
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      new_cookie = visa_access(actor, new_root, host, config)
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(new_cookie)}", URI.parse("https://#{host}/"),
      )
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 422, browser.response.status
      assert_predicate new_root.reload, :currently_usable?
    end

    test "#{realm} verified hint without an OP session is forbidden in both languages" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      grant = create_grant(config, actor, root, "core-#{realm}-jp")
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!

      { "en" => "This action is not allowed.", "ja" => "禁止された振る舞いです" }.each do |locale, message|
        request_hint(browser, grant, locale: locale)

        assert_equal 403, browser.response.status
        assert_equal message, browser.response.body
        assert_nil browser.response.location
        assert_nil browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
        assert_not_predicate root.reload, :revoked?
        assert_predicate grant.reload, :active?
      end
    end

    test "#{realm} a hint for another device of the same person cannot select its grant" do
      actor = actor_for(realm)
      current = create_root(config, actor)
      other = create_root(config, actor)
      grant = create_grant(config, actor, other, "core-#{realm}-jp")
      browser = visa_browser(config, actor, current)
      request_hint(browser, grant, locale: "en")

      assert_equal 403, browser.response.status
      assert_equal "This action is not allowed.", browser.response.body
      assert_nil browser.response.location
      assert_nil browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
      assert_not_predicate current.reload, :revoked?
      assert_not_predicate other.reload, :revoked?
      assert_predicate grant.reload, :active?
    end

    test "#{realm} a hint for an unrelated person cannot select its grant" do
      current_actor = actor_for(realm)
      other_actor = fresh_actor(realm)
      current = create_root(config, current_actor)
      other = create_root(config, other_actor)
      grant = create_grant(config, other_actor, other, "core-#{realm}-jp")
      browser = visa_browser(config, current_actor, current)
      request_hint(browser, grant, locale: "en")

      assert_equal 403, browser.response.status
      assert_equal "This action is not allowed.", browser.response.body
      assert_nil browser.response.location
      assert_nil browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
      assert_not_predicate current.reload, :revoked?
      assert_not_predicate other.reload, :revoked?
      assert_predicate grant.reload, :active?
    end

    test "#{realm} a no-hint request without an OP session reports already signed out" do
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      before = config.fetch(:stop).count
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_equal "You are already signed out.", page_description(browser)
      page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")
      props = JSON.parse(page.text).fetch("props")

      assert_instance_of FalseClass, props.fetch("active")
      assert_nil props.fetch("form")
      assert_nil browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
      assert_equal before, config.fetch(:stop).count
    end

    test "#{realm} confirmation refuses a different current device" do
      actor = actor_for(realm)
      original = create_root(config, actor)
      replacement = create_root(config, actor)
      browser = visa_browser(config, actor, original)
      stage_no_hint(browser)
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      cookie = visa_access(actor, replacement, host, config)
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(cookie)}", URI.parse("https://#{host}/"),
      )
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 403, browser.response.status
      assert_equal "This action is not allowed.", browser.response.body
      assert_not_predicate original.reload, :revoked?
      assert_not_predicate replacement.reload, :revoked?
    end

    test "#{realm} a repeated confirmation reports already signed out and writes no second stop" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      browser = visa_browser(config, actor, root)
      stage_no_hint(browser)
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 303, browser.response.status
      stops = config.fetch(:stop).count
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 200, browser.response.status
      assert_equal "You are already signed out.", page_description(browser)
      assert_equal stops, config.fetch(:stop).count
    end

    test "#{realm} programming errors during the stop propagate" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      browser = visa_browser(config, actor, root)
      stage_no_hint(browser)
      failure = ->(**) { raise NoMethodError, "broken stop implementation" }

      OpAuthorityStopCommitter.stub(:stop_root, failure) do
        assert_raises(NoMethodError) { browser.post("/oidc/logout/confirmation?ri=jp&lx=en") }
      end

      assert_not_predicate root.reload, :revoked?
    end

    test "#{realm} a failed precondition on an active device is forbidden" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      browser = visa_browser(config, actor, root)
      stage_no_hint(browser)
      failure = ->(**) { raise AuthenticationLogoutCurrentSession::PreconditionFailed, "changed" }
      OpAuthorityStopCommitter.stub(:stop_root, failure) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end

      assert_equal 403, browser.response.status
      assert_not_predicate root.reload, :revoked?
      assert_predicate browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY], :present?
    end

    test "#{realm} a failed precondition after a committed stop reports already signed out" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      browser = visa_browser(config, actor, root)
      stage_no_hint(browser)
      original_new = AuthenticationLogoutCurrentSession.method(:new)
      factory = ->(**arguments) { CommittedPrecondition.new(original_new.call(**arguments)) }
      AuthenticationLogoutCurrentSession.stub(:new, factory) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end

      assert_equal 200, browser.response.status
      assert_equal "You are already signed out.", page_description(browser)
      assert_predicate root.reload, :revoked?
      assert_not browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].present?
    end

    test "#{realm} an unreadable persisted device preserves the browser and returns unknown" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      browser = visa_browser(config, actor, root)
      stage_no_hint(browser)
      device_class = root.device_session.class
      original_find = device_class.method(:find_by)
      stop_failed = false
      lookup =
        lambda do |**attributes|
          raise ActiveRecord::ConnectionNotEstablished, "writer unavailable" if stop_failed && attributes.key?(:id)

          original_find.call(**attributes)
        end
      failure =
        lambda do |**|
          stop_failed = true
          raise ActiveRecord::StatementInvalid, "stop failed"
        end
      device_class.stub(:find_by, lookup) do
        OpAuthorityStopCommitter.stub(:stop_root, failure) do
          browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
        end
      end

      assert_equal 503, browser.response.status
      assert_nil browser.response.location
      assert_not_predicate root.reload, :revoked?
      assert_predicate browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY], :present?
    end

    test "#{realm} a stop failing before commit keeps the browser and pending request" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      grant = create_grant(config, actor, root, "core-#{realm}-jp")
      browser = visa_browser(config, actor, root)
      stage_no_hint(browser)
      failure = ->(**) { raise ActiveRecord::ConnectionNotEstablished, "stop failed before commit" }
      OpAuthorityStopCommitter.stub(:stop_root, failure) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end

      assert_equal 500, browser.response.status
      assert_nil browser.response.location
      assert_not_predicate root.reload, :revoked?
      assert_predicate grant.reload, :active?
      assert_predicate browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY], :present?
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
    end

    test "#{realm} an unknown commit keeps the browser and a retry observes the committed stop" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      browser = visa_browser(config, actor, root)
      stage_no_hint(browser)
      original_new = AuthenticationLogoutCurrentSession.method(:new)
      factory = ->(**arguments) { CommittedUnknown.new(original_new.call(**arguments)) }
      AuthenticationLogoutCurrentSession.stub(:new, factory) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end

      assert_equal 503, browser.response.status
      assert_nil browser.response.location
      assert_predicate root.reload, :revoked?
      assert_predicate browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY], :present?
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      stops = config.fetch(:stop).count
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 200, browser.response.status
      assert_equal "You are already signed out.", page_description(browser)
      assert_equal stops, config.fetch(:stop).count
    end

    test "#{realm} a notice store failure after commit renders the signed-out page" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      grant = create_grant(config, actor, root, "core-#{realm}-jp")
      browser = visa_browser(config, actor, root)
      stage_no_hint(browser)
      Valkey::AuthState::SignOutNoticeStore.stub(:new, FailingNoticeStore.new) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end

      assert_equal 200, browser.response.status
      assert_equal I18n.t("sign.shared.sign_out.completed_description", locale: :en), page_description(browser)
      assert_nil browser.response.location
      assert_predicate root.reload, :revoked?
      assert_predicate grant.reload, :revoked?
      assert_not browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].present?
      assert_equal 1, config.fetch(:target).where(root_id: root.id).count
    end

    test "#{realm} leaving Visa confirmation keeps the OP session and both grants active" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      origin = create_grant(config, actor, root, "core-#{realm}-jp")
      sibling = create_grant(config, actor, root, "warp-#{realm}-jp")
      hosts = Rails.configuration.x.boot_config.fetch(:hosts)
      core_host = hosts.public_send(config.fetch(:core_host)).host
      visa_host = hosts.public_send(config.fetch(:visa_host)).host
      browser = open_session
      install_credentials(browser, origin, actor, root, core_host, config)
      sibling_browser = open_session
      warp_host = hosts.public_send(config.fetch(:warp_host)).host
      install_credentials(sibling_browser, sibling, actor, root, warp_host, config)
      stops = config.fetch(:stop).count
      browser.post("/sign/out?ri=jp")

      assert_equal 303, browser.response.status
      assert_empty browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s
      assert_empty browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s
      assert_predicate origin.reload, :active?
      assert_equal stops, config.fetch(:stop).count
      target = URI.parse(browser.response.location)
      browser.host!(visa_host)
      cookie = visa_access(actor, root, visa_host, config)
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(cookie)}", URI.parse("https://#{visa_host}/"),
      )
      browser.get(target.request_uri)
      3.times do
        break unless browser.response.redirect?

        browser.get(jump_rt_url_from_location_for_test(browser.response.location))
      end

      assert_equal 200, browser.response.status
      browser.get("/?ri=jp")

      assert_predicate root.reload, :currently_usable?
      assert_predicate origin.reload, :active?
      assert_predicate sibling.reload, :active?
      assert_equal stops, config.fetch(:stop).count
      browser.host!(core_host)
      browser.post("/sign/out?ri=jp")

      assert_equal 401, browser.response.status
      sibling_browser.get("/dashboard?ri=jp")

      assert_equal 200, sibling_browser.response.status
    end

    test "#{realm} a missing Jump ticket after commit renders the signed-out page" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      grant = create_grant(config, actor, root, "core-#{realm}-jp")
      browser = visa_browser(config, actor, root)
      request_hint(browser, grant, locale: "en")
      3.times do
        break unless browser.response.redirect?

        browser.get(jump_rt_url_from_location_for_test(browser.response.location))
      end

      assert_equal 200, browser.response.status
      JumpRtIssuer.stub(:call, nil) { browser.post("/oidc/logout/confirmation?ri=jp&lx=en") }

      assert_equal 200, browser.response.status
      assert_equal I18n.t("sign.shared.sign_out.completed_description", locale: :en), page_description(browser)
      assert_nil browser.response.location
      assert_predicate root.reload, :revoked?
      assert_predicate grant.reload, :revoked?
      assert_not browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].present?
    end

    test "#{realm} a rejected Jump gateway after commit renders the signed-out page" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      grant = create_grant(config, actor, root, "core-#{realm}-jp")
      browser = visa_browser(config, actor, root)
      request_hint(browser, grant, locale: "en")
      3.times do
        break unless browser.response.redirect?

        browser.get(jump_rt_url_from_location_for_test(browser.response.location))
      end

      assert_equal 200, browser.response.status
      failed = RedirectsTargetResult.failure(kind: :external, source: :jump_rt, reason: :invalid_origin)
      RedirectsJumpGatewayUrl.stub(:call, failed) { browser.post("/oidc/logout/confirmation?ri=jp&lx=en") }

      assert_equal 200, browser.response.status
      assert_equal I18n.t("sign.shared.sign_out.completed_description", locale: :en), page_description(browser)
      assert_nil browser.response.location
      assert_predicate root.reload, :revoked?
      assert_predicate grant.reload, :revoked?
      assert_not browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].present?
    end

    test "#{realm} programming errors after commit propagate" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      grant = create_grant(config, actor, root, "core-#{realm}-jp")
      browser = visa_browser(config, actor, root)
      request_hint(browser, grant, locale: "en")
      3.times do
        break unless browser.response.redirect?

        browser.get(jump_rt_url_from_location_for_test(browser.response.location))
      end
      failure = ->(**) { raise NoMethodError, "broken redirect implementation" }

      JumpRtIssuer.stub(:call, failure) do
        assert_raises(NoMethodError) { browser.post("/oidc/logout/confirmation?ri=jp&lx=en") }
      end

      assert_predicate root.reload, :revoked?
      assert_predicate grant.reload, :revoked?
    end

    test "#{realm} redirect construction failure after commit renders the signed-out page" do
      actor = actor_for(realm)
      root = create_root(config, actor)
      grant = create_grant(config, actor, root, "core-#{realm}-jp")
      browser = visa_browser(config, actor, root)
      request_hint(browser, grant, locale: "en")
      3.times do
        break unless browser.response.redirect?

        browser.get(jump_rt_url_from_location_for_test(browser.response.location))
      end

      assert_equal 200, browser.response.status
      # The Jump issuer reports an unavailable ticket store by returning no token.
      failure = ->(**) { }
      JumpRtIssuer.stub(:call, failure) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end

      assert_equal 200, browser.response.status
      assert_equal I18n.t("sign.shared.sign_out.completed_description", locale: :en), page_description(browser)
      assert_nil browser.response.location
      assert_predicate root.reload, :revoked?
      assert_predicate grant.reload, :revoked?
      assert config.fetch(:participant).exists?(grant_id: grant.id)
      assert_not browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].present?
    end

    test "#{realm} confirmation stops both rotated roots and their grants on the current device" do
      actor = actor_for(realm)
      predecessor = create_root(config, actor)
      other_root = create_root(config, actor)
      predecessor.rotate_refresh_token!
      rotated = config.fetch(:token).rotate_refresh!(presented_refresh_digest: predecessor.reload.refresh_token_digest)

      assert_equal :rotated, rotated.fetch(:status)
      current = rotated.fetch(:token)

      assert_equal predecessor.device_session_id, current.device_session_id

      origin = create_grant(config, actor, current, "core-#{realm}-jp")
      sibling = create_grant(config, actor, current, "warp-#{realm}-jp")
      other_grant = create_grant(config, actor, other_root, "warp-#{realm}-jp")
      hosts = Rails.configuration.x.boot_config.fetch(:hosts)
      core_host = hosts.public_send(config.fetch(:core_host)).host
      warp_host = hosts.public_send(config.fetch(:warp_host)).host
      visa_host = hosts.public_send(config.fetch(:visa_host)).host
      browser = open_session
      sibling_browser = open_session
      install_credentials(browser, origin, actor, current, core_host, config)
      install_credentials(sibling_browser, sibling, actor, current, warp_host, config)

      browser.post("/sign/out?ri=jp")

      assert_equal 303, browser.response.status
      end_session = URI.parse(browser.response.location)
      end_query = Rack::Utils.parse_nested_query(end_session.query.to_s)

      assert_equal visa_host, end_session.host
      assert_equal origin.logout_hint.id_token, end_query.fetch("id_token_hint")
      browser.host!(visa_host)
      visa_cookie = visa_access(actor, current, visa_host, config)
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(visa_cookie)}", URI.parse("https://#{visa_host}/"),
      )
      browser.get(end_session.request_uri)
      3.times do
        break unless browser.response.redirect?

        browser.get(jump_rt_url_from_location_for_test(browser.response.location))
      end

      assert_equal 200, browser.response.status
      pending = browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]

      assert_equal current.device_session.public_id, pending.fetch("device_session_public_id")
      assert_equal origin.public_id, pending.fetch("grant_public_id")
      browser.post(
        "/oidc/logout/confirmation?ri=jp", headers: {
          "Origin" => "https://#{visa_host}", "Sec-Fetch-Site" => "same-origin",
        },
      )

      assert_equal 303, browser.response.status
      callback = URI.parse(jump_rt_url_from_location_for_test(browser.response.location))

      assert_equal end_query.fetch("state"), Rack::Utils.parse_nested_query(callback.query.to_s).fetch("state")
      assert_equal URI.parse(end_query.fetch("post_logout_redirect_uri")).host, callback.host
      [predecessor, current].each do |root|
        assert_predicate root.reload, :revoked?
        assert_equal 1, config.fetch(:target).where(root_id: root.id).count
      end
      assert_predicate current.device_session.reload, :revoked?
      assert_predicate origin.reload, :revoked?
      assert_predicate sibling.reload, :revoked?
      assert_predicate other_root.reload, :currently_usable?
      assert_predicate other_grant.reload, :active?
      browser.host!(core_host)
      browser.post("/sign/out?ri=jp")

      assert_equal 401, browser.response.status
      sibling_browser.get("/dashboard")

      assert_not_equal 200, sibling_browser.response.status
    end
  end

  class UncommittedUnknown
    def call
      raise AuthenticationLogoutCurrentSession::CommitOutcomeUnknown, "commit outcome unavailable"
    end
  end

  class CommittedPrecondition
    def initialize(operation) = @operation = operation

    def call
      @operation.call
      raise AuthenticationLogoutCurrentSession::PreconditionFailed, "device changed"
    end
  end

  class CommittedUnknown
    def initialize(operation) = @operation = operation

    def call
      @operation.call
      raise AuthenticationLogoutCurrentSession::CommitOutcomeUnknown, "commit outcome unavailable"
    end
  end

  class FailingNoticeStore
    def issue!(**) = raise(Umaxica::Valkey::Unavailable, "notice storage unavailable")
  end

  private

  def actor_for(realm)
    case realm
    when "app" then clients(:one)
    when "com" then visitors(:reserved_visitor)
    when "org" then Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    else raise ArgumentError, "unsupported realm"
    end
  end

  def page_description(browser)
    page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")

    assert page
    JSON.parse(page.text).fetch("props").fetch("description")
  end

  def stage_no_hint(browser)
    browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

    assert_equal 200, browser.response.status
    assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
  end

  def fresh_actor(realm)
    case realm
    when "app" then Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
    )
    when "com" then Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
    )
    when "org" then Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    else raise ArgumentError, "unsupported realm"
    end
  end

  def visa_browser(config, actor, root)
    host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
    browser = open_session
    browser.host!(host)
    browser.https!
    cookie = visa_access(actor, root, host, config)
    browser.cookies << Rack::Test::Cookie.new(
      "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(cookie)}", URI.parse("https://#{host}/"),
    )
    browser
  end

  def request_hint(browser, grant, locale:, token: grant.logout_hint.id_token, client_id: grant.oidc_client_id)
    client = OidcClientRegistry.find!(grant.oidc_client_id)
    browser.get(
      "/oidc/logout", params: {
        id_token_hint: token,
        client_id: client_id,
        post_logout_redirect_uri: client.post_logout_redirect_uris.first,
        state: "test-state",
        ri: "jp",
        lx: locale,
      },
    )
  end

  def create_root(config, actor)
    config.fetch(:token).create!(
      :authentication_epoch => 0, config.fetch(:owner) => actor, config.fetch(:kind) => config.fetch(:kind_value),
    )
  end

  def create_grant(config, actor, root, client_id)
    client = OidcClientRegistry.find!(client_id)
    grant = config.fetch(:grant).create!(
      :authentication_epoch => 0, config.fetch(:root) => root, :oidc_client_id => client_id,
      :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
      :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
    )
    store_oidc_rp_logout_hint!(grant, actor, client)
    grant
  end

  def install_credentials(browser, grant, actor, root, host, config)
    client = OidcClientRegistry.find!(grant.oidc_client_id)
    browser.host!(host)
    browser.https!
    browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      actor, host:, resource_type: config.fetch(:resource_type), session_public_id: root.public_id,
             base_session_public_id: root.public_id, oidc_sid: grant.public_id, oidc_jti: grant.oidc_jti,
             expires_at: 10.minutes.from_now, scopes: %w(openid profile), issuer: OidcIssuer.for_client(client),
             audiences: [client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
             subject: OidcSubject.for(actor, resource_type: config.fetch(:resource_type)), client_id: client.client_id,
    )
    browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = grant.issue_refresh_token!
  end

  def visa_access(actor, root, host, config)
    AuthenticationToken.encode(
      actor, host:, session_public_id: root.device_session.public_id, oidc_sid: root.device_session.public_id,
             oidc_jti: root.oidc_jti, resource_type: config.fetch(:resource_type),
             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(config.fetch(:resource_type)),
             authentication_context: root.authentication_context_value.to_s,
    )
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
