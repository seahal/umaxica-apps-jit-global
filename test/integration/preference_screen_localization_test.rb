# typed: false
# frozen_string_literal: true

require "test_helper"

# Every preference screen, on every surface, in both regions and both locales.
#
# https://www.umaxica.org/preference/timezone/edit?ri=us rendered "Timezone Settings" and
# "Asia Tokyo": humanized key fragments produced by `t(..., default: ...)` cascades, which suppress
# the exception `config.i18n.raise_on_missing_translations` exists to raise. The defaults are gone,
# so a missing key now raises; this test walks the screens so that raise happens in CI rather than
# in front of a user, and asserts no prop still carries a humanized fragment.
class PreferenceScreenLocalizationTest < ActionDispatch::IntegrationTest
  SURFACES = [
    { name: "app", host_env: "PUBLIC_BASE_SERVICE_URL", fallback_host: "base.app.localhost" },
    { name: "com", host_env: "PUBLIC_BASE_CORPORATE_URL", fallback_host: "base.com.localhost" },
    { name: "org", host_env: "PUBLIC_BASE_STAFF_URL", fallback_host: "base.org.localhost" },
  ].freeze

  SCREENS = %w(
    region timezone language theme cookie motion density pagination currency calendar clock
  ).freeze

  REGIONS = %w(jp us).freeze
  LOCALES = %w(en ja).freeze

  # The shapes the removed `default:` cascades used to produce: a key fragment run through
  # `titleize`/`upcase` instead of a translation.
  HUMANIZED_FRAGMENTS = [
    "Asia Tokyo", "Etc Utc", "America New York", "America Los Angeles", "Pacific Honolulu",
    "Date Format", "Time Format", "Page Size", "Hour 12", "Hour 24",
  ].freeze

  setup do
    https!
  end

  SURFACES.each do |surface|
    name = surface.fetch(:name)

    REGIONS.each do |region|
      LOCALES.each do |locale|
        test "base_#{name} renders every preference screen in #{locale} for ri=#{region}" do
          SCREENS.each do |screen|
            get_preference_screen(surface, screen, region: region, locale: locale)

            assert_response :success,
                            "/preference/#{screen}/edit?ri=#{region}&lx=#{locale} must render on base_#{name}"

            props = inertia_props

            assert_predicate props.fetch("title"), :present?
            assert_predicate props.dig("back_link", "label"), :present?

            assert_no_match(
              /translation missing/i, response.body,
              "/preference/#{screen}/edit?ri=#{region}&lx=#{locale} rendered a missing-translation marker",
            )
          end
        end
      end
    end

    test "base_#{name} timezone choices are translated rather than humanized in en" do
      get_preference_screen(surface, "timezone", region: "us", locale: "en")

      assert_response :success

      labels = inertia_choice_labels

      assert_predicate labels, :present?, "the timezone screen must offer choices"

      labels.each do |label|
        assert_not_includes HUMANIZED_FRAGMENTS, label,
                            "#{label.inspect} is a humanized key fragment, not a translation"
      end
    end

    test "base_#{name} theme choices list system, light, then dark" do
      option_class = "#{name.capitalize}PreferenceThemeOption".constantize
      get_preference_screen(surface, "theme", region: "jp", locale: "ja")

      assert_response :success
      assert_equal(
        [option_class::SYSTEM, option_class::LIGHT, option_class::DARK],
        inertia_props.dig("form", "choices").pluck("value"),
      )
    end
  end

  private

  def get_preference_screen(surface, screen, region:, locale:)
    host!(surface_host(surface))
    get(
      public_send(
        "edit_base_#{surface.fetch(:name)}_preference_#{screen}_url",
        host: surface_host(surface), ri: region, lx: locale,
      ),
    )
  end

  def surface_host(surface)
    ENV.fetch(surface.fetch(:host_env), surface.fetch(:fallback_host))
  end
end
