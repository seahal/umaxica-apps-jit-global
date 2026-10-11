# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BasePreferenceAuthoritySlice1fTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_preferences, :client_token_kinds

  SURFACES = {
    app: {
      host_env: "PUBLIC_BASE_SERVICE_URL",
      host_default: "base.app.localhost",
      preference_count: "AppPreference.count",
    },
    com: {
      host_env: "PUBLIC_BASE_CORPORATE_URL",
      host_default: "base.com.localhost",
      preference_count: "ComPreference.count",
    },
    org: {
      host_env: "PUBLIC_BASE_STAFF_URL",
      host_default: "base.org.localhost",
      preference_count: "OrgPreference.count",
    },
  }.freeze

  test "base preference root renders for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("base_#{surface}_preference_url", ri: "jp", host: host)

      assert_response :success
      # The index renders through Inertia, and the footer theme control is part of the React
      # surface layout, so its presence is carried by the shared chrome prop rather than by markup.
      assert_select "script[data-page='app'][type='application/json']", count: 1
      assert_not inertia_props.dig("chrome", "theme_controls", "hidden")
      assert_predicate cookies[PreferenceCookieName.access(surface: surface)], :present?
      assert_predicate cookies[PreferenceCookieName.refresh(surface: surface)], :present?
    end
  end

  test "base theme preference edit hides footer ajax theme controls for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_base_#{surface}_preference_theme_url", ri: "jp", host: host)

      assert_response :success
      # The theme screen owns the theme control while it is being edited, so the footer copy is
      # suppressed through the chrome prop.
      assert inertia_props.dig("chrome", "theme_controls", "hidden")
      assert_equal "base/#{surface}/preference/option", inertia_component
      assert_equal "preference_theme", inertia_props.dig("form", "scope")
      assert_equal "option_id", inertia_props.dig("form", "field")
      assert_predicate inertia_choice_pairs, :any?
    end
  end

  test "cookie banner settings url is the cookie preference edit for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("base_#{surface}_preference_url", ri: "jp", host: host)

      assert_response :success
      uri = URI.parse(inertia_props.dig("chrome", "cookie_controls", "settings_url"))
      query_keys = uri.query.to_s.split("&").map { |pair| pair.split("=", 2).first }

      assert_equal "/preference/cookie/edit", uri.path
      assert_equal "jp", Rack::Utils.parse_query(uri.query).fetch("ri")
      assert_equal query_keys.uniq, query_keys
      assert_not inertia_props.dig("chrome", "cookie_controls", "hidden")
    end
  end

  test "base cookie preference edit hides the cookie banner for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_base_#{surface}_preference_cookie_url", ri: "jp", host: host)

      assert_response :success
      # The cookie screen owns consent while it is being edited, so the banner copy is
      # suppressed through the chrome prop the same way the theme footer is on the theme screen.
      assert inertia_props.dig("chrome", "cookie_controls", "hidden")
      assert_equal "base/#{surface}/preference/cookie", inertia_component
    end
  end

  test "base cookie preference edit renders translations for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_base_#{surface}_preference_cookie_url", ri: "jp", host: host)

      assert_response :success
      assert_no_match(/translation missing/i, response.body)
      assert_equal "base/#{surface}/preference/cookie", inertia_component
      assert_equal "/preference/cookie", preference_form_action_path
      assert_equal "preference_cookie", inertia_props.dig("form", "scope")
      assert_includes inertia_props.dig("form", "categories").map { |category| category.fetch("key") },
                      "consented"
    end
  end

  test "base preference screen edit renders for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_base_#{surface}_preference_language_url", ri: "jp", lx: "en", host: host)

      assert_response :success
      assert_no_match(/id\.umaxica/, response.body)
      assert_no_match(%r{/sign/[^"]*/preference}, response.body)
      assert_equal "/preference/language", preference_form_action_path
    end
  end

  test "base preference reset edit posts to base for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_base_#{surface}_preference_customization_url", ri: "jp", host: host)

      assert_response :success
      assert_no_match(/id\.umaxica/, response.body)
      assert_no_match(%r{/sign/[^"]*/preference}, response.body)
      assert_equal "/preference/customization", preference_form_action_path
    end
  end

  test "base org preference region edit posts to base host" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    host! host

    get edit_base_org_preference_region_url(ri: "jp", host: host)

    assert_response :success
    assert_no_match(/id\.umaxica/, response.body)
    assert_no_match(%r{/sign/[^"]*/preference}, response.body)
    assert_equal "/preference/region", preference_form_action_path
  end

  test "base preference region edit renders localized region names for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_base_#{surface}_preference_region_url", ri: "jp", host: host)

      assert_response :success

      labels = inertia_choice_labels

      assert_equal 2, labels.size
      assert_equal ["アメリカ合衆国 (USA)", "日本"], labels.sort

      get public_send("edit_base_#{surface}_preference_region_url", ri: "us", host: host)

      assert_response :success
      assert_select "html[lang='en']"
      # The region screen is not the language settings UI -- language has its own
      # page -- so its heading names only the region.
      assert_equal "Region Settings", inertia_props.fetch("title")
      assert_equal ["Japan - 日本", "United States - USA"], inertia_choice_labels.sort
    end
  end

  test "base preference region edit disables the region already stored for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_base_#{surface}_preference_region_url", ri: "us", host: host)

      assert_response :success

      prefix = surface.to_s.camelize
      us_id = PreferenceClassRegistry.option_class(prefix, :region)::US
      jp_id = PreferenceClassRegistry.option_class(prefix, :region)::JP
      choices = inertia_props.fetch("form").fetch("choices")
      stored = choices.find { |choice| choice.fetch("value") == us_id }
      other = choices.find { |choice| choice.fetch("value") == jp_id }

      assert stored.fetch("disabled")
      assert_not other.fetch("disabled")
      assert_equal us_id, inertia_props.fetch("form").fetch("value")
    end
  end

  test "base org preference timezone edit posts to base host" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    host! host

    get edit_base_org_preference_timezone_url(ri: "jp", host: host)

    assert_response :success
    assert_no_match(/id\.umaxica/, response.body)
    assert_no_match(%r{/sign/[^"]*/preference}, response.body)
    assert_equal "/preference/timezone", preference_form_action_path
  end

  test "base app preference timezone edit renders localized timezone option labels" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host

    get edit_base_app_preference_timezone_url(ri: "us", lx: "ja", host: host)

    assert_response :success

    labels = inertia_choice_labels

    assert_includes labels, "協定世界時 (UTC)"
    assert_includes labels, "日本標準時 (Asia/Tokyo)"
    assert_not_includes labels, "Etc/UTC"
    assert_not_includes labels, "Asia/Tokyo"

    get edit_base_app_preference_timezone_url(ri: "us", lx: "en", host: host)

    assert_response :success
    assert_select "html[lang='en']"
    assert_includes inertia_choice_labels, "Coordinated Universal Time (UTC)"
    assert_includes inertia_choice_labels, "Japan Standard Time (Asia/Tokyo)"
  end

  test "base preference timezone choices are ordered by ascending UTC offset" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host

    get edit_base_app_preference_timezone_url(ri: "jp", host: host)

    assert_response :success

    # Option row ids: 1 Etc/UTC, 2 Asia/Tokyo, 3 New_York, 4 Chicago, 5 Denver, 6 Los_Angeles,
    # 7 Anchorage, 8 Honolulu. Standard offsets ascending run Honolulu (UTC-10) -> ... -> New_York
    # (UTC-05) -> UTC (UTC+00) -> Tokyo (UTC+09), which is deliberately not the id order.
    assert_equal(
      [8, 7, 6, 5, 4, 3, 1, 2],
      inertia_choice_pairs.map(&:last),
    )
  end

  test "base preference write updates app user preference" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    patch base_app_preference_theme_url(host: host),
          params: { preference_theme: { option_id: "dr" } },
          headers: session_headers(host, token, user),
          as: :json

    assert_response :ok
    assert_equal "dr", response.parsed_body.dig("preference", "ct")
    assert_equal "dr", user.user_preference.reload.theme
  end

  test "base preference GET overlay does not overwrite signed in app preference" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    user.user_preference.update!(language: "ja", timezone: "Asia/Tokyo", theme: "li")

    get base_app_preference_url(host: host, ri: "jp", lx: "en", tz: "utc", ct: "dr"),
        headers: session_headers(host, token, user)

    assert_response :success
    user.user_preference.reload

    assert_equal "ja", user.user_preference.language
    assert_equal "Asia/Tokyo", user.user_preference.timezone
    assert_equal "li", user.user_preference.theme
  end

  test "base preference ignores JS readable theme cookie as canonical input" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    user.user_preference.update!(theme: "li")
    cookies[PreferenceBase::THEME_COOKIE_KEY] = "dr"

    get base_app_preference_url(host: host, ri: "jp"),
        headers: session_headers(host, token, user)

    assert_response :success
    assert_equal "li", user.user_preference.reload.theme
  end

  test "base preference reset remains destructive and removes app user preference" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    user.user_preference.update!(theme: "dr")

    delete base_app_preference_customization_url(host: host),
           params: { confirm_reset: "1" },
           headers: session_headers(host, token, user)

    assert_redirected_to base_app_preference_url(host: host)
    assert_nil user.reload.user_preference
  end

  private

  # The screen forms live in the Inertia page object, so the action a screen posts to is a prop
  # rather than a form element attribute.
  def preference_form_action_path
    URI.parse(inertia_props.fetch("form").fetch("action")).path
  end

  def session_headers(host, token, user)
    bearer_headers(
      jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client"),
      host: host,
    )
  end

  def host_headers(host = nil)
    host.present? ? { "Host" => host } : {}
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
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

    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "SIGN")
    surface =
      if service == "SIGN"
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
end
