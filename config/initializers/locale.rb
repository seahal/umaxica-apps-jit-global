# typed: false
# frozen_string_literal: true

require "i18n/backend/fallbacks"

# Each environment states both settings in config/environments/*.rb. They are required: an unset or
# non-boolean value raises here rather than defaulting, because a quiet default is how a missing
# translation went unnoticed before.
#
# Why they exist: the fallback chain below returns the other language's string before
# config.i18n.raise_on_missing_translations can fire, so a key present in only one language never
# raised anywhere. Production keeps the chain so a visitor sees the other language instead of an
# error page; development and test turn that same situation into an exception.
locale_settings = Rails.configuration.x.locale
fallbacks_enabled = locale_settings.fallbacks_enabled
raise_on_fallback = locale_settings.raise_on_fallback

# rubocop:disable I18n/RailsI18n/DecorateString -- raised before any translation is loaded
unless [true, false].include?(fallbacks_enabled)
  raise ArgumentError,
        "config.x.locale.fallbacks_enabled must be true or false, got #{fallbacks_enabled.inspect}"
end

unless [true, false].include?(raise_on_fallback)
  raise ArgumentError,
        "config.x.locale.raise_on_fallback must be true or false, got #{raise_on_fallback.inspect}"
end
# rubocop:enable I18n/RailsI18n/DecorateString

# Overrides the hook I18n::Backend::Fallbacks#translate calls after it resolves a key through a
# locale other than the requested one (i18n 1.15.2, lib/i18n/backend/fallbacks.rb). Re-read that
# method when upgrading i18n: if the hook is renamed or no longer called, this stops raising.
module LocaleFallbackGuard
  private

  def on_fallback(original_locale, _fallback_locale, key, options)
    raise I18n::MissingTranslationData.new(original_locale, key, options)
  end
end

I18n::Backend::Simple.include I18n::Backend::Fallbacks
# Included after Fallbacks so that its on_fallback takes precedence.
I18n::Backend::Simple.include LocaleFallbackGuard if raise_on_fallback

# The locale bundles are a closed set: one file per region and language. Translations are added to
# these four files, never to a new file beside them.
#
# Why the set is closed: a per-feature bundle scatters one namespace (for example `base.app`) across
# files, so a reviewer can no longer see a region's copy in one place, the duplicate-key guard in
# test/initializers/locale_bundle_integrity_test.rb (which works per file) stops seeing collisions,
# and the jp and us bundles drift apart unnoticed.
#
# Why this is checked at boot instead of documented: between 2026-05-26 and 2026-08-14 this file
# loaded a literal list of these four paths and silently ignored everything else, which kept the set
# closed only by accident and hid the dropped translations. Replacing the list with a glob removed
# the silence but also removed the constraint, and extra bundles appeared. The check below keeps the
# constraint and makes its violation loud, in the place every Rails command passes through.
#
# To add a region or language, extend expected_locale_bundles in the same change that adds the file.
locale_root = Rails.root.join("config/locales")

# A local rather than a constant because the tests reload this initializer.
expected_locale_bundles = %w(
  jp/en.yml
  jp/ja.yml
  us/en.yml
  us/ja.yml
).freeze

# Every file format the I18n backend can load, so a bundle cannot slip past under another extension.
found_locale_bundles =
  Dir[locale_root.join("**", "*.{yml,yaml,rb}")].map { |path|
    Pathname.new(path).relative_path_from(locale_root).to_s
  }

unexpected_locale_bundles = found_locale_bundles - expected_locale_bundles
missing_locale_bundles = expected_locale_bundles - found_locale_bundles

if unexpected_locale_bundles.any? || missing_locale_bundles.any?
  # rubocop:disable I18n/RailsI18n/DecorateString -- raised before any translation is loaded
  raise RuntimeError, <<~MESSAGE
    The locale bundles under #{locale_root} do not match the expected set.

      Expected exactly: #{expected_locale_bundles.join(", ")}
      Unexpected files: #{unexpected_locale_bundles.empty? ? "(none)" : unexpected_locale_bundles.join(", ")}
      Missing files:    #{missing_locale_bundles.empty? ? "(none)" : missing_locale_bundles.join(", ")}

    This application keeps all translations in one bundle per region and language. Please do not
    create a new locale file for a feature or namespace.

    If you added a file: move its keys into the matching existing bundle (for example, keys from
    jp/some_feature.ja.yml belong in jp/ja.yml, under the same key path, in alphabetical order),
    repeat that for every region and language, and then delete the file you added.

    If a file is missing: restore it. Each of the four bundles is required.

    If you are intentionally adding a region or a language: add its bundle path to
    expected_locale_bundles in config/initializers/locale.rb in the same change.

    The reasoning is recorded in the comment above expected_locale_bundles and in
    docs/architecture/i18n.md.
  MESSAGE
  # rubocop:enable I18n/RailsI18n/DecorateString
end

locale_files = expected_locale_bundles.map { |path| locale_root.join(path).to_s }

I18n.load_path =
  I18n.load_path.reject { |path| path.to_s.start_with?(locale_root.to_s) } + locale_files

I18n.available_locales = [:en, :ja]
I18n.default_locale = :ja
I18n.fallbacks =
  if fallbacks_enabled
    I18n::Locale::Fallbacks.new(en: [:en, :ja], ja: [:ja, :en])
  else
    I18n::Locale::Fallbacks.new(en: [:en], ja: [:ja])
  end
I18n.backend.reload!
