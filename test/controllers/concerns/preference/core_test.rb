# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceCoreHarness < ApplicationController
  class << self
    def before_action(*) = nil
  end

  include PreferenceCore

  attr_accessor :params_hash, :session_hash, :render_args, :written_cookies

  def initialize
    super
    @params_hash = {}
    @session_hash = {}
    @written_cookies = []
  end

  def params = ActionController::Parameters.new(params_hash)

  def session = session_hash

  def render(**kwargs) = self.render_args = kwargs

  def preference_prefix = "App"

  def preference_prefix_underscore = "app_preference"

  def preference_class = AppPreference

  def with_preference_connection(*) = yield

  def write_preference_cookie(key, value) = written_cookies << [key, value]

  def issue_access_token_from(*) = nil

  def preference_snapshot_for(*) = {}
end

class PreferenceCoreTest < ActiveSupport::TestCase
  FakeOption = Struct.new(:name)
  FakeAssociation = Struct.new(:option_id, :option)
  FakeCookie = Struct.new(:consented, :functional, :performant, :targetable)

  FakePreference =
    Struct.new(
      :language, :region, :timezone, :theme,
      :currency, :date_format, :time_format, :motion, :density, :page_size,
      :app_preference_language, :app_preference_region, :app_preference_timezone,
      :app_preference_theme, :app_preference_currency, :app_preference_date_format,
      :app_preference_time_format, :app_preference_motion, :app_preference_density,
      :app_preference_page_size, :app_preference_cookie,
      keyword_init: true,
    ) do
      def class = AppPreference

      def blank? = false

      def persisted? = false

      def reload = self

      def association(_)
        Struct.new(:loaded?) {
          define_method(:reload) { true }
        }.new(false)
      end
    end

  FakeAssociatedPreference =
    Struct.new(
      :app_preference_language, :app_preference_region, :app_preference_timezone,
      :app_preference_theme, :app_preference_currency, :app_preference_date_format,
      :app_preference_time_format, :app_preference_motion, :app_preference_density,
      :app_preference_page_size, :app_preference_cookie,
      keyword_init: true,
    ) do
      def class = AppPreference

      def blank? = false
    end

  class FakeWritablePreference
    attr_reader :updates

    def initialize
      @updates = []
    end

    def update!(attrs)
      @updates << attrs
    end
  end

  FakeResource =
    Struct.new(:id, :user_preference, :staff_preference, :visitor_preference) do
      def blank? = false
    end

  setup do
    @controller = PreferenceCoreHarness.new
    @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.app.localhost")
    @controller.response = ActionDispatch::TestResponse.new
  end

  test "preference response payload uses direct preference methods and defaults" do
    cookie = FakeCookie.new(true, false, true, false)
    @controller.instance_variable_set(
      :@preferences,
      FakePreference.new(language: "en", region: "us", timezone: "Etc/UTC", theme: "dr", app_preference_cookie: cookie),
    )

    payload = @controller.send(:preference_response_payload)

    assert_equal "en", payload[:lx]
    assert_equal "us", payload[:ri]
    assert_equal "Etc/UTC", payload[:tz]
    assert_equal "dr", payload[:ct]
    assert payload[:consented]
    assert payload[:performant]
    assert_not payload[:functional]
    assert_not payload[:targetable]

    @controller.instance_variable_set(:@preferences, nil)
    defaults = @controller.send(:preference_response_payload)

    assert_equal Actor::Preference::DEFAULTS[:language], defaults[:lx]
    assert_not defaults[:consented]
  end

  test "resolved preference snapshot and cookie use associations" do
    preference = FakeAssociatedPreference.new(
      app_preference_language: FakeAssociation.new(nil, FakeOption.new("EN")),
      app_preference_region: FakeAssociation.new(nil, FakeOption.new("US")),
      app_preference_timezone: FakeAssociation.new(nil, FakeOption.new("Etc/UTC")),
      app_preference_theme: FakeAssociation.new(nil, FakeOption.new("dark")),
      app_preference_currency: FakeAssociation.new(nil, FakeOption.new("JPY")),
      app_preference_date_format: FakeAssociation.new(nil, FakeOption.new("iso")),
      app_preference_time_format: FakeAssociation.new(nil, FakeOption.new("24")),
      app_preference_motion: FakeAssociation.new(nil, FakeOption.new("standard")),
      app_preference_density: FakeAssociation.new(nil, FakeOption.new("compact")),
      app_preference_page_size: FakeAssociation.new(nil, FakeOption.new("50")),
      app_preference_cookie: FakeCookie.new(false, true, false, true),
    )

    assert_equal(
      {
        language: "en",
        region: "us",
        timezone: "Etc/UTC",
        theme: "dr",
        currency: "jpy",
        date_format: "iso",
        time_format: "24",
        motion: "standard",
        density: "compact",
        page_size: "50",
      },
      @controller.send(:resolved_preference_snapshot, preference),
    )
    assert_equal(
      { consented: false, functional: true, performant: false, targetable: true },
      @controller.send(:resolved_preference_cookie, preference),
    )
    assert_equal(
      { consented: false, functional: false, performant: false, targetable: false },
      @controller.send(:resolved_preference_cookie, nil),
    )
  end

  test "preference_write_owner_id returns nil when current_resource is not available" do
    assert_nil @controller.send(:preference_write_owner_id)
  end

  test "preference_write_owner_id raises when current_resource resolution fails" do
    @controller.define_singleton_method(:current_resource) do
      raise StandardError, "resource lookup failed"
    end

    error =
      assert_raises(PreferenceBase::ResolutionError) do
        @controller.send(:preference_write_owner_id)
      end

    assert_match "Preference current_resource resolution failed", error.message
    assert_equal "resource lookup failed", error.cause.message
  end

  test "refresh_preference_token_from_db_for_edit_entry raises when current_resource resolution fails" do
    @controller.instance_variable_set(:@preferences, FakePreference.new)
    @controller.define_singleton_method(:copy_preference_values!) { |*| true }
    @controller.define_singleton_method(:current_resource) do
      raise StandardError, "resource lookup failed"
    end

    error =
      assert_raises(PreferenceBase::ResolutionError) do
        @controller.send(:refresh_preference_token_from_db_for_edit_entry!)
      end

    assert_match "Preference current_resource resolution failed", error.message
  end

  test "sync_to_resource_preference raises when current_resource resolution fails" do
    @controller.define_singleton_method(:current_resource) do
      raise StandardError, "resource lookup failed"
    end

    error =
      assert_raises(PreferenceBase::ResolutionError) do
        @controller.send(:sync_to_resource_preference!)
      end

    assert_match "Preference current_resource resolution failed", error.message
  end

  test "sync_to_resource_preference! returns nil when current_resource is unavailable or blank" do
    assert_nil PreferenceCoreHarness.new.send(:sync_to_resource_preference!)

    @controller.define_singleton_method(:current_resource) { nil }

    assert_nil @controller.send(:sync_to_resource_preference!)
  end

  test "sync_to_resource_preference keeps shared preference public_id" do
    Prosopite.pause do
      [1, 2, 3].each { |id| VisitorStatus.find_or_create_by!(id: id) }
      [0, 1, 2, 3].each { |id| VisitorVisibility.find_or_create_by!(id: id) }
    end
    preference = ComPreference.create!(
      status_id: ComPreferenceStatus::NOTHING,
      binding_method_id: ComPreferenceBindingMethod::NOTHING,
      dbsc_status_id: ComPreferenceDbscStatus::NOTHING,
      discarded_at: 20.years.from_now,
      purged_at: 20.years.from_now,
    )
    resource_pref = VisitorPreference.create!(visitor: Visitor.create!)
    @controller.instance_variable_set(:@preferences, preference)
    original_public_id = preference.public_id

    @controller.send(:sync_direct_resource_preference!, resource_pref)

    assert_equal original_public_id, preference.reload.public_id
  end

  test "reset destroy removes app resource preference without duplicate association queries" do
    preference = client_preferences(:one)
    theme_id = preference.user_preference_theme.id

    assert_nothing_raised do
      Prosopite.scan do
        @controller.send(:destroy_resource_preference_for_reset!, preference)
      end
    end

    assert_nil ClientPreference.find_by(id: preference.id)
    assert_nil ClientPreferenceTheme.find_by(id: theme_id)
  end

  test "reset destroy removes org resource preference children" do
    preference = operator_preferences(:one)
    theme_id = preference.staff_preference_theme.id

    @controller.send(:destroy_resource_preference_for_reset!, preference)

    assert_nil OperatorPreference.find_by(id: preference.id)
    assert_nil OperatorPreferenceTheme.find_by(id: theme_id)
  end

  test "reset destroy removes com resource preference children" do
    Prosopite.pause do
      VisitorMfaLevel.ensure_defaults!
      VisitorMfaStatus.ensure_defaults!
      VisitorStatus.ensure_defaults!
      VisitorVisibility.ensure_defaults!
      VisitorPreferenceThemeOption.ensure_defaults!
    end
    preference = VisitorPreference.create!(visitor: Visitor.create!)
    theme = VisitorPreferenceTheme.create!(preference: preference)

    @controller.send(:destroy_resource_preference_for_reset!, preference)

    assert_nil VisitorPreference.find_by(id: preference.id)
    assert_nil VisitorPreferenceTheme.find_by(id: theme.id)
  end

  test "with_dual_write_transaction rolls back both databases when the block raises" do
    token, resource, controller = build_cross_db_dual_write_pair

    error =
      assert_raises(StandardError) do
        controller.send(:with_dual_write_transaction, resource) do
          token.update!(jti: "should-roll-back")
          resource.update!(language: "en")
          raise StandardError, "boom"
        end
      end

    assert_equal "boom", error.message
    assert_nil token.reload.jti, "token (source) write must roll back when the mirror block fails"
    assert_equal "ja", resource.reload.language, "resource (mirror) write must roll back too"
  end

  test "with_dual_write_transaction commits both databases when the block succeeds" do
    token, resource, controller = build_cross_db_dual_write_pair

    controller.send(:with_dual_write_transaction, resource) do
      token.update!(jti: "committed-token")
      resource.update!(language: "en")
    end

    assert_equal "committed-token", token.reload.jti
    assert_equal "en", resource.reload.language
  end

  test "preference_write_resource_preference! returns existing resource preference per surface" \
       "and falls back to creation" do
    user_pref = Object.new
    staff_pref = Object.new
    visitor_pref = Object.new
    resource = FakeResource.new(42, user_pref, staff_pref, visitor_pref)

    @controller.define_singleton_method(:preference_class) { AppPreference }

    assert_same user_pref, @controller.send(:preference_write_resource_preference!, resource)

    org_controller = PreferenceCoreHarness.new
    org_controller.define_singleton_method(:preference_class) { OrgPreference }

    assert_same staff_pref, org_controller.send(:preference_write_resource_preference!, resource)

    com_controller = PreferenceCoreHarness.new
    com_controller.define_singleton_method(:preference_class) { ComPreference }

    assert_same visitor_pref, com_controller.send(:preference_write_resource_preference!, resource)

    created = Object.new
    called = nil
    creator = PreferenceCoreHarness.new
    creator.define_singleton_method(:preference_class) { AppPreference }
    creator.define_singleton_method(:create_resource_preference_for_write!) do |model, fk, resource_id|
      called = [model, fk, resource_id]
      created
    end
    missing = FakeResource.new(7, nil, nil, nil)

    assert_same created, creator.send(:preference_write_resource_preference!, missing)
    assert_equal [ClientPreference, :user_id, 7], called
  end

  test "sync_direct_resource_preference! only writes when there is data to sync" do
    resource_pref = FakeWritablePreference.new

    @controller.define_singleton_method(:resolved_preference_snapshot) { |_pref| {} }
    @controller.define_singleton_method(:resolved_preference_cookie) { |_pref| {} }

    assert_nil @controller.send(:sync_direct_resource_preference!, resource_pref)
    assert_empty resource_pref.updates

    @controller.define_singleton_method(:resolved_preference_snapshot) { |_pref| { language: "en" } }
    @controller.define_singleton_method(:resolved_preference_cookie) { |_pref| { consented: true } }

    @controller.send(:sync_direct_resource_preference!, resource_pref)

    assert_equal [{ language: "en", consented: true }], resource_pref.updates
  end

  test "write_resource_preference_cookie! ignores blank and unsupported attributes" do
    resource_pref = FakeWritablePreference.new

    assert_nil @controller.send(:write_resource_preference_cookie!, resource_pref, {})
    assert_empty resource_pref.updates

    attrs = ActionController::Parameters.new(
      consented: "1",
      functional: "1",
      performant: "0",
      targetable: "0",
      ignored: "x",
    ).permit(:consented, :functional, :performant, :targetable, :ignored)

    @controller.send(:write_resource_preference_cookie!, resource_pref, attrs)

    assert_equal 1, resource_pref.updates.size
    assert_equal(
      { "consented" => "1", "functional" => "1", "performant" => "0", "targetable" => "0" },
      resource_pref.updates.first,
    )
  end

  test "cookie params and update params cover nested and flat forms" do
    @controller.params_hash = { preference_cookie: { consented: "1",
                                                     functional: "1",
                                                     performant: "0",
                                                     targetable: "0", } }
    nested = @controller.send(:preference_cookie_params)

    assert_equal "1", nested[:consented]

    cookie = Struct.new(:consented?).new(false)
    update = @controller.send(:build_cookie_update_params, cookie, nested)

    assert update[:consented_at]

    cookie = Struct.new(:consented?).new(true)
    update = @controller.send(
      :build_cookie_update_params, cookie,
      ActionController::Parameters.new(consented: "0").permit(:consented),
    )

    assert_nil update[:consented_at]
  end

  test "safe return and color theme params cover fallback inputs" do
    @controller.params_hash = { return_to: "/safe", theme: "dark" }

    assert_equal "/safe", @controller.send(:safe_return_to_path)
    assert_equal "dark", @controller.send(:preference_theme_params)[:option_id]

    @controller.params_hash = { return_to: "//evil.example", ct: "dr" }

    assert_nil @controller.send(:safe_return_to_path)
    assert_equal "dr", @controller.send(:preference_theme_params)[:option_id]
  end

  test "preference routing helpers map screens and authorities" do
    @controller.define_singleton_method(:controller_path) { "sign/app/preferences" }

    assert_equal "sign", @controller.send(:preference_route_authority)
    assert_equal :region, @controller.send(:preference_group_screen, :currency)
    assert_nil @controller.send(:preference_group_screen, :theme)
    assert_equal :cu, @controller.send(:preference_context_key_for_screen, :currency)
    assert_nil @controller.send(:preference_context_key_for_screen, :theme)
    assert_equal "sign_app_preference_currency_url", @controller.send(:preference_url_helper_name, :currency)
    assert_equal "edit_sign_app_preference_currency_url", @controller.send(:preference_edit_url_helper_name, :currency)
    assert_raises(ArgumentError) { @controller.send(:preference_url_helper_name, :unknown) }
  end

  test "resolved writable timezone and timezone normalization handle valid and invalid values" do
    assert_equal "Asia/Tokyo", @controller.send(:normalize_known_timezone, "Asia/Tokyo")
    assert_nil @controller.send(:normalize_known_timezone, "Invalid/Zone")
    assert_equal "Asia/Tokyo", @controller.send(:resolved_writable_timezone, FakeAssociation.new(1, nil), "Asia/Tokyo")

    @controller.define_singleton_method(:option_id_to_timezone) { |_id, _prefix| "Europe/Paris" }

    assert_equal "Europe/Paris", @controller.send(:resolved_writable_timezone, FakeAssociation.new(1, nil), nil)
  end

  test "reset_preference_state clears memoized preference state" do
    @controller.instance_variable_set(:@preferences, FakePreference.new)
    @controller.instance_variable_set(:@preference_payload, { "x" => 1 })
    @controller.instance_variable_set(:@refresh_token_value, "token")

    @controller.send(:reset_preference_state)

    assert_nil @controller.instance_variable_get(:@preferences)
    assert_nil @controller.instance_variable_get(:@preference_payload)
    assert_nil @controller.instance_variable_get(:@refresh_token_value)
  end

  # There is no titleized fallback any more: a missing option label has to raise so it is caught in
  # development and test rather than shown to a user as a humanized key fragment.
  test "preference option label reads the surface scoped translation" do
    I18n.stub(:t, ->(key) { "translated:#{key}" }) do
      assert_equal "translated:acme.app.preference.theme.options.dark",
                   @controller.send(:preference_option_label, :theme, "dark")
    end
  end

  test "regional_default_option_ids maps us and jp to the region-owned currency" do
    us_ids = @controller.send(:regional_default_option_ids, AppPreferenceRegionOption::US)

    assert_equal AppPreferenceCurrencyOption::USD, us_ids.fetch(:currency)
    assert_equal AppPreferenceLanguageOption::EN, us_ids.fetch(:language)
    assert_equal AppPreferenceDateFormatOption::US, us_ids.fetch(:date_format)
    assert_equal AppPreferenceTimeFormatOption::HOUR_12, us_ids.fetch(:time_format)

    jp_ids = @controller.send(:regional_default_option_ids, AppPreferenceRegionOption::JP)

    assert_equal AppPreferenceCurrencyOption::JPY, jp_ids.fetch(:currency)
    assert_equal AppPreferenceLanguageOption::JA, jp_ids.fetch(:language)
    assert_equal AppPreferenceDateFormatOption::ISO, jp_ids.fetch(:date_format)
    assert_equal AppPreferenceTimeFormatOption::HOUR_24, jp_ids.fetch(:time_format)
  end

  test "regional_default_option_ids returns nil for an unknown region option" do
    assert_nil @controller.send(:regional_default_option_ids, nil)
    assert_nil @controller.send(:regional_default_option_ids, 0)
    assert_nil @controller.send(:regional_default_option_ids, 99)
  end

  test "preference option label suffixes the currency code" do
    I18n.stub(:t, ->(_key) { "US Dollar" }) do
      assert_equal "US Dollar (USD)", @controller.send(:preference_option_label, :currency, "usd")
    end
  end

  test "preference option label raises when the option has no translation" do
    assert_raises(I18n::MissingTranslationData) do
      @controller.send(:preference_option_label, :theme, "no_such_option")
    end
  end

  test "preference write redirect consumes the edited context parameter" do
    @controller.params_hash = {
      ri: "jp",
      lx: "en",
      tz: "Etc/UTC",
      ct: "dr",
      cu: "usd",
      df: "us",
      tf: "12",
      mo: "rd",
      dn: "cp",
      ps: "50",
    }

    {
      language: :lx,
      timezone: :tz,
      theme: :ct,
      currency: :cu,
      date_format: :df,
      time_format: :tf,
      motion: :mo,
      density: :dn,
      page_size: :ps,
    }.each do |screen, context_key|
      redirect_params = @controller.send(
        :preference_write_redirect_params,
        except: @controller.send(:preference_context_key_for_screen, screen) || context_key,
      )

      assert_nil redirect_params[context_key], "#{screen} should consume #{context_key}"
      assert_equal "jp", redirect_params[:ri]
    end
  end

  test "preference write redirect clears ri when region is the edited parameter" do
    # Regression: if ri is not excluded when redirecting after a region update,
    # the URL's ri=<old_value> survives the redirect and the page never reflects
    # the newly-saved JWT region value.
    @controller.params_hash = { ri: "us", lx: "en" }

    redirect_params = @controller.send(:preference_write_redirect_params, except: :ri)

    assert_nil redirect_params[:ri],
               "ri must be absent after a region update so set_region re-derives it from the JWT"
    assert_equal "en", redirect_params[:lx]
  end

  test "theme params still accept legacy colortheme scope" do
    @controller.params_hash = { preference_colortheme: { option_id: "dark" } }

    assert_equal "dark", @controller.send(:preference_theme_params)[:option_id]
  end

  test "render update response and reset state cover response helpers" do
    @controller.instance_variable_set(
      :@preferences,
      FakePreference.new(language: "en", region: "us", timezone: "Etc/UTC", theme: "dr", app_preference_cookie: nil),
    )

    @controller.send(:render_preference_update_response)

    assert_equal :ok, @controller.render_args[:status]
    assert @controller.render_args[:json].key?(:preference)
    assert_equal "en", @controller.render_args[:json].fetch(:preference).fetch(:lx)
    assert_not @controller.render_args[:json].fetch(:preference).key?(:r18s)

    @controller.instance_variable_set(:@preference_payload, { "x" => 1 })
    @controller.instance_variable_set(:@refresh_token_value, "token")
    @controller.send(:reset_preference_state)

    assert_nil @controller.instance_variable_get(:@preferences)
    assert_nil @controller.instance_variable_get(:@preference_payload)
    assert_nil @controller.instance_variable_get(:@refresh_token_value)
  end

  private

  # Builds a token-side (ComPreference / com_setting) and resource-side
  # (VisitorPreference / com_principal) record so the cross-database dual-write
  # transaction is exercised against two genuinely different connection owners.
  def build_cross_db_dual_write_pair
    Prosopite.pause do
      [1, 2, 3].each { |id| VisitorStatus.find_or_create_by!(id: id) }
      [0, 1, 2, 3].each { |id| VisitorVisibility.find_or_create_by!(id: id) }
    end

    token = ComPreference.create!(
      status_id: ComPreferenceStatus::NOTHING,
      binding_method_id: ComPreferenceBindingMethod::NOTHING,
      dbsc_status_id: ComPreferenceDbscStatus::NOTHING,
      discarded_at: 20.years.from_now,
      purged_at: 20.years.from_now,
    )
    resource = VisitorPreference.create!(visitor: Visitor.create!)

    controller = PreferenceCoreHarness.new
    controller.define_singleton_method(:preference_class) { ComPreference }

    [token, resource, controller]
  end
end

# DAMP local route helper aliases for former shared test support.
class PreferenceCoreHarness
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

class PreferenceCoreTest
  test "preference core guards handle blank children and tokens" do
    h = PreferenceCoreHarness.new
    h.define_singleton_method(:option_id_to_language) { |_id, _prefix| nil }
    h.send(:pin_locale_to_saved_language, nil)
    h.send(:pin_locale_to_saved_language, PreferenceCoreTest::FakeAssociation.new(nil, nil))

    h.define_singleton_method(:refresh_token_value) { nil }

    assert_nil h.send(:find_preference_for_delete)
    h.define_singleton_method(:refresh_token_value) { "refresh" }
    h.define_singleton_method(:refresh_token_lookup_digest) { |_token| nil }

    assert_nil h.send(:find_preference_for_delete)

    h.instance_variable_set(:@preferences, nil)

    assert_nil h.send(:reset_preference_by_rebootstrap!)
    h.define_singleton_method(:current_resource) { nil }

    assert_nil h.send(:existing_resource_preference_for_reset)
    assert_nil h.send(:destroy_resource_preference_for_reset!, nil)
    assert_nil h.send(:reset_current_resource_preference_association, Object.new)
  end

  test "preference core update endpoints short circuit when records are empty" do
    h = PreferenceCoreHarness.new
    blank_child = PreferenceCoreTest::FakeAssociation.new(nil, nil)
    h.define_singleton_method(:load_or_refresh_preference_child) { |_suffix, **_| blank_child }
    h.define_singleton_method(:update_preference_child_dual_write!) { |*| nil }
    h.define_singleton_method(:preference_language_params) { {} }
    h.send(:set_language_preferences_update)
    h.define_singleton_method(:preference_theme_params) { {} }
    h.define_singleton_method(:load_or_refresh_preference_child) { |_suffix, **_| blank_child }
    h.send(:set_theme_preferences_update)
    h.define_singleton_method(:ensure_preferences_record) { nil }
    assert_raises(PreferenceOperationError) { h.send(:set_timezone_preferences_update) }
  end
end
