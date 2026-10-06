# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::App::WelcomeDashboardAuthoritySlice1CTest < ActionDispatch::IntegrationTest
  # Exercise the public exception representation used outside development.
  setup do
    @previous_detailed_exceptions = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
  end

  teardown do
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @previous_detailed_exceptions
  end

  fixtures :clients, :client_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @sign_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
    @user.update!(status_id: ClientStatus::ACTIVE)
  end

  test "public_root_renders one neutral link to the Base sign entry" do
    get base_app_root_url(ri: "jp"), headers: host_headers(@host)

    assert_response :success
    assert_equal base_app_sign_show_path(ri: "jp"), inertia_props.fetch("sign_in").fetch("href")
    assert_nil inertia_props["sign_up"]
  end

  test "dashboard_renders_when_signed_in" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(surface: :app, principal: @user, token: token)
    selected_persona(token).update!(moniker: "Selected App Persona")
    token.update!(last_used_at: 10.minutes.ago)
    last_used_at = token.reload.last_used_at

    get base_app_dashboard_url(ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_equal last_used_at, token.reload.last_used_at
    assert_equal "base/app/dashboards/show", inertia_component
    assert_equal I18n.t("base.shared.dashboard.title", locale: :ja), inertia_props.fetch("title")
    assert_not inertia_props.key?("description")

    sections = inertia_props.fetch("sections")
    expected_headings = [
      I18n.t("base.shared.dashboard.sections.menu_links", locale: :ja),
      I18n.t("base.shared.dashboard.sections.primary_links", locale: :ja),
    ]

    assert_equal expected_headings,
                 sections.map { |section| section.fetch("heading") }

    menu_links = sections.first.fetch("items")

    assert_equal(
      { "display_name" => "Selected App Persona",
        "avatar_image" => { "src" => base_app_dashboard_avatar_image_path(v: "default") }, },
      sections.first.fetch("current_identity"),
    )
    primary_links = sections.second.fetch("items")
    links = sections.flat_map { |section| section.fetch("items") }
    hrefs = links.map { |link| link.fetch("href") }
    labelled = links.to_h { |link| [link.fetch("label"), link.fetch("href")] }
    primary_hrefs = primary_links.map { |link| link.fetch("href") }

    assert_equal [
      base_app_preference_path(ri: "jp"),
      base_app_switcher_path(ri: "jp"),
      new_base_app_sign_out_path(ri: "jp"),
    ], menu_links.map { |link| link.fetch("href") }
    menu_links.each do |link|
      assert_not_includes primary_hrefs, link.fetch("href")
    end

    assert_includes hrefs, base_app_dashboard_path(ri: "jp")
    assert_equal base_app_accounts_path(ri: "jp"), labelled.fetch(dashboard_label(:account))
    assert_equal base_app_organizations_path(ri: "jp"), labelled.fetch(dashboard_label(:organization))
    assert_equal base_app_avatars_path(ri: "jp"), labelled.fetch(dashboard_label(:avatar))
    assert_equal base_app_switcher_path(ri: "jp"), labelled.fetch(dashboard_label(:switcher))
    assert_equal base_app_identity_path(ri: "jp"), labelled.fetch(dashboard_label(:identity))
    assert_equal base_app_preference_path(ri: "jp"), labelled.fetch(dashboard_label(:preference))
    assert_equal base_app_billings_path(ri: "jp"), labelled.fetch(dashboard_label(:billings))
    assert_equal base_app_groups_path(ri: "jp"), labelled.fetch(dashboard_label(:groups))
    assert_equal base_app_pwa_offline_path(ri: "jp"), labelled.fetch(dashboard_label(:offline))
    assert_not_includes hrefs, base_app_sessions_path(ri: "jp")
    assert_not hrefs.any? { |href| href.match?(%r{/preference/(calendar|clock|currency)}) }
    assert_not hrefs.any? { |href| href.match?(%r{/identity/(emails|telephones|secrets|sessions)}) }
    assert_not_includes hrefs, base_app_selector_path(ri: "jp")
    assert_not labelled.key?(dashboard_label(:selector))
    assert_includes hrefs, new_base_app_sign_out_path(ri: "jp")
    # The dashboard links to pages; it never posts a logout itself.
    assert_select "form[action^=?]", base_app_oidc_logout_path, count: 0
    assert_not hrefs.any? { |href| href.include?("/sign/in") || href.include?("/sign/up") }
    assert_empty labelled.keys & [
      dashboard_label(:oidc_discovery), dashboard_label(:jwks), dashboard_label(:userinfo),
    ]
    assert_no_match(%r{//example|umaxica\.example|evil\.example}, response.body)
    assert_no_match(/サインイン済み|Signed in/i, response.body)
  end

  test "dashboard_identity_uses_the_selected_app_persona_not_request_parameters" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(surface: :app, principal: @user, token: token)
    selected_persona(token).update!(moniker: "Authenticated App Persona")
    selected_account_public_id = token.selected_account_public_id
    token.update!(last_used_at: 10.minutes.ago)
    last_used_at = token.reload.last_used_at

    get base_app_dashboard_url(
      ri: "jp", account_public_id: "attacker-account", avatar_public_id: "attacker-avatar",
      moniker: "Attacker Persona",
    ), headers: session_headers(token)

    assert_response :success
    identity = inertia_props.fetch("sections").first.fetch("current_identity")

    assert_equal "Authenticated App Persona", identity.fetch("display_name")
    assert_equal %w(display_name avatar_image), identity.keys
    assert_equal selected_account_public_id, token.reload.selected_account_public_id
    assert_equal last_used_at, token.reload.last_used_at
  end

  test "dashboard_fails_explicitly_when_the_selected_app_persona_has_no_display_name" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(surface: :app, principal: @user, token: token)
    selected_persona(token).update!(moniker: " ")

    error =
      assert_raises(RuntimeError) do
        get(base_app_dashboard_url(ri: "jp"), headers: session_headers(token))
      end

    assert_match "selected app Persona has no display name", error.message
  end

  test "authenticated direct root request returns 404 without redirect" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(surface: :app, principal: @user, token: token)

    get "/", headers: session_headers(token)

    assert_response :not_found
    assert_nil response.location
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "anonymous direct root request renders Home" do
    get "/", headers: host_headers(@host)

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_not inertia_props.key?("sections")
  end

  test "authenticated direct dashboard request renders Dashboard" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(surface: :app, principal: @user, token: token)

    get "/dashboard", headers: session_headers(token)

    assert_response :success
    assert_equal "base/app/dashboards/show", inertia_component
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

  test "root_with_an_expired_app_session_renders_the_home" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(surface: :app, principal: @user, token: token)
    token.update!(discard_at: token.created_at)
    travel 1.second

    get base_app_root_url(ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component
  end

  test "root_with_a_credential_for_a_missing_app_session_record_renders_the_home" do
    get base_app_root_url(ri: "jp"),
        headers: as_user_headers(@user, host: @host, session_public_id: "missing-session-0001")

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component
  end

  test "root_with_a_malformed_app_bearer_renders_the_home" do
    get base_app_root_url(ri: "jp"), headers: bearer_headers("not-a-jwt", host: @host)

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component
  end

  test "root_ignores_unrelated_query_parameters_for_the_app_representation" do
    get base_app_root_url(ri: "jp", signed_in: "1", dashboard: "1"), headers: host_headers(@host)

    assert_response :success
    assert_equal "base/app/roots/index", inertia_component
  end

  test "authenticated_preference_navigation_returns_to_the_canonical_app_root" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(surface: :app, principal: @user, token: token)
    token.update!(last_used_at: 10.minutes.ago)
    last_used_at = token.reload.last_used_at

    %w(jp us).each do |region|
      get base_app_preference_url(ri: region), headers: session_headers(token)

      assert_response :success
      assert_equal base_app_dashboard_path(ri: region), inertia_props.dig("up_link", "href")
      assert_equal last_used_at, token.reload.last_used_at
    end
  end

  test "shared dashboard does not expose a raw Auth selector" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(surface: :app, principal: @user, token: token)

    get base_app_dashboard_url(ri: "jp"), headers: session_headers(token)

    labelled =
      inertia_props.fetch("sections")
        .flat_map { |section| section.fetch("items") }
        .to_h { |link| [link.fetch("label"), link.fetch("href")] }

    assert_not labelled.key?(dashboard_label(:authorize_sign_in))
    assert_not labelled.key?(dashboard_label(:authorize_sign_up))
  end

  test "menu links preserve the full request context" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(surface: :app, principal: @user, token: token)

    get base_app_dashboard_url(ri: "jp", ct: "dr", lx: "en", tz: "asia/tokyo"),
        headers: session_headers(token)

    menu_hrefs = inertia_props.fetch("sections").first.fetch("items").map { |item| item.fetch("href") }
    menu_hrefs.each do |href|
      query = Rack::Utils.parse_nested_query(URI.parse(href).query.to_s)

      assert_equal "jp", query.fetch("ri")
      assert_equal "dr", query.fetch("ct")
      assert_equal "en", query.fetch("lx")
      assert_equal "asia/tokyo", query.fetch("tz")
    end
  end

  test "identity_show_links_up_to_the_dashboard" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(surface: :app, principal: @user, token: token)

    get base_app_identity_url(ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_equal "base/app/identities/show", inertia_component
    assert_equal I18n.t("base.shared.identity.up_link", locale: :ja), inertia_props.dig("up_link", "label")
    assert_equal base_app_dashboard_path(ri: "jp"), inertia_props.dig("up_link", "href")
  end

  test "identity_show_links_to_identity_pages" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(surface: :app, principal: @user, token: token)

    get base_app_identity_url(ri: "jp"), headers: session_headers(token)

    assert_response :success
    labelled =
      inertia_props.fetch("sections")
        .flat_map { |section| section.fetch("items") }
        .to_h { |link| [link.fetch("label"), link.fetch("href")] }

    assert_equal base_app_identity_emails_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.emails", locale: :ja))
    assert_equal base_app_identity_telephones_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.telephones", locale: :ja))
    assert_equal base_app_identity_birthdate_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.birthdate", locale: :ja))
    assert_not_includes labelled.values, "/identity/secrets"
    assert_equal base_app_sessions_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.sessions", locale: :ja))
    assert_equal base_app_identity_activities_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.activities", locale: :ja))
    assert_equal base_app_identity_standing_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.standing", locale: :ja))
    assert_equal base_app_identity_passkeys_url(ri: "jp"),
                 labelled.fetch(I18n.t("controller.sign.app.setting.index.passkey", locale: :ja))
    assert_equal auth_app_settings_totps_url(ri: "jp", host: @sign_host, protocol: "https"),
                 labelled.fetch(I18n.t("controller.sign.app.setting.index.totp", locale: :ja))
    assert_equal auth_app_settings_google_url(ri: "jp", host: @sign_host, protocol: "https"),
                 labelled.fetch(I18n.t("controller.sign.app.setting.index.google", locale: :ja))
    assert_equal auth_app_settings_apple_url(ri: "jp", host: @sign_host, protocol: "https"),
                 labelled.fetch(I18n.t("controller.sign.app.setting.index.apple", locale: :ja))
    assert_equal base_app_identity_mfa_challenge_path(ri: "jp"),
                 labelled.fetch(I18n.t("sign.app.settings.show.mfa", locale: :ja))
    assert_equal base_app_identity_mfa_reset_path(ri: "jp"),
                 labelled.fetch(I18n.t("sign.app.settings.mfa.show.reset_title", locale: :ja))
    assert_equal new_base_app_identity_withdrawal_path(ri: "jp"),
                 labelled.fetch(I18n.t("base.shared.identity.links.withdrawal", locale: :ja))
    assert_not_includes labelled.values, new_base_app_sign_out_path(ri: "jp")
  end

  test "welcome_requires_authentication" do
    get base_app_welcome_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  test "invalid browser cookie partitions remain anonymous on literal Home and Dashboard" do
    expired = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    expired.update!(discard_at: expired.created_at)
    revoked = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    revoked.revoke!
    session_ids = [
      ["expired", expired.public_id],
      ["revoked", revoked.public_id],
      ["missing", "missing-session-0001"],
    ]
    credentials = []
    session_ids.each do |label, session_id|
      credential = AuthenticationToken.encode(
        @user, host: @host, session_public_id: session_id, resource_type: "client",
               jwt_issuer_id: "surface:BASE_APP",
      )
      credentials << [label, credential]
    end
    credentials << ["malformed", "not-a-jwt"]

    credentials.each do |label, credential|
      cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = credential
      get "/", headers: { "Host" => @host }

      assert_response :success, label
      assert_nil response.location, label
      assert_equal "base/app/roots/index", inertia_component, label

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
    ClientPersona.find_by!(public_id: token.selected_account_public_id)
  end

  def session_headers(token)
    as_user_headers(@user, host: @host, session_public_id: token.public_id)
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Base::App::WelcomeDashboardAuthoritySlice1CTest
  private
end

# DAMP local route helper aliases for former shared test support.
class Base::App::WelcomeDashboardAuthoritySlice1CTest
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
class Base::App::WelcomeDashboardAuthoritySlice1CTest
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
    return host_headers(host).merge(headers) unless user.respond_to?(:persisted?) && user.persisted? &&
      user.class.name == "Client"

    ensure_user_token_reference_records!
    token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
    token ||= ClientToken.where(user_id: user.id).where("discard_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    bearer_headers(
      jwt_access_token_for(
        user, host: host, session_public_id: session_public_id.presence || token.public_id,
              resource_type: "client",
      ),
      host: host, headers: headers,
    )
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    return host_headers(host).merge(headers) unless staff.respond_to?(:persisted?) && staff.persisted? &&
      staff.class.name == "Operator"

    ensure_staff_token_reference_records!
    token = session_public_id.present? ? OperatorToken.find_by(public_id: session_public_id) : nil
    token ||= OperatorToken.where(staff_id: staff.id).where(
      "discard_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= OperatorToken.create!(
      staff_id: staff.id, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    bearer_headers(
      jwt_access_token_for(
        staff, host: host, session_public_id: session_public_id.presence || token.public_id,
               resource_type: "operator",
      ),
      host: host, headers: headers,
    )
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    return host_headers(host).merge(headers) unless visitor.respond_to?(:persisted?) && visitor.persisted? &&
      visitor.class.name == "Visitor"

    ensure_visitor_token_reference_records!
    token = session_public_id.present? ? VisitorToken.find_by(public_id: session_public_id) : nil
    token ||= VisitorToken.where(visitor_id: visitor.id).where(
      "discard_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= VisitorToken.create!(
      visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    bearer_headers(
      jwt_access_token_for(
        visitor, host: host, session_public_id: session_public_id.presence || token.public_id,
                 resource_type: "visitor",
      ),
      host: host, headers: headers,
    )
  end

  def jwt_access_token_for(resource, host: nil, session_public_id: nil, resource_type: nil)
    AuthenticationToken.encode(
      resource, host: host, session_public_id: session_public_id, resource_type: resource_type,
                jwt_issuer_id: jwt_issuer_id_for_test_host(host, resource_type),
    )
  end

  # Base shares its production origin with Acme (both `https://www.umaxica.<tld>`), so the
  # issuer namespace cannot be inferred from a host substring like "base". Match against the
  # actual configured Base hosts first; fall back to substring heuristics for surfaces whose
  # hosts are texually distinct (acme/core/sign).
  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    base_hosts = {
      "APP" => ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      "ORG" => ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      "COM" => ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
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
