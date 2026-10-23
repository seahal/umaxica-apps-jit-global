# typed: false
# frozen_string_literal: true

require "test_helper"

class ActorContextTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    Actor.reset
  end

  teardown do
    Actor.reset
  end

  test "defaults for unauthenticated state" do
    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_equal Actor::Preference::NULL, Actor.preferences
    assert_predicate Actor, :unauthenticated?
    assert_not Actor.authenticated?
    assert_not Actor.signed_in?
    assert_not Actor.signed_up?
    assert_nil Actor.client
    assert_nil Actor.operator
    assert_nil Actor.visitor
    assert_equal Actor::Authentication::NULL, Actor.authn
    assert_equal Actor::Configuration::NULL, Actor.configuration
  end

  test "setting client actor" do
    user = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 123)
    Actor.actor = user
    Actor.actor_type = :client

    assert_equal user, Actor.actor
    assert_equal :client, Actor.actor_type
    assert_predicate Actor, :client?
    assert_predicate Actor, :authenticated?
    assert_predicate Actor, :signed_in?
    assert_predicate Actor, :signed_up?
    assert_equal user, Actor.client
    assert_not Actor.unauthenticated?
  end

  test "signed_up is false for authenticated actor without persisted identity" do
    Actor.actor = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)
    Actor.actor_type = :client

    assert_predicate Actor, :signed_in?
    assert_not Actor.signed_up?
  end

  test "authentication null object is safe for guests" do
    assert_predicate Actor.authn, :null?
    assert_nil Actor.authn.login_public_id
    assert_equal [], Actor.authn.amr
    assert_not Actor.authn.verified?
  end

  test "configuration null object is safe for guests" do
    assert_predicate Actor.configuration, :null?
    assert_predicate Actor.configuration.anything, :blank?
    assert_not Actor.configuration.anything.enabled?
    assert_equal "", Actor.configuration.anything.deeply.nested.to_s
  end

  test "configuration is an immutable request context box" do
    configuration = Actor::Configuration.new(feature: true)

    assert configuration.feature
    assert_equal({ feature: true }, configuration.to_h)
    assert_predicate configuration, :frozen?

    updated = configuration.with(region: "jp")

    assert_equal({ feature: true }, configuration.to_h)
    assert_equal({ feature: true, region: "jp" }, updated.to_h)
    assert_not_same configuration, updated
  end

  test "configuration supports typed sign namespace values" do
    sign_configuration =
      Actor::SignConfiguration.new(
        value: "required",
        enabled: true,
        mode: "strict",
      )

    Actor.configuration = Actor::Configuration.new(sign: sign_configuration)

    assert_equal "required", Actor.configuration.sign.value
    assert Actor.configuration.sign.enabled
    assert_equal "strict", Actor.configuration.sign.mode
  end

  test "setting staff actor" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 456)
    Actor.actor = staff
    Actor.actor_type = :operator

    assert_equal staff, Actor.actor
    assert_equal :operator, Actor.actor_type
    assert_predicate Actor, :operator?
    assert_predicate Actor, :authenticated?
    assert_equal staff, Actor.operator
  end

  test "setting visitor actor" do
    visitor = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 789)
    Actor.actor = visitor
    Actor.actor_type = :visitor

    assert_equal visitor, Actor.actor
    assert_equal :visitor, Actor.actor_type
    assert_predicate Actor, :visitor?
    assert_predicate Actor, :authenticated?
    assert_equal visitor, Actor.visitor
  end

  test "resets preference to NULL" do
    Actor.install_context!(preferences: Actor::Preference.new(language: "en"))

    assert_equal "en", Actor.preferences.language

    Actor.reset

    assert_equal Actor::Preference::NULL, Actor.preferences
  end

  test "preference null object behavior" do
    pref = Actor::Preference::NULL

    assert_predicate pref, :null?
    assert_equal :ja, pref.locale
    assert_equal "Asia/Tokyo", pref.time_zone.name
    assert_predicate pref, :system_theme?
    assert_not pref.dark_mode?
  end

  test "preference from jwt" do
    claim = {
      "lx" => "en",
      "ri" => "us",
      "tz" => "UTC",
      "ct" => "dr",
      "cu" => "usd",
      "df" => "mdy",
      "tf" => "hour_12",
      "mo" => "reduced",
      "dn" => "compact",
      "ps" => "50",
    }
    pref = Actor::Preference.from_jwt(claim)

    assert_equal "en", pref.language
    assert_equal :en, pref.locale
    assert_equal "us", pref.region
    assert_equal "UTC", pref.time_zone.name
    assert_equal "usd", pref.currency
    assert_equal "mdy", pref.date_format
    assert_equal "hour_12", pref.time_format
    assert_equal "reduced", pref.motion
    assert_equal "compact", pref.density
    assert_equal "50", pref.page_size
    assert_predicate pref, :dark_mode?
    assert_not pref.null?
  end

  test "preference handles custom locale and cookie object values" do
    cookie_source = Struct.new(:consented, :functional, :performant, :targetable, :consent_version, :consented_at)
      .new(true, true, true, false, "2.0", Time.current)
    pref = Actor::Preference.new(language: "fr").with_cookie(cookie_source)

    assert_equal :fr, pref.locale
    assert_predicate pref.cookie, :consented?
    assert_predicate pref.cookie, :functional?
    assert_predicate pref.cookie, :performant?
    assert_not pref.cookie.targetable?
  end

  test "preference blank cookie object becomes null cookie" do
    pref = Actor::Preference.new.with_cookie(nil)

    assert_equal Actor::Preference::NULL_COOKIE, pref.cookie
  end

  test "preference theme predicates" do
    assert_predicate Actor::Preference.new(theme: "dr"), :dark_mode?
    assert_predicate Actor::Preference.new(theme: "li"), :light_mode?
    assert_predicate Actor::Preference.new(theme: "sy"), :system_theme?
  end

  test "preference to_h" do
    pref = Actor::Preference.new(language: "en", theme: "dr", motion: "reduced")
    hash = pref.to_h

    assert_equal "en", hash[:language]
    assert_equal "dr", hash[:theme]
    assert_equal "reduced", hash[:motion]
    assert_not hash[:consented]
  end

  test "cookie consent define" do
    cookie = Actor::Preference::Cookie.new(
      consented: true, functional: true, performant: false, targetable: false,
      consent_version: "1.0", consented_at: Time.current,
    )

    assert_predicate cookie, :consented?
    assert_predicate cookie, :functional?
    assert_not cookie.performant?
    assert_not cookie.targetable?
  end
end
