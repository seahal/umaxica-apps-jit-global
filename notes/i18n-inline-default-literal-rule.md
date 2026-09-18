# ADR Note: Inline I18n Default Literal Rule

## Status

Accepted note (2026-04-17)

## Summary

Literal string defaults in `t()` / `I18n.t()` are prohibited in repository code.

Examples of prohibited usage:

- `t("some.key", default: "Inline text")`
- `I18n.t("some.key", default: "Inline text")`

Allowed exceptions:

- `default: :fallback_key`
- `default: nil` when the caller explicitly handles `nil`

## Reason

Translation text must remain auditable and centralized in locale YAML files under `config/locales/`.

Inline literal defaults make translation coverage difficult to audit and can hide missing keys from
normal translation validation.

## Scope

This rule applies to repository code, including:

- `app/`
- `engines/`
- `lib/`
- views and helpers where `t()` or `I18n.t()` is used

The implementation scope must be defined from current repository search results, not from a stale
example list in an old plan.

## Implementation Guidance

- Treat the current code search result as the source of truth for violations.
- Do not rely on historical file examples or pre-engine-split paths.
- Move inline literal translation text into locale YAML files.
- Keep the translation key stable where possible.

## Migration-Phase Handling

Inline I18n default literal cleanup is handled opportunistically during migration work.

Rules for the migration phase:

- when a touched file contains a prohibited literal `default:` value, correct it as part of the same
  change
- untouched files do not block unrelated migration work
- new code must not introduce new literal string defaults
- if migration work exposes a broken or missing translation contract in a touched file, fix it in
  the same change instead of carrying the violation forward

## Regression Policy

Updated 2026-08-13: the cleanup of `app/` is complete and the regression test is no longer optional.

`test/initializers/locale_bundle_integrity_test.rb` fails on any `t(..., default:)` or
`I18n.t(..., default:)` under `app/`. It also fails on a duplicate YAML mapping key in a locale
bundle, and on a bundle under `config/locales` that is missing from the load path — both silently
discard translations the same way an inline default does.

The rule is stronger than the original wording: a `default:` of any kind, not only a literal string,
suppresses `I18n::MissingTranslation` and therefore defeats
`config.i18n.raise_on_missing_translations`. Add the key to the locale bundles instead. Where a
value genuinely cannot be translated (a database-supplied proper noun), render it directly rather
than dressing it as a translation lookup.

## Related

- `AGENTS.md`
- `notes/implementation/2026-08-13-i18n-missing-translation-detection.md`
