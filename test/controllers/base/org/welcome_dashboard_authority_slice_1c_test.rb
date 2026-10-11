# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::Org::WelcomeDashboardAuthoritySlice1CTest < ActionDispatch::IntegrationTest
  # Exercise the public exception representation used outside development.
  setup do
    @previous_detailed_exceptions = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
  end

  teardown do
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @previous_detailed_exceptions
  end

  fixtures :operators

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @sign_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    @staff = operators(:one)
  end

  test "public_root_renders one neutral link to the Base sign entry" do
    get base_org_root_url(ri: "jp"), headers: host_headers(@host)

    assert_response :success
    assert_equal base_org_sign_show_path(ri: "jp"), inertia_props.fetch("sign_in").fetch("href")
    assert_nil inertia_props["sign_up"]
  end

  test "dashboard_renders_when_signed_in" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    select_token!(surface: :org, principal: @staff, token: token)
    selected_persona(token).update!(moniker: "Selected Org Agent")
    token.update!(last_used_at: 10.minutes.ago)
    last_used_at = token.reload.last_used_at

    http_headers_9 =
      begin
        fx0_token = token
        begin
          f0_headers = as_staff_headers(@staff, host: @host, session_public_id: fx0_token.public_id)
          f0_host = f0_headers["Host"]
          f0_route =
            begin
              Rails.application.routes.recognize_path("https://#{f0_host}/") if f0_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f0_family, f0_surface = f0_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f0_family) && f0_surface == "org"
            f0_client_id =
              case f0_family
              when "base" then "base-#{f0_surface}-ww"
              when "edit" then "edit-org"
              else "#{f0_family}-#{f0_surface}"
              end
            f0_token = OperatorToken.find_by!(public_id: f0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f0_client = OidcClientRegistry.find!(f0_client_id)
            f0_key = [f0_client.client_id, f0_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f0_key] && f0_token.currently_usable? &&
                !(f0_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f0_token.device_session_id,
                  oidc_client_id: f0_client.client_id,
                  revoked_at: nil,
                ))
              f0_token.rotate_refresh_token! unless f0_token.device_session.current_refresh_token_id
              f0_now = Time.current
              f0_session = OperatorRpSession.create!(
                operator_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                refresh_token_expires_at: f0_now + 10.minutes,
              )
              f0_access = AuthenticationTokenService.encode(
                f0_token.staff, host: f0_host, resource_type: "operator",
                                session_public_id: f0_token.public_id, base_session_public_id: f0_token.public_id,
                                oidc_sid: f0_session.public_id, oidc_jti: f0_session.oidc_jti,
                                expires_at: f0_now + 10.minutes, scopes: %w(openid profile),
                                issuer: OidcIssuer.for_client(f0_client), audiences: [f0_client.aud],
                                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                                subject: OidcSubject.for(
                                  f0_token.staff,
                                  resource_type: "operator",
                                ), client_id: f0_client.client_id,
              )
              @base_browser_rp_credentials[f0_key] = [f0_access, f0_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f0_key]
              f0_access, f0_refresh = @base_browser_rp_credentials.fetch(f0_key)
              f0_cookie = [
                f0_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f0_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f0_refresh)}",
              ].join("; ")
              f0_headers = f0_headers.merge(
                "Cookie" => f0_cookie,
                "HTTP_COOKIE" => f0_cookie,
              )
            end
          end
          f0_headers
        end
      end
    get base_org_dashboard_url(ri: "jp"), headers: http_headers_9

    assert_response :success
    assert_equal last_used_at, token.reload.last_used_at
    assert_equal "base/org/dashboards/show", inertia_component
    assert_equal I18n.t("base.shared.dashboard.title", locale: :ja), inertia_props.fetch("title")
    assert_no_match(/id\.umaxica/, response.body)

    sections = inertia_props.fetch("sections")
    expected_headings = [
      I18n.t("base.shared.dashboard.sections.menu_links", locale: :ja),
      I18n.t("base.shared.dashboard.sections.primary_links", locale: :ja),
    ]

    assert_equal expected_headings,
                 sections.map { |section| section.fetch("heading") }

    menu_links = sections.first.fetch("items")

    assert_equal({ "display_name" => "Selected Org Agent" }, sections.first.fetch("current_identity"))
    primary_links = sections.second.fetch("items")
    links = sections.flat_map { |section| section.fetch("items") }
    hrefs = links.map { |link| link.fetch("href") }
    labelled = links.to_h { |link| [link.fetch("label"), link.fetch("href")] }
    primary_hrefs = primary_links.map { |link| link.fetch("href") }

    assert_equal [
      base_org_identity_path(ri: "jp"),
      base_org_switcher_path(ri: "jp"),
      new_base_org_sign_out_path(ri: "jp"),
    ], menu_links.map { |link| link.fetch("href") }
    # The dashboard "preference" link intentionally targets the identity page, which the menu also links to.
    menu_links.reject { |link| link.fetch("href") == base_org_identity_path(ri: "jp") }.each do |link|
      assert_not_includes primary_hrefs, link.fetch("href")
    end

    assert_includes hrefs, base_org_dashboard_path(ri: "jp")
    assert_equal base_org_accounts_path(ri: "jp"), labelled.fetch(dashboard_label(:account))
    assert_equal base_org_organizations_path(ri: "jp"), labelled.fetch(dashboard_label(:organization))
    assert_equal base_org_avatar_path(ri: "jp"), labelled.fetch(dashboard_label(:avatar))
    assert_includes hrefs, base_org_switcher_path(ri: "jp")
    assert_equal base_org_identity_path(ri: "jp"), labelled.fetch(dashboard_label(:preference))
    assert_equal base_org_pwa_offline_path(ri: "jp"), labelled.fetch(dashboard_label(:offline))
    assert_not hrefs.any? { |href| href.match?(%r{/preference/(calendar|clock|currency)}) }
    assert_not hrefs.any? { |href| href.match?(%r{/identity/(emails|telephones|secrets|sessions)}) }
    assert_includes hrefs, new_base_org_sign_out_path(ri: "jp")
    assert_not hrefs.any? { |href| href.include?("/sign/in") || href.include?("/sign/up") }
    assert_not labelled.key?(dashboard_label(:oidc_discovery))
    assert_not labelled.key?(dashboard_label(:jwks))
    assert_not labelled.key?(dashboard_label(:userinfo))

    publishing_heading = I18n.t("base.shared.dashboard.sections.publishing", locale: :ja)

    assert_not inertia_props.fetch("sections").any? { |section| section.fetch("heading") == publishing_heading }
    assert_no_match(%r{//example|umaxica\.example|evil\.example}, response.body)
  end

  test "dashboard_identity_uses_the_selected_org_persona_not_request_parameters" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    select_token!(surface: :org, principal: @staff, token: token)
    selected_persona(token).update!(moniker: "Authenticated Org Agent")
    selected_account_public_id = token.selected_account_public_id
    token.update!(last_used_at: 10.minutes.ago)
    last_used_at = token.reload.last_used_at

    http_headers_8 =
      begin
        fx1_token = token
        begin
          f1_headers = as_staff_headers(@staff, host: @host, session_public_id: fx1_token.public_id)
          f1_host = f1_headers["Host"]
          f1_route =
            begin
              Rails.application.routes.recognize_path("https://#{f1_host}/") if f1_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f1_family, f1_surface = f1_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f1_family) && f1_surface == "org"
            f1_client_id =
              case f1_family
              when "base" then "base-#{f1_surface}-ww"
              when "edit" then "edit-org"
              else "#{f1_family}-#{f1_surface}"
              end
            f1_token = OperatorToken.find_by!(public_id: f1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f1_client = OidcClientRegistry.find!(f1_client_id)
            f1_key = [f1_client.client_id, f1_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f1_key] && f1_token.currently_usable? &&
                !(f1_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f1_token.device_session_id,
                  oidc_client_id: f1_client.client_id,
                  revoked_at: nil,
                ))
              f1_token.rotate_refresh_token! unless f1_token.device_session.current_refresh_token_id
              f1_now = Time.current
              f1_session = OperatorRpSession.create!(
                operator_token: f1_token, oidc_client_id: f1_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f1_now,
                refresh_token_expires_at: f1_now + 10.minutes,
              )
              f1_access = AuthenticationTokenService.encode(
                f1_token.staff, host: f1_host, resource_type: "operator",
                                session_public_id: f1_token.public_id, base_session_public_id: f1_token.public_id,
                                oidc_sid: f1_session.public_id, oidc_jti: f1_session.oidc_jti,
                                expires_at: f1_now + 10.minutes, scopes: %w(openid profile),
                                issuer: OidcIssuer.for_client(f1_client), audiences: [f1_client.aud],
                                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f1_client),
                                subject: OidcSubject.for(
                                  f1_token.staff,
                                  resource_type: "operator",
                                ), client_id: f1_client.client_id,
              )
              @base_browser_rp_credentials[f1_key] = [f1_access, f1_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f1_key]
              f1_access, f1_refresh = @base_browser_rp_credentials.fetch(f1_key)
              f1_cookie = [
                f1_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f1_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f1_refresh)}",
              ].join("; ")
              f1_headers = f1_headers.merge(
                "Cookie" => f1_cookie,
                "HTTP_COOKIE" => f1_cookie,
              )
            end
          end
          f1_headers
        end
      end
    get base_org_dashboard_url(
      ri: "jp", account_public_id: "attacker-account", avatar_public_id: "attacker-avatar",
      moniker: "Attacker Persona",
    ), headers: http_headers_8

    assert_response :success
    identity = inertia_props.fetch("sections").first.fetch("current_identity")

    assert_equal "Authenticated Org Agent", identity.fetch("display_name")
    assert_equal ["display_name"], identity.keys
    assert_equal selected_account_public_id, token.reload.selected_account_public_id
    assert_equal last_used_at, token.reload.last_used_at
  end

  test "dashboard_fails_explicitly_when_the_selected_org_persona_has_no_display_name" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    select_token!(surface: :org, principal: @staff, token: token)
    selected_persona(token).update!(moniker: " ")

    http_headers_7 =
      begin
        fx2_token = token
        begin
          f2_headers = as_staff_headers(@staff, host: @host, session_public_id: fx2_token.public_id)
          f2_host = f2_headers["Host"]
          f2_route =
            begin
              Rails.application.routes.recognize_path("https://#{f2_host}/") if f2_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f2_family, f2_surface = f2_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f2_family) && f2_surface == "org"
            f2_client_id =
              case f2_family
              when "base" then "base-#{f2_surface}-ww"
              when "edit" then "edit-org"
              else "#{f2_family}-#{f2_surface}"
              end
            f2_token = OperatorToken.find_by!(public_id: f2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f2_client = OidcClientRegistry.find!(f2_client_id)
            f2_key = [f2_client.client_id, f2_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f2_key] && f2_token.currently_usable? &&
                !(f2_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f2_token.device_session_id,
                  oidc_client_id: f2_client.client_id,
                  revoked_at: nil,
                ))
              f2_token.rotate_refresh_token! unless f2_token.device_session.current_refresh_token_id
              f2_now = Time.current
              f2_session = OperatorRpSession.create!(
                operator_token: f2_token, oidc_client_id: f2_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f2_now,
                refresh_token_expires_at: f2_now + 10.minutes,
              )
              f2_access = AuthenticationTokenService.encode(
                f2_token.staff, host: f2_host, resource_type: "operator",
                                session_public_id: f2_token.public_id, base_session_public_id: f2_token.public_id,
                                oidc_sid: f2_session.public_id, oidc_jti: f2_session.oidc_jti,
                                expires_at: f2_now + 10.minutes, scopes: %w(openid profile),
                                issuer: OidcIssuer.for_client(f2_client), audiences: [f2_client.aud],
                                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f2_client),
                                subject: OidcSubject.for(
                                  f2_token.staff,
                                  resource_type: "operator",
                                ), client_id: f2_client.client_id,
              )
              @base_browser_rp_credentials[f2_key] = [f2_access, f2_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f2_key]
              f2_access, f2_refresh = @base_browser_rp_credentials.fetch(f2_key)
              f2_cookie = [
                f2_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f2_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f2_refresh)}",
              ].join("; ")
              f2_headers = f2_headers.merge(
                "Cookie" => f2_cookie,
                "HTTP_COOKIE" => f2_cookie,
              )
            end
          end
          f2_headers
        end
      end
    error =
      assert_raises(RuntimeError) do
        get(
          base_org_dashboard_url(ri: "jp"), headers: http_headers_7,
        )
      end

    assert_match "selected org Persona has no display name", error.message
  end

  test "authenticated direct root request returns 404 without redirect" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    select_token!(surface: :org, principal: @staff, token: token)

    http_headers_6 =
      begin
        fx3_token = token
        begin
          f3_headers = as_staff_headers(@staff, host: @host, session_public_id: fx3_token.public_id)
          f3_host = f3_headers["Host"]
          f3_route =
            begin
              Rails.application.routes.recognize_path("https://#{f3_host}/") if f3_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f3_family, f3_surface = f3_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f3_family) && f3_surface == "org"
            f3_client_id =
              case f3_family
              when "base" then "base-#{f3_surface}-ww"
              when "edit" then "edit-org"
              else "#{f3_family}-#{f3_surface}"
              end
            f3_token = OperatorToken.find_by!(public_id: f3_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f3_client = OidcClientRegistry.find!(f3_client_id)
            f3_key = [f3_client.client_id, f3_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f3_key] && f3_token.currently_usable? &&
                !(f3_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f3_token.device_session_id,
                  oidc_client_id: f3_client.client_id,
                  revoked_at: nil,
                ))
              f3_token.rotate_refresh_token! unless f3_token.device_session.current_refresh_token_id
              f3_now = Time.current
              f3_session = OperatorRpSession.create!(
                operator_token: f3_token, oidc_client_id: f3_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f3_now,
                refresh_token_expires_at: f3_now + 10.minutes,
              )
              f3_access = AuthenticationTokenService.encode(
                f3_token.staff, host: f3_host, resource_type: "operator",
                                session_public_id: f3_token.public_id, base_session_public_id: f3_token.public_id,
                                oidc_sid: f3_session.public_id, oidc_jti: f3_session.oidc_jti,
                                expires_at: f3_now + 10.minutes, scopes: %w(openid profile),
                                issuer: OidcIssuer.for_client(f3_client), audiences: [f3_client.aud],
                                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f3_client),
                                subject: OidcSubject.for(
                                  f3_token.staff,
                                  resource_type: "operator",
                                ), client_id: f3_client.client_id,
              )
              @base_browser_rp_credentials[f3_key] = [f3_access, f3_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f3_key]
              f3_access, f3_refresh = @base_browser_rp_credentials.fetch(f3_key)
              f3_cookie = [
                f3_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f3_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f3_refresh)}",
              ].join("; ")
              f3_headers = f3_headers.merge(
                "Cookie" => f3_cookie,
                "HTTP_COOKIE" => f3_cookie,
              )
            end
          end
          f3_headers
        end
      end
    get "/", headers: http_headers_6

    assert_response :not_found
    assert_nil response.location
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "anonymous direct root request renders Home" do
    get "/", headers: host_headers(@host)

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_not inertia_props.key?("sections")
  end

  test "authenticated direct dashboard request renders Dashboard" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    select_token!(surface: :org, principal: @staff, token: token)

    http_headers_5 =
      begin
        fx4_token = token
        begin
          f4_headers = as_staff_headers(@staff, host: @host, session_public_id: fx4_token.public_id)
          f4_host = f4_headers["Host"]
          f4_route =
            begin
              Rails.application.routes.recognize_path("https://#{f4_host}/") if f4_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f4_family, f4_surface = f4_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f4_family) && f4_surface == "org"
            f4_client_id =
              case f4_family
              when "base" then "base-#{f4_surface}-ww"
              when "edit" then "edit-org"
              else "#{f4_family}-#{f4_surface}"
              end
            f4_token = OperatorToken.find_by!(public_id: f4_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f4_client = OidcClientRegistry.find!(f4_client_id)
            f4_key = [f4_client.client_id, f4_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f4_key] && f4_token.currently_usable? &&
                !(f4_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f4_token.device_session_id,
                  oidc_client_id: f4_client.client_id,
                  revoked_at: nil,
                ))
              f4_token.rotate_refresh_token! unless f4_token.device_session.current_refresh_token_id
              f4_now = Time.current
              f4_session = OperatorRpSession.create!(
                operator_token: f4_token, oidc_client_id: f4_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f4_now,
                refresh_token_expires_at: f4_now + 10.minutes,
              )
              f4_access = AuthenticationTokenService.encode(
                f4_token.staff, host: f4_host, resource_type: "operator",
                                session_public_id: f4_token.public_id, base_session_public_id: f4_token.public_id,
                                oidc_sid: f4_session.public_id, oidc_jti: f4_session.oidc_jti,
                                expires_at: f4_now + 10.minutes, scopes: %w(openid profile),
                                issuer: OidcIssuer.for_client(f4_client), audiences: [f4_client.aud],
                                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f4_client),
                                subject: OidcSubject.for(
                                  f4_token.staff,
                                  resource_type: "operator",
                                ), client_id: f4_client.client_id,
              )
              @base_browser_rp_credentials[f4_key] = [f4_access, f4_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f4_key]
              f4_access, f4_refresh = @base_browser_rp_credentials.fetch(f4_key)
              f4_cookie = [
                f4_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f4_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f4_refresh)}",
              ].join("; ")
              f4_headers = f4_headers.merge(
                "Cookie" => f4_cookie,
                "HTTP_COOKIE" => f4_cookie,
              )
            end
          end
          f4_headers
        end
      end
    get "/dashboard", headers: http_headers_5

    assert_response :success
    assert_equal "base/org/dashboards/show", inertia_component
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  # The accepted Base guidance contract supersedes anonymous Dashboard's old 404.
  # Authenticated Home remains a rendered 404 in its separate test above.
  test "anonymous direct dashboard request reaches the same Base passive Sign entry" do
    get "/dashboard", headers: { "Host" => @host }

    assert_response :redirect
    destination = URI.parse(response.location)

    assert_equal @host, destination.host
    assert_equal "/sign", destination.path
    assert_equal "jp", Rack::Utils.parse_query(destination.query).fetch("ri")
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "root_with_an_expired_org_session_renders_the_home" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    select_token!(surface: :org, principal: @staff, token: token)
    token.update!(discard_at: token.created_at)
    travel 1.second

    http_headers_4 =
      begin
        fx5_token = token
        begin
          f5_headers = as_staff_headers(@staff, host: @host, session_public_id: fx5_token.public_id)
          f5_host = f5_headers["Host"]
          f5_route =
            begin
              Rails.application.routes.recognize_path("https://#{f5_host}/") if f5_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f5_family, f5_surface = f5_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f5_family) && f5_surface == "org"
            f5_client_id =
              case f5_family
              when "base" then "base-#{f5_surface}-ww"
              when "edit" then "edit-org"
              else "#{f5_family}-#{f5_surface}"
              end
            f5_token = OperatorToken.find_by!(public_id: f5_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f5_client = OidcClientRegistry.find!(f5_client_id)
            f5_key = [f5_client.client_id, f5_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f5_key] && f5_token.currently_usable? &&
                !(f5_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f5_token.device_session_id,
                  oidc_client_id: f5_client.client_id,
                  revoked_at: nil,
                ))
              f5_token.rotate_refresh_token! unless f5_token.device_session.current_refresh_token_id
              f5_now = Time.current
              f5_session = OperatorRpSession.create!(
                operator_token: f5_token, oidc_client_id: f5_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f5_now,
                refresh_token_expires_at: f5_now + 10.minutes,
              )
              f5_access = AuthenticationTokenService.encode(
                f5_token.staff, host: f5_host, resource_type: "operator",
                                session_public_id: f5_token.public_id, base_session_public_id: f5_token.public_id,
                                oidc_sid: f5_session.public_id, oidc_jti: f5_session.oidc_jti,
                                expires_at: f5_now + 10.minutes, scopes: %w(openid profile),
                                issuer: OidcIssuer.for_client(f5_client), audiences: [f5_client.aud],
                                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f5_client),
                                subject: OidcSubject.for(
                                  f5_token.staff,
                                  resource_type: "operator",
                                ), client_id: f5_client.client_id,
              )
              @base_browser_rp_credentials[f5_key] = [f5_access, f5_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f5_key]
              f5_access, f5_refresh = @base_browser_rp_credentials.fetch(f5_key)
              f5_cookie = [
                f5_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f5_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f5_refresh)}",
              ].join("; ")
              f5_headers = f5_headers.merge(
                "Cookie" => f5_cookie,
                "HTTP_COOKIE" => f5_cookie,
              )
            end
          end
          f5_headers
        end
      end
    get base_org_root_url(ri: "jp"), headers: http_headers_4

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
  end

  # The RP credential is checked against its live RP Session on every request, so a credential
  # whose RP Session row is gone is refused although the root cookie beside it is still valid.
  test "root_with_a_credential_whose_org_rp_session_record_is_gone_renders_the_home" do
    headers =
      begin
        rp_headers = as_staff_headers(@staff, host: @host)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "org"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OperatorRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
            rp_now = Time.current
            rp_session = OperatorRpSession.create!(
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.staff, host: rp_host, resource_type: "operator",
                              session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                              oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                              expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                              issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                              subject: OidcSubject.for(
                                rp_token.staff,
                                resource_type: "operator",
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
    OperatorRpSession.where(oidc_client_id: "base-org-ww").delete_all

    get base_org_root_url(ri: "jp"), headers: headers

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
  end

  test "root_with_a_malformed_org_bearer_renders_the_home" do
    get base_org_root_url(ri: "jp"), headers: bearer_headers("not-a-jwt", host: @host)

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
  end

  test "root_ignores_unrelated_query_parameters_for_the_org_representation" do
    get base_org_root_url(ri: "jp", signed_in: "1", dashboard: "1"), headers: host_headers(@host)

    assert_response :success
    assert_equal "base/org/roots/index", inertia_component
  end

  test "authenticated_preference_navigation_returns_to_the_canonical_org_root" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    select_token!(surface: :org, principal: @staff, token: token)
    token.update!(last_used_at: 10.minutes.ago)
    last_used_at = token.reload.last_used_at

    %w(jp us).each do |region|
      http_headers_3 =
        begin
          fx6_token = token
          begin
            f6_headers = as_staff_headers(@staff, host: @host, session_public_id: fx6_token.public_id)
            f6_host = f6_headers["Host"]
            f6_route =
              begin
                Rails.application.routes.recognize_path("https://#{f6_host}/") if f6_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f6_family, f6_surface = f6_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f6_family) && f6_surface == "org"
              f6_client_id =
                case f6_family
                when "base" then "base-#{f6_surface}-ww"
                when "edit" then "edit-org"
                else "#{f6_family}-#{f6_surface}"
                end
              f6_token = OperatorToken.find_by!(public_id: f6_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f6_client = OidcClientRegistry.find!(f6_client_id)
              f6_key = [f6_client.client_id, f6_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f6_key] && f6_token.currently_usable? &&
                  !(f6_token.device_session_id && OperatorRpSession.exists?(
                    device_session_id: f6_token.device_session_id,
                    oidc_client_id: f6_client.client_id,
                    revoked_at: nil,
                  ))
                f6_token.rotate_refresh_token! unless f6_token.device_session.current_refresh_token_id
                f6_now = Time.current
                f6_session = OperatorRpSession.create!(
                  operator_token: f6_token, oidc_client_id: f6_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f6_now,
                  refresh_token_expires_at: f6_now + 10.minutes,
                )
                f6_access = AuthenticationTokenService.encode(
                  f6_token.staff, host: f6_host, resource_type: "operator",
                                  session_public_id: f6_token.public_id, base_session_public_id: f6_token.public_id,
                                  oidc_sid: f6_session.public_id, oidc_jti: f6_session.oidc_jti,
                                  expires_at: f6_now + 10.minutes, scopes: %w(openid profile),
                                  issuer: OidcIssuer.for_client(f6_client), audiences: [f6_client.aud],
                                  jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f6_client),
                                  subject: OidcSubject.for(
                                    f6_token.staff,
                                    resource_type: "operator",
                                  ), client_id: f6_client.client_id,
                )
                @base_browser_rp_credentials[f6_key] = [f6_access, f6_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f6_key]
                f6_access, f6_refresh = @base_browser_rp_credentials.fetch(f6_key)
                f6_cookie = [
                  f6_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f6_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f6_refresh)}",
                ].join("; ")
                f6_headers = f6_headers.merge(
                  "Cookie" => f6_cookie,
                  "HTTP_COOKIE" => f6_cookie,
                )
              end
            end
            f6_headers
          end
        end
      get base_org_preference_url(ri: region), headers: http_headers_3

      assert_response :success
      assert_equal base_org_dashboard_path(ri: region), inertia_props.dig("up_link", "href")
      assert_equal last_used_at, token.reload.last_used_at
    end
  end

  test "identity_show_links_up_to_the_dashboard" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    select_token!(surface: :org, principal: @staff, token: token)

    http_headers_2 =
      begin
        fx7_token = token
        begin
          f7_headers = as_staff_headers(@staff, host: @host, session_public_id: fx7_token.public_id)
          f7_host = f7_headers["Host"]
          f7_route =
            begin
              Rails.application.routes.recognize_path("https://#{f7_host}/") if f7_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f7_family, f7_surface = f7_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f7_family) && f7_surface == "org"
            f7_client_id =
              case f7_family
              when "base" then "base-#{f7_surface}-ww"
              when "edit" then "edit-org"
              else "#{f7_family}-#{f7_surface}"
              end
            f7_token = OperatorToken.find_by!(public_id: f7_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f7_client = OidcClientRegistry.find!(f7_client_id)
            f7_key = [f7_client.client_id, f7_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f7_key] && f7_token.currently_usable? &&
                !(f7_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f7_token.device_session_id,
                  oidc_client_id: f7_client.client_id,
                  revoked_at: nil,
                ))
              f7_token.rotate_refresh_token! unless f7_token.device_session.current_refresh_token_id
              f7_now = Time.current
              f7_session = OperatorRpSession.create!(
                operator_token: f7_token, oidc_client_id: f7_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f7_now,
                refresh_token_expires_at: f7_now + 10.minutes,
              )
              f7_access = AuthenticationTokenService.encode(
                f7_token.staff, host: f7_host, resource_type: "operator",
                                session_public_id: f7_token.public_id, base_session_public_id: f7_token.public_id,
                                oidc_sid: f7_session.public_id, oidc_jti: f7_session.oidc_jti,
                                expires_at: f7_now + 10.minutes, scopes: %w(openid profile),
                                issuer: OidcIssuer.for_client(f7_client), audiences: [f7_client.aud],
                                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f7_client),
                                subject: OidcSubject.for(
                                  f7_token.staff,
                                  resource_type: "operator",
                                ), client_id: f7_client.client_id,
              )
              @base_browser_rp_credentials[f7_key] = [f7_access, f7_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f7_key]
              f7_access, f7_refresh = @base_browser_rp_credentials.fetch(f7_key)
              f7_cookie = [
                f7_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f7_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f7_refresh)}",
              ].join("; ")
              f7_headers = f7_headers.merge(
                "Cookie" => f7_cookie,
                "HTTP_COOKIE" => f7_cookie,
              )
            end
          end
          f7_headers
        end
      end
    get base_org_identity_url(ri: "jp"), headers: http_headers_2

    assert_response :success
    assert_equal "base/org/identities/show", inertia_component
    assert_equal I18n.t("base.shared.identity.up_link", locale: :ja), inertia_props.dig("up_link", "label")
    assert_equal base_org_dashboard_path(ri: "jp"), inertia_props.dig("up_link", "href")
  end

  test "menu links preserve the full request context" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    select_token!(surface: :org, principal: @staff, token: token)

    http_headers_1 =
      begin
        fx8_token = token
        begin
          f8_headers = as_staff_headers(@staff, host: @host, session_public_id: fx8_token.public_id)
          f8_host = f8_headers["Host"]
          f8_route =
            begin
              Rails.application.routes.recognize_path("https://#{f8_host}/") if f8_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f8_family, f8_surface = f8_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f8_family) && f8_surface == "org"
            f8_client_id =
              case f8_family
              when "base" then "base-#{f8_surface}-ww"
              when "edit" then "edit-org"
              else "#{f8_family}-#{f8_surface}"
              end
            f8_token = OperatorToken.find_by!(public_id: f8_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f8_client = OidcClientRegistry.find!(f8_client_id)
            f8_key = [f8_client.client_id, f8_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f8_key] && f8_token.currently_usable? &&
                !(f8_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f8_token.device_session_id,
                  oidc_client_id: f8_client.client_id,
                  revoked_at: nil,
                ))
              f8_token.rotate_refresh_token! unless f8_token.device_session.current_refresh_token_id
              f8_now = Time.current
              f8_session = OperatorRpSession.create!(
                operator_token: f8_token, oidc_client_id: f8_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f8_now,
                refresh_token_expires_at: f8_now + 10.minutes,
              )
              f8_access = AuthenticationTokenService.encode(
                f8_token.staff, host: f8_host, resource_type: "operator",
                                session_public_id: f8_token.public_id, base_session_public_id: f8_token.public_id,
                                oidc_sid: f8_session.public_id, oidc_jti: f8_session.oidc_jti,
                                expires_at: f8_now + 10.minutes, scopes: %w(openid profile),
                                issuer: OidcIssuer.for_client(f8_client), audiences: [f8_client.aud],
                                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f8_client),
                                subject: OidcSubject.for(
                                  f8_token.staff,
                                  resource_type: "operator",
                                ), client_id: f8_client.client_id,
              )
              @base_browser_rp_credentials[f8_key] =
                [f8_access, f8_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f8_key]
              f8_access, f8_refresh = @base_browser_rp_credentials.fetch(f8_key)
              f8_cookie = [
                f8_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f8_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f8_refresh)}",
              ].join("; ")
              f8_headers = f8_headers.merge(
                "Cookie" => f8_cookie,
                "HTTP_COOKIE" => f8_cookie,
              )
            end
          end
          f8_headers
        end
      end
    get base_org_dashboard_url(ri: "jp", ct: "dr", lx: "en", tz: "asia/tokyo"),
        headers: http_headers_1

    menu_hrefs = inertia_props.fetch("sections").first.fetch("items").map { |item| item.fetch("href") }
    menu_hrefs.each do |href|
      query = Rack::Utils.parse_nested_query(URI.parse(href).query.to_s)

      assert_equal "jp", query.fetch("ri")
      assert_equal "dr", query.fetch("ct")
      assert_equal "en", query.fetch("lx")
      assert_equal "asia/tokyo", query.fetch("tz")
    end
  end

  test "identity_show_links_to_identity_pages" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    select_token!(surface: :org, principal: @staff, token: token)

    http_headers_0 =
      begin
        fx9_token = token
        begin
          f9_headers = as_staff_headers(@staff, host: @host, session_public_id: fx9_token.public_id)
          f9_host = f9_headers["Host"]
          f9_route =
            begin
              Rails.application.routes.recognize_path("https://#{f9_host}/") if f9_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f9_family, f9_surface = f9_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f9_family) && f9_surface == "org"
            f9_client_id =
              case f9_family
              when "base" then "base-#{f9_surface}-ww"
              when "edit" then "edit-org"
              else "#{f9_family}-#{f9_surface}"
              end
            f9_token = OperatorToken.find_by!(public_id: f9_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f9_client = OidcClientRegistry.find!(f9_client_id)
            f9_key = [f9_client.client_id, f9_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f9_key] && f9_token.currently_usable? &&
                !(f9_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: f9_token.device_session_id,
                  oidc_client_id: f9_client.client_id,
                  revoked_at: nil,
                ))
              f9_token.rotate_refresh_token! unless f9_token.device_session.current_refresh_token_id
              f9_now = Time.current
              f9_session = OperatorRpSession.create!(
                operator_token: f9_token, oidc_client_id: f9_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f9_now,
                refresh_token_expires_at: f9_now + 10.minutes,
              )
              f9_access = AuthenticationTokenService.encode(
                f9_token.staff, host: f9_host, resource_type: "operator",
                                session_public_id: f9_token.public_id, base_session_public_id: f9_token.public_id,
                                oidc_sid: f9_session.public_id, oidc_jti: f9_session.oidc_jti,
                                expires_at: f9_now + 10.minutes, scopes: %w(openid profile),
                                issuer: OidcIssuer.for_client(f9_client), audiences: [f9_client.aud],
                                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f9_client),
                                subject: OidcSubject.for(
                                  f9_token.staff,
                                  resource_type: "operator",
                                ), client_id: f9_client.client_id,
              )
              @base_browser_rp_credentials[f9_key] = [f9_access, f9_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f9_key]
              f9_access, f9_refresh = @base_browser_rp_credentials.fetch(f9_key)
              f9_cookie = [
                f9_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f9_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f9_refresh)}",
              ].join("; ")
              f9_headers = f9_headers.merge(
                "Cookie" => f9_cookie,
                "HTTP_COOKIE" => f9_cookie,
              )
            end
          end
          f9_headers
        end
      end
    get base_org_identity_url(ri: "jp"), headers: http_headers_0

    assert_response :success
    labelled =
      inertia_props.fetch("sections")
        .flat_map { |section| section.fetch("items") }
        .to_h { |link| [link.fetch("label"), link.fetch("href")] }

    assert_equal base_org_identity_emails_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.emails", locale: :ja))
    assert_equal base_org_identity_telephones_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.telephones", locale: :ja))
    assert_equal base_org_identity_birthdate_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.birthdate", locale: :ja))
    assert_equal base_org_identity_secrets_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.secrets", locale: :ja))
    assert_equal base_org_sessions_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.sessions", locale: :ja))
    assert_equal base_org_identity_activities_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.activities", locale: :ja))
    assert_equal base_org_identity_standing_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.standing", locale: :ja))
    assert_equal base_org_identity_withdrawal_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.withdrawal", locale: :ja))
    assert_equal new_base_org_sign_out_path(ri: "jp"),
                 labelled.fetch(I18n.t("sign.app.settings.show.logout", locale: :ja))
  end

  test "welcome_route_exists" do
    route = Rails.application.routes.recognize_path(
      "https://#{@host}/welcome",
      method: :get,
    )

    assert_equal "base/org/welcomes", route.fetch(:controller)
  end

  test "invalid browser cookie partitions remain anonymous on literal Home and Dashboard" do
    expired = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    expired.update!(discard_at: expired.created_at)
    revoked = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    revoked.revoke!
    session_ids = [
      ["expired", expired.public_id],
      ["revoked", revoked.public_id],
      ["missing", "missing-session-0001"],
    ]
    credentials = []
    session_ids.each do |label, session_id|
      credential = AuthenticationToken.encode(
        @staff, host: @host, session_public_id: session_id, resource_type: "operator",
                jwt_issuer_id: "surface:BASE_ORG",
      )
      credentials << [label, credential]
    end
    credentials << ["malformed", "not-a-jwt"]

    credentials.each do |label, credential|
      cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = credential
      get "/", headers: { "Host" => @host }

      assert_response :success, label
      assert_nil response.location, label
      assert_equal "base/org/roots/index", inertia_component, label

      cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = credential
      get "/dashboard", headers: { "Host" => @host }

      assert_response :redirect, label
      destination = URI.parse(response.location)

      assert_equal @host, destination.host, label
      assert_equal "/sign", destination.path, label
      assert_equal "jp", Rack::Utils.parse_query(destination.query).fetch("ri"), label
      assert_equal "no-store", response.headers["Cache-Control"], label
    end
  end

  private

  # Requests use ri=jp, so the dashboard renders its Japanese copy.
  def dashboard_label(key)
    I18n.t(key, scope: "base.shared.dashboard.links", locale: :ja)
  end

  def select_token!(surface:, principal:, token:)
    BaseSelectorBootstrapAuthority.call(surface: surface, principal: principal)
    BaseSelectorAuthority.prepare(surface: surface, principal: principal, session: token)
  end

  def selected_persona(token)
    Agent.find_by!(public_id: token.selected_account_public_id)
  end

  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Base::Org::WelcomeDashboardAuthoritySlice1CTest
  private
end

# DAMP local helper copy on the test class.
class Base::Org::WelcomeDashboardAuthoritySlice1CTest
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

  # Base shares its production origin with Acme (both `https://www.umaxica.<tld>`), so the
  # issuer namespace cannot be inferred from a host substring like "base". Match against the
  # actual configured Base hosts first; fall back to substring heuristics for surfaces whose
  # hosts are texually distinct (acme/core/sign).
  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    base_hosts = {
      "APP" => ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      "ORG" => ENV.fetch("PUBLIC_BASE_STAFF_URL"),
      "COM" => ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
    }
    return "surface:BASE_#{base_hosts.key(normalized)}" if base_hosts.value?(normalized)

    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
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
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
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
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
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
