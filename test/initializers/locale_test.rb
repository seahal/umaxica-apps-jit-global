# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString
# rubocop:disable I18n/RailsI18n/DecorateStringFormattingUsingInterpolation

require "test_helper"
# require "helpers/global_test_support"

class LocaleInitializerTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  INITIALIZER_PATH = Rails.root.join("config/initializers/locale.rb")

  test "loads locale files when REGION_CODE is not set" do
    ENV.delete("REGION_CODE")

    assert_nothing_raised { reload_locale_initializer }
    assert_equal supported_locale_paths, config_locale_load_paths
    assert_equal [:en, :ja], I18n.available_locales.sort
    assert_equal :ja, I18n.default_locale
    assert_equal [:en, :ja], I18n.fallbacks[:en]
    assert_equal [:ja, :en], I18n.fallbacks[:ja]
  end

  test "provides english labels for app settings links" do
    assert_nothing_raised { reload_locale_initializer }

    I18n.with_locale(:en) do
      assert_equal "Passkey", I18n.t("controller.sign.app.setting.index.passkey")
      assert_equal "Recovery Code", I18n.t("controller.sign.app.setting.index.secret_credential")
      assert_equal "Email", I18n.t("controller.sign.app.setting.index.email")
      assert_equal "Telephone", I18n.t("controller.sign.app.setting.index.telephone")
      assert_equal "Session", I18n.t("controller.sign.app.setting.index.session")
      assert_equal "Activity", I18n.t("controller.sign.app.setting.index.activity")
    end
  end

  test "provides english labels for app language preference screen" do
    assert_nothing_raised { reload_locale_initializer }

    I18n.with_locale(:en) do
      assert_equal "Preferences", I18n.t("base.app.preferences.title")
      assert_equal "Manage language, theme, and other preferences in one place.",
                   I18n.t("base.app.preferences.description")
      assert_equal "Region Settings", I18n.t("base.app.preferences.region_settings")
      assert_equal "Language Settings", I18n.t("base.app.preferences.language_settings")
      assert_equal "Timezone Settings", I18n.t("base.app.preferences.timezone_settings")
      assert_equal "Cookie Settings", I18n.t("base.app.preferences.cookie_settings")
      assert_equal "Theme Settings", I18n.t("base.app.preferences.theme_settings")
      assert_equal "Reset Settings", I18n.t("base.app.preferences.reset_settings")
      assert_equal "Back to settings", I18n.t("base.app.preferences.back_to_settings")
      assert_equal "Back to top", I18n.t("base.app.preferences.up_link")
      assert_equal "Back", I18n.t("base.app.preferences.regions.back_link")
      assert_equal "Back", I18n.t("base.com.preferences.regions.back_link")
      assert_equal "Back", I18n.t("base.org.preferences.regions.back_link")
      assert_equal "Preferences", I18n.t("base.com.preferences.title")
      assert_equal "Preferences", I18n.t("base.org.preferences.title")
      assert_equal "Timezone Settings", I18n.t("base.com.preferences.timezone_settings")
      assert_equal "Timezone Settings", I18n.t("base.org.preferences.timezone_settings")
    end
  end

  test "provides english labels for acme preference screen and language names" do
    assert_nothing_raised { reload_locale_initializer }

    I18n.with_locale(:en) do
      assert_equal "Language Settings", I18n.t("acme.app.preference.language.edit.heading")
      assert_equal "Language", I18n.t("acme.app.preference.language.edit.language_label")
      # The region screen adjusts regional defaults but is not the language UI,
      # so its heading names only the region.
      assert_equal "Region Settings", I18n.t("acme.app.preference.region.edit.heading")
      assert_equal "Region Settings", I18n.t("acme.com.preference.region.edit.heading")
      assert_equal "Region Settings", I18n.t("acme.org.preference.region.edit.heading")
      assert_equal "Date Format", I18n.t("acme.app.preference.date_format.edit.heading")
      assert_equal "Reset Preferences", I18n.t("acme.app.preference.resets.title")
      assert_equal "Clear preference data", I18n.t("acme.app.preference.resets.button")
      assert_equal "Region Settings", I18n.t("base.app.preferences.region_settings")
      assert_equal "Language Settings", I18n.t("acme.app.preferences.language_settings")
      assert_equal "Manage language, theme, and other preferences in one place.",
                   I18n.t("acme.app.preferences.description")
      assert_equal "Language Settings", I18n.t("acme.app.preference.language.edit.heading")
      assert_equal "Change the display language for the application.",
                   I18n.t("acme.app.preference.language.edit.description")
      assert_equal "Language", I18n.t("acme.app.preference.language.edit.language_label")
      assert_equal "Update Settings", I18n.t("acme.app.preferences.update_settings")
      assert_equal "Submitting...", I18n.t("acme.app.preferences.submitting")
      assert_equal "Region Settings", I18n.t("acme.app.preferences.region_settings")
      assert_equal "Back to Preferences", I18n.t("acme.app.preferences.back_to_settings")
      assert_equal "US Dollar", I18n.t("acme.app.preference.currency.options.usd")
      assert_equal "Japanese Yen", I18n.t("acme.app.preference.currency.options.jpy")
      assert_equal "日本語", I18n.t("languages.japanese")
      assert_equal "English", I18n.t("languages.english")
    end
  end

  test "provides english labels for app region preference links" do
    assert_nothing_raised { reload_locale_initializer }

    I18n.with_locale(:en) do
      assert_equal "Preferences", I18n.t("base.app.preferences.title")
      assert_equal "Region Settings", I18n.t("acme.app.preferences.regions.title")
      assert_equal "Choose your region...", I18n.t("acme.app.preferences.regions.select_region_prompt")
      assert_equal "Region Settings", I18n.t("acme.app.preferences.regions.region_section")
      assert_equal "Select Region", I18n.t("acme.app.preferences.regions.select_region")
      assert_equal "Japan - 日本", I18n.t("acme.app.preferences.regions.select_region_selector.JP")
      assert_equal "United States - USA", I18n.t("acme.app.preferences.regions.select_region_selector.US")
      assert_equal "Timezone Settings", I18n.t("acme.app.preferences.region.timezone.link")
      assert_equal "Language Settings", I18n.t("acme.app.preferences.region.language.link")
      assert_equal "Currency", I18n.t("acme.app.preferences.region.currency.link")
      assert_equal "Date Format", I18n.t("acme.app.preferences.region.date_format.link")
      assert_equal "Time Format", I18n.t("acme.app.preferences.region.time_format.link")
    end
  end

  test "provides localized labels for app date format preference screen" do
    assert_nothing_raised { reload_locale_initializer }

    I18n.with_locale(:ja) do
      assert_equal "日付形式", I18n.t("acme.app.preference.date_format.edit.heading")
      assert_equal "アプリケーションで表示する日付形式を選択します。",
                   I18n.t("acme.app.preference.date_format.edit.description")
      assert_equal "日付形式", I18n.t("acme.app.preference.date_format.edit.option_label")
      assert_equal "ISO形式 (YYYY-MM-DD)", I18n.t("acme.app.preference.date_format.options.iso")
      assert_equal "英国式 (DD/MM/YYYY)", I18n.t("acme.app.preference.date_format.options.uk")
      assert_equal "米国式 (MM/DD/YYYY)", I18n.t("acme.app.preference.date_format.options.us")
    end
  end

  test "provides localized labels for com region preference links" do
    assert_nothing_raised { reload_locale_initializer }

    I18n.with_locale(:ja) do
      assert_equal "地域設定", I18n.t("acme.com.preferences.regions.title")
      assert_equal "地域を選択してください…", I18n.t("acme.com.preferences.regions.select_region_prompt")
      assert_equal "地域設定", I18n.t("acme.com.preferences.regions.region_section")
      assert_equal "地域を選択", I18n.t("acme.com.preferences.regions.select_region")
      assert_equal "日本", I18n.t("acme.com.preferences.regions.select_region_selector.JP")
      assert_equal "アメリカ合衆国 (USA)", I18n.t("acme.com.preferences.regions.select_region_selector.US")
      assert_equal "タイムゾーン設定", I18n.t("acme.com.preferences.region.timezone.link")
      assert_equal "言語設定", I18n.t("acme.com.preferences.region.language.link")
      assert_equal "通貨設定", I18n.t("acme.com.preferences.region.currency.link")
      assert_equal "日付形式", I18n.t("acme.com.preferences.region.date_format.link")
      assert_equal "時刻形式", I18n.t("acme.com.preferences.region.time_format.link")
    end
  end

  test "provides localized labels for app region preference links" do
    assert_nothing_raised { reload_locale_initializer }

    I18n.with_locale(:ja) do
      assert_equal "地域設定", I18n.t("acme.app.preferences.regions.title")
      assert_equal "地域を選択してください…", I18n.t("acme.app.preferences.regions.select_region_prompt")
      assert_equal "地域設定", I18n.t("acme.app.preferences.regions.region_section")
      assert_equal "地域を選択", I18n.t("acme.app.preferences.regions.select_region")
      assert_equal "日本", I18n.t("acme.app.preferences.regions.select_region_selector.JP")
      assert_equal "アメリカ合衆国 (USA)", I18n.t("acme.app.preferences.regions.select_region_selector.US")
      assert_equal "タイムゾーン設定", I18n.t("acme.app.preferences.region.timezone.link")
      assert_equal "言語設定", I18n.t("acme.app.preferences.region.language.link")
      assert_equal "通貨設定", I18n.t("acme.app.preferences.region.currency.link")
      assert_equal "日付形式", I18n.t("acme.app.preferences.region.date_format.link")
      assert_equal "時刻形式", I18n.t("acme.app.preferences.region.time_format.link")
    end
  end

  test "provides localized labels for app display and accessibility preferences" do
    assert_nothing_raised { reload_locale_initializer }

    %w(app com org).each do |surface|
      I18n.with_locale(:en) do
        assert_equal "Preferences", I18n.t("base.app.preferences.title")
        assert_equal "Motion Settings", I18n.t("acme.#{surface}.preferences.motion_settings")
        assert_equal "Density Settings", I18n.t("acme.#{surface}.preferences.density_settings")
        assert_equal "Page Size", I18n.t("acme.#{surface}.preferences.pagination_settings")
      end

      I18n.with_locale(:ja) do
        assert_equal "設定", I18n.t("base.app.preferences.title")
        assert_equal "モーション設定", I18n.t("acme.#{surface}.preferences.motion_settings")
        assert_equal "表示密度設定", I18n.t("acme.#{surface}.preferences.density_settings")
        assert_equal "1ページあたりの表示件数", I18n.t("acme.#{surface}.preferences.pagination_settings")
      end
    end

    I18n.with_locale(:en) do
      assert_equal "Reduced motion", I18n.t("acme.app.preference.motion.options.reduced")
      assert_equal "Compact density", I18n.t("acme.app.preference.density.options.compact")
      assert_equal "50 items", I18n.t("acme.app.preference.page_size.options.50")
      assert_equal "Unlimited", I18n.t("acme.app.preference.page_size.options.infinity")
    end

    I18n.with_locale(:ja) do
      assert_equal "控えめなモーション", I18n.t("acme.app.preference.motion.options.reduced")
      assert_equal "コンパクト", I18n.t("acme.app.preference.density.options.compact")
      assert_equal "50件", I18n.t("acme.app.preference.page_size.options.50")
      assert_equal "無制限", I18n.t("acme.app.preference.page_size.options.infinity")
    end
  end

  test "region preference screens provide localized top back links" do
    {
      en: "Back",
      ja: "もどる",
    }.then do |expectations|
      assert_nothing_raised { reload_locale_initializer }

      expectations.each do |locale, expected|
        I18n.with_locale(locale) do
          %w(app com org).each do |surface|
            assert_equal expected, I18n.t("acme.#{surface}.preferences.regions.back_link")
          end
        end
      end
    end
  end

  test "region preference screens provide org regional option links" do
    {
      en: ["Timezone Settings", "Language Settings", "Currency", "Date Format", "Time Format"],
      ja: %w(タイムゾーン設定 言語設定 通貨設定 日付形式 時刻形式),
    }.then do |expectations|
      assert_nothing_raised { reload_locale_initializer }

      expectations.each do |locale, expected|
        I18n.with_locale(locale) do
          keys = %w(timezone language currency date_format time_format)

          assert_equal expected,
                       keys.map { |key| I18n.t("acme.org.preferences.region.#{key}.link") }
        end
      end
    end
  end

  test "region preference screens provide language labels for every surface and locale" do
    expectations = {
      en: {
        app: ["Language Settings", "Change the display language for the application.", "Language"],
        org: ["Language Settings", "Change the display language for the organization console.", "Language"],
        com: ["Language Settings", "Change the display language for the corporate site.", "Language"],
      },
      ja: {
        app: ["言語設定", "アプリケーションの表示言語を変更します。", "言語"],
        org: ["言語設定", "組織コンソールの表示言語を変更します。", "言語"],
        com: ["言語設定", "コーポレート画面の表示言語を変更します。", "言語"],
      },
    }

    assert_nothing_raised { reload_locale_initializer }

    expectations.each do |locale, surfaces|
      I18n.with_locale(locale) do
        surfaces.each do |surface, (heading, description, label)|
          assert_equal heading, I18n.t("acme.#{surface}.preference.language.edit.heading")
          assert_equal description, I18n.t("acme.#{surface}.preference.language.edit.description")
          assert_equal label, I18n.t("acme.#{surface}.preference.language.edit.language_label")
        end
      end
    end
  end

  test "provides localized labels for org regional option screens" do
    assert_nothing_raised { reload_locale_initializer }

    I18n.with_locale(:ja) do
      assert_equal "通貨設定", I18n.t("acme.org.preference.currency.edit.heading")
      assert_equal "表示に使う通貨を選択します。", I18n.t("acme.org.preference.currency.edit.description")
      assert_equal "通貨", I18n.t("acme.org.preference.currency.edit.option_label")
      assert_equal "米国ドル", I18n.t("acme.org.preference.currency.options.usd")
      assert_equal "日本円", I18n.t("acme.org.preference.currency.options.jpy")

      assert_equal "日付形式", I18n.t("acme.org.preference.date_format.edit.heading")
      assert_equal "表示する日付形式を選択します。", I18n.t("acme.org.preference.date_format.edit.description")
      assert_equal "日付形式", I18n.t("acme.org.preference.date_format.edit.option_label")
      assert_equal "ISO形式 (YYYY-MM-DD)", I18n.t("acme.org.preference.date_format.options.iso")
      assert_equal "英国式 (DD/MM/YYYY)", I18n.t("acme.org.preference.date_format.options.uk")
      assert_equal "米国式 (MM/DD/YYYY)", I18n.t("acme.org.preference.date_format.options.us")

      assert_equal "時刻形式", I18n.t("acme.org.preference.time_format.edit.heading")
      assert_equal "表示する時刻形式を選択します。", I18n.t("acme.org.preference.time_format.edit.description")
      assert_equal "時刻形式", I18n.t("acme.org.preference.time_format.edit.option_label")
      assert_equal "24時間表記", I18n.t("acme.org.preference.time_format.options.hour_24")
      assert_equal "12時間表記", I18n.t("acme.org.preference.time_format.options.hour_12")
    end
  end

  private

  def reload_locale_initializer
    load(INITIALIZER_PATH)
  end

  def config_locale_load_paths
    I18n.load_path
      .map(&:to_s)
      .select { |path| path.start_with?(Rails.root.join("config/locales").to_s) }
      .sort
  end

  def supported_locale_paths
    %w(
      config/locales/jp/en.yml
      config/locales/jp/ja.yml
      config/locales/us/en.yml
      config/locales/us/ja.yml
    ).map { |path| Rails.root.join(path).to_s }.sort
  end
end

# rubocop:enable I18n/RailsI18n/DecorateStringFormattingUsingInterpolation
# rubocop:enable I18n/RailsI18n/DecorateString
