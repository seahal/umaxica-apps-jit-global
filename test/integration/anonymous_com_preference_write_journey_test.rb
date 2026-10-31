# typed: false
# frozen_string_literal: true

require "test_helper"
require "jwt"

# WU-7 section 4.4 integration journey on the anonymous com surface: an explicit consent write
# issues exactly the section 4.1 shared cookie set (signed JWT, language, experience, browser
# binding), stores the binding digest, and the *matching* follow-up read renders the stored consent.
class AnonymousComPreferenceWriteJourneyTest < ActionDispatch::IntegrationTest
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

  fixtures :com_preferences, :com_preference_statuses,
           :com_preference_language_options,
           :com_preference_theme_options, :com_preference_timezone_options,
           :com_preference_currencies, :com_preference_date_formats, :com_preference_time_formats,
           :com_preference_motions, :com_preference_densities, :com_preference_page_sizes

  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! @host
    https!
    [ComPreferenceCurrencyOption, ComPreferenceDateFormatOption, ComPreferenceTimeFormatOption,
     ComPreferenceMotionOption, ComPreferenceDensityOption, ComPreferencePageSizeOption,].each(&:ensure_defaults!)
  end

  test "a consent write issues the four-cookie set" do
    @original_forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    cookies["preference_refresh"] = "invalid-retired-refresh-credential"
    cookies["preference_dbsc"] = "retired-dbsc-credential"

    patch(
      base_com_preference_cookie_path(ri: "jp"),
      params: { preference_cookie: { consented: "true", functional: "true" } },
      headers: browser_write_headers.merge(csrf_write_headers),
    )

    assert_response :see_other

    set_cookies = response_set_cookie_names

    # The section 4.1 shared set rides this response. Legacy item cookies are only expired to
    # prevent cookie tossing from overriding the Preference JWT.
    assert_includes set_cookies, PreferenceCookieName.anonymous_jwt
    assert_includes set_cookies, PreferenceIoKeys::Cookies::LANGUAGE
    assert_includes set_cookies, PreferenceCookieName.anonymous_experience
    assert_includes set_cookies, PreferenceBrowserBinding::COOKIE_NAME

    # The issued JWT is the section 4.2 shape bound to the fresh anonymous row.
    jwt_cookie = response_cookies.fetch(PreferenceCookieName.anonymous_jwt)
    payload, = JWT.decode(jwt_cookie, nil, false)

    assert_not_includes payload.keys, "client_id"
    assert_not_includes payload.keys, "preference_type"
    assert_equal "com", payload.fetch("aud")
    assert_predicate payload.fetch("preferences"), :present?
    cookie_headers = Array(response.headers["Set-Cookie"]).flat_map { |header| header.split("\n") }
    ["preference_refresh", "preference_dbsc"].each do |name|
      header = cookie_headers.find { |entry| entry.start_with?("#{name}=") }

      assert_not_nil header
      assert_operator Time.httpdate(header.match(/expires=([^;]+)/i)[1]), :<, Time.current
    end
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience,].each do |name|
      header = cookie_headers.find { |entry| entry.start_with?("#{name}=") }

      assert_not_nil header
      assert_equal Time.at(payload.fetch("exp")).utc, Time.httpdate(header.match(/expires=([^;]+)/i)[1])
    end

    # The write created its own anonymous row: the JWT's subject resolves to a live row whose
    # separate binding row carries the digest from this consent.
    row = ComPreference.find_by(public_id: payload.fetch("sub"))

    assert_predicate row, :present?
    assert ComPreferenceChronicle.exists?(subject_type: "ComPreference", subject_id: row.id)
    assert_not row.has_attribute?(:token_digest)
    assert_equal ComPreferenceWebPushOption::DISABLED, ComPreferenceWebPush.find_by!(preference_id: row.id).option_id
    cookie_row = ComPreferenceCookie.find_by(preference_id: row.id)

    assert_predicate cookie_row, :present?
    binding_row = ComPreferenceBrowserBinding.find_by!(preference_id: row.id)

    assert_predicate binding_row.digest, :present?
    assert cookie_row.consented
    assert_equal PreferenceBrowserBinding.digest_for(response_cookies.fetch(PreferenceBrowserBinding::COOKIE_NAME)),
                 binding_row.digest
  ensure
    ActionController::Base.allow_forgery_protection = @original_forgery
  end

  test "a preference cookie exceeding 3 KiB is refused before commit" do
    issuer = "https://#{"a" * 1800}.example"
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }

    PreferenceJwtConfiguration.stub(:com_issuer, issuer) do
      assert_no_difference -> { ComPreference.count } do
        patch base_com_api_v0_preferences_theme_path, params: { theme: "dark" }.to_json, headers: headers
      end
    end

    assert_response :service_unavailable
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "preference cookie header size accepts the nearest reachable boundary and rejects the next size" do
    limit = SecurityJwtPreferenceTokenCodec::ANONYMOUS_COM_TOKEN_MAX_BYTES
    labels = @host.split(".")
    domain = ".#{labels.last(2).join(".")}" if labels.length >= 3
    sample_options = {
      domain: domain,
      path: "/",
      secure: true,
      httponly: true,
      same_site: :lax,
      expires: 400.days.from_now,
    }.compact
    candidates =
      (1680..1810).filter_map do |padding|
        issuer = "https://#{"a" * padding}.example"
        token = nil
        PreferenceJwtConfiguration.stub(:com_issuer, issuer) do
          token = PreferenceToken.encode(
            DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: @host, preference_type: "ComPreference",
                                                           public_id: "x" * 21, jti: "x" * 27, issued_at: Time.current,
          )
        end
        next if token.nil?

        size = Rack::Utils.set_cookie_header(
          PreferenceCookieName.anonymous_jwt,
          sample_options.merge(value: token),
        ).bytesize
        [size, issuer]
      end
    # Base64url cannot represent every adjacent byte length; exercise the nearest reachable sizes.
    below = candidates.select { |size, _issuer| size < limit }.max_by(&:first)
    at_or_below = candidates.select { |size, _issuer| size <= limit }.max_by(&:first)
    above = candidates.select { |size, _issuer| size > limit }.min_by(&:first)

    assert below
    assert at_or_below
    assert above
    [below, at_or_below, above].uniq.each do |size, issuer|
      reset!
      host! @host
      https!
      PreferenceJwtConfiguration.stub(:com_issuer, issuer) do
        if size <= limit
          patch base_com_api_v0_preferences_theme_path,
                params: { theme: "dark" }.to_json,
                headers: { "Accept" => "application/json", "Content-Type" => "application/json" }

          assert_response :ok
          cookie =
            Array(response.headers["Set-Cookie"]).flat_map { |value| value.split("\n") }
              .find { |value| value.start_with?("#{PreferenceCookieName.anonymous_jwt}=") }

          assert_equal size, cookie.bytesize
        else
          assert_no_difference -> { ComPreference.count } do
            patch base_com_api_v0_preferences_theme_path,
                  params: { theme: "dark" }.to_json,
                  headers: { "Accept" => "application/json", "Content-Type" => "application/json" }
          end

          assert_response :service_unavailable
        end
      end
    end
  end

  test "the com consent screen rejects invalid input without creating a preference" do
    assert_no_difference -> { ComPreference.count } do
      patch base_com_preference_cookie_path(ri: "jp"),
            params: { preference_cookie: { consented: "invalid" } }
    end

    assert_response :unprocessable_content
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "the com consent screen rolls back and does not issue cookies on signing failure" do
    cookies["preference_refresh"] = "old-refresh"
    cookies["preference_dbsc"] = "old-dbsc"

    PreferenceToken.stub(:encode, nil) do
      assert_no_difference [-> { ComPreference.count }, -> { ComPreferenceChronicle.count }] do
        patch base_com_preference_cookie_path(ri: "jp"),
              params: { preference_cookie: { consented: "true" } }
      end
    end

    assert_response :service_unavailable
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceBrowserBinding::COOKIE_NAME}="
    assert_not_includes response.headers["Set-Cookie"].to_s, "preference_refresh="
    assert_not_includes response.headers["Set-Cookie"].to_s, "preference_dbsc="
  end

  test "the matched read renders the stored consent from the issued JWT" do
    raw = PreferenceBrowserBinding.mint_value
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    ComPreferenceLanguage.create!(preference: preference, option_id: ComPreferenceLanguageOption::JA)
    ComPreferenceTheme.create!(preference: preference, option_id: ComPreferenceThemeOption::SYSTEM)
    cookie_row = ComPreferenceCookie.create!(
      preference: preference, consented: true,
    )
    ComPreferenceConsentReceipt.create!(preference: preference, version: SecureRandom.uuid, recorded_at: Time.current)
    binding_row = ComPreferenceBrowserBinding.create!(
      preference: preference, digest: PreferenceBrowserBinding.digest_for(raw),
    )
    preference.update!(jti: JitSecurityJwtJtiGenerator.generate)
    token = PreferenceToken.encode(
      { "theme" => "system",
        "language" => "ja",
        "timezone" => "Asia/Tokyo",
        "currency" => "jpy",
        "date_format" => "iso",
        "time_format" => "24",
        "motion" => "standard",
        "density" => "standard",
        "page_size" => "infinity", }, host: @host, preference_type: "ComPreference",
                                      issued_at: Time.current,
                                      public_id: preference.public_id, jti: preference.jti,
    )

    assert_predicate PreferenceToken.decode(token, host: @host), :present?
    cookies[PreferenceCookieName.anonymous_jwt] = token
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = raw
    get edit_base_com_preference_cookie_path(ri: "jp")

    assert_response :ok
    assert_equal token, request.cookies[PreferenceCookieName.anonymous_jwt]
    assert_equal raw, request.cookies[PreferenceBrowserBinding::COOKIE_NAME]
    categories = inertia_props.fetch("form").fetch("categories")

    assert categories.find { |c| c.fetch("key") == "consented" }.fetch("value")
    assert cookie_row.reload.consented
    assert_equal binding_row.reload.digest, PreferenceBrowserBinding.digest_for(raw)
  end

  test "the com consent API requires a matching browser binding to suppress the banner" do
    raw = PreferenceBrowserBinding.mint_value
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    ComPreferenceCookie.create!(
      preference: preference, consented: true,
    )
    ComPreferenceConsentReceipt.create!(preference: preference, version: SecureRandom.uuid, recorded_at: Time.current)
    ComPreferenceBrowserBinding.create!(preference: preference, digest: PreferenceBrowserBinding.digest_for(raw))
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      { "theme" => "system",
        "language" => "ja",
        "timezone" => "Asia/Tokyo",
        "currency" => "jpy",
        "date_format" => "iso",
        "time_format" => "24",
        "motion" => "standard",
        "density" => "standard",
        "page_size" => "infinity", }, host: @host, preference_type: "ComPreference",
                                      issued_at: Time.current,
                                      public_id: preference.public_id, jti: preference.jti,
    )
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = raw

    assert_no_difference -> { ComPreference.count } do
      get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }
    end
    assert_response :ok
    assert_not response.parsed_body.fetch("show_banner")

    cookies[PreferenceBrowserBinding::COOKIE_NAME] = PreferenceBrowserBinding.mint_value
    get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert response.parsed_body.fetch("show_banner")

    cookies.delete(PreferenceBrowserBinding::COOKIE_NAME)
    get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert response.parsed_body.fetch("show_banner")

    preference.update!(last_issued_expires_at: 1.minute.from_now)
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = raw
    ComPreference.stub(:database_now, preference.last_issued_expires_at) do
      get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

      assert_response :ok
      assert response.parsed_body.fetch("show_banner")
    end
  end

  test "the consent screen hides every category when a binding is missing" do
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    ComPreferenceCookie.create!(preference: preference, consented: false, functional: true)
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "system" }), host: @host, preference_type: "ComPreference",
                                                       issued_at: Time.current,
                                                       public_id: preference.public_id, jti: preference.jti,
    )

    get edit_base_com_preference_cookie_path(ri: "jp")

    assert_response :ok
    categories = inertia_props.fetch("form").fetch("categories")

    assert_not categories.find { |category| category.fetch("key") == "functional" }.fetch("value")
    assert ComPreferenceCookie.find_by!(preference_id: preference.id).functional
  end

  test "the theme API reads the theme from the com preference JWT" do
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    token = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark", "language" => "ja" }), host: @host, preference_type: "ComPreference",
                                                                         issued_at: Time.current,
                                                                         public_id: preference.public_id,
                                                                         jti: preference.jti,
    )
    cookies[PreferenceCookieName.anonymous_jwt] = token

    assert_no_difference -> { ComPreference.count } do
      get base_com_api_v0_preferences_theme_path, headers: { "Accept" => "application/json" }
    end

    assert_response :ok
    assert_equal "dr", response.parsed_body.fetch("theme")
  end

  test "the com page renders the verified JWT language and theme without writing" do
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    token = PreferenceToken.encode(
      { "theme" => "dark",
        "language" => "en",
        "timezone" => "Asia/Tokyo",
        "currency" => "jpy",
        "date_format" => "iso",
        "time_format" => "24",
        "motion" => "standard",
        "density" => "standard",
        "page_size" => "infinity", }, host: @host, preference_type: "ComPreference",
                                      issued_at: Time.current,
                                      public_id: preference.public_id, jti: preference.jti,
    )
    cookies[PreferenceCookieName.anonymous_jwt] = token
    cookies["ct"] = "li"

    assert_no_difference -> { ComPreference.count } do
      get edit_base_com_preference_cookie_path(ri: "jp")
    end

    assert_response :ok
    assert_select "html[lang=en][data-theme=dark]"
  end

  test "an older com JWT remains usable for display after the row generation changes" do
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    token = PreferenceToken.encode(
      { "theme" => "dark",
        "language" => "en",
        "timezone" => "Asia/Tokyo",
        "currency" => "jpy",
        "date_format" => "iso",
        "time_format" => "24",
        "motion" => "standard",
        "density" => "standard",
        "page_size" => "infinity", }, host: @host, preference_type: "ComPreference",
                                      issued_at: Time.current,
                                      public_id: preference.public_id, jti: preference.jti,
    )
    preference.update!(jti: JitSecurityJwtJtiGenerator.generate)
    cookies[PreferenceCookieName.anonymous_jwt] = token

    assert_no_difference -> { ComPreference.count } do
      get edit_base_com_preference_cookie_path(ri: "jp")
    end

    assert_response :ok
    assert_select "html[lang=en][data-theme=dark]"
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "an invalid com theme API write does not issue display cookies" do
    patch base_com_api_v0_preferences_theme_path,
          params: { theme: "invalid" }.to_json,
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" }

    assert_response :unprocessable_content
    headers = Array(response.headers["Set-Cookie"]).flat_map { |header| header.split("\n") }
    names = headers.map { |header| header.split("=", 2).first }

    assert_not_includes names, "ct"
    assert_not_includes names, PreferenceIoKeys::Cookies::LANGUAGE
    assert_not_includes names, "tz"
    assert_not_includes names, PreferenceCookieName.anonymous_jwt
  end

  test "the com theme API saves and rereads the signed preference" do
    patch base_com_api_v0_preferences_theme_path,
          params: { theme: "dark" }.to_json,
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" }

    assert_response :ok
    claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))

    assert_equal ComPreferenceThemeOption::DARK, ComPreferenceTheme.find_by!(preference_id: preference.id).option_id
    get base_com_api_v0_preferences_theme_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_equal "dr", response.parsed_body.fetch("theme")
  end

  test "the com theme screen saves a valid option and rejects an invalid option" do
    patch base_com_preference_theme_path(ri: "jp"), params: { preference_theme: { option_id: "2" } }

    assert_response :see_other
    claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))

    assert_equal ComPreferenceThemeOption::DARK, ComPreferenceTheme.find_by!(preference_id: preference.id).option_id
    assert_no_difference -> { ComPreference.count } do
      patch base_com_preference_theme_path(ri: "jp"), params: { preference_theme: { option_id: "99" } }
    end

    assert_response :unprocessable_content
    assert_equal ComPreferenceThemeOption::DARK, ComPreferenceTheme.find_by!(preference_id: preference.id).option_id
  end

  test "the com theme screen rolls back on signing failure" do
    PreferenceToken.stub(:encode, nil) do
      assert_no_difference -> { ComPreference.count } do
        patch base_com_preference_theme_path(ri: "jp"), params: { preference_theme: { option_id: "dr" } }
      end
    end

    assert_response :service_unavailable
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "the com currency screen saves a valid value and rejects an invalid value" do
    patch base_com_preference_currency_path(ri: "jp"), params: { preference_currency: { option_id: "usd" } }

    assert_response :see_other
    claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))

    assert_equal ComPreferenceCurrencyOption::USD,
                 ComPreferenceCurrency.find_by!(preference_id: preference.id).option_id
    assert_equal "usd", claims.fetch("preferences").fetch("currency")
    assert_no_difference -> { ComPreference.count } do
      patch base_com_preference_currency_path(ri: "jp"), params: { preference_currency: { option_id: "invalid" } }
    end

    assert_response :unprocessable_content
    assert_equal ComPreferenceCurrencyOption::USD,
                 ComPreferenceCurrency.find_by!(preference_id: preference.id).option_id
  end

  test "the com currency screen rolls back on signing failure" do
    PreferenceToken.stub(:encode, nil) do
      assert_no_difference -> { ComPreference.count } do
        patch base_com_preference_currency_path(ri: "jp"), params: { preference_currency: { option_id: "jpy" } }
      end
    end

    assert_response :service_unavailable
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "the com selectable screens persist their selected options in one preference" do
    [
      [base_com_preference_calendar_path(ri: "jp"), :preference_date_format, "us", "date_format", "us"],
      [base_com_preference_clock_path(ri: "jp"), :preference_time_format, "12", "time_format", "12"],
      [base_com_preference_motion_path(ri: "jp"), :preference_motion, "reduced", "motion", "reduced"],
      [base_com_preference_density_path(ri: "jp"), :preference_density, "compact", "density", "compact"],
      [base_com_preference_pagination_path(ri: "jp"), :preference_page_size, "50", "page_size", "50"],
    ].each do |path, parameter, value, claim, expected|
      patch path, params: { parameter => { option_id: value } }

      assert_response :see_other
      claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)

      assert_equal expected, claims.fetch("preferences").fetch(claim)
    end
  end

  test "a com selectable screen rejects invalid input without creating a preference" do
    assert_no_difference -> { ComPreference.count } do
      patch base_com_preference_calendar_path(ri: "jp"), params: { preference_date_format: { option_id: "invalid" } }
    end

    assert_response :unprocessable_content
  end

  test "a com selectable screen rolls back when signing fails" do
    PreferenceToken.stub(:encode, nil) do
      assert_no_difference -> { ComPreference.count } do
        patch base_com_preference_motion_path(ri: "jp"), params: { preference_motion: { option_id: "reduced" } }
      end
    end

    assert_response :service_unavailable
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "the com language and timezone screens save verified display settings" do
    patch base_com_preference_language_path(ri: "jp"), params: { preference_language: { option_id: "en" } }

    assert_response :see_other
    claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)

    assert_equal "en", claims.fetch("preferences").fetch("language")
    patch base_com_preference_timezone_path(ri: "jp"),
          params: { preference_timezone: { option_id: "America/New_York" } }

    assert_response :see_other
    claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)

    assert_equal "America/New_York", claims.fetch("preferences").fetch("timezone")
  end

  test "the com language and timezone screens reject unknown values without creating a preference" do
    assert_no_difference -> { ComPreference.count } do
      patch base_com_preference_language_path(ri: "jp"), params: { preference_language: { option_id: "unknown" } }

      assert_response :unprocessable_content
      patch base_com_preference_timezone_path(ri: "jp"), params: { preference_timezone: { option_id: "unknown" } }

      assert_response :unprocessable_content
    end
  end

  test "the base actor uses the stored region without requiring a browser binding" do
    patch base_com_preference_region_path(ri: "jp"), params: { preference_region: { option_id: "us" } }

    assert_response :see_other
    rendered_preferences = []
    writes = []
    capture = ->(*) { rendered_preferences << Actor.preferences }
    sql_capture =
      ->(_name, _start, _finish, _id, payload) {
        writes << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)/i)
      }
    ActiveSupport::Notifications.subscribed(sql_capture, "sql.active_record") do
      ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
        get base_com_root_path

        assert_redirected_to base_com_root_url(ri: "us")
        follow_redirect!
      end
    end

    assert_response :success
    assert rendered_preferences.any? { |preference| preference.region == "us" }
    assert_empty writes

    rendered_preferences.clear
    ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
      get base_com_root_path(ri: "jp")
    end

    assert_response :success
    assert rendered_preferences.any? { |preference| preference.region == "jp" }
  end

  test "the com region screen saves the region and its four display defaults" do
    patch base_com_api_v0_preferences_theme_path,
          params: { theme: "dark" }.to_json,
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" }

    assert_response :ok
    patch base_com_preference_region_path(ri: "jp", ct: "light", tz: "America/New_York"),
          params: { preference_region: { option_id: "us" } }

    assert_response :see_other
    claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)
    preferences = claims.fetch("preferences")
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))

    assert_equal ComPreferenceRegionOption::US, ComPreferenceRegion.find_by!(preference_id: preference.id).option_id
    assert_equal "en", preferences.fetch("language")
    assert_equal "us", preferences.fetch("date_format")
    assert_equal "12", preferences.fetch("time_format")
    assert_equal "usd", preferences.fetch("currency")
    assert_equal "dark", preferences.fetch("theme")
    assert_equal "Asia/Tokyo", preferences.fetch("timezone")
    assert_not_includes preferences, "region"

    patch base_com_preference_region_path(ri: "us"), params: { preference_region: { option_id: "jp" } }

    assert_response :see_other
    claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)
    preferences = claims.fetch("preferences")

    assert_equal "ja", preferences.fetch("language")
    assert_equal "iso", preferences.fetch("date_format")
    assert_equal "24", preferences.fetch("time_format")
    assert_equal "jpy", preferences.fetch("currency")
    assert_equal "dark", preferences.fetch("theme")
    assert_equal "Asia/Tokyo", preferences.fetch("timezone")
  end

  test "the com region screen rejects an unknown region without writing" do
    assert_no_difference -> { ComPreference.count } do
      patch base_com_preference_region_path(ri: "jp"), params: { preference_region: { option_id: "invalid" } }
    end

    assert_response :unprocessable_content
  end

  test "the com region bundle rolls back on signing failure" do
    PreferenceToken.stub(:encode, nil) do
      assert_no_difference -> { ComPreference.count } do
        patch base_com_preference_region_path(ri: "jp"), params: { preference_region: { option_id: "us" } }
      end
    end

    assert_response :service_unavailable
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "com reset retires the current preference and creates defaults" do
    patch base_com_api_v0_preferences_theme_path,
          params: { theme: "dark" }.to_json,
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" }

    assert_response :ok
    old_claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)
    old = ComPreference.find_by!(public_id: old_claims.fetch("sub"))

    reset_audits = ComPreferenceChronicle.where(
      subject_type: "ComPreference", subject_id: old.id, event_id: ComPreferenceChronicleEvent::RESET_BY_USER_DECISION,
    )
    assert_difference -> { reset_audits.count }, 1 do
      assert_difference -> { ComPreference.count }, 1 do
        delete base_com_preference_customization_path(ri: "jp"), params: { confirm_reset: "1" }
      end
    end

    assert_response :see_other
    assert_equal ComPreferenceStatus::RETIRED, old.reload.status_id
    retention = Time.at(old_claims.fetch("exp")).utc + 30.days

    assert_not old.issuance_retention_elapsed?(now: retention - 1.second)
    assert old.issuance_retention_elapsed?(now: retention)
    claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)

    assert_not_equal old.public_id, claims.fetch("sub")
    assert_equal "system", claims.fetch("preferences").fetch("theme")
  end

  test "com reset refuses missing confirmation without creating a preference" do
    assert_no_difference -> { ComPreference.count } do
      delete base_com_preference_customization_path(ri: "jp"), params: { confirm_reset: "0" }
    end

    assert_response :redirect
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "com reset retires a bound consent and web push generation and clears its browser binding" do
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch base_com_api_v0_preferences_cookie_path, params: { consented: true }.to_json, headers: headers

    assert_response :ok
    patch base_com_api_v0_preferences_web_push_path, params: { web_push: "enabled" }.to_json, headers: headers

    assert_response :ok
    old_claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: @host)
    old = ComPreference.find_by!(public_id: old_claims.fetch("sub"))
    old_binding = ComPreferenceBrowserBinding.find_by!(preference_id: old.id).attributes
    old_consent = ComPreferenceCookie.find_by!(preference_id: old.id).attributes
    old_push = ComPreferenceWebPush.find_by!(preference_id: old.id).attributes
    old_receipt = ComPreferenceConsentReceipt.find_by!(preference_id: old.id).attributes
    assert_difference -> { ComPreference.count }, 1 do
      delete base_com_preference_customization_path(ri: "jp"), params: { confirm_reset: "1" }
    end

    assert_response :see_other
    assert_equal ComPreferenceStatus::RETIRED, old.reload.status_id
    assert_equal old_binding, ComPreferenceBrowserBinding.find_by!(preference_id: old.id).attributes
    assert_equal old_consent, ComPreferenceCookie.find_by!(preference_id: old.id).attributes
    assert_equal old_push, ComPreferenceWebPush.find_by!(preference_id: old.id).attributes
    assert_equal old_receipt, ComPreferenceConsentReceipt.find_by!(preference_id: old.id).attributes
    claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: @host)
    replacement = ComPreference.find_by!(public_id: claims.fetch("sub"))

    assert_not_equal old.id, replacement.id
    assert_equal ComPreferenceStatus::ACTIVE, replacement.status_id
    assert_not ComPreferenceBrowserBinding.exists?(preference_id: replacement.id)
    assert_not ComPreferenceConsentReceipt.exists?(preference_id: replacement.id)
    assert_not ComPreferenceCookie.find_by!(preference_id: replacement.id).consented
    assert_equal ComPreferenceWebPushOption::DISABLED,
                 ComPreferenceWebPush.find_by!(preference_id: replacement.id).option_id
    cookie_headers = Array(response.headers["Set-Cookie"]).flat_map { |header| header.split("\n") }
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience,].each do |name|
      header = cookie_headers.find { |entry| entry.start_with?("#{name}=") }

      assert_not_nil header
      assert_equal Time.at(claims.fetch("exp")).utc, Time.httpdate(header.match(/expires=([^;]+)/i)[1])
    end
    binding_header = cookie_headers.find { |entry| entry.start_with?("#{PreferenceBrowserBinding::COOKIE_NAME}=") }

    assert_not_nil binding_header
    assert_operator Time.httpdate(binding_header.match(/expires=([^;]+)/i)[1]), :<, Time.current
    assert_no_match(/\bdomain=/i, binding_header)
    assert_empty cookies[PreferenceBrowserBinding::COOKIE_NAME].to_s
  end

  test "com reset signing failure keeps a bound generation and does not clear its browser binding" do
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch base_com_api_v0_preferences_cookie_path, params: { consented: true }.to_json, headers: headers

    assert_response :ok
    token = cookies[PreferenceCookieName.anonymous_jwt]
    binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    claims = PreferenceToken.decode(token, host: @host)
    old = ComPreference.find_by!(public_id: claims.fetch("sub"))
    original = old.attributes
    old_binding = ComPreferenceBrowserBinding.find_by!(preference_id: old.id).attributes
    old_receipt = ComPreferenceConsentReceipt.find_by!(preference_id: old.id).attributes

    PreferenceToken.stub(:encode, nil) do
      assert_no_difference -> { ComPreference.count } do
        delete base_com_preference_customization_path(ri: "jp"), params: { confirm_reset: "1" }
      end
    end

    assert_response :service_unavailable
    assert_equal original, old.reload.attributes
    assert_equal old_binding, ComPreferenceBrowserBinding.find_by!(preference_id: old.id).attributes
    assert_equal old_receipt, ComPreferenceConsentReceipt.find_by!(preference_id: old.id).attributes
    assert_equal token, cookies[PreferenceCookieName.anonymous_jwt]
    assert_equal binding, cookies[PreferenceBrowserBinding::COOKIE_NAME]
    [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
     PreferenceCookieName.anonymous_experience, PreferenceBrowserBinding::COOKIE_NAME,].each do |name|
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  end

  test "com reset rolls back retirement when signing fails" do
    patch base_com_api_v0_preferences_theme_path,
          params: { theme: "dark" }.to_json,
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" }
    old_claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)
    old = ComPreference.find_by!(public_id: old_claims.fetch("sub"))

    reset_audits = ComPreferenceChronicle.where(
      subject_type: "ComPreference", subject_id: old.id, event_id: ComPreferenceChronicleEvent::RESET_BY_USER_DECISION,
    )

    PreferenceToken.stub(:encode, nil) do
      assert_no_difference -> { reset_audits.count } do
        assert_no_difference -> { ComPreference.count } do
          delete base_com_preference_customization_path(ri: "jp"), params: { confirm_reset: "1" }
        end
      end
    end

    assert_response :service_unavailable
    assert_equal ComPreferenceStatus::ACTIVE, old.reload.status_id
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "com reset rolls back retirement when the reset audit cannot be written" do
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch base_com_api_v0_preferences_theme_path, params: { theme: "dark" }.to_json, headers: headers

    assert_response :ok
    token = cookies[PreferenceCookieName.anonymous_jwt]
    old_claims = PreferenceToken.decode(token, host: @host)
    old = ComPreference.find_by!(public_id: old_claims.fetch("sub"))
    reset_audits = ComPreferenceChronicle.where(
      subject_type: "ComPreference", subject_id: old.id, event_id: ComPreferenceChronicleEvent::RESET_BY_USER_DECISION,
    )
    failure = ->(*) { raise ActiveRecord::StatementInvalid, "audit unavailable" }

    ComPreferenceChronicle.stub(:create!, failure) do
      assert_no_difference -> { reset_audits.count } do
        assert_no_difference -> { ComPreference.count } do
          delete base_com_preference_customization_path(ri: "jp"), params: { confirm_reset: "1" }
        end
      end
    end

    assert_response :service_unavailable
    assert_equal ComPreferenceStatus::ACTIVE, old.reload.status_id
    assert_equal token, cookies[PreferenceCookieName.anonymous_jwt]
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "com reset with a stale JWT leaves its referenced row unchanged" do
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch base_com_api_v0_preferences_theme_path, params: { theme: "dark" }.to_json, headers: headers
    token = cookies[PreferenceCookieName.anonymous_jwt]
    claims, = JWT.decode(token, nil, false)
    original = ComPreference.find_by!(public_id: claims.fetch("sub"))
    patch base_com_api_v0_preferences_theme_path, params: { theme: "light" }.to_json, headers: headers

    assert_response :ok
    reset!
    host! @host
    https!
    cookies[PreferenceCookieName.anonymous_jwt] = token
    reset_audits = ComPreferenceChronicle.where(
      subject_type: "ComPreference", subject_id: original.id,
      event_id: ComPreferenceChronicleEvent::RESET_BY_USER_DECISION,
    )
    assert_no_difference -> { reset_audits.count } do
      assert_difference -> { ComPreference.count }, 1 do
        delete base_com_preference_customization_path(ri: "jp"), params: { confirm_reset: "1" }
      end
    end

    assert_response :see_other
    assert_equal ComPreferenceStatus::ACTIVE, original.reload.status_id
    assert_equal ComPreferenceThemeOption::LIGHT, ComPreferenceTheme.find_by!(preference_id: original.id).option_id
  end

  test "the com theme API ignores a legacy theme cookie without a JWT" do
    cookies["ct"] = "dr"
    get base_com_api_v0_preferences_theme_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_equal "sy", response.parsed_body.fetch("theme")
  end

  test "duplicate com preference or binding cookies are rejected without creating a row" do
    [PreferenceCookieName.anonymous_jwt, PreferenceBrowserBinding::COOKIE_NAME,
     PreferenceCookieName.anonymous_experience, PreferenceIoKeys::Cookies::LANGUAGE,].each do |name|
      assert_no_difference -> { ComPreference.count } do
        get base_com_api_v0_preferences_cookie_path,
            headers: { "Accept" => "application/json", "Cookie" => "#{name}=first; #{name}=second" }
      end

      assert_response :bad_request
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  end

  test "duplicate preference cookies cannot change consent, web push, display settings or reset a valid row" do
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch base_com_api_v0_preferences_cookie_path, params: { consented: true }.to_json, headers: headers

    assert_response :ok
    token = cookies[PreferenceCookieName.anonymous_jwt]
    binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    claims = PreferenceToken.decode(token, host: @host)
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))
    original = preference.attributes
    original_binding = ComPreferenceBrowserBinding.find_by!(preference_id: preference.id).attributes
    original_consent = ComPreferenceCookie.find_by!(preference_id: preference.id).attributes
    original_push = ComPreferenceWebPush.find_by!(preference_id: preference.id).attributes
    names = [PreferenceCookieName.anonymous_jwt, PreferenceBrowserBinding::COOKIE_NAME,
             PreferenceCookieName.anonymous_experience, PreferenceIoKeys::Cookies::LANGUAGE,]
    names.each do |name|
      valid_value =
        if name == PreferenceCookieName.anonymous_jwt
          token
        elsif name == PreferenceBrowserBinding::COOKIE_NAME
          binding
        else
          "first"
        end
      ["#{name}=#{valid_value}; #{name}=injected", "#{name}=injected; #{name}=#{valid_value}"].each do |duplicates|
        cookie_parts = [duplicates]
        unless name == PreferenceCookieName.anonymous_jwt
          cookie_parts << "#{PreferenceCookieName.anonymous_jwt}=#{token}"
        end
        unless name == PreferenceBrowserBinding::COOKIE_NAME
          cookie_parts << "#{PreferenceBrowserBinding::COOKIE_NAME}=#{binding}"
        end
        hostile_headers = headers.merge("Cookie" => cookie_parts.join("; "))
        assert_no_difference -> { ComPreference.count } do
          patch base_com_api_v0_preferences_theme_path, params: { theme: "dark" }.to_json, headers: hostile_headers

          assert_response :bad_request
          names.each { |cookie_name| assert_not_includes response.headers["Set-Cookie"].to_s, "#{cookie_name}=" }
          patch base_com_api_v0_preferences_cookie_path, params: { consented: false }.to_json, headers: hostile_headers

          assert_response :bad_request
          names.each { |cookie_name| assert_not_includes response.headers["Set-Cookie"].to_s, "#{cookie_name}=" }
          patch base_com_api_v0_preferences_web_push_path, params: { web_push: "enabled" }.to_json,
                                                           headers: hostile_headers

          assert_response :bad_request
          names.each { |cookie_name| assert_not_includes response.headers["Set-Cookie"].to_s, "#{cookie_name}=" }
          delete base_com_preference_customization_path(ri: "jp"), params: { confirm_reset: "1" }.to_json,
                                                                   headers: hostile_headers

          assert_response :bad_request
          names.each { |cookie_name| assert_not_includes response.headers["Set-Cookie"].to_s, "#{cookie_name}=" }
        end

        assert_equal original, preference.reload.attributes
        assert_equal original_binding, ComPreferenceBrowserBinding.find_by!(preference_id: preference.id).attributes
        assert_equal original_consent, ComPreferenceCookie.find_by!(preference_id: preference.id).attributes
        assert_equal original_push, ComPreferenceWebPush.find_by!(preference_id: preference.id).attributes
      end
    end
  end

  test "a generation collision rolls back the save and reports a dependency failure" do
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch base_com_api_v0_preferences_theme_path, params: { theme: "dark" }.to_json, headers: headers

    assert_response :ok
    token = cookies[PreferenceCookieName.anonymous_jwt]
    claims, = JWT.decode(token, nil, false)
    original = ComPreference.find_by!(public_id: claims.fetch("sub"))
    other = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    original_jti = original.jti
    original_snapshot = [original.last_issued_at, original.last_issued_expires_at]

    JitSecurityJwtJtiGenerator.stub(:generate, other.jti) do
      patch base_com_api_v0_preferences_theme_path, params: { theme: "light" }.to_json, headers: headers
    end

    assert_response :service_unavailable
    assert_equal original_jti, original.reload.jti
    assert_equal original_snapshot, [original.last_issued_at, original.last_issued_expires_at]
    assert_equal ComPreferenceThemeOption::DARK, ComPreferenceTheme.find_by!(preference_id: original.id).option_id
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceCookieName.anonymous_jwt}="
  end

  test "a com theme signing failure rolls back and emits no preference cookies" do
    PreferenceToken.stub(:encode, nil) do
      assert_no_difference -> { ComPreference.count } do
        patch base_com_api_v0_preferences_theme_path,
              params: { theme: "dark" }.to_json,
              headers: { "Accept" => "application/json", "Content-Type" => "application/json" }
      end
    end

    assert_response :service_unavailable
    headers = Array(response.headers["Set-Cookie"]).flat_map { |header| header.split("\n") }
    names = headers.map { |header| header.split("=", 2).first }

    assert_not_includes names, PreferenceCookieName.anonymous_jwt
    assert_not_includes names, PreferenceCookieName.anonymous_experience
    assert_not_includes names, PreferenceIoKeys::Cookies::LANGUAGE
  end

  test "a com consent API write creates a bound preference and reads it back" do
    assert_difference -> { ComPreference.count }, 1 do
      patch base_com_api_v0_preferences_cookie_path,
            params: { cookie: { consented: true, functional: true } }.to_json,
            headers: { "Accept" => "application/json", "Content-Type" => "application/json" }
    end

    assert_response :ok
    assert response.parsed_body.fetch("cookie").fetch("functional")
    token = cookies[PreferenceCookieName.anonymous_jwt]
    binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    claims, = JWT.decode(token, nil, false)
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))
    cookie = ComPreferenceCookie.find_by!(preference_id: preference.id)

    assert_equal PreferenceBrowserBinding.digest_for(binding),
                 ComPreferenceBrowserBinding.find_by!(preference_id: preference.id).digest
    assert cookie.functional
    get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_not response.parsed_body.fetch("show_banner")
  end

  test "a com consent API signing failure rolls back the preference and emits no preference cookies" do
    PreferenceToken.stub(:encode, nil) do
      assert_no_difference -> { ComPreference.count } do
        patch base_com_api_v0_preferences_cookie_path,
              params: { consented: true }.to_json,
              headers: { "Accept" => "application/json", "Content-Type" => "application/json" }
      end
    end

    assert_response :service_unavailable
    headers = Array(response.headers["Set-Cookie"]).flat_map { |header| header.split("\n") }
    names = headers.map { |header| header.split("=", 2).first }

    assert_not_includes names, PreferenceCookieName.anonymous_jwt
    assert_not_includes names, PreferenceCookieName.anonymous_experience
    assert_not_includes names, PreferenceIoKeys::Cookies::LANGUAGE
    assert_not_includes names, PreferenceBrowserBinding::COOKIE_NAME
  end

  test "a signed com JWT missing a display field creates a new preference on write" do
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch base_com_api_v0_preferences_cookie_path, params: { consented: true }.to_json, headers: headers

    assert_response :ok
    claims, jwt_header = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)
    original = ComPreference.find_by!(public_id: claims.fetch("sub"))
    original_functional = ComPreferenceCookie.find_by!(preference_id: original.id).functional
    incomplete = claims.merge("preferences" => claims.fetch("preferences").except("theme"))
    reset!
    host! @host
    https!
    cookies[PreferenceCookieName.anonymous_jwt] = JWT.encode(
      incomplete, PreferenceJwtConfiguration.private_key_for_active("preference_com"),
      jwt_header.fetch("alg"), jwt_header.except("alg"),
    )

    assert_difference -> { ComPreference.count }, 1 do
      patch base_com_api_v0_preferences_cookie_path,
            params: { cookie: { consented: true, functional: true } }.to_json, headers: headers
    end

    assert_response :ok
    new_claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)

    assert_not_equal original.public_id, new_claims.fetch("sub")
    assert_equal DISPLAY_SNAPSHOT.keys.sort, new_claims.fetch("preferences").keys.sort
    assert_equal original_functional, ComPreferenceCookie.find_by!(preference_id: original.id).functional
  end

  test "a stale com JWT creates a new preference without changing the original" do
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch base_com_api_v0_preferences_cookie_path, params: { consented: true }.to_json, headers: headers

    assert_response :ok
    old_token = cookies[PreferenceCookieName.anonymous_jwt]
    claims, = JWT.decode(old_token, nil, false)
    original = ComPreference.find_by!(public_id: claims.fetch("sub"))

    patch base_com_api_v0_preferences_cookie_path,
          params: { cookie: { consented: true, functional: true } }.to_json, headers: headers

    assert_response :ok
    assert ComPreferenceCookie.find_by!(preference_id: original.id).functional

    reset!
    host! @host
    https!
    cookies[PreferenceCookieName.anonymous_jwt] = old_token
    assert_difference -> { ComPreference.count }, 1 do
      patch base_com_api_v0_preferences_cookie_path,
            params: { cookie: { consented: true, functional: false } }.to_json, headers: headers
    end

    assert_response :ok
    assert ComPreferenceCookie.find_by!(preference_id: original.id).functional
  end

  test "a com JWT expiring at the database decision time cannot update its row" do
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    cookie = ComPreferenceCookie.create!(preference: preference, consented: true, functional: true)
    token = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "system" }), host: @host, preference_type: "ComPreference",
                                                       issued_at: Time.current,
                                                       public_id: preference.public_id, jti: preference.jti,
    )
    claims, header = JWT.decode(token, nil, false)
    claims["exp"] = Time.current.to_i + 5
    token = JWT.encode(
      claims, PreferenceJwtConfiguration.private_key_for_active("preference_com"),
      header.fetch("alg"), header.except("alg"),
    )
    cookies[PreferenceCookieName.anonymous_jwt] = token

    ComPreference.stub(:database_now, Time.at(claims.fetch("exp")).utc) do
      assert_difference -> { ComPreference.count }, 1 do
        patch base_com_api_v0_preferences_cookie_path,
              params: { cookie: { consented: true, functional: false } }.to_json,
              headers: { "Accept" => "application/json", "Content-Type" => "application/json" }
      end
    end

    assert_response :ok
    assert cookie.reload.functional
  end

  test "a com consent API issuance uses the database decision time" do
    decision_time = 10.seconds.ago.change(usec: 0)

    ComPreference.stub(:database_now, decision_time) do
      patch base_com_api_v0_preferences_cookie_path,
            params: { consented: true }.to_json,
            headers: { "Accept" => "application/json", "Content-Type" => "application/json" }
    end

    assert_response :ok
    claims, = JWT.decode(cookies[PreferenceCookieName.anonymous_jwt], nil, false)

    assert_equal decision_time.to_i, claims.fetch("iat")
    assert_equal decision_time.to_i + 400.days.to_i, claims.fetch("exp")
    preference = ComPreference.find_by!(public_id: claims.fetch("sub"))

    assert_equal Time.at(claims.fetch("iat")).utc, preference.last_issued_at
    assert_equal Time.at(claims.fetch("exp")).utc, preference.last_issued_expires_at
    cookie_headers = Array(response.headers["Set-Cookie"]).flat_map { |header| header.split("\n") }
    names = [PreferenceCookieName.anonymous_jwt, PreferenceIoKeys::Cookies::LANGUAGE,
             PreferenceCookieName.anonymous_experience, PreferenceBrowserBinding::COOKIE_NAME,]
    names.each do |name|
      header = cookie_headers.find { |entry| entry.start_with?("#{name}=") }

      assert_not_nil header
      assert_equal Time.at(claims.fetch("exp")).utc, Time.httpdate(header.match(/expires=([^;]+)/i)[1])
    end

    get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    names.each { |name| assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}=" }
    assert_equal Time.at(claims.fetch("exp")).utc, preference.reload.last_issued_expires_at
  end

  test "a com JWT does not supply the app or org theme" do
    token = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: @host, preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: "foreign-com-preference",
                                                     jti: JitSecurityJwtJtiGenerator.generate,
    )

    [[ENV.fetch("PUBLIC_BASE_SERVICE_URL"), base_app_api_v0_preferences_theme_path],
     [ENV.fetch("PUBLIC_BASE_STAFF_URL"), base_org_api_v0_preferences_theme_path],].each do |host, path|
      host! host
      cookies[PreferenceCookieName.anonymous_jwt] = token
      get path, headers: { "Accept" => "application/json" }

      assert_response :ok
      assert_equal "sy", response.parsed_body.fetch("theme")
    end
  end

  private

  def browser_write_headers
    {
      "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin",
    }
  end

  # The com write entry is a same-origin POST form, so the token rides the params like a browser
  # form would; the cross-site boundary tests own the refusal paths.
  def csrf_write_headers
    get(edit_base_com_preference_cookie_path(ri: "jp"))
    token = response.parsed_body.at_css('meta[name="csrf-token"]')&.attr("content") || ""

    { "X-CSRF-Token" => token }
  end

  def response_cookies
    @response_cookies ||= extract_cookies_from_response
  end

  def response_set_cookie_names
    response_cookies.keys
  end

  def extract_cookies_from_response
    raw = response.headers["Set-Cookie"] || ""
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line|
      begin
        line.to_s.split("(?<!Expires=\w{3}), (?=[a-zA-Z_])")
      rescue StandardError
        [line]
      end
    }.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = Rack::Utils.unescape(value.to_s) if name.present?
    end
  end
end
