# typed: false
# frozen_string_literal: true

require "openssl"

require "test_helper"
# require "helpers/global_test_support"

class PreferenceSanitizeTestController < ::ApplicationController
  include ::PreferenceBase

  attr_accessor :test_params, :test_controller_path

  def initialize(*)
    super
    @test_params = {}
  end

  def controller_path
    @test_controller_path || "acme/app/preferences"
  end

  def params
    @test_params.with_indifferent_access
  end

  def test_sanitize_option_id(params_hash, option_type:)
    sanitize_option_id(params_hash.dup.with_indifferent_access, option_type: option_type)
  end

  def test_ensure_preference_reference_defaults!
    send(:ensure_preference_reference_defaults!)
  end
end

module Preference
  class BaseTest < ActiveSupport::TestCase
    test "preference cookie key constants are stable" do
      assert_equal "ct", PreferenceBase::THEME_COOKIE_KEY
      assert_equal "language", PreferenceBase::LANGUAGE_COOKIE_KEY
      assert_equal "tz", PreferenceBase::TIMEZONE_COOKIE_KEY
    end
  end

  class SanitizeOptionIdTest < ActionDispatch::IntegrationTest
    setup do
      @controller = PreferenceSanitizeTestController.new
    end

    test "returns integer option_id as-is" do
      result = @controller.test_sanitize_option_id({ option_id: 1 }, option_type: :timezone)

      assert_equal 1, result[:option_id]
    end

    test "converts numeric string to integer" do
      result = @controller.test_sanitize_option_id({ option_id: "2" }, option_type: :timezone)

      assert_equal 2, result[:option_id]
    end

    test "resolves valid timezone constant name" do
      result = @controller.test_sanitize_option_id({ option_id: "ASIA_TOKYO" }, option_type: :timezone)

      assert_equal AppPreferenceTimezoneOption::ASIA_TOKYO, result[:option_id]
    end

    test "resolves valid timezone with slash notation" do
      result = @controller.test_sanitize_option_id({ option_id: "Asia/Tokyo" }, option_type: :timezone)

      assert_equal AppPreferenceTimezoneOption::ASIA_TOKYO, result[:option_id]
    end

    test "resolves United States timezone with slash notation" do
      result = @controller.test_sanitize_option_id({ option_id: "America/New_York" }, option_type: :timezone)

      assert_equal AppPreferenceTimezoneOption::AMERICA_NEW_YORK, result[:option_id]
    end

    test "resolves valid language constant name" do
      result = @controller.test_sanitize_option_id({ option_id: "JA" }, option_type: :language)

      assert_equal AppPreferenceLanguageOption::JA, result[:option_id]
    end

    test "resolves valid region constant name" do
      result = @controller.test_sanitize_option_id({ option_id: "JP" }, option_type: :region)

      assert_equal AppPreferenceRegionOption::JP, result[:option_id]
    end

    test "resolves valid theme constant name" do
      result = @controller.test_sanitize_option_id({ option_id: "dark" }, option_type: :theme)

      assert_equal AppPreferenceThemeOption::DARK, result[:option_id]
    end

    test "ignores invalid constant name - returns unchanged" do
      result = @controller.test_sanitize_option_id({ option_id: "INVALID_CONST" }, option_type: :timezone)

      assert_equal "INVALID_CONST", result[:option_id]
    end

    test "ignores malicious input attempting to access arbitrary constant" do
      malicious_inputs = %w(
        RAILS_ENV
        SECRET_KEY_BASE
        ApplicationController
        Object
        Kernel
      )

      Prosopite.pause do
        malicious_inputs.each do |input|
          result = @controller.test_sanitize_option_id({ option_id: input }, option_type: :timezone)

          assert_equal input, result[:option_id], "Expected malicious input '#{input}' to be returned unchanged"
        end
      end
    end

    test "handles nil option_id" do
      result = @controller.test_sanitize_option_id({ option_id: nil }, option_type: :timezone)

      assert_nil result[:option_id]
    end

    test "handles empty string option_id" do
      result = @controller.test_sanitize_option_id({ option_id: "" }, option_type: :timezone)

      assert_nil result[:option_id]
    end

    test "normalizes lowercase input" do
      result = @controller.test_sanitize_option_id({ option_id: "asia_tokyo" }, option_type: :timezone)

      assert_equal AppPreferenceTimezoneOption::ASIA_TOKYO, result[:option_id]
    end

    test "normalizes hyphenated input" do
      result = @controller.test_sanitize_option_id({ option_id: "asia-tokyo" }, option_type: :timezone)

      assert_equal AppPreferenceTimezoneOption::ASIA_TOKYO, result[:option_id]
    end

    test "leaves a non-numeric option_id unchanged when no option_type is given" do
      result = @controller.test_sanitize_option_id({ option_id: "some-label" }, option_type: nil)

      assert_equal "some-label", result[:option_id]
    end
  end

  class EnsureReferenceDefaultsTest < ActiveSupport::TestCase
    setup do
      @controller = PreferenceSanitizeTestController.new
    end

    teardown do
      ApplicationRecord.clear_fixed_id_seed_cache!
    end

    test "recreates missing app preference activity level defaults" do
      AppPreferenceChronicle.delete_all
      AppPreferenceChronicleLevel.where(id: AppPreferenceChronicleLevel::INFO).delete_all

      assert_nil AppPreferenceChronicleLevel.find_by(id: AppPreferenceChronicleLevel::INFO)

      @controller.test_ensure_preference_reference_defaults!

      assert_not_nil AppPreferenceChronicleLevel.find_by(id: AppPreferenceChronicleLevel::INFO)
    end

    test "recreates missing org preference activity level defaults on the activity writer" do
      @controller.test_controller_path = "core/org/preferences"
      OrgPreferenceChronicle.delete_all
      OrgPreferenceChronicleLevel.where(id: OrgPreferenceChronicleLevel::INFO).delete_all

      assert_nil OrgPreferenceChronicleLevel.find_by(id: OrgPreferenceChronicleLevel::INFO)

      @controller.test_ensure_preference_reference_defaults!

      assert_not_nil OrgPreferenceChronicleLevel.find_by(id: OrgPreferenceChronicleLevel::INFO)
    end

    test "recreates missing app preference parent reference defaults" do
      called = []

      AppPreferenceStatus.stub(:ensure_defaults!, -> { called << :status }) do
        AppPreferenceChronicleLevel.stub(:ensure_defaults!, -> { called << :chronicle_level }) do
          AppPreferenceChronicleEvent.stub(:ensure_defaults!, -> { called << :chronicle_event }) do
            AppPreferenceBindingMethod.stub(:ensure_defaults!, -> { called << :binding_method }) do
              AppPreferenceDbscStatus.stub(:ensure_defaults!, -> { called << :dbsc_status }) do
                @controller.test_ensure_preference_reference_defaults!
              end
            end
          end
        end
      end

      assert_equal %i(status chronicle_level chronicle_event binding_method dbsc_status), called
    end
  end

  class JwtConfigurationTest < ActiveSupport::TestCase
    test "audience_for selects matching host family and keeps localhost in development" do
      assert_includes PreferenceJwtConfiguration.audience_for("log.umaxica.app"), "www.umaxica.app"
      assert_includes PreferenceJwtConfiguration.audience_for("www.umaxica.com"), "www.umaxica.com"
      assert_includes PreferenceJwtConfiguration.audience_for("base.org.localhost"), "org.localhost"
    end
  end

  class ConnectionRoleFallbackTest < ActiveSupport::TestCase
    setup do
      @controller = PreferenceSanitizeTestController.new
    end

    test "with_preference_connection falls back to writing when reading role is not configured" do
      calls = []
      owner =
        Class.new do
          define_singleton_method(:connected_to) do |role:, &block|
            calls << role
            raise ActiveRecord::ConnectionNotDefined, "No reading role" if role == :reading

            block.call
          end
        end

      @controller.define_singleton_method(:preference_connection_owner) { owner }

      result = @controller.send(:with_preference_connection, :reading) { :loaded }

      assert_equal :loaded, result
      assert_equal %i(reading writing), calls
    end

    test "with_preference_connection does not hide missing writing role" do
      owner =
        Class.new do
          define_singleton_method(:connected_to) do |role:, &|
            raise ActiveRecord::ConnectionNotDefined, "No #{role} role"
          end
        end

      @controller.define_singleton_method(:preference_connection_owner) { owner }

      assert_raises(ActiveRecord::ConnectionNotDefined) do
        @controller.send(:with_preference_connection, :writing) { :loaded }
      end
    end

    test "with_preference_connection yields directly when there is no connection owner" do
      @controller.define_singleton_method(:preference_connection_owner) { nil }

      result = @controller.send(:with_preference_connection, :writing) { :direct }

      assert_equal :direct, result
    end
  end

  class AccessTokenIssuerJtiTest < ActiveSupport::TestCase
    PREFERENCE_CASES = [
      ["app", AppPreference, AppPreferenceStatus],
      ["com", ComPreference, ComPreferenceStatus],
      ["org", OrgPreference, OrgPreferenceStatus],
    ].freeze

    setup do
      @controller = PreferenceSanitizeTestController.new
      @controller.response = ActionDispatch::TestResponse.new
    end

    PREFERENCE_CASES.each do |surface, preference_class, status_class|
      test "issuing #{surface} access token twice keeps the first token current" do
        preference = create_preference_record(preference_class, status_class, token_label: "#{surface}-stable")
        @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.#{surface}.localhost")
        @controller.test_controller_path = "sign/#{surface}/preferences"
        @controller.define_singleton_method(:preference_class) { preference_class }

        with_preference_jwt_keys(host: @controller.request.host) do
          @controller.send(:issue_access_token_from, preference)
          first_token = @controller.send(:cookies)[@controller.send(:access_token_cookie_name)]
          first_payload = PreferenceToken.decode(
            first_token,
            host: @controller.request.host,
            jwt_issuer_id: @controller.send(:preference_jwt_issuer_id),
          )
          first_jti = preference.reload.jti

          @controller.send(:issue_access_token_from, preference)

          assert_equal first_jti, preference.reload.jti
          assert @controller.send(:preference_access_token_current?, preference, first_payload)
        end
      end
    end

    PREFERENCE_CASES.each do |surface, preference_class, status_class|
      test "explicit #{surface} jti rotation rejects an older preference access token" do
        preference = create_preference_record(
          preference_class,
          status_class,
          token_label: "#{surface}-explicit-rotate",
        )
        @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.#{surface}.localhost")
        @controller.test_controller_path = "sign/#{surface}/preferences"
        @controller.define_singleton_method(:preference_class) { preference_class }

        with_preference_jwt_keys(host: @controller.request.host) do
          @controller.send(:issue_access_token_from, preference)
          first_token = @controller.send(:cookies)[@controller.send(:access_token_cookie_name)]
          first_payload = PreferenceToken.decode(
            first_token,
            host: @controller.request.host,
            jwt_issuer_id: @controller.send(:preference_jwt_issuer_id),
          )
          first_jti = preference.reload.jti

          @controller.send(:issue_access_token_from, preference, rotate_jti: true)

          assert_not_equal first_jti, preference.reload.jti
          assert_not @controller.send(:preference_access_token_current?, preference, first_payload)
        end
      end
    end

    private

    def create_preference_record(preference_class, status_class, token_label:)
      preference_class.create!(
        status_id: status_class::NOTHING,
        discarded_at: 1.day.from_now,
        token_digest: preference_class.digest_refresh_token("#{token_label}-refresh"),
        jti: "jti-#{token_label}",
      )
    end
  end

  class JwtConfigurationTest < ActiveSupport::TestCase
    test "active_kid returns value from ENV" do
      with_env("PREFERENCE_JWT_ACTIVE_KID" => "test_kid") do
        assert_equal JitSecurityJwtRegistry.issuer("preference").current_kid,
                     PreferenceJwtConfiguration.active_kid
      end
    end

    test "leeway_seconds ignores the environment and returns the fixed profile leeway" do
      with_env("PREFERENCE_JWT_LEEWAY_SECONDS" => "3600") do
        assert_equal SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS,
                     PreferenceJwtConfiguration.leeway_seconds
      end
    end

    test "issuer returns value from ENV" do
      with_env("PREFERENCE_JWT_ISSUER" => "test-issuer") do
        assert_equal "test-issuer", PreferenceJwtConfiguration.issuer
      end
    end

    test "audiences are derived from boot config hosts" do
      expected = Rails.configuration.x.boot_config.fetch(:hosts).base_origins.map(&:host) +
        %w(app.localhost org.localhost com.localhost localhost)

      assert_equal expected,
                   PreferenceJwtConfiguration.audiences
    end

    test "audience_for filters to matching TLD only" do
      result = PreferenceJwtConfiguration.audience_for("log.umaxica.app")

      assert_includes result, "www.umaxica.app"
      assert_includes result, "app.localhost", "localhost fallback is included in non-production"
      assert_not_includes result, "www.umaxica.com"
    end

    test "audience_for returns only matching TLD for com host" do
      result = PreferenceJwtConfiguration.audience_for("wwww.umaxica.com")

      assert_includes result, "www.umaxica.com"
      assert_includes result, "app.localhost"
      assert_not_includes result, "www.umaxica.app"
    end

    test "audience_for includes localhost for localhost host" do
      result = PreferenceJwtConfiguration.audience_for("id.app.localhost")

      assert_includes result, "app.localhost"
      assert_includes result, "localhost"
      assert_not_includes result, "www.umaxica.app"
    end

    test "audience_for raises when host is blank" do
      assert_raises(ArgumentError) { PreferenceJwtConfiguration.audience_for("") }
      assert_raises(ArgumentError) { PreferenceJwtConfiguration.audience_for(nil) }
    end

    test "audience_for raises when no configured TLD matches" do
      assert_equal ["app.localhost"], PreferenceJwtConfiguration.audience_for("example.invalid")
    end

    test "audience_for raises for an .org host when only .app/.com are configured" do
      assert_includes PreferenceJwtConfiguration.audience_for("log.umaxica.org"), "www.umaxica.org"
    end

    test "host_scope_for uses matching configured audience for sibling hosts" do
      assert_equal "www.umaxica.app", PreferenceJwtConfiguration.host_scope_for("log.umaxica.app")
      assert_equal "www.umaxica.com", PreferenceJwtConfiguration.host_scope_for("www.umaxica.com")
    end

    test "host_scope_for raises when no configured audience matches" do
      assert_equal "localhost", PreferenceJwtConfiguration.host_scope_for("example.invalid")
    end

    test "parse_header decodes token header" do
      token = JWT.encode({ foo: "bar" }, nil, "none", { kid: "test_kid" })
      header = PreferenceJwtConfiguration.parse_header(token)

      assert_equal "test_kid", header["kid"]
    end

    private

    def with_env(vars)
      original = vars.keys.index_with { |k| ENV[k] }
      vars.each { |k, v| ENV[k] = v }
      yield
    ensure
      original.each { |k, v| ENV[k] = v }
    end
  end

  class TokenTest < ActiveSupport::TestCase
    setup do
      @preferences = { "theme" => "dark" }.freeze
      @host = "app.localhost"
      @type = "user"
      @public_id = "test_id"
      @jti = "test_jti"

      # Generate a test EC key
      @key = OpenSSL::PKey::EC.generate("secp384r1")
      @der = Base64.encode64(@key.to_der)
      @pub_der = Base64.encode64(@key.public_to_der)
    end

    test "encode and decode a valid token" do
      PreferenceJwtConfiguration.stub(:private_key_for_active, @key) do
        PreferenceJwtConfiguration.stub(:public_key_for, @key) do
          PreferenceJwtConfiguration.stub(:active_kid, "test_kid") do
            token = PreferenceToken.encode(
              @preferences,
              host: @host,
              preference_type: @type,
              public_id: @public_id,
              jti: @jti,
            )

            assert_not_nil token

            decoded = PreferenceToken.decode(token, host: @host)

            assert_not_nil decoded
            assert_equal @preferences, decoded["preferences"]
            assert_equal PreferenceJwtConfiguration.host_scope_for(@host), decoded["host"]
            assert_equal @type, decoded["preference_type"]
            assert_equal @public_id, decoded["public_id"]
            assert_equal @jti, decoded["jti"]
          end
        end
      end
    end

    test "decode returns nil for invalid host" do
      PreferenceJwtConfiguration.stub(:private_key_for_active, @key) do
        PreferenceJwtConfiguration.stub(:public_key_for, @key) do
          PreferenceJwtConfiguration.stub(:active_kid, "test_kid") do
            token = PreferenceToken.encode(
              @preferences,
              host: @host,
              preference_type: @type,
              public_id: @public_id,
              jti: @jti,
            )

            assert_nil PreferenceToken.decode(token, host: "wrong.host")
          end
        end
      end
    end

    test "extract_preferences returns preferences from payload" do
      payload = { "preferences" => { "theme" => "light" } }

      assert_equal({ "theme" => "light" }, PreferenceToken.extract_preferences(payload))
      assert_equal({}, PreferenceToken.extract_preferences(nil))
    end
  end

  class PreferenceBaseMethodsTest < ActiveSupport::TestCase
    FakePreferenceState =
      Struct.new(
        :binding_method, :dbsc_status, :dbsc_session_id, :expires_at,
        :status_id, :discarded_at, :replaced_by_id, :public_id,
        keyword_init: true,
      ) do
        def binding_method_dbsc? = binding_method == :dbsc

        def binding_method_legacy? = binding_method == :legacy

        def dbsc_status_pending? = dbsc_status == :pending

        def dbsc_status_active? = dbsc_status == :active

        def dbsc_status_failed? = dbsc_status == :failed

        def dbsc_status_revoke? = dbsc_status == :revoke

        def replay? = false

        def accessible?
          discarded_at.nil? ||
            (discarded_at.respond_to?(:infinite?) && discarded_at.infinite?) ||
            discarded_at > Time.current
        end

        def revoked? = discarded_at.present? && discarded_at <= Time.current
      end

    setup do
      Actor.reset
      @controller = PreferenceSanitizeTestController.new
      @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.app.localhost")
      @controller.response = ActionDispatch::TestResponse.new
    end

    teardown do
      Actor.reset
    end

    test "resolve_option_id_from_param returns default for blank value" do
      assert_equal 99, @controller.send(:resolve_option_id_from_param, nil, :timezone, 99, "prefix")
      assert_equal 99, @controller.send(:resolve_option_id_from_param, "", :timezone, 99, "prefix")
    end

    test "resolve preference transport delegates to legacy preference cookie pipeline" do
      delegated = false
      @controller.define_singleton_method(:set_preferences_cookie) { delegated = true }

      @controller.send(:resolve_preference_transport)

      assert delegated
    end

    test "preference edit entry refresh copies resource preference before issuing token" do
      resource = Object.new
      resource_preference = Object.new
      shared_preference = Object.new
      calls = []

      @controller.instance_variable_set(:@preferences, shared_preference)
      @controller.define_singleton_method(:current_resource) { resource }
      @controller.define_singleton_method(:resolved_resource_preference) { |candidate|
        (candidate == resource) ? resource_preference : nil
      }
      @controller.define_singleton_method(:copy_preference_values!) do |source, target, prefix|
        calls << [:copy, source, target, prefix]
      end
      @controller.define_singleton_method(:preference_prefix) { "App" }
      @controller.define_singleton_method(:reload_preference_for_token!) do |preference|
        calls << [:reload, preference]
      end
      @controller.define_singleton_method(:issue_access_token_from) do |preference|
        calls << [:issue, preference]
      end

      @controller.send(:refresh_preference_token_from_db_for_edit_entry!)

      assert_equal [
        [:copy, resource_preference, shared_preference, "App"],
        [:reload, shared_preference],
        [:issue, shared_preference],
      ], calls
    end

    test "preference edit entry refresh is a no-op without a logged-in resource preference" do
      calls = []

      @controller.instance_variable_set(:@preferences, Object.new)
      @controller.define_singleton_method(:current_resource) { nil }
      @controller.define_singleton_method(:copy_preference_values!) do |_source, _target, _prefix|
        calls << :copy
      end

      @controller.send(:refresh_preference_token_from_db_for_edit_entry!)

      assert_empty calls
    end

    test "resolve_option_id_from_param returns integer for valid input" do
      assert_equal AppPreferenceTimezoneOption::ASIA_TOKYO,
                   @controller.send(:resolve_option_id_from_param, "Asia/Tokyo", :timezone, 99, "prefix")
    end

    test "preference child records are created with the parent association" do
      preference = Object.new
      option_ids = PreferenceClassRegistry::CHILD_RECORD_TYPES.index_with.with_index { |_, index| index + 1 }
      created_records = []
      record_class =
        Class.new do
          define_singleton_method(:create!) { |attributes| created_records << attributes }
        end
      PreferenceClassRegistry::CHILD_RECORD_TYPES.each do |type|
        preference.define_singleton_method(:"create_app_preference_#{type}!") do |attributes|
          created_records << attributes
        end
      end

      PreferenceClassRegistry.stub(:record_class, ->(_prefix, _type) { record_class }) do
        @controller.send(:create_preference_option_records, "App", preference, option_ids)
      end

      assert_equal PreferenceClassRegistry::CHILD_RECORD_TYPES.size, created_records.size
      assert_equal option_ids.values, created_records.pluck(:option_id)
      assert created_records.none? { |attributes| attributes.key?(:preference_id) }
      assert created_records.none? { |attributes| attributes.key?(:preference) }
    end

    test "preference child records are created on their model writing connection" do
      preference = Object.new
      option_ids = PreferenceClassRegistry::CHILD_RECORD_TYPES.index_with.with_index { |_, index| index + 1 }
      roles = []
      created_records = []
      PreferenceClassRegistry::CHILD_RECORD_TYPES.each do |type|
        preference.define_singleton_method(:"create_app_preference_#{type}!") do |attributes|
          created_records << attributes
        end
      end

      connection_owner =
        Class.new(ApplicationRecord) do
          self.abstract_class = true
        end
      connection_owner.define_singleton_method(:connected_to) do |role:, &block|
        roles << role
        block.call
      end

      record_class = Class.new(connection_owner)
      record_class.define_singleton_method(:create!) { |attributes| created_records << attributes }

      PreferenceClassRegistry.stub(:record_class, ->(_prefix, _type) { record_class }) do
        @controller.send(:create_preference_option_records, "App", preference, option_ids)
      end

      assert_equal Array.new(PreferenceClassRegistry::CHILD_RECORD_TYPES.size, :writing), roles
      assert_equal PreferenceClassRegistry::CHILD_RECORD_TYPES.size, created_records.size
    end

    test "preference cookie is created with the parent association" do
      preference = Object.new
      created_attributes = nil
      preference.define_singleton_method(:create_app_preference_cookie!) do |attributes|
        created_attributes = attributes
      end
      cookie_class =
        Class.new do
          define_singleton_method(:create!) { |attributes| created_attributes = attributes }
        end

      PreferenceClassRegistry.stub(:cookie_class, ->(_prefix) { cookie_class }) do
        @controller.send(:create_preference_cookie, "App", preference)
      end

      assert_not created_attributes[:functional]
      assert_not created_attributes.key?(:preference_id)
      assert_not created_attributes.key?(:preference)
    end

    test "normalized_locale returns sym for valid locale" do
      I18n.stub(:available_locales, [:en, :ja]) do
        assert_equal :en, @controller.send(:normalized_locale, "en")
        assert_equal :ja, @controller.send(:normalized_locale, "JA")
        assert_nil @controller.send(:normalized_locale, "invalid")
        assert_nil @controller.send(:normalized_locale, "")
      end
    end

    test "normalized_locale returns nil when a present value stringifies to a blank locale" do
      value_blank_when_stringified =
        Class.new do
          def blank? = false

          def to_s = ""
        end.new

      assert_nil @controller.send(:normalized_locale, value_blank_when_stringified)
    end

    test "locale_from_region returns mapped locale" do
      assert_equal "ja", @controller.send(:locale_from_region, "jp")
      assert_equal "en", @controller.send(:locale_from_region, "us")
      assert_nil @controller.send(:locale_from_region, "unknown")
    end

    test "available_locale_strings returns unique lowercased strings" do
      I18n.stub(:available_locales, %i(en JA en)) do
        # Clear memoized value
        @controller.instance_variable_set(:@available_locale_strings, nil)

        assert_equal %w(en ja), @controller.send(:available_locale_strings)
      end
    end

    test "host_matches? requires the exact host scope and the same registrable domain" do
      PreferenceJwtConfiguration.stub(:host_scope_for, "example.com") do
        assert PreferenceToken.send(:host_matches?, "example.com", "example.com")
        assert PreferenceToken.send(:host_matches?, "example.com", "sub.example.com")
        assert_not PreferenceToken.send(:host_matches?, "example.com", "other.com")
        assert_not PreferenceToken.send(:host_matches?, "sub.example.com", "sub.example.com")
        assert_not PreferenceToken.send(:host_matches?, nil, "example.com")
        assert_not PreferenceToken.send(:host_matches?, 42, "example.com")
      end
    end

    test "audience_matches? requires exact membership of the host scope" do
      assert PreferenceToken.send(:audience_matches?, ["a.com", "b.com"], "a.com")
      assert_not PreferenceToken.send(:audience_matches?, ["a.com", "b.com"], "sub.b.com")
      assert_not PreferenceToken.send(:audience_matches?, ["a.com", "b.com"], "c.com")
    end

    test "cookie banner endpoint returns nil when host is not expected" do
      @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "wrong.localhost")

      assert_nil @controller.send(:cookie_banner_endpoint_url)
      assert_not @controller.send(:cookie_banner_endpoint_available_for_request?)
    end

    test "extract_cookie_banner_consent handles consent aliases" do
      assert_nil @controller.send(:extract_cookie_banner_consent, nil)
      assert_nil @controller.send(:extract_cookie_banner_consent, "bad")
      assert_nil @controller.send(:extract_cookie_banner_consent, { "preferences" => "bad" })
      assert @controller.send(:extract_cookie_banner_consent, { "preferences" => { "consent" => true } })
      assert_not @controller.send(:extract_cookie_banner_consent, { "preferences" => { "consented" => false } })
    end

    test "preference dbsc helpers name binding status payload and expiry" do
      dbsc = FakePreferenceState.new(
        binding_method: :dbsc,
        dbsc_status: :active,
        dbsc_session_id: "session-1",
        discarded_at: 20.minutes.from_now,
      )
      legacy = FakePreferenceState.new(binding_method: :legacy, dbsc_status: :pending)
      nothing = FakePreferenceState.new(binding_method: :nothing, dbsc_status: :nothing)

      @controller.define_singleton_method(:preference_dbsc_path) { "/dbsc" }

      assert_equal "dbsc", @controller.send(:dbsc_binding_method_name, dbsc)
      assert_equal "legacy", @controller.send(:dbsc_binding_method_name, legacy)
      assert_equal "nothing", @controller.send(:dbsc_binding_method_name, nothing)
      assert_equal "pending", @controller.send(:dbsc_status_name, legacy)
      assert_equal "active", @controller.send(:dbsc_status_name, dbsc)
      assert_equal "nothing", @controller.send(:dbsc_status_name, nothing)
      assert_equal(
        {
          binding_method: "dbsc",
          status: "active",
          session_id: "session-1",
          registration_url: "/dbsc",
          verification_url: "/dbsc",
        },
        @controller.send(:preference_dbsc_payload_for, dbsc),
      )
      assert_nil @controller.send(:preference_dbsc_payload_for, nil)
      assert_in_delta 10.minutes.from_now.to_i,
                      @controller.send(:preference_dbsc_cookie_expires_at, dbsc).to_i, 1
      assert_nil @controller.send(:preference_dbsc_cookie_expires_at, legacy)
    end

    test "preference refresh binding validates only active dbsc-bound preferences" do
      legacy = FakePreferenceState.new(binding_method: :legacy)

      assert @controller.send(:preference_refresh_binding_allowed?, legacy)

      dbsc = FakePreferenceState.new(binding_method: :dbsc, dbsc_status: :pending, dbsc_session_id: "session-1")

      assert_not @controller.send(:preference_refresh_binding_allowed?, dbsc)
      assert_equal "dbsc_not_active", @controller.instance_variable_get(:@preference_refresh_binding_reason)

      dbsc.dbsc_status = :active

      assert_not @controller.send(:preference_refresh_binding_allowed?, dbsc)
      assert_equal "missing_bound_cookie", @controller.instance_variable_get(:@preference_refresh_binding_reason)

      @controller.send(:cookies)[@controller.send(:preference_dbsc_cookie_name)] = "wrong"

      assert_not @controller.send(:preference_refresh_binding_allowed?, dbsc)
      assert_equal "session_id_mismatch", @controller.instance_variable_get(:@preference_refresh_binding_reason)

      @controller.send(:cookies)[@controller.send(:preference_dbsc_cookie_name)] = "session-1"

      assert @controller.send(:preference_refresh_binding_allowed?, dbsc)
    end

    test "refresh token data and preference status helpers handle edge cases" do
      assert_equal [nil, nil], @controller.send(:refresh_token_data, nil)

      @controller.define_singleton_method(:parse_refresh_token) { |_| ["public-id", "verifier"] }
      @controller.define_singleton_method(:digest_refresh_token) { |value| "digest:#{value}" }

      assert_equal ["public-id", "digest:verifier"], @controller.send(:refresh_token_data, "token")

      status_class = Class.new
      status_class.const_set(:DELETED, 99)
      @controller.define_singleton_method(:preference_status_class) { status_class }
      valid = FakePreferenceState.new(status_id: 1, discarded_at: 5.minutes.from_now)
      deleted = FakePreferenceState.new(status_id: 99, discarded_at: 5.minutes.from_now)
      expired = FakePreferenceState.new(status_id: 1, discarded_at: 1.minute.ago)
      revoked = FakePreferenceState.new(status_id: 1, discarded_at: Time.current)

      assert @controller.send(:valid_refresh_preference?, valid)
      assert_not @controller.send(:valid_refresh_preference?, nil)
      assert_not @controller.send(:valid_refresh_preference?, deleted)
      assert_not @controller.send(:valid_refresh_preference?, expired)
      assert_not @controller.send(:valid_refresh_preference?, revoked)
    end

    test "preference payload and cookie helpers expose stored values" do
      @controller.instance_variable_set(
        :@preference_payload,
        { "preferences" => { "ct" => "dr" }, "public_id" => "pref-public", "jti" => "jti-1" },
      )

      assert_equal({ "ct" => "dr" }, @controller.send(:preference_payload_preferences))
      assert_equal "dr", @controller.send(:preference_payload_value, :ct)
      assert_equal "pref-public", @controller.send(:preference_payload_public_id)
      assert_equal "jti-1", @controller.send(:preference_payload_jti)

      expires_at = 1.hour.from_now
      @controller.send(:set_refresh_token_cookie, "refresh-token", expires_at)
      @controller.send(:set_preference_dbsc_cookie!, "dbsc-token", expires_at: expires_at)

      assert_equal "refresh-token", @controller.send(:cookies)[@controller.send(:refresh_token_cookie_name)]
      assert_equal "dbsc-token", @controller.send(:cookies)[@controller.send(:preference_dbsc_cookie_name)]

      deletion_options = @controller.send(:preference_cookie_deletion_options)

      assert_not deletion_options.key?(:expires)
      assert_equal :strict, deletion_options[:same_site]
      assert_equal "/", deletion_options[:path]
      assert_not deletion_options.key?(:domain)
    end

    test "preference credential cookie options are host only and host-prefix compatible in secure contexts" do
      expires_at = 1.hour.from_now

      production = ActiveSupport::EnvironmentInquirer.new("production")

      Rails.stub(:env, production) do
        options = @controller.send(:preference_cookie_options, expires_at: expires_at, httponly: true)

        assert options[:secure]
        assert_equal :strict, options[:same_site]
        assert_equal "/", options[:path]
        assert_not options.key?(:domain)
      end
    end

    test "preference access and refresh cookies use strict same site" do
      expires_at = 1.hour.from_now

      assert_equal :strict, @controller.send(:preference_auth_cookie_options, expires_at: expires_at)[:same_site]

      @controller.send(:set_refresh_token_cookie, "refresh-token", expires_at)

      assert_equal "refresh-token", @controller.send(:cookies)[@controller.send(:refresh_token_cookie_name)]
    end

    test "legacy scoped preference refresh cookie is read during compatibility window" do
      @controller.send(:cookies)["app_preference_refresh"] = "legacy-refresh-token"

      assert_equal "legacy-refresh-token", @controller.send(:refresh_token_value)
    end

    test "new preference credential write clears legacy scoped cookies" do
      cookies = @controller.send(:cookies)
      cookies["app_preference_access"] = "legacy-access-token"
      cookies["app_preference_refresh"] = "legacy-refresh-token"
      cookies["app_preference_dbsc"] = "legacy-dbsc-token"

      @controller.send(:set_refresh_token_cookie, "refresh-token", 1.hour.from_now)

      assert_equal "refresh-token", cookies[@controller.send(:refresh_token_cookie_name)]
      assert_nil cookies["app_preference_access"]
      assert_nil cookies["app_preference_refresh"]
      assert_nil cookies["app_preference_dbsc"]
    end

    test "write guard raises for audience mismatched access token" do
      cookies = @controller.send(:cookies)
      cookies[@controller.send(:access_token_cookie_name)] = "wrong-audience-token"
      decode_calls = []

      PreferenceToken.stub(
        :decode,
        lambda do |token, host:, jwt_issuer_id:, raise_on_audience_mismatch:|
          decode_calls << [token, host, jwt_issuer_id, raise_on_audience_mismatch]
          raise PreferenceToken::AudienceMismatchError, "Invalid audience"
        end,
      ) do
        assert_raises(PreferenceToken::AudienceMismatchError) do
          @controller.send(:ensure_preference_access_token_audience_for_write!)
        end
      end

      assert_equal [
        [
          "wrong-audience-token",
          "id.app.localhost",
          "surface:ACME_APP",
          true,
        ],
      ], decode_calls
    end

    test "load access token payload falls back when referenced preference record is missing" do
      payload = {
        "preferences" => { "ct" => "dr" },
        "public_id" => "missing-public",
      }
      relation = Struct.new(:record) do
        define_method(:find_by) do |*|
          record
        end
      end.new(nil)

      [AppPreference, ComPreference, OrgPreference].each do |klass|
        @controller.instance_variable_set(:@preferences, nil)
        @controller.instance_variable_set(:@preference_payload, nil)

        PreferenceToken.stub(:decode, payload) do
          PreferenceToken.stub(:extract_preference_type, klass.name) do
            PreferenceToken.stub(:extract_public_id, "missing-public") do
              klass.stub(:includes, relation) do
                @controller.define_singleton_method(:preference_class) { klass }
                @controller.send(:cookies)[@controller.send(:access_token_cookie_name)] = "access-token"

                assert @controller.send(:load_access_token_payload)
                assert_nil @controller.instance_variable_get(:@preferences)
                assert_equal payload, @controller.instance_variable_get(:@preference_payload)
                assert_equal "access-token", @controller.send(:cookies)[@controller.send(:access_token_cookie_name)]
              end
            end
          end
        end
      end
    end

    test "bounded access token preference record loader reads through writing connection" do
      preference = app_preferences(:one)
      preference.update!(jti: "current-jti")
      payload = {
        "preferences" => { "ct" => "dr" },
        "public_id" => "existing-public",
        "jti" => "current-jti",
      }
      relation = Struct.new(:record) do
        define_method(:find_by) do |*|
          record
        end
      end.new(preference)

      roles = []
      @controller.send(:cookies)[@controller.send(:access_token_cookie_name)] = "access-token"

      # The lookup is `preference_class.active.unconsumed.includes(...).find_by(...)`
      # (scoped to reject a retired/expired row -- see
      # app/controllers/concerns/preference_access_token_transport.rb), so
      # `.active`/`.unconsumed` must resolve back to the class itself here
      # for the `.includes` stub below to still intercept the chain.
      PreferenceToken.stub(:decode, payload) do
        PreferenceToken.stub(:extract_preference_type, AppPreference.name) do
          PreferenceToken.stub(:extract_public_id, "existing-public") do
            AppPreference.stub(:active, AppPreference) do
              AppPreference.stub(:unconsumed, AppPreference) do
                AppPreference.stub(:includes, relation) do
                  @controller.define_singleton_method(:with_preference_connection) do |role, &block|
                    roles << role
                    block.call
                  end

                  assert @controller.send(:load_access_token_payload)
                  assert_equal preference, @controller.send(:load_access_token_preference_record!)
                  assert_equal preference, @controller.instance_variable_get(:@preferences)
                  assert_equal [:writing], roles
                end
              end
            end
          end
        end
      end
    end

    test "load access token payload rejects stale preference jti" do
      preference = app_preferences(:one)
      preference.update!(jti: "current-jti")
      payload = {
        "preferences" => { "ct" => "dr" },
        "public_id" => preference.public_id,
        "jti" => "stale-jti",
      }
      relation = Struct.new(:record) do
        define_method(:find_by) do |*|
          record
        end
      end.new(preference)

      @controller.send(:cookies)[@controller.send(:access_token_cookie_name)] = "access-token"

      PreferenceToken.stub(:decode, payload) do
        PreferenceToken.stub(:extract_preference_type, AppPreference.name) do
          PreferenceToken.stub(:extract_public_id, preference.public_id) do
            PreferenceToken.stub(:extract_jti, "stale-jti") do
              AppPreference.stub(:includes, relation) do
                @controller.define_singleton_method(:preference_class) { AppPreference }

                assert @controller.send(:load_access_token_payload)
                assert_nil @controller.send(:load_access_token_preference_record!)
                assert_nil @controller.instance_variable_get(:@preferences)
                assert_nil @controller.instance_variable_get(:@preference_payload)
                assert_nil @controller.send(:cookies)[@controller.send(:access_token_cookie_name)]
              end
            end
          end
        end
      end
    end

    test "load access token payload rejects missing jti when preference row has current jti" do
      preference = app_preferences(:one)
      preference.update!(jti: "current-jti")
      payload = {
        "preferences" => { "ct" => "dr" },
        "public_id" => preference.public_id,
      }
      relation = Struct.new(:record) do
        define_method(:find_by) do |*|
          record
        end
      end.new(preference)

      @controller.send(:cookies)[@controller.send(:access_token_cookie_name)] = "access-token"

      PreferenceToken.stub(:decode, payload) do
        PreferenceToken.stub(:extract_preference_type, AppPreference.name) do
          PreferenceToken.stub(:extract_public_id, preference.public_id) do
            AppPreference.stub(:includes, relation) do
              @controller.define_singleton_method(:preference_class) { AppPreference }

              assert @controller.send(:load_access_token_payload)
              assert_nil @controller.send(:load_access_token_preference_record!)
              assert_nil @controller.instance_variable_get(:@preferences)
              assert_nil @controller.instance_variable_get(:@preference_payload)
              assert_nil @controller.send(:cookies)[@controller.send(:access_token_cookie_name)]
            end
          end
        end
      end
    end

    test "load access token payload allows legacy preference rows without jti" do
      preference = app_preferences(:one)
      preference.update!(jti: nil)
      payload = {
        "preferences" => { "ct" => "dr" },
        "public_id" => preference.public_id,
        "jti" => "legacy-token-jti",
      }
      relation = Struct.new(:record) do
        define_method(:find_by) do |*|
          record
        end
      end.new(preference)

      @controller.send(:cookies)[@controller.send(:access_token_cookie_name)] = "access-token"

      PreferenceToken.stub(:decode, payload) do
        PreferenceToken.stub(:extract_preference_type, AppPreference.name) do
          PreferenceToken.stub(:extract_public_id, preference.public_id) do
            AppPreference.stub(:includes, relation) do
              @controller.define_singleton_method(:preference_class) { AppPreference }

              assert @controller.send(:load_access_token_payload)
              assert_equal preference, @controller.send(:load_access_token_preference_record!)
              assert_equal preference, @controller.instance_variable_get(:@preferences)
            end
          end
        end
      end
    end

    test "banner theme class and audit helper edge branches" do
      @controller.define_singleton_method(:current_resource) { Object.new }
      @controller.define_singleton_method(:adopt_preference_for!) { |_| raise RuntimeError, "boom" }

      assert_nil @controller.send(:restore_preference_from_resource!, Object.new)

      @controller.instance_variable_set(:@preference_class, AppPreference)

      assert_equal AppPreferenceStatus, @controller.send(:preference_status_class)
      assert_equal "app_preference_theme", @controller.send(:preference_theme_association)

      Actor.install_context!(preferences: Actor::Preference.new(theme: "dr"))
      @controller.send(:set_color_theme)

      assert_equal "dr", @controller.instance_variable_get(:@color_theme)
    end

    test "set color theme uses actor preference before jwt payload and cookie" do
      Actor.install_context!(preferences: Actor::Preference.new(theme: "dr"))
      @controller.send(:cookies)[PreferenceBase::THEME_COOKIE_KEY] = "li"
      @controller.define_singleton_method(:preference_payload_value) { |_| "sy" }

      @controller.send(:set_color_theme)

      assert_equal "dr", @controller.instance_variable_get(:@color_theme)
    end

    test "set color theme writes default sy from the preference value not a missing-preference branch" do
      Actor.install_context!(preferences: Actor::Preference.new)

      @controller.send(:set_color_theme)

      assert_equal "sy", @controller.instance_variable_get(:@color_theme)
      assert_equal "sy", @controller.send(:cookies)[PreferenceBase::THEME_COOKIE_KEY]
    end

    test "set color theme writes public option cookies from actor preferences" do
      Actor.install_context!(
        preferences: Actor::Preference.new(
          language: "en",
          region: "us",
          timezone: "Etc/UTC",
          theme: "dr",
          currency: "usd",
          date_format: "slash",
          time_format: "12",
          motion: "reduced",
          density: "compact",
          page_size: "50",
        ),
      )

      @controller.send(:set_color_theme)
      cookies = @controller.send(:cookies)

      assert_equal "dr", cookies[PreferenceIoKeys::Cookies::THEME]
      assert_equal "Etc/UTC", cookies[PreferenceIoKeys::Cookies::TIMEZONE]
      assert_equal "usd", cookies[PreferenceIoKeys::Cookies::CURRENCY]
      assert_equal "slash", cookies[PreferenceIoKeys::Cookies::DATE_FORMAT]
      assert_equal "12", cookies[PreferenceIoKeys::Cookies::TIME_FORMAT]
      assert_equal "reduced", cookies[PreferenceIoKeys::Cookies::MOTION]
      assert_equal "compact", cookies[PreferenceIoKeys::Cookies::DENSITY]
      assert_equal "50", cookies[PreferenceIoKeys::Cookies::PAGE_SIZE]
      assert_nil cookies[PreferenceBase::LANGUAGE_COOKIE_KEY]
      assert_nil cookies["ri"]
      assert_nil cookies["lx"]
    end

    test "public option cookies are written from preference payload keys" do
      @controller.send(
        :write_public_option_cookies,
        {
          "ct" => "li",
          "tz" => "Asia/Tokyo",
          "cu" => "jpy",
          "df" => "iso",
          "tf" => "24",
          "mo" => "standard",
          "dn" => "standard",
          "ps" => "infinity",
          "ri" => "jp",
          "lx" => "ja",
        },
      )
      cookies = @controller.send(:cookies)

      assert_equal "li", cookies[PreferenceIoKeys::Cookies::THEME]
      assert_equal "Asia/Tokyo", cookies[PreferenceIoKeys::Cookies::TIMEZONE]
      assert_equal "jpy", cookies[PreferenceIoKeys::Cookies::CURRENCY]
      assert_equal "iso", cookies[PreferenceIoKeys::Cookies::DATE_FORMAT]
      assert_equal "24", cookies[PreferenceIoKeys::Cookies::TIME_FORMAT]
      assert_equal "standard", cookies[PreferenceIoKeys::Cookies::MOTION]
      assert_equal "standard", cookies[PreferenceIoKeys::Cookies::DENSITY]
      assert_equal "infinity", cookies[PreferenceIoKeys::Cookies::PAGE_SIZE]
      assert_nil cookies["ri"]
      assert_nil cookies["lx"]
    end

    test "set color theme ignores explicit request parameter after actor overlay is resolved" do
      Actor.install_context!(preferences: Actor::Preference.new(theme: "dr"))
      @controller.test_params = { PreferenceIoKeys::Params::CT => "li" }

      @controller.send(:set_color_theme)

      assert_equal "dr", @controller.instance_variable_get(:@color_theme)
    end

    test "cookie banner endpoint resolves helper on expected host" do
      old = ENV["PRIVATE_BASE_SERVICE_URL"]
      ENV["PRIVATE_BASE_SERVICE_URL"] = "base.app.localhost"
      @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "base.app.localhost")
      @controller.define_singleton_method(:base_app_web_v0_cookie_url) { "https://base.app.localhost/web/v0/cookie" }

      assert @controller.send(:cookie_banner_endpoint_available_for_request?)
      assert_equal "https://base.app.localhost/web/v0/cookie", @controller.send(:cookie_banner_endpoint_url)
    ensure
      ENV["PRIVATE_BASE_SERVICE_URL"] = old
    end

    test "preference class mapping and option fallback helpers cover unknown branches" do
      unknown_class = Class.new
      unknown_class.define_singleton_method(:name) { "UnknownPreference" }
      @controller.instance_variable_set(:@preference_class, unknown_class)

      assert_raises(ArgumentError) { @controller.send(:preference_binding_method_class) }
      assert_raises(ArgumentError) { @controller.send(:preference_dbsc_status_class) }

      assert_equal "zz", @controller.send(:option_id_to_language, "ZZ", "App")
      assert_equal "xx", @controller.send(:option_id_to_region, "XX", "App")
      assert_equal "Mars/Base", @controller.send(:option_id_to_timezone, "Mars/Base", "App")
      assert_equal "contrast", @controller.send(:option_id_to_theme, "contrast", "App")
      assert_nil @controller.send(:option_id_to_preference_value, "missing", "App", :currency)
    end

    test "refresh failure handlers and render error branches set state" do
      @controller.define_singleton_method(:preference_class) { AppPreference }
      @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.app.localhost")
      @controller.request.request_id = "request-1"
      @controller.test_params = { controller: "acme/app/preferences", action: "show" }

      preference = FakePreferenceState.new(public_id: "pref-public")
      refresh_failed_logs = []

      Rails.logger.stub(:warn, ->(message) { refresh_failed_logs << message }) do
        @controller.send(:handle_preference_refresh_failed, preference, "refresh-public")
      end

      assert @controller.send(:preference_refresh_failed?)
      assert_match(/preference\.token\.refresh\.failed/, refresh_failed_logs.last)
      assert_match(/"request_id":"request-1"/, refresh_failed_logs.last)
      assert_match(%r{"controller":"acme/app/preferences"}, refresh_failed_logs.last)
      assert_match(/"action":"show"/, refresh_failed_logs.last)
      assert_match(/"preference_public_id":"pref-public"/, refresh_failed_logs.last)
      assert_match(/"refresh_public_id":"refresh-public"/, refresh_failed_logs.last)

      @controller.send(:clear_preference_refresh_failure!)
      @controller.instance_variable_set(:@preference_refresh_binding_reason, "missing")
      binding_denied_logs = []

      Rails.logger.stub(:warn, ->(message) { binding_denied_logs << message }) do
        @controller.send(:handle_preference_refresh_binding_denied, preference, "refresh-public")
      end

      assert @controller.send(:preference_refresh_failed?)
      assert @controller.instance_variable_get(:@preference_refresh_binding_denied)
      assert_match(/preference\.token\.refresh\.binding_denied/, binding_denied_logs.last)
      assert_match(/"reason":"missing"/, binding_denied_logs.last)
      assert_match(/"request_id":"request-1"/, binding_denied_logs.last)

      rendered = []
      headed = []
      @controller.define_singleton_method(:render) { |**kwargs| rendered << kwargs }
      @controller.define_singleton_method(:head) { |status| headed << status }

      @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.app.localhost")
      @controller.request.request_id = "request-1"
      @controller.request.set_header("HTTP_ACCEPT", "application/json")
      @controller.send(:render_preference_refresh_error!)

      assert_equal :unauthorized, rendered.last[:status]

      @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.app.localhost")
      @controller.request.request_id = "request-1"
      @controller.request.set_header("HTTP_ACCEPT", "text/html")
      @controller.send(:render_preference_refresh_error!)

      assert_equal :unauthorized, headed.last
    end

    test "refresh token lifetime covers replay failed and rotated branches" do
      rotated_class =
        Class.new do
          class << self
            define_method(:rotated=) do |val|
              @rotated = val
            end

            define_method(:rotated) do
              @rotated
            end

            define_method(:name) do
              "AppPreference"
            end

            define_method(:rotate!) do |**|
              rotated
            end
          end
        end

      preference = FakePreferenceState.new(binding_method: :legacy, public_id: "pref-public")
      preference.define_singleton_method(:class) { rotated_class }
      replay = FakePreferenceState.new(binding_method: :legacy, public_id: "replay-public")
      replay.define_singleton_method(:replay?) { true }

      @controller.instance_variable_set(:@refresh_token_value, "old-refresh")
      @controller.instance_variable_set(:@refresh_presented_digest, "digest")
      @controller.instance_variable_set(:@refresh_public_id, "refresh-public")
      @controller.define_singleton_method(:find_preference_by_presented_token) { replay }
      @controller.define_singleton_method(:handle_preference_refresh_replay!) { |pref| @handled_replay = pref }
      rotation_failed_logs = []
      @controller.request.request_id = "request-2"
      @controller.test_params = { controller: "acme/app/preferences", action: "show" }

      rotated_class.rotated = nil
      Rails.logger.stub(:warn, ->(message) { rotation_failed_logs << message }) do
        @controller.send(:refresh_refresh_token_lifetime, preference)
      end

      assert_equal replay, @controller.instance_variable_get(:@handled_replay)
      assert_empty rotation_failed_logs

      @controller.define_singleton_method(:find_preference_by_presented_token) { nil }
      @controller.instance_variable_set(:@handled_replay, nil)
      @controller.instance_variable_set(:@preference_refresh_failed, false)

      Rails.logger.stub(:warn, ->(message) { rotation_failed_logs << message }) do
        @controller.send(:refresh_refresh_token_lifetime, preference)
      end

      assert @controller.send(:preference_refresh_failed?)
      assert_match(/preference\.token\.refresh\.rotation_failed/, rotation_failed_logs.last)
      assert_match(/"refresh_public_id":"refresh-public"/, rotation_failed_logs.last)
      assert_match(%r{"controller":"acme/app/preferences"}, rotation_failed_logs.last)

      rotated = FakePreferenceState.new(
        binding_method: :dbsc,
        dbsc_session_id: "dbsc-session",
        discarded_at: 2.hours.from_now,
        public_id: "rotated-public",
      )
      rotated.define_singleton_method(:class) { rotated_class }
      rotated.define_singleton_method(:issued_refresh_token) { "new-refresh" }
      rotated.define_singleton_method(:binding_method_dbsc?) { true }
      rotated_class.rotated = rotated

      calls = []
      @controller.define_singleton_method(:create_audit_log) { |**kwargs| calls << [:audit, kwargs] }
      @controller.define_singleton_method(:set_refresh_token_cookie) { |token, discarded_at|
        calls << [:refresh_cookie, token, discarded_at]
      }
      @controller.define_singleton_method(:set_preference_dbsc_cookie!) { |token, expires_at:|
        calls << [:dbsc_cookie, token, expires_at]
      }
      @controller.define_singleton_method(:issue_preference_dbsc_registration_header_for) { |pref|
        calls << [:dbsc_header, pref]
      }
      @controller.define_singleton_method(:preference_dbsc_cookie_expires_at) { |_| 10.minutes.from_now }

      @controller.send(:refresh_refresh_token_lifetime, preference)

      assert_equal rotated, @controller.instance_variable_get(:@preferences)
      assert_equal "new-refresh", @controller.instance_variable_get(:@refresh_token_value)
      assert_includes calls.map(&:first), :audit
      assert_includes calls.map(&:first), :refresh_cookie
      assert_includes calls.map(&:first), :dbsc_cookie
    end

    test "load preference record from refresh token covers valid invalid and create branches" do
      preference = FakePreferenceState.new(binding_method: :legacy, status_id: 1, discarded_at: 2.hours.from_now)
      @controller.define_singleton_method(:refresh_token_value) { "refresh-token" }
      @controller.define_singleton_method(:refresh_token_data) { |_| ["public-id", "digest"] }
      @controller.define_singleton_method(:find_refresh_preference) { |*, **| preference }
      @controller.define_singleton_method(:valid_refresh_preference?) { |_| true }

      assert_equal [preference, false], @controller.send(:load_preference_record_from_refresh_token!)

      @controller.instance_variable_set(:@preferences, nil)
      @controller.define_singleton_method(:valid_refresh_preference?) { |_| false }
      @controller.define_singleton_method(:handle_preference_refresh_failed) { |*| @preference_refresh_failed = true }

      assert_equal [nil, false], @controller.send(:load_preference_record_from_refresh_token!)

      @controller.instance_variable_set(:@preferences, nil)
      @controller.define_singleton_method(:refresh_token_value) { nil }
      @controller.define_singleton_method(:find_refresh_preference) { |*, **| nil }
      created = FakePreferenceState.new(binding_method: :legacy)
      @controller.define_singleton_method(:create_new_preference_record!) { created }

      assert_equal [created, true],
                   @controller.send(:load_preference_record_from_refresh_token!, create_if_missing: true)
    end

    test "normalize_preference_audit_event_id returns nil for a blank event id" do
      assert_nil @controller.send(:normalize_preference_audit_event_id, nil)
      assert_nil @controller.send(:normalize_preference_audit_event_id, "")
    end

    test "ensure_preferences_record returns the already loaded preference without further lookups" do
      loaded = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now)
      @controller.instance_variable_set(:@preferences, loaded)
      @controller.define_singleton_method(:load_access_token_preference_record!) { nil }
      @controller.define_singleton_method(:load_preference_record_from_refresh_token!) do |**|
        raise RuntimeError, "should not be called"
      end

      assert_equal loaded, @controller.send(:ensure_preferences_record)
    end

    test "ensure_preferences_record adopts the preference resolved from the refresh token" do
      resolved = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now)
      @controller.instance_variable_set(:@preferences, nil)
      @controller.define_singleton_method(:load_access_token_preference_record!) { nil }
      @controller.define_singleton_method(:load_preference_record_from_refresh_token!) { |**| [resolved, false] }

      assert_equal resolved, @controller.send(:ensure_preferences_record)
      assert_equal resolved, @controller.instance_variable_get(:@preferences)
    end

    test "ensure_preferences_record creates a new preference when the refresh token yields none " \
         "and no failure was recorded" do
      created = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now)
      @controller.instance_variable_set(:@preferences, nil)
      @controller.instance_variable_set(:@preference_refresh_failed, false)
      @controller.define_singleton_method(:load_access_token_preference_record!) { nil }
      @controller.define_singleton_method(:load_preference_record_from_refresh_token!) { |**| [nil, false] }
      @controller.define_singleton_method(:create_new_preference_record!) { created }

      assert_equal created, @controller.send(:ensure_preferences_record)
    end

    test "ensure_preferences_record resets a stale refresh failure before creating a fresh preference" do
      created = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now)
      @controller.instance_variable_set(:@preferences, nil)
      @controller.instance_variable_set(:@preference_refresh_failed, true)
      @controller.instance_variable_set(:@refresh_token_value, "stale")
      @controller.instance_variable_set(:@refresh_presented_digest, "stale-digest")
      @controller.instance_variable_set(:@refresh_public_id, "stale-public")
      @controller.define_singleton_method(:load_access_token_preference_record!) { nil }
      @controller.define_singleton_method(:load_preference_record_from_refresh_token!) { |**| [nil, false] }
      @controller.define_singleton_method(:create_new_preference_record!) { created }

      assert_equal created, @controller.send(:ensure_preferences_record)
      assert_not @controller.instance_variable_get(:@preference_refresh_failed)
      assert_nil @controller.instance_variable_get(:@refresh_token_value)
      assert_nil @controller.instance_variable_get(:@refresh_presented_digest)
      assert_nil @controller.instance_variable_get(:@refresh_public_id)
    end

    test "create_audit_log skips creating an audit event row when no event id is given" do
      preference = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now)
      @controller.instance_variable_set(:@preferences, preference)
      @controller.request = ActionDispatch::TestRequest.create
      event_lookup_calls = 0
      audit_event_class =
        Class.new do
          define_singleton_method(:find_or_create_by!) do |*_args|
            event_lookup_calls += 1
          end
          define_singleton_method(:ensure_defaults!) do
            event_lookup_calls += 1
          end
        end
      created_attributes = nil
      audit_class =
        Class.new do
          define_singleton_method(:create!) { |attrs| created_attributes = attrs }
        end
      @controller.define_singleton_method(:preference_audit_event_class) { audit_event_class }
      @controller.define_singleton_method(:preference_audit_class) { audit_class }

      @controller.send(:create_audit_log, event_id: nil, context: { foo: "bar" })

      assert_equal 0, event_lookup_calls
      assert_nil created_attributes[:event_id]
    end

    test "create_audit_log does not N+1 when several regional bundle events are recorded" do
      preference = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now)
      @controller.instance_variable_set(:@preferences, preference)
      @controller.request = ActionDispatch::TestRequest.create
      AppPreferenceChronicleEvent.ensure_defaults!
      AppPreferenceChronicleLevel.ensure_defaults!

      events = %w(
        UPDATE_PREFERENCE_REGION
        UPDATE_PREFERENCE_LANGUAGE
        UPDATE_PREFERENCE_DATE_FORMAT
        UPDATE_PREFERENCE_TIME_FORMAT
        UPDATE_PREFERENCE_CURRENCY
      )

      assert_nothing_raised do
        Prosopite.scan do
          events.each do |event_id|
            @controller.send(:create_audit_log, event_id: event_id, context: { field: event_id })
          end
        end
      end

      assert_equal events.size, AppPreferenceChronicle.where(subject_id: preference.id.to_s).count
    end

    test "find_preference_by_presented_token returns nil without a presented digest" do
      @controller.instance_variable_set(:@refresh_presented_digest, nil)

      assert_nil @controller.send(:find_preference_by_presented_token)
    end

    test "find_preference_by_presented_token narrows by public id when one was presented" do
      matching = AppPreference.create!(
        status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now,
        token_digest: "digest-shared-a", public_id: "public-a",
      )
      AppPreference.create!(
        status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now,
        token_digest: "digest-shared-a", public_id: "public-b",
      )
      @controller.instance_variable_set(:@refresh_presented_digest, "digest-shared-a")
      @controller.instance_variable_set(:@refresh_public_id, "public-a")

      assert_equal matching.id, @controller.send(:find_preference_by_presented_token).id
    end

    test "find_preference_by_presented_token returns the latest match when no public id is presented" do
      AppPreference.create!(
        status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now, token_digest: "digest-solo",
      )
      latest = AppPreference.create!(
        status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now, token_digest: "digest-solo",
      )
      @controller.instance_variable_set(:@refresh_presented_digest, "digest-solo")
      @controller.instance_variable_set(:@refresh_public_id, nil)

      assert_equal latest.id, @controller.send(:find_preference_by_presented_token).id
    end

    test "handle_preference_refresh_replay! skips the redundant update when compromised_at is already set" do
      preference = Struct.new(
        :discarded_at, :compromised_at, :revoked_at, :replaced_by_id, :public_id, keyword_init: true,
      ).new(
        discarded_at: 1.day.from_now, compromised_at: 1.hour.ago, revoked_at: nil,
        replaced_by_id: nil, public_id: "already-compromised",
      )
      update_calls = 0
      preference.define_singleton_method(:update!) { |_attrs| update_calls += 1 }

      result = @controller.send(:handle_preference_refresh_replay!, preference)

      assert_equal :compromised, result
      assert_equal 0, update_calls
      assert @controller.send(:preference_refresh_failed?)
    end

    test "preference_refresh_grace_replacement returns nil for preferences that do not support grace rotation" do
      assert_nil @controller.send(:preference_refresh_grace_replacement, Object.new)
    end

    test "preference_refresh_grace_replacement returns nil when the rotated replacement is no longer valid" do
      invalid_replacement = AppPreference.create!(
        status_id: AppPreferenceStatus::DELETED, discarded_at: 1.day.from_now,
      )
      preference =
        Struct.new(:replaced_by_id) do
          def rotated_within_grace? = true
        end.new(invalid_replacement.id)

      assert_nil @controller.send(:preference_refresh_grace_replacement, preference)
    end

    test "adopt_preference_refresh_grace! notifies the rotated resource when adoption is supported" do
      replacement = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now)
      preference = AppPreference.create!(
        status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now, replaced_by_id: replacement.id,
      )
      resource = Object.new
      adopt_calls = []
      @controller.define_singleton_method(:current_resource) { resource }
      @controller.define_singleton_method(:adopt_rotated_preference!) { |res, repl| adopt_calls << [res, repl] }

      @controller.send(:adopt_preference_refresh_grace!, preference, replacement)

      assert_equal [[resource, replacement]], adopt_calls
      assert_equal replacement, @controller.instance_variable_get(:@preferences)
    end

    test "adopt_preference_refresh_grace! does not notify adoption when there is no current resource" do
      replacement = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now)
      preference = AppPreference.create!(
        status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now, replaced_by_id: replacement.id,
      )
      adopt_calls = []
      @controller.define_singleton_method(:current_resource) { nil }
      @controller.define_singleton_method(:adopt_rotated_preference!) { |res, repl| adopt_calls << [res, repl] }

      @controller.send(:adopt_preference_refresh_grace!, preference, replacement)

      assert_empty adopt_calls
    end
  end

  class BuildPreferencesPayloadTest < ActiveSupport::TestCase
    FakeCookie = Struct.new(:consented, :functional, :performant, :targetable, keyword_init: true)
    FakePreference =
      Struct.new(
        :app_preference_language, :app_preference_region, :app_preference_timezone,
        :app_preference_theme, :app_preference_currency, :app_preference_date_format,
        :app_preference_time_format, :app_preference_motion, :app_preference_density,
        :app_preference_page_size, :app_preference_cookie, keyword_init: true,
      ) do
        def class
          AppPreference
        end
      end

    setup do
      @controller = PreferenceSanitizeTestController.new
    end

    test "build_preferences_payload includes consent categories from cookie record" do
      cookie = FakeCookie.new(consented: true, functional: true, performant: false, targetable: false)
      preference = FakePreference.new(app_preference_cookie: cookie)

      payload = @controller.send(:build_preferences_payload, preference)

      assert payload["consented"]
      assert payload["functional"]
      assert_not payload["performant"]
      assert_not payload["targetable"]
      assert_equal Actor::Preference::SCHEMA_VERSION, payload["ver"]
      assert_equal "ja", payload["lx"]
      assert_equal "jp", payload["ri"]
      assert_equal "Asia/Tokyo", payload["tz"]
      assert_equal "sy", payload["ct"]
    end

    test "build_preferences_payload defaults consent to false when cookie is nil" do
      preference = FakePreference.new(app_preference_cookie: nil)

      payload = @controller.send(:build_preferences_payload, preference)

      assert_not payload["consented"]
      assert_not payload["functional"]
      assert_not payload["performant"]
      assert_not payload["targetable"]
    end

    test "build_preferences_payload does not include legacy consent key" do
      preference = FakePreference.new(app_preference_cookie: nil)

      payload = @controller.send(:build_preferences_payload, preference)

      assert_not payload.key?("consent"), "legacy 'consent' key should no longer be present"
    end
  end
  private

  def encode_preference_jwt(preferences:, host:, public_id:, preference_type: "AppPreference")
    jti = "test-jti-#{SecureRandom.uuid}"
    token = nil

    with_preference_jwt_keys(host: host) do
      token = PreferenceToken.encode(
        preferences,
        host: host,
        preference_type: preference_type,
        public_id: public_id,
        jti: jti,
      )
    end

    token
  end

  def with_preference_jwt_keys(host: nil)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    public_key_for_stub = ->(_kid, **_options) { key }
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences

    PreferenceJwtConfiguration.stub(:private_key, key) do
      PreferenceJwtConfiguration.stub(:public_key, key) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, key) do
          PreferenceJwtConfiguration.stub(:public_key_for, public_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) do
                  yield
                end
              end
            end
          end
        end
      end
    end
  end
end

# DAMP local route helper aliases for former shared test support.
class PreferenceSanitizeTestController
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
class Preference::BaseTest
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
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    ensure_user_token_reference_records!
    token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
    token ||= ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    ensure_staff_token_reference_records!
    token = session_public_id.present? ? OperatorToken.find_by(public_id: session_public_id) : nil
    token ||= OperatorToken.where(staff_id: staff.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= OperatorToken.create!(
      staff_id: staff.id, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    ensure_visitor_token_reference_records!
    token = session_public_id.present? ? VisitorToken.find_by(public_id: session_public_id) : nil
    token ||= VisitorToken.where(visitor_id: visitor.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= VisitorToken.create!(
      visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
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
    %w(SIGN_APP SIGN_ORG SIGN_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
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

# DAMP preference JWT key helper for the nested JTI test.
class Preference::AccessTokenIssuerJtiTest
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

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
end
