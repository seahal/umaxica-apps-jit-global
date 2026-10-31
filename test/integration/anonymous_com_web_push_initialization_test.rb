# typed: false
# frozen_string_literal: true

require "test_helper"

class AnonymousComWebPushInitializationTest < ActionDispatch::IntegrationTest
  DISPLAY_SNAPSHOT = {
    "theme" => "system",
    "language" => "ja",
    "timezone" => "Asia/Tokyo",
    "currency" => "jpy",
    "date_format" => "iso",
    "time_format" => "24",
    "motion" => "standard",
    "density" => "standard",
    "page_size" => "infinity",
  }.freeze

  self.fixture_table_names = []

  setup do
    [ComPreferenceStatus].each(&:ensure_defaults!)
  end

  test "generic screen saves each supported option through the com preference boundary" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    cases = [
      ["theme", { preference_theme: { option_id: "dark" } }, "theme", "dark"],
      ["currency", { preference_currency: { option_id: "usd" } }, "currency", "usd"],
      ["language", { preference_language: { option_id: "en" } }, "language", "en"],
      ["timezone", { preference_timezone: { option_id: "Etc/UTC" } }, "timezone", "Etc/UTC"],
      ["calendar", { preference_date_format: { option_id: "us" } }, "date_format", "us"],
      ["clock", { preference_time_format: { option_id: "12" } }, "time_format", "12"],
      ["motion", { preference_motion: { option_id: "reduced" } }, "motion", "reduced"],
      ["density", { preference_density: { option_id: "compact" } }, "density", "compact"],
      ["pagination", { preference_page_size: { option_id: "20" } }, "page_size", "20"],
      ["region", { preference_region: { option_id: "jp" } }, "currency", "jpy"],
    ]

    cases.each do |screen, submitted, field, expected|
      patch base_com_preference_screen_path(ri: "jp"),
            params: submitted.merge(preference_screen: screen),
            headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

      assert_response :see_other, screen
      payload = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)

      assert_equal expected, payload.fetch("preferences").fetch(field), screen
    end

    patch base_com_preference_screen_path(ri: "jp"),
          params: { preference_screen: "cookie", preference_cookie: { consented: "true" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    assert_predicate cookies[PreferenceBrowserBinding::COOKIE_NAME], :present?
  end

  test "generic screen rejects an unknown screen before writing or issuing preference cookies" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!

    assert_no_difference -> { ComPreference.count } do
      patch base_com_preference_screen_path(ri: "jp"),
            params: { preference_screen: "unknown", option_id: "dark" },
            headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
    end

    assert_response :unprocessable_content
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "a generic screen save ignores a legacy com refresh credential" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    cookies["preference_refresh"] = "legacy-credential"

    assert_difference -> { ComPreference.count }, 1 do
      patch base_com_preference_screen_path(ri: "jp"),
            params: { preference_screen: "theme", preference_theme: { option_id: "dark" } },
            headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
    end

    assert_response :see_other
    payload = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)

    assert_not ComPreference.find_by!(public_id: payload.fetch("sub")).has_attribute?(:token_digest)
    assert_equal "dark", payload.fetch("preferences").fetch("theme")
  end

  test "generic screen signing failure rolls back the new preference without issuing cookies" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    ComPreferenceThemeOption.ensure_defaults!

    assert_no_difference -> { ComPreference.count } do
      PreferenceToken.stub(:encode, nil) do
        patch base_com_preference_screen_path(ri: "jp"),
              params: { preference_screen: "theme", preference_theme: { option_id: "dark" } },
              headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      end
    end

    assert_response :service_unavailable
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceIoKeys::Cookies::LANGUAGE}="
  end

  test "generic screen refuses a write without a CSRF token" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host!(host)
    https!
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    assert_no_difference -> { ComPreference.count } do
      patch(
        base_com_preference_screen_path(ri: "jp"),
        params: { preference_screen: "theme", preference_theme: { option_id: "dark" } },
        headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" },
      )
    end

    assert_response :unprocessable_content
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "invalid JWT writes on the API and screen start from defaults without changing its old row" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host!(host)
    https!
    patch base_com_preference_language_path(ri: "jp"), params: { preference_language: { option_id: "en" } }

    assert_response :see_other
    old_token = cookies[PreferenceCookieName.anonymous_jwt]
    old_payload = PreferenceToken.decode(old_token, host: host)
    old_preference = ComPreference.find_by!(public_id: old_payload.fetch("sub"))
    old_attributes = old_preference.attributes
    old_language = ComPreferenceLanguage.find_by!(preference_id: old_preference.id).attributes

    %i(api screen).each do |surface|
      reset!
      host!(host)
      https!
      cookies[PreferenceCookieName.anonymous_jwt] = "#{old_token}invalid"
      assert_difference -> { ComPreference.count }, 1 do
        if surface == :api
          patch base_com_api_v0_preferences_theme_path,
                params: { theme: "dark" }.to_json,
                headers: { "Accept" => "application/json", "Content-Type" => "application/json" }
        else
          patch base_com_preference_theme_path(ri: "jp"), params: { preference_theme: { option_id: "dark" } }
        end
      end

      assert_includes [200, 303], response.status
      new_payload = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)

      assert_not_equal old_preference.public_id, new_payload.fetch("sub")
      assert_equal "dark", new_payload.fetch("preferences").fetch("theme")
      assert_equal "ja", new_payload.fetch("preferences").fetch("language")
      assert_equal old_attributes, old_preference.reload.attributes
      assert_equal old_language, ComPreferenceLanguage.find_by!(preference_id: old_preference.id).attributes
      new_preference = ComPreference.find_by!(public_id: new_payload.fetch("sub"))

      assert_not ComPreferenceCookie.find_by!(preference_id: new_preference.id).consented
      assert_not ComPreferenceBrowserBinding.exists?(preference_id: new_preference.id)
    end
  end

  test "a com GET ignores legacy refresh and DBSC cookies without creating preference state" do
    host!(ENV.fetch("PUBLIC_BASE_CORPORATE_URL"))
    https!
    cookies["preference_refresh"] = "untrusted-legacy-refresh"
    cookies["preference_dbsc"] = "untrusted-legacy-binding"
    writes = []
    observer =
      lambda do |_name, _start, _finish, _id, event|
        writes << event.fetch(:sql) if event.fetch(:sql).match?(/\A\s*(INSERT|UPDATE|DELETE)\b/i)
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      get base_com_root_path(ri: "jp")
    end

    assert_response :success
    assert_empty writes
    headers = response.headers["Set-Cookie"].to_s

    assert_not_includes headers, "preference_refresh="
    assert_not_includes headers, "preference_dbsc="
    assert_nil cookies[PreferenceCookieName.anonymous_jwt]
  end

  test "prefetch GET and HEAD requests do not write database state" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    patch base_com_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "true" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    token = cookies[PreferenceCookieName.anonymous_jwt]
    binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    cases = [
      [base_com_root_path(ri: "jp"), "text/html"],
      [base_com_preference_path(ri: "jp"), "text/html"],
      [edit_base_com_preference_theme_path(ri: "jp"), "text/html"],
      [edit_base_com_preference_cookie_path(ri: "jp"), "text/html"],
      [base_com_api_v0_preferences_cookie_path, "application/json"],
      [base_com_api_v0_preferences_theme_path, "application/json"],
      [base_com_api_v0_preferences_web_push_path, "application/json"],
    ]
    [nil, "invalid", token].each do |credential|
      browser = open_session
      browser.host!(host)
      browser.https!
      browser.cookies[PreferenceCookieName.anonymous_jwt] = credential if credential
      browser.cookies[PreferenceBrowserBinding::COOKIE_NAME] = binding if credential == token
      cases.each do |path, accept|
        browser.cookies[PreferenceCookieName.anonymous_jwt] = credential if credential
        headers = { "Accept" => accept, "Purpose" => "prefetch", "Sec-Purpose" => "prefetch" }
        writes = []
        observer =
          lambda do |_name, _start, _finish, _id, event|
            writes << event.fetch(:sql) if event.fetch(:sql).match?(/\A\s*(INSERT|UPDATE|DELETE|MERGE|TRUNCATE)\b/i)
          end
        ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
          browser.get(path, headers: headers)

          assert_equal 200, browser.response.status, "GET #{path}"
          browser.cookies[PreferenceCookieName.anonymous_jwt] = credential if credential
          browser.head(path, headers: headers)

          assert_equal 200, browser.response.status, "HEAD #{path}"
        end

        assert_empty writes, path
      end
    end
  end

  test "an anonymous consent save creates a disabled web push preference" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!

    assert_no_difference -> { ComPreferenceAdultContentGate.count } do
      assert_difference -> { ComPreferenceWebPush.count }, 1 do
        patch base_com_preference_cookie_path(ri: "jp"),
              params: { preference_cookie: { consented: "true" } },
              headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      end
    end

    assert_response :see_other
    token = cookies[PreferenceCookieName.anonymous_jwt]
    payload = PreferenceToken.decode(token, host: host)
    binding_header =
      Array(response.headers["Set-Cookie"]).flat_map { |line| line.split("\n") }
        .find { |line| line.start_with?("#{PreferenceBrowserBinding::COOKIE_NAME}=") }
    preference = ComPreference.find_by!(public_id: payload.fetch("sub"))
    push = ComPreferenceWebPush.find_by!(preference_id: preference.id)

    assert_equal ComPreferenceWebPushOption::DISABLED, push.option_id
    assert_equal Time.at(payload.fetch("exp")).utc, Time.httpdate(binding_header.match(/expires=([^;]+)/i)[1])
    assert_not payload.fetch("preferences").key?("web_push")

    cookie_headers = Array(response.headers["Set-Cookie"]).flat_map { |line| line.split("\n") }
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience, PreferenceBrowserBinding::COOKIE_NAME,].each do |name|
      header = cookie_headers.find { |line| line.start_with?("#{name}=") }

      assert_match(/(?:\A|;\s*)secure(?:;|\z)/i, header, name)
      assert_match(/(?:\A|;\s*)path=\/(?:;|\z)/i, header, name)
      assert_match(/(?:\A|;\s*)samesite=lax(?:;|\z)/i, header, name)
      if [PreferenceCookieName.anonymous_jwt, PreferenceBrowserBinding::COOKIE_NAME].include?(name)
        assert_match(/(?:\A|;\s*)httponly(?:;|\z)/i, header, name)
      else
        assert_no_match(/(?:\A|;\s*)httponly(?:;|\z)/i, header, name)
      end
      next if name == PreferenceBrowserBinding::COOKIE_NAME

      domain = host.split(".").last(2).join(".")

      assert_match(/(?:\A|;\s*)domain=\.?#{Regexp.escape(domain)}(?:;|\z)/i, header, name)
    end

    assert_no_match(/(?:\A|;\s*)domain=/i, binding_header)
  end

  test "saving an existing preference with missing display children issues a complete default snapshot" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    [ComPreferenceCurrencyOption, ComPreferenceDateFormatOption, ComPreferenceTimeFormatOption,
     ComPreferenceMotionOption, ComPreferenceDensityOption, ComPreferencePageSizeOption,].each(&:ensure_defaults!)
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: host, preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: preference.public_id, jti: preference.jti,
    )

    patch base_com_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "true" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    payload = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
    expected = {
      "theme" => "system",
      "language" => "ja",
      "timezone" => "Asia/Tokyo",
      "currency" => "jpy",
      "date_format" => "iso",
      "time_format" => "24",
      "motion" => "standard",
      "density" => "standard",
      "page_size" => "infinity",
    }

    assert_equal preference.public_id, payload.fetch("sub")
    assert_equal expected, payload.fetch("preferences")
    assert_equal "ja", cookies[PreferenceIoKeys::Cookies::LANGUAGE]
    assert_equal expected.except("language"), JSON.parse(cookies[PreferenceCookieName.anonymous_experience])
  end

  test "a stored non-display option rejects a save and rolls back its changes" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    ComPreferenceCurrencyOption.ensure_defaults!
    generation = JitSecurityJwtJtiGenerator.generate
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: generation,
    )
    ComPreferenceCurrency.create!(preference: preference, option_id: ComPreferenceCurrencyOption::NOTHING)
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: host, preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: preference.public_id, jti: generation,
    )

    patch base_com_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "true" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :service_unavailable
    assert_equal generation, preference.reload.jti
    assert_nil ComPreferenceCookie.find_by(preference_id: preference.id)
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceBrowserBinding::COOKIE_NAME}="
  end

  test "a read rebuilds both display cookies without rotating the signed preference" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    patch base_com_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "true" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    token = cookies[PreferenceCookieName.anonymous_jwt]
    payload = PreferenceToken.decode(token, host: host)
    preference = ComPreference.find_by!(public_id: payload.fetch("sub"))
    generation = preference.jti
    binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    browser = open_session
    browser.host!(host)
    browser.https!
    browser.cookies[PreferenceCookieName.anonymous_jwt] = token
    browser.cookies[PreferenceBrowserBinding::COOKIE_NAME] = binding
    browser.cookies[PreferenceCookieName.anonymous_experience] = '{"theme":"dark","theme":"light"}'
    writes = []
    errors = []
    observer =
      lambda do |_name, _start, _finish, _id, event|
        writes << event.fetch(:sql) if event.fetch(:sql).match?(/\A\s*(INSERT|UPDATE|DELETE)\b/i)
      end
    Rails.logger.stub(:error, ->(message) { errors << message.to_s }) do
      ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
        browser.get(edit_base_com_preference_cookie_path(ri: "jp"))
      end
    end

    assert_equal 200, browser.response.status
    assert_empty writes
    assert errors.any? { |message| message.include?("preference.display_cookie.invalid") }
    assert_not_includes errors.join, token
    assert_not_includes errors.join, '{"theme":"dark","theme":"light"}'
    assert_equal generation, preference.reload.jti
    assert_equal token, browser.cookies[PreferenceCookieName.anonymous_jwt]
    assert_equal payload.fetch("preferences").fetch("language"), browser.cookies[PreferenceIoKeys::Cookies::LANGUAGE]
    assert_equal payload.fetch("preferences").except("language"),
                 JSON.parse(browser.cookies[PreferenceCookieName.anonymous_experience])
    headers = Array(browser.response.headers["Set-Cookie"]).flat_map { |line| line.split("\n") }
    [PreferenceIoKeys::Cookies::LANGUAGE, PreferenceCookieName.anonymous_experience].each do |name|
      header = headers.find { |line| line.start_with?("#{name}=") }

      assert_equal Time.at(payload.fetch("exp")).utc, Time.httpdate(header.match(/expires=([^;]+)/i)[1])
    end
    assert_not_includes browser.response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="

    healthy_browser = open_session
    healthy_browser.host!(host)
    healthy_browser.https!
    healthy_browser.cookies[PreferenceCookieName.anonymous_jwt] = token
    healthy_browser.cookies[PreferenceIoKeys::Cookies::LANGUAGE] = payload.fetch("preferences").fetch("language")
    healthy_browser.cookies[PreferenceCookieName.anonymous_experience] =
      payload.fetch("preferences").except("language").to_json
    healthy_browser.get(edit_base_com_preference_cookie_path(ri: "jp"))

    assert_equal 200, healthy_browser.response.status
    assert_not_includes healthy_browser.response.headers["Set-Cookie"].to_s, "#{PreferenceIoKeys::Cookies::LANGUAGE}="
    assert_not_includes healthy_browser.response.headers["Set-Cookie"].to_s,
                        "#{PreferenceCookieName.anonymous_experience}="
  end

  test "a valid display cookie from another revision is repaired without an invalid-cookie error" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    patch base_com_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "true" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other

    token = cookies[PreferenceCookieName.anonymous_jwt]
    signed = PreferenceToken.decode(token, host: host).fetch("preferences")
    other_theme = (signed.fetch("theme") == "dark") ? "light" : "dark"
    browser = open_session
    browser.host!(host)
    browser.https!
    browser.cookies[PreferenceCookieName.anonymous_jwt] = token
    browser.cookies[PreferenceIoKeys::Cookies::LANGUAGE] = signed.fetch("language")
    browser.cookies[PreferenceCookieName.anonymous_experience] =
      signed.except("language").merge("theme" => other_theme).to_json
    errors = []
    Rails.logger.stub(:error, ->(message) { errors << message.to_s }) do
      browser.get(edit_base_com_preference_cookie_path(ri: "jp"))
    end

    assert_equal 200, browser.response.status
    assert_equal signed.except("language"), JSON.parse(browser.cookies[PreferenceCookieName.anonymous_experience])
    assert_not errors.any? { |message| message.include?("preference.display_cookie.invalid") }
  end

  test "a stale but unexpired JWT repairs display cookies from the current database snapshot" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    patch base_com_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "true" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    old_token = cookies[PreferenceCookieName.anonymous_jwt]
    old_payload = PreferenceToken.decode(old_token, host: host)
    patch base_com_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: "dark" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    new_payload = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)

    assert_equal old_payload.fetch("sub"), new_payload.fetch("sub")
    assert_not_equal old_payload.fetch("jti"), new_payload.fetch("jti")
    assert_equal "dark", new_payload.fetch("preferences").fetch("theme")
    browser = open_session
    browser.host!(host)
    browser.https!
    browser.cookies[PreferenceCookieName.anonymous_jwt] = old_token
    browser.get(edit_base_com_preference_cookie_path(ri: "jp"))

    assert_equal 200, browser.response.status
    assert_equal new_payload.fetch("preferences").except("language"),
                 JSON.parse(browser.cookies[PreferenceCookieName.anonymous_experience])
    assert_equal old_token, browser.cookies[PreferenceCookieName.anonymous_jwt]
    headers = Array(browser.response.headers["Set-Cookie"]).flat_map { |line| line.split("\n") }
    [PreferenceIoKeys::Cookies::LANGUAGE, PreferenceCookieName.anonymous_experience].each do |name|
      header = headers.find { |line| line.start_with?("#{name}=") }

      assert_equal Time.at(old_payload.fetch("exp")).utc, Time.httpdate(header.match(/expires=([^;]+)/i)[1])
    end
    assert_not_includes browser.response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "an invalid JWT clears shared display cookies on their domain but preserves the host binding" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    binding = PreferenceBrowserBinding.mint_value
    cookies[PreferenceCookieName.anonymous_jwt] = "invalid"
    cookies[PreferenceIoKeys::Cookies::LANGUAGE] = "en"
    cookies[PreferenceCookieName.anonymous_experience] = '{"theme":"dark"}'
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = binding

    assert_no_difference -> { ComPreference.count } do
      get edit_base_com_preference_cookie_path(ri: "jp")
    end

    assert_response :ok
    headers = Array(response.headers["Set-Cookie"]).flat_map { |line| line.split("\n") }
    domain = host.split(".").last(2).join(".")
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience,].each do |name|
      header = headers.find { |line| line.start_with?("#{name}=") }

      assert_not_nil header, name
      assert_match(/(?:\A|;\s*)domain=\.?#{Regexp.escape(domain)}(?:;|\z)/i, header, name)
      assert_operator Time.httpdate(header.match(/expires=([^;]+)/i)[1]), :<, Time.current
    end
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceBrowserBinding::COOKIE_NAME}="
    assert_equal binding, cookies[PreferenceBrowserBinding::COOKIE_NAME]
  end

  test "missing JWT clears orphaned display cookies on the base host" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    cookies[PreferenceIoKeys::Cookies::LANGUAGE] = "en"
    cookies[PreferenceCookieName.anonymous_experience] = '{"theme":"dark"}'

    assert_no_difference -> { ComPreference.count } do
      get "/", params: { ri: "jp" }
    end

    assert_response :success
    assert_equal "system", response.parsed_body.at_css("html")["data-theme"]
    headers = Array(response.headers["Set-Cookie"]).flat_map { |line| line.split("\n") }
    domain = host.split(".").last(2).join(".")
    [PreferenceIoKeys::Cookies::LANGUAGE, PreferenceCookieName.anonymous_experience].each do |name|
      header = headers.find { |line| line.start_with?("#{name}=") }

      assert_not_nil header, name
      assert_match(/(?:\A|;\s*)domain=\.?#{Regexp.escape(domain)}(?:;|\z)/i, header, name)
      assert_operator Time.httpdate(header.match(/expires=([^;]+)/i)[1]), :<, Time.current
    end
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "the read-only corporate host does not clear invalid shared preference cookies or read preference rows" do
    host!(ENV.fetch("PUBLIC_WARP_CORPORATE_URL"))
    https!
    cookies[PreferenceCookieName.anonymous_jwt] = "invalid"
    cookies[PreferenceIoKeys::Cookies::LANGUAGE] = "en"
    cookies[PreferenceCookieName.anonymous_experience] = '{"theme":"dark"}'
    preference_queries = []
    observer =
      lambda do |_name, _start, _finish, _id, event|
        preference_queries << event.fetch(:sql) if event.fetch(:sql).match?(/\bcom_preferences\b/i)
      end
    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      get "/", params: { ri: "jp" }
    end

    assert_response :success
    assert_empty preference_queries
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience,].each do |name|
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  end

  test "the read-only corporate host displays a valid shared JWT without preference DB or private key" do
    base_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host!(base_host)
    https!
    patch base_com_preference_theme_path(ri: "jp"), params: { preference_theme: { option_id: "dark" } }

    assert_response :see_other
    token = cookies[PreferenceCookieName.anonymous_jwt]
    browser = open_session
    browser.host!(ENV.fetch("PUBLIC_WARP_CORPORATE_URL"))
    browser.https!
    browser.cookies[PreferenceCookieName.anonymous_jwt] = token
    queries = []
    observer =
      lambda do |_name, _start, _finish, _id, event|
        queries << event.fetch(:sql) if event.fetch(:sql).match?(/\bcom_preference(?:s|_\w+)\b/i)
      end
    no_private_key = ->(*) { raise RuntimeError, "private key must not be read by a reader" }

    PreferenceJwtConfiguration.stub(:private_key_for_active, no_private_key) do
      ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
        browser.get("/", params: { ri: "jp" })
      end
    end

    assert_equal 200, browser.response.status
    assert_equal "dark", browser.response.parsed_body.at_css("html")["data-theme"]
    assert_empty queries
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience, PreferenceBrowserBinding::COOKIE_NAME,].each do |name|
      assert_not_includes browser.response.headers["Set-Cookie"].to_s, "#{name}="
    end
  end

  test "a valid JWT for an unavailable row still supplies display values without cookie deletion" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    token = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark", "language" => "en" }), host: host, preference_type: "ComPreference",
                                                                         issued_at: Time.current,
                                                                         public_id: SecureRandom.uuid,
                                                                         jti: SecureRandom.uuid,
    )
    cookies[PreferenceCookieName.anonymous_jwt] = token

    assert_no_difference -> { ComPreference.count } do
      get "/", params: { ri: "jp" }
    end

    assert_response :success
    assert_equal "dark", response.parsed_body.at_css("html")["data-theme"]
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceIoKeys::Cookies::LANGUAGE}="
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_experience}="
  end

  test "a save evaluates existing row expiration with the database clock" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    ComPreferenceThemeOption.ensure_defaults!
    now = ComPreference.database_now
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "system" }), host: host, preference_type: "ComPreference",
                                                       issued_at: Time.current,
                                                       public_id: preference.public_id, jti: preference.jti,
    )

    travel_to(now + 1.hour) do
      assert_no_difference -> { ComPreference.count } do
        patch base_com_preference_theme_path(ri: "jp"),
              params: { preference_theme: { option_id: "dark" } },
              headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      end

      assert_response :see_other
      payload = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)

      assert_equal preference.public_id, payload.fetch("sub")
      assert_equal "dark", payload.fetch("preferences").fetch("theme")
    end
  end

  test "resaving extends the existing preference to the new JWT expiry without shortening retention" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host!(host)
    https!
    initial_time = ComPreference.database_now.change(usec: 0)

    ComPreference.stub(:database_now, initial_time) do
      patch base_com_preference_cookie_path(ri: "jp"), params: { preference_cookie: { consented: "true" } }
    end

    assert_response :see_other
    original = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
    preference = ComPreference.find_by!(public_id: original.fetch("sub"))
    renewed_time = initial_time + 2.days
    renewed = nil
    travel_to(renewed_time) do
      ComPreference.stub(:database_now, renewed_time) do
        assert_no_difference -> { ComPreference.count } do
          patch base_com_preference_cookie_path(ri: "jp"), params: { preference_cookie: { functional: "true" } }
        end
      end

      assert_response :see_other
      renewed = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
    end

    preference.reload

    assert_equal original.fetch("sub"), renewed.fetch("sub")
    assert_equal Time.at(renewed.fetch("exp")).utc, preference.last_issued_expires_at
    assert_operator renewed.fetch("exp"), :>, original.fetch("exp")
    after_original_expiry = Time.at(original.fetch("exp") + 1).utc
    travel_to(after_original_expiry) do
      ComPreference.stub(:database_now, after_original_expiry) do
        get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }
      end

      assert_response :ok
      assert_not response.parsed_body.fetch("show_banner")
    end
  end

  test "reset retains the last issued expiry for the retired row" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host!(host)
    https!
    patch base_com_preference_cookie_path(ri: "jp"), params: { preference_cookie: { consented: "true" } }

    assert_response :see_other
    payload = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
    preference = ComPreference.find_by!(public_id: payload.fetch("sub"))
    expiry = Time.at(payload.fetch("exp")).utc
    delete base_com_preference_customization_path(ri: "jp"), params: { confirm_reset: "1" }

    assert_response :see_other
    assert_equal ComPreferenceStatus::RETIRED, preference.reload.status_id
    assert_equal expiry, preference.last_issued_expires_at
    assert_not preference.issuance_retention_elapsed?(now: expiry + 30.days - 1.second)
    assert preference.issuance_retention_elapsed?(now: expiry + 30.days)
  end

  test "a read repairs display cookies for a row valid according to the database clock" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    patch base_com_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "true" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    token = cookies[PreferenceCookieName.anonymous_jwt]
    payload = PreferenceToken.decode(token, host: host)

    assert_predicate ComPreference.where(public_id: payload.fetch("sub")), :exists?
    now = ComPreference.database_now
    browser = open_session
    browser.host!(host)
    browser.https!
    browser.cookies[PreferenceCookieName.anonymous_jwt] = token

    travel_to(now + 1.hour) do
      browser.get("/", params: { ri: "jp" })

      assert_equal 200, browser.response.status
      assert_equal payload.fetch("preferences").fetch("language"),
                   browser.cookies[PreferenceIoKeys::Cookies::LANGUAGE]
      assert_equal payload.fetch("preferences").except("language"),
                   JSON.parse(browser.cookies[PreferenceCookieName.anonymous_experience])
      assert_equal token, browser.cookies[PreferenceCookieName.anonymous_jwt]
    end
  end

  test "reset retires the old row and deletes the secure host-only binding after commit" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    patch base_com_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "true" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    previous = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
    old_row = ComPreference.find_by!(public_id: previous.fetch("sub"))
    delete base_com_preference_customization_path(ri: "jp"),
           params: { confirm_reset: "1" },
           headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    assert_equal ComPreferenceStatus::RETIRED, old_row.reload.status_id
    replacement = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)

    assert_not_equal previous.fetch("sub"), replacement.fetch("sub")
    headers = Array(response.headers["Set-Cookie"]).flat_map { |line| line.split("\n") }
    header = headers.find { |line| line.start_with?("#{PreferenceBrowserBinding::COOKIE_NAME}=") }

    assert_not_nil header
    assert_match(/(?:\A|;\s*)secure(?:;|\z)/i, header)
    assert_match(/(?:\A|;\s*)httponly(?:;|\z)/i, header)
    assert_match(/(?:\A|;\s*)path=\/(?:;|\z)/i, header)
    assert_no_match(/(?:\A|;\s*)domain=/i, header)
    assert_operator Time.httpdate(header.match(/expires=([^;]+)/i)[1]), :<, Time.current
  end

  test "reset signing failure preserves the existing row and all preference cookies" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    patch base_com_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "true" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    token = cookies[PreferenceCookieName.anonymous_jwt]
    binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    payload = PreferenceToken.decode(token, host: host)
    preference = ComPreference.find_by!(public_id: payload.fetch("sub"))
    generation = preference.jti
    cookie = ComPreferenceCookie.find_by!(preference_id: preference.id)

    PreferenceToken.stub(:encode, nil) do
      assert_no_difference -> { ComPreference.count } do
        delete base_com_preference_customization_path(ri: "jp"),
               params: { confirm_reset: "1" },
               headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      end
    end

    assert_response :service_unavailable
    assert_equal ComPreferenceStatus::ACTIVE, preference.reload.status_id
    assert_equal generation, preference.jti
    assert cookie.reload.consented
    assert_equal token, cookies[PreferenceCookieName.anonymous_jwt]
    assert_equal binding, cookies[PreferenceBrowserBinding::COOKIE_NAME]
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience, PreferenceBrowserBinding::COOKIE_NAME,].each do |name|
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  end

  test "a missing signing key returns a dependency error and rolls back a preference save" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    patch base_com_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "true" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    token = cookies[PreferenceCookieName.anonymous_jwt]
    payload = PreferenceToken.decode(token, host: host)
    preference = ComPreference.find_by!(public_id: payload.fetch("sub"))
    generation = preference.jti
    original_theme = ComPreferenceTheme.find_by!(preference_id: preference.id).option_id
    key_failure = ->(*) { raise JitSecurityJwtRegistry::ConfigurationError, "key unavailable" }

    PreferenceJwtConfiguration.stub(:private_key_for_active, key_failure) do
      assert_no_difference -> { ComPreference.count } do
        patch base_com_preference_theme_path(ri: "jp"),
              params: { preference_theme: { option_id: "dark" } },
              headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      end
    end

    assert_response :service_unavailable
    assert_equal generation, preference.reload.jti
    assert_equal original_theme, ComPreferenceTheme.find_by!(preference_id: preference.id).option_id
    assert_equal token, cookies[PreferenceCookieName.anonymous_jwt]
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience, PreferenceBrowserBinding::COOKIE_NAME,].each do |name|
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  end

  test "an unavailable verification key rejects a save without treating the JWT as invalid" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    patch base_com_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "true" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    token = cookies[PreferenceCookieName.anonymous_jwt]
    payload = PreferenceToken.decode(token, host: host)
    preference = ComPreference.find_by!(public_id: payload.fetch("sub"))
    generation = preference.jti
    original_theme = ComPreferenceTheme.find_by!(preference_id: preference.id).option_id
    key_failure = ->(*) { raise JitSecurityJwtRegistry::ConfigurationError, "key unavailable" }

    PreferenceJwtConfiguration.stub(:public_key_for, key_failure) do
      assert_no_difference -> { ComPreference.count } do
        patch base_com_preference_theme_path(ri: "jp"),
              params: { preference_theme: { option_id: "dark" } },
              headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      end
    end

    assert_response :service_unavailable
    assert_equal generation, preference.reload.jti
    assert_equal original_theme, ComPreferenceTheme.find_by!(preference_id: preference.id).option_id
    assert_equal token, cookies[PreferenceCookieName.anonymous_jwt]
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience, PreferenceBrowserBinding::COOKIE_NAME,].each do |name|
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  end

  test "a verification key failure renders default com displays without deleting preference cookies" do
    base_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    token = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: base_host, preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: SecureRandom.uuid, jti: SecureRandom.uuid,
    )
    failure = ->(*) { raise JitSecurityJwtRegistry::ConfigurationError, "key unavailable" }
    [base_host, ENV.fetch("PUBLIC_WARP_CORPORATE_URL")].each do |host|
      browser = open_session
      browser.host!(host)
      browser.https!
      browser.cookies[PreferenceCookieName.anonymous_jwt] = token
      browser.cookies[PreferenceIoKeys::Cookies::LANGUAGE] = "en"
      browser.cookies[PreferenceCookieName.anonymous_experience] = '{"theme":"dark"}'

      PreferenceJwtConfiguration.stub(:public_key_for, failure) do
        browser.get("/", params: { ri: "jp" })
      end

      assert_equal 200, browser.response.status
      assert_equal "system", browser.response.parsed_body.at_css("html")["data-theme"]
      [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
       PreferenceCookieName.anonymous_experience,].each do |name|
        assert_not_includes browser.response.headers["Set-Cookie"].to_s, "#{name}="
      end
      assert_equal token, browser.cookies[PreferenceCookieName.anonymous_jwt]
    end
  end

  test "a database read failure renders the default without deleting preference cookies" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    patch base_com_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: "dark" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    token = cookies[PreferenceCookieName.anonymous_jwt]
    failure = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "database unavailable" }

    ComPreference.stub(:database_now, failure) do
      get "/", params: { ri: "jp" }
    end

    assert_response :success
    assert_equal "system", response.parsed_body.at_css("html")["data-theme"]
    assert_equal token, cookies[PreferenceCookieName.anonymous_jwt]
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience,].each do |name|
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  end

  test "settings screens render defaults without child lookups after preference database failure" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    patch base_com_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: "dark" } },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }

    assert_response :see_other
    token = cookies[PreferenceCookieName.anonymous_jwt]
    failure = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "database unavailable" }
    [
      [edit_base_com_preference_theme_path(ri: "jp"), ComPreferenceTheme],
      [edit_base_com_preference_currency_path(ri: "jp"), ComPreferenceCurrency],
      [edit_base_com_preference_cookie_path(ri: "jp"), ComPreferenceCookie],
    ].each do |path, child_class|
      browser = open_session
      browser.host!(host)
      browser.https!
      browser.cookies[PreferenceCookieName.anonymous_jwt] = token
      ComPreference.stub(:database_now, failure) do
        child_class.stub(:find_by, failure) { browser.get(path) }
      end

      assert_equal 200, browser.response.status, path
      assert_equal "system", browser.response.parsed_body.at_css("html")["data-theme"], path
      assert_equal token, browser.cookies[PreferenceCookieName.anonymous_jwt], path
      assert_not_includes browser.response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}=", path
    end
  end
end
