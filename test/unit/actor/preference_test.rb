# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Actor::PreferenceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "NULL returns safe defaults" do
    pref = Actor::Preference::NULL

    assert_predicate pref, :null?
    assert_equal "ja", pref.language
    assert_equal "jp", pref.region
    assert_equal "Asia/Tokyo", pref.timezone
    assert_equal "sy", pref.theme
    assert_equal "jpy", pref.currency
    assert_equal "iso", pref.date_format
    assert_equal "24", pref.time_format
    assert_equal "standard", pref.motion
    assert_equal "standard", pref.density
    assert_equal "infinity", pref.page_size
    assert_equal :ja, pref.locale
    assert_predicate pref, :system_theme?
    assert_not pref.dark_mode?
    assert_not pref.light_mode?
  end

  test "NULL cookie returns false for all consent flags" do
    cookie = Actor::Preference::NULL.cookie

    assert_not cookie.consented?
    assert_not cookie.functional?
    assert_not cookie.performant?
    assert_not cookie.targetable?
    assert_nil cookie.consent_version
    assert_nil cookie.consented_at
  end

  test "custom preference overrides defaults" do
    pref = Actor::Preference.new(
      language: "en",
      region: "us",
      timezone: "America/New_York",
      theme: "dr",
      currency: "usd",
      date_format: "mdy",
      time_format: "12",
      motion: "reduced",
      density: "compact",
      page_size: "50",
    )

    assert_not pref.null?
    assert_equal "en", pref.language
    assert_equal "us", pref.region
    assert_equal "America/New_York", pref.timezone
    assert_equal "usd", pref.currency
    assert_equal "mdy", pref.date_format
    assert_equal "12", pref.time_format
    assert_equal "reduced", pref.motion
    assert_equal "compact", pref.density
    assert_equal "50", pref.page_size
    assert_equal :en, pref.locale
    assert_predicate pref, :dark_mode?
    assert_not pref.system_theme?
  end

  test "preference with cookie consent" do
    cookie = Actor::Preference::Cookie.new(
      consented: true,
      functional: true,
      performant: false,
      targetable: false,
      consent_version: "v1",
      consented_at: Time.zone.parse("2026-01-01"),
    )
    pref = Actor::Preference.new(cookie: cookie)

    assert_predicate pref.cookie, :consented?
    assert_predicate pref.cookie, :functional?
    assert_not pref.cookie.performant?
    assert_equal "v1", pref.cookie.consent_version
  end

  test "preference is frozen" do
    pref = Actor::Preference.new

    assert_predicate pref, :frozen?
  end

  test "preference does not expose a public id" do
    pref = Actor::Preference.new

    assert_not_respond_to pref, :public_id
  end

  test "time_zone returns ActiveSupport::TimeZone" do
    pref = Actor::Preference.new(timezone: "America/New_York")

    assert_instance_of ActiveSupport::TimeZone, pref.time_zone
    assert_equal "America/New_York", pref.time_zone.name
  end

  test "time_zone falls back to Asia/Tokyo for unknown zone" do
    pref = Actor::Preference.new(timezone: "Invalid/Zone")

    assert_equal "Asia/Tokyo", pref.time_zone.name
  end

  test "to_h returns preference summary" do
    pref = Actor::Preference.new(language: "en", theme: "li")

    h = pref.to_h

    assert_equal "en", h[:language]
    assert_equal "li", h[:theme]
    assert_equal "jpy", h[:currency]
    assert_equal "iso", h[:date_format]
    assert_equal "24", h[:time_format]
    assert_equal "standard", h[:motion]
    assert_equal "standard", h[:density]
    assert_equal "infinity", h[:page_size]
    assert_not h[:consented]
  end

  test "Actor.preferences returns NULL by default" do
    Actor.reset

    assert_equal Actor::Preference::NULL, Actor.preferences
    assert_predicate Actor.preferences, :null?
  end

  test "Actor.preferences can be assigned" do
    Actor.reset
    custom = Actor::Preference.new(language: "en")
    Actor.install_context!(preferences: custom)

    assert_equal "en", Actor.preferences.language
    assert_not Actor.preferences.null?
  ensure
    Actor.reset
  end

  test "from_jwt returns NULL for nil input" do
    assert_equal Actor::Preference::NULL, Actor::Preference.from_jwt(nil)
  end

  test "from_jwt returns NULL for non-hash input" do
    assert_equal Actor::Preference::NULL, Actor::Preference.from_jwt("string")
    assert_equal Actor::Preference::NULL, Actor::Preference.from_jwt(123)
    assert_equal Actor::Preference::NULL, Actor::Preference.from_jwt([])
  end

  test "from_jwt constructs correct Preference from valid prf hash" do
    prf = {
      "ver" => Actor::Preference::SCHEMA_VERSION,
      "lx" => "en",
      "ri" => "us",
      "tz" => "America/New_York",
      "ct" => "dr",
      "cu" => "usd",
      "df" => "mdy",
      "tf" => "12",
      "mo" => "reduced",
      "dn" => "compact",
      "ps" => "infinity",
    }
    pref = Actor::Preference.from_jwt(prf)

    assert_not pref.null?
    assert_equal "en", pref.language
    assert_equal "us", pref.region
    assert_equal "America/New_York", pref.timezone
    assert_equal "dr", pref.theme
    assert_equal "usd", pref.currency
    assert_equal "mdy", pref.date_format
    assert_equal "12", pref.time_format
    assert_equal "reduced", pref.motion
    assert_equal "compact", pref.density
    assert_equal "infinity", pref.page_size
  end

  test "from_jwt accepts preference snapshot without version" do
    pref = Actor::Preference.from_jwt({ "lx" => "en", "ri" => "us" })

    assert_not pref.null?
    assert_equal "en", pref.language
    assert_equal "us", pref.region
  end

  test "from_jwt accepts long extended preference keys" do
    prf = {
      "currency" => "eur",
      "date_format" => "dmy",
      "time_format" => "hour_24",
      "motion" => "none",
      "density" => "comfortable",
      "page_size" => "100",
    }
    pref = Actor::Preference.from_jwt(prf)

    assert_equal "eur", pref.currency
    assert_equal "dmy", pref.date_format
    assert_equal "hour_24", pref.time_format
    assert_equal "none", pref.motion
    assert_equal "comfortable", pref.density
    assert_equal "100", pref.page_size
  end

  test "from_jwt ignores removed r18s payload key" do
    pref = Actor::Preference.from_jwt({ "lx" => "en", "r18s" => "deny" })

    assert_equal "en", pref.language
    assert_not_respond_to pref, :adult_content_gate
  end

  test "from_jwt falls back to DEFAULTS for missing keys" do
    prf = { "lx" => "en" } # Only language provided
    pref = Actor::Preference.from_jwt(prf)

    assert_equal "en", pref.language
    assert_equal "jp", pref.region # DEFAULTS[:region]
    assert_equal "Asia/Tokyo", pref.timezone # DEFAULTS[:timezone]
    assert_equal "sy", pref.theme # DEFAULTS[:theme]
    assert_equal "jpy", pref.currency
    assert_equal "standard", pref.motion
  end

  test "from_jwt handles empty hash" do
    pref = Actor::Preference.from_jwt({})

    assert_equal "ja", pref.language
    assert_equal "jp", pref.region
    assert_equal "Asia/Tokyo", pref.timezone
    assert_equal "sy", pref.theme
    assert_equal "jpy", pref.currency
    assert_equal "infinity", pref.page_size
  end

  test "from_jwt with cookie parameter" do
    cookie = Actor::Preference::Cookie.new(
      consented: true,
      functional: true,
      performant: false,
      targetable: false,
      consent_version: "v1",
      consented_at: Time.zone.parse("2026-01-01"),
    )
    prf = { "lx" => "en" }
    pref = Actor::Preference.from_jwt(prf, cookie: cookie)

    assert_predicate pref.cookie, :consented?
    assert_predicate pref.cookie, :functional?
  end

  test "hash is consistent for equal preferences" do
    pref1 = Actor::Preference.new(language: "en", region: "us")
    pref2 = Actor::Preference.new(language: "en", region: "us")

    assert_equal pref1.hash, pref2.hash
    assert_equal 1, Set[pref1, pref2].size
  end

  test "hash differs for different preferences" do
    pref1 = Actor::Preference.new(language: "en", region: "us")
    pref2 = Actor::Preference.new(language: "ja", region: "jp")

    assert_not_equal pref1.hash, pref2.hash
  end

  test "with_cookie keeps preference values and updates cookie state" do
    pref = Actor::Preference.new(
      language: "en",
      region: "us",
      timezone: "America/New_York",
      theme: "dr",
      currency: "usd",
      motion: "reduced",
    )

    updated = pref.with_cookie(
      consented: true,
      functional: true,
      performant: false,
      targetable: true,
      consent_version: "v2",
    )

    assert_equal "en", updated.language
    assert_equal "us", updated.region
    assert_equal "America/New_York", updated.timezone
    assert_equal "dr", updated.theme
    assert_equal "usd", updated.currency
    assert_equal "reduced", updated.motion
    assert_predicate updated.cookie, :consented?
    assert_predicate updated.cookie, :functional?
    assert_not updated.cookie.performant?
    assert_predicate updated.cookie, :targetable?
    assert_equal "v2", updated.cookie.consent_version
  end

  test "browser state is explicit and survives cookie replacement" do
    original = Actor::Preference.new
    enabled = original.with_browser_state(cookie: Actor::Preference::NULL_COOKIE, web_push: "enabled")

    assert_equal "disabled", original.web_push
    assert_equal "enabled", enabled.with_cookie(Actor::Preference::NULL_COOKIE).web_push
    assert_not_equal original, enabled
    assert_raises(ArgumentError) { Actor::Preference.new(web_push: "unknown") }
  end
end
