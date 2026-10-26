# typed: false
# frozen_string_literal: true

require "i18n/backend/fallbacks"

I18n::Backend::Simple.include I18n::Backend::Fallbacks

# The locale bundles are a closed set: one file per language. Region (jp, us) does not change
# translation content (D-113), so there is no per-region bundle. Translations are added to these two
# files, never to a new file beside them.
#
# Why the set is closed: a per-feature bundle scatters one namespace (for example `base.app`) across
# files, so a reviewer can no longer see a language's copy in one place, the duplicate-key guard in
# test/initializers/locale_bundle_integrity_test.rb (which works per file) stops seeing collisions,
# and copies of one key drift apart unnoticed (the former jp and us bundles had drifted on 114 keys
# before they were merged on 2026-10-25).
#
# Why this is checked at boot instead of documented: between 2026-05-26 and 2026-08-14 this file
# loaded a literal list of the then four paths and silently ignored everything else, which kept the set
# closed only by accident and hid the dropped translations. Replacing the list with a glob removed
# the silence but also removed the constraint, and extra bundles appeared. The check below keeps the
# constraint and makes its violation loud, in the place every Rails command passes through.
#
# To add a language, extend expected_locale_bundles in the same change that adds the file.
locale_root = Rails.root.join("config/locales")

# A local rather than a constant because the tests reload this initializer.
expected_locale_bundles = %w(
  en.yml
  ja.yml
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

    This application keeps all translations in one bundle per language. Please do not
    create a new locale file for a feature or namespace.

    If you added a file: move its keys into the matching existing bundle (for example, keys from
    some_feature.ja.yml belong in ja.yml, under the same key path, in alphabetical order),
    repeat that for every language, and then delete the file you added.

    If a file is missing: restore it. Each of the two bundles is required.

    If you are intentionally adding a language: add its bundle path to
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
I18n.fallbacks = I18n::Locale::Fallbacks.new(en: [:en], ja: [:ja])
I18n.backend.reload!
