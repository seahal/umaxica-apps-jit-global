# Locale bundle closed-set check

Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted worktree changes. The changes
that affect this result are `config/initializers/locale.rb`, the four bundles under
`config/locales/{jp,us}/`, and `docs/architecture/i18n.md`. Unrelated in-flight work was also present
in the worktree, including pending migrations.

## What was checked

`config/initializers/locale.rb` now raises at boot unless the files under `config/locales/` are
exactly `jp/en.yml`, `jp/ja.yml`, `us/en.yml`, and `us/ja.yml`. This is initializer wiring, so it is
recorded here rather than covered by Minitest.

## Observations

All runs used `bin/rails runner` in the development environment.

- With the four stray files `{jp,us}/base_app_navigation.{en,ja}.yml` present, boot raised
  `RuntimeError` from the initializer and listed all four under "Unexpected files".
- After their 8 keys per file were moved under `base.app.navigation` in the four bundles and the
  stray files were deleted, boot succeeded. The application's own entries on `I18n.load_path` were
  exactly the four bundles. `I18n.t("base.app.navigation.membership", id: 7)` returned
  `Membership 7` in `en`, and `base.app.navigation.groups_empty` returned the Japanese copy in `ja`.
- The moved keys were compared with `YAML.load_file` before deletion: each bundle's
  `base.app.navigation` hash equalled the hash in the stray file it replaced.
- With `us/ja.yml` temporarily renamed, boot raised and listed `us/ja.yml` under "Missing files".
  The file was restored.
- With an empty `jp/probe.ja.yml` added, boot raised and listed it under "Unexpected files". The
  probe was removed.
- `bundle exec rubocop config/initializers/locale.rb` reported no offenses.

## Not completed

`bin/rails test test/initializers/locale_test.rb test/initializers/locale_bundle_integrity_test.rb`
and the related controller tests did not run. The test environment refused to start because of a
pending migration from unrelated in-flight work
(`db/app_principals_migrate/20261003215326_rebuild_app_secret_credentials.rb`), which was left
unapplied.
