# typed: false
# frozen_string_literal: true

require "test_helper"

class AnonymousComWebPushApiTest < ActionDispatch::IntegrationTest
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
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! @host
    https!
  end

  test "a save binds web push to the browser and reads never extend it" do
    patch base_com_api_v0_preferences_web_push_path,
          params: { web_push: "enabled" }.to_json,
          headers: { "Accept" => "application/json",
                     "Content-Type" => "application/json",
                     "Origin" => "https://#{@host}",
                     "Sec-Fetch-Site" => "same-origin", }

    assert_response :ok
    assert_equal "enabled", response.parsed_body.fetch("web_push")
    binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]

    assert_predicate binding, :present?
    payload = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: @host)
    binding_header =
      Array(response.headers["Set-Cookie"]).flat_map { |line| line.split("\n") }
        .find { |line| line.start_with?("#{PreferenceBrowserBinding::COOKIE_NAME}=") }

    assert_equal Time.at(payload.fetch("exp")).utc, Time.httpdate(binding_header.match(/expires=([^;]+)/i)[1])
    get base_com_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_equal "enabled", response.parsed_body.fetch("web_push")
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceBrowserBinding::COOKIE_NAME}="

    cookies[PreferenceBrowserBinding::COOKIE_NAME] = PreferenceBrowserBinding.mint_value
    get base_com_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_equal "disabled", response.parsed_body.fetch("web_push")
    patch base_com_api_v0_preferences_web_push_path,
          params: { web_push: "disabled" }.to_json,
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" }

    assert_response :forbidden
    patch base_com_api_v0_preferences_cookie_path,
          params: { consented: true }.to_json,
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" }

    assert_response :forbidden
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = binding
    get base_com_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }

    assert_equal "enabled", response.parsed_body.fetch("web_push")
    cookies.delete(PreferenceBrowserBinding::COOKIE_NAME)
    get base_com_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_equal "disabled", response.parsed_body.fetch("web_push")
    snapshots = []
    capture = ->(*) { snapshots << Actor.preferences }
    ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
      get base_com_root_path(ri: "jp")
    end

    assert_response :success
    assert_not_empty snapshots
    assert snapshots.all? { |snapshot| snapshot.web_push == "disabled" }
  end

  test "the Base API does not mirror bound browser state into the request actor" do
    patch base_com_api_v0_preferences_web_push_path,
          params: { web_push: "enabled" }.to_json,
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" }

    assert_response :ok
    snapshots = []
    capture =
      lambda do |_name, _start, _finish, _id, payload|
        snapshots << Actor.preferences if payload[:sql].to_s.match?(/com_preference_web_pushes/i)
      end
    ActiveSupport::Notifications.subscribed(capture, "sql.active_record") do
      get base_com_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }
    end

    assert_response :ok
    assert_equal "enabled", response.parsed_body.fetch("web_push")
    assert_not_empty snapshots
    assert snapshots.all? { |snapshot| snapshot.web_push == "disabled" }
    assert snapshots.all? { |snapshot| !snapshot.cookie.consented? }
  end

  test "a write without a CSRF token is rejected" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    assert_no_difference -> { ComPreference.count } do
      patch(
        base_com_api_v0_preferences_web_push_path,
        params: { web_push: "enabled" }.to_json,
        headers: { "Accept" => "application/json", "Content-Type" => "application/json" },
      )
    end

    assert_response :forbidden
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "a same-origin write with a session CSRF token succeeds" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get(edit_base_com_preference_cookie_path(ri: "jp"))
    token = response.parsed_body.at_css('meta[name="csrf-token"]').attr("content")

    patch(
      base_com_api_v0_preferences_web_push_path,
      params: { web_push: "enabled" }.to_json,
      headers: { "Accept" => "application/json",
                 "Content-Type" => "application/json",
                 "Origin" => "https://#{@host}",
                 "Sec-Fetch-Site" => "same-origin",
                 "X-CSRF-Token" => token, },
    )

    assert_response :ok
    assert_equal "enabled", response.parsed_body.fetch("web_push")
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "a retired row cannot supply enabled web push even with a matching binding" do
    [ComPreferenceStatus,
     ComPreferenceWebPushOption,].each(&:ensure_defaults!)
    binding = PreferenceBrowserBinding.mint_value
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      status_id: ComPreferenceStatus::RETIRED,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    ComPreferenceCookie.create!(
      preference: preference,
    )
    ComPreferenceBrowserBinding.create!(preference: preference, digest: PreferenceBrowserBinding.digest_for(binding))
    ComPreferenceWebPush.create!(preference: preference, option_id: ComPreferenceWebPushOption::ENABLED)
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "system" }), host: @host, preference_type: "ComPreference",
                                                       issued_at: Time.current,
                                                       public_id: preference.public_id, jti: preference.jti,
    )
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = binding

    assert_no_difference -> { ComPreferenceWebPush.count } do
      get base_com_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }
    end

    assert_response :ok
    assert_equal "disabled", response.parsed_body.fetch("web_push")
    snapshots = []
    capture = ->(*) { snapshots << Actor.preferences }
    ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
      get base_com_root_path(ri: "jp")
    end

    assert_response :success
    assert_not_empty snapshots
    assert snapshots.all? { |snapshot| snapshot.web_push == "disabled" }
  end

  test "web push reads its binding even when the consent child is absent" do
    [ComPreferenceStatus,
     ComPreferenceWebPushOption,].each(&:ensure_defaults!)
    binding = PreferenceBrowserBinding.mint_value
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    ComPreferenceBrowserBinding.create!(preference: preference, digest: PreferenceBrowserBinding.digest_for(binding))
    ComPreferenceWebPush.create!(preference: preference, option_id: ComPreferenceWebPushOption::ENABLED)
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "system" }), host: @host, preference_type: "ComPreference",
                                                       issued_at: Time.current,
                                                       public_id: preference.public_id, jti: preference.jti,
    )
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = binding

    get base_com_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_equal "enabled", response.parsed_body.fetch("web_push")
    assert_not ComPreferenceCookie.exists?(preference_id: preference.id)

    cookies[PreferenceIoKeys::Cookies::LANGUAGE] = DISPLAY_SNAPSHOT.fetch("language")
    cookies[PreferenceCookieName.anonymous_experience] = DISPLAY_SNAPSHOT.except("language").to_json
    snapshots = []
    capture = ->(*) { snapshots << Actor.preferences }
    ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
      get base_com_root_path(ri: "jp")
    end

    assert_response :success
    assert snapshots.any? { |snapshot| snapshot.web_push == "enabled" }
    assert snapshots.none? { |snapshot| snapshot.cookie.consented? }
    assert_not ComPreferenceCookie.exists?(preference_id: preference.id)

    token = cookies[PreferenceCookieName.anonymous_jwt]
    reset!
    host! @host
    https!
    cookies[PreferenceCookieName.anonymous_jwt] = token
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = PreferenceBrowserBinding.mint_value
    cookies[PreferenceIoKeys::Cookies::LANGUAGE] = DISPLAY_SNAPSHOT.fetch("language")
    cookies[PreferenceCookieName.anonymous_experience] = DISPLAY_SNAPSHOT.except("language").to_json
    snapshots.clear
    ActiveSupport::Notifications.subscribed(capture, "render_template.action_view") do
      get base_com_root_path(ri: "jp")
    end

    assert_response :success
    assert_not_empty snapshots
    assert snapshots.all? { |snapshot| snapshot.web_push == "disabled" }
  end

  test "bound reads stop at the JWT expiry measured by the database clock" do
    [ComPreferenceStatus,
     ComPreferenceWebPushOption,].each(&:ensure_defaults!)
    now = ComPreference.database_now
    binding = PreferenceBrowserBinding.mint_value
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    ComPreferenceCookie.create!(preference: preference, consented: true)
    ComPreferenceConsentReceipt.create!(preference: preference, version: SecureRandom.uuid, recorded_at: now)
    ComPreferenceBrowserBinding.create!(preference: preference, digest: PreferenceBrowserBinding.digest_for(binding))
    ComPreferenceWebPush.create!(preference: preference, option_id: ComPreferenceWebPushOption::ENABLED)
    token = PreferenceToken.encode(
      DISPLAY_SNAPSHOT, host: @host, preference_type: "ComPreference",
                        issued_at: Time.current,
                        public_id: preference.public_id, jti: preference.jti,
    )
    cookies[PreferenceCookieName.anonymous_jwt] = token
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = binding
    claims, = JWT.decode(token, nil, false)
    expiry = Time.at(claims.fetch("exp")).utc

    [[expiry - 1.second, "enabled", false], [expiry, "disabled", true],
     [expiry + 1.second, "disabled", true],].each do |database_time, expected_push, expected_banner|
      ComPreference.stub(:database_now, database_time) do
        get base_com_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }

        assert_response :ok
        assert_equal expected_push, response.parsed_body.fetch("web_push")
        get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

        assert_response :ok
        assert_equal expected_banner, response.parsed_body.fetch("show_banner")
      end
    end
  end

  test "consent and web push read row expiry against the database clock" do
    [ComPreferenceStatus,
     ComPreferenceWebPushOption,].each(&:ensure_defaults!)
    now = ComPreference.database_now
    binding = PreferenceBrowserBinding.mint_value
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: now + 10.minutes,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    ComPreferenceCookie.create!(
      preference: preference, consented: true,
    )
    ComPreferenceConsentReceipt.create!(preference: preference, version: SecureRandom.uuid, recorded_at: now)
    ComPreferenceBrowserBinding.create!(preference: preference, digest: PreferenceBrowserBinding.digest_for(binding))
    ComPreferenceWebPush.create!(preference: preference, option_id: ComPreferenceWebPushOption::ENABLED)
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "system" }), host: @host, preference_type: "ComPreference",
                                                       issued_at: Time.current,
                                                       public_id: preference.public_id, jti: preference.jti,
    )
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = binding

    travel_to(now + 1.hour) do
      get base_com_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }

      assert_response :ok
      assert_equal "enabled", response.parsed_body.fetch("web_push")
      get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

      assert_response :ok
      assert_not response.parsed_body.fetch("show_banner")
    end
  end

  test "database failure reads no consent and disables web push without clearing browser cookies" do
    patch base_com_api_v0_preferences_web_push_path,
          params: { web_push: "enabled" }.to_json,
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" }

    assert_response :ok
    token = cookies[PreferenceCookieName.anonymous_jwt]
    binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    failure = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "database unavailable" }

    ComPreference.stub(:database_now, failure) do
      get base_com_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }

      assert_response :ok
      assert_equal "disabled", response.parsed_body.fetch("web_push")
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceBrowserBinding::COOKIE_NAME}="
      get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

      assert_response :ok
      assert response.parsed_body.fetch("show_banner")
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceBrowserBinding::COOKIE_NAME}="
    end

    assert_equal token, cookies[PreferenceCookieName.anonymous_jwt]
    assert_equal binding, cookies[PreferenceBrowserBinding::COOKIE_NAME]
  end

  test "bound consent and web push expire at the exact database-time boundary" do
    [ComPreferenceStatus,
     ComPreferenceWebPushOption,].each(&:ensure_defaults!)
    now = ComPreference.database_now
    binding = PreferenceBrowserBinding.mint_value
    preference = ComPreference.create!(
      last_issued_at: Time.current,
      last_issued_expires_at: now + 10.minutes,
      jti: JitSecurityJwtJtiGenerator.generate,
    )
    cookie = ComPreferenceCookie.create!(
      preference: preference, consented: true,
    )
    ComPreferenceConsentReceipt.create!(preference: preference, version: SecureRandom.uuid, recorded_at: now)
    ComPreferenceBrowserBinding.create!(preference: preference, digest: PreferenceBrowserBinding.digest_for(binding))
    push = ComPreferenceWebPush.create!(preference: preference, option_id: ComPreferenceWebPushOption::ENABLED)
    cookies[PreferenceCookieName.anonymous_jwt] = PreferenceToken.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "system" }), host: @host, preference_type: "ComPreference",
                                                       issued_at: Time.current,
                                                       public_id: preference.public_id, jti: preference.jti,
    )
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = binding
    expiry = preference.reload.last_issued_expires_at

    [[expiry - Rational(1, 1_000_000), "enabled", false], [expiry, "disabled", true],
     [expiry + Rational(1, 1_000_000), "disabled", true],].each do |database_time, expected_push, expected_banner|
      ComPreference.stub(:database_now, database_time) do
        get base_com_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }

        assert_response :ok
        assert_equal expected_push, response.parsed_body.fetch("web_push")
        get base_com_api_v0_preferences_cookie_path, headers: { "Accept" => "application/json" }

        assert_response :ok
        assert_equal expected_banner, response.parsed_body.fetch("show_banner")
        assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceBrowserBinding::COOKIE_NAME}="
      end
    end

    assert cookie.reload.consented
    assert_equal ComPreferenceWebPushOption::ENABLED, push.reload.option_id
  end

  test "an unsupported option is rejected without creating a preference" do
    assert_no_difference -> { ComPreference.count } do
      patch base_com_api_v0_preferences_web_push_path,
            params: { web_push: "unknown" }.to_json,
            headers: { "Accept" => "application/json",
                       "Content-Type" => "application/json",
                       "Origin" => "https://#{@host}",
                       "Sec-Fetch-Site" => "same-origin", }
    end

    assert_response :unprocessable_content
  end

  test "an invalid stored display option rolls back web push and issues no cookies" do
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch base_com_api_v0_preferences_web_push_path, params: { web_push: "disabled" }.to_json, headers: headers

    assert_response :ok
    payload = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: @host)
    preference = ComPreference.find_by!(public_id: payload.fetch("sub"))
    generation = preference.jti
    binding = ComPreferenceBrowserBinding.find_by!(preference_id: preference.id).digest
    unknown_option = ComPreferenceTimezoneOption.create!(id: 2_147_483_647)
    ComPreferenceTimezone.find_by!(preference_id: preference.id).update!(option: unknown_option)

    assert_no_difference -> { ComPreference.count } do
      patch base_com_api_v0_preferences_web_push_path, params: { web_push: "enabled" }.to_json, headers: headers
    end

    assert_response :service_unavailable
    assert_equal ComPreferenceWebPushOption::DISABLED,
                 ComPreferenceWebPush.find_by!(preference_id: preference.id).option_id
    assert_equal generation, preference.reload.jti
    assert_equal binding, ComPreferenceBrowserBinding.find_by!(preference_id: preference.id).digest
    [PreferenceCookieName.anonymous_jwt, PreferenceCookieName.anonymous_experience,
     PreferenceIoKeys::Cookies::LANGUAGE, PreferenceBrowserBinding::COOKIE_NAME,].each do |name|
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{name}="
    end
  end

  test "a browser can bind a new preference without changing the old preference" do
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    patch base_com_api_v0_preferences_web_push_path, params: { web_push: "enabled" }.to_json, headers: headers

    assert_response :ok
    binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    token = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: @host)
    preference = ComPreference.find_by!(public_id: token.fetch("sub"))
    generation = preference.jti
    cookies.delete(PreferenceCookieName.anonymous_jwt)

    assert_difference -> { ComPreference.count }, 1 do
      patch base_com_api_v0_preferences_web_push_path, params: { web_push: "disabled" }.to_json, headers: headers
    end

    assert_response :ok
    assert_equal generation, preference.reload.jti
    assert_equal ComPreferenceWebPushOption::ENABLED,
                 ComPreferenceWebPush.find_by!(preference_id: preference.id).option_id
    assert_equal binding, cookies[PreferenceBrowserBinding::COOKIE_NAME]
    new_payload = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: @host)
    replacement = ComPreference.find_by!(public_id: new_payload.fetch("sub"))

    assert_not_equal preference.id, replacement.id
    assert_equal PreferenceBrowserBinding.digest_for(binding),
                 ComPreferenceBrowserBinding.find_by!(preference_id: replacement.id).digest
    assert_equal ComPreferenceWebPushOption::DISABLED,
                 ComPreferenceWebPush.find_by!(preference_id: replacement.id).option_id
  end
end
