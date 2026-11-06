# typed: false
# frozen_string_literal: true

require "test_helper"

class AnonymousComPreferenceResponseBindingTest < ActionDispatch::IntegrationTest
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

  test "a theme write does not disclose unbound consent categories" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    [ComPreferenceStatus,
     ComPreferenceThemeOption,].each(&:ensure_defaults!)
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    cookie = ComPreferenceCookie.create!(preference: preference, consented: false, functional: true)
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "system" }), host: host, preference_type: "ComPreference",
                                                       issued_at: Time.current,
                                                       public_id: preference.public_id, jti: preference.jti,
    )

    patch base_com_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: "dark" } },
          headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_not response.parsed_body.fetch("preference").fetch("functional")
    assert cookie.reload.functional
  end

  test "a theme write returns consent categories for the matching browser" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    [ComPreferenceStatus,
     ComPreferenceThemeOption,].each(&:ensure_defaults!)
    binding = PreferenceBrowserBinding.mint_value
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    ComPreferenceCookie.create!(
      preference: preference, functional: true,
    )
    ComPreferenceConsentReceipt.create!(preference: preference, version: SecureRandom.uuid, recorded_at: Time.current)
    ComPreferenceBrowserBinding.create!(preference: preference, digest: PreferenceBrowserBinding.digest_for(binding))
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = binding
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "system" }), host: host, preference_type: "ComPreference",
                                                       issued_at: Time.current,
                                                       public_id: preference.public_id, jti: preference.jti,
    )

    patch base_com_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: "dark" } },
          headers: { "Accept" => "application/json" }

    assert_response :ok
    assert response.parsed_body.fetch("preference").fetch("functional")
  end

  test "a theme response does not disclose consent if the preference expires after the write" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    [ComPreferenceStatus,
     ComPreferenceThemeOption,].each(&:ensure_defaults!)
    now = ComPreference.database_now
    binding = PreferenceBrowserBinding.mint_value
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    cookie = ComPreferenceCookie.create!(
      preference: preference, functional: true,
    )
    ComPreferenceBrowserBinding.create!(preference: preference, digest: PreferenceBrowserBinding.digest_for(binding))
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = binding
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "system" }), host: host, preference_type: "ComPreference",
                                                       issued_at: Time.current,
                                                       public_id: preference.public_id, jti: preference.jti,
    )
    expiry = Time.at(now.to_i + SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_TTL.to_i).utc
    calls = 0
    clock =
      lambda do
        calls += 1
        (calls == 1) ? now : expiry
      end

    ComPreference.stub(:database_now, clock) do
      patch base_com_preference_theme_path(ri: "jp"),
            params: { preference_theme: { option_id: "dark" } },
            headers: { "Accept" => "application/json" }
    end

    assert_response :ok
    assert_operator calls, :>=, 2
    assert_not response.parsed_body.fetch("preference").fetch("functional")
    assert cookie.reload.functional
  end

  test "a response read failure reports an error after the preference write has committed" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    https!
    [ComPreferenceStatus,
     ComPreferenceThemeOption,].each(&:ensure_defaults!)
    now = ComPreference.database_now
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    generation = preference.jti
    old_token = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "system" }), host: host, preference_type: "ComPreference",
                                                       issued_at: Time.current,
                                                       public_id: preference.public_id, jti: generation,
    )
    cookies[PreferenceCookieName.anonymous_jwt] = old_token
    calls = 0
    clock =
      lambda do
        calls += 1
        raise ActiveRecord::ConnectionNotEstablished, "database unavailable" if calls > 1

        now
      end

    ComPreference.stub(:database_now, clock) do
      patch base_com_preference_theme_path(ri: "jp"),
            params: { preference_theme: { option_id: "dark" } },
            headers: { "Accept" => "application/json" }
    end

    assert_response :service_unavailable
    assert_operator calls, :>=, 2
    assert_not_equal generation, preference.reload.jti
    assert_equal ComPreferenceThemeOption::DARK, ComPreferenceTheme.find_by!(preference_id: preference.id).option_id
    assert_empty response.body

    committed = preference.attributes
    reset!
    host! host
    https!
    cookies[PreferenceCookieName.anonymous_jwt] = old_token
    assert_difference -> { ComPreference.count }, 1 do
      patch base_com_api_v0_preferences_theme_path,
            params: { theme: "light" }.to_json,
            headers: { "Accept" => "application/json", "Content-Type" => "application/json" }
    end

    assert_response :ok
    claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: host)
    replacement = ComPreference.find_by!(public_id: claims.fetch("sub"))

    assert_not_equal preference.id, replacement.id
    assert_equal committed, preference.reload.attributes
    assert_equal ComPreferenceThemeOption::DARK, ComPreferenceTheme.find_by!(preference_id: preference.id).option_id
    assert_equal "light", claims.fetch("preferences").fetch("theme")
    assert_not ComPreferenceCookie.find_by!(preference_id: replacement.id).consented
    assert_not ComPreferenceBrowserBinding.exists?(preference_id: replacement.id)
    assert_equal ComPreferenceWebPushOption::DISABLED,
                 ComPreferenceWebPush.find_by!(preference_id: replacement.id).option_id
  end
end
