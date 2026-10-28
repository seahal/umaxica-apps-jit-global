# Base ORG Translation Keys Moved to Their Own Surface Namespace

Date: 2026-10-27. Commit: `b6e7871073bdc43a55fc5f05e8476de8ee71252f`. The worktree also held the
owner's uncommitted `.devcontainer/compose.yaml` change, which does not affect this result.

## Finding

`Base::Org` controllers referenced 20 app translation keys (20 call sites): 4 `base.app.avatars.*`
and 16 `sign.app.*`, against `adr/i18n-explicit-translation-keys.md`. Source:
`plans/backlog/2026-10-21-base-com-org-translation-namespace.md`.

Base COM was left unchanged on purpose: all 81 of its app-key call sites are in `identity/*`
controllers that the COM authentication removal deletes.

## Change

- 18 keys copied to `base.org.*` / `sign.org.*` in `config/locales/{en,ja}.yml` by line insertion.
  A script verified, per bundle, that no existing key or value changed, that exactly the 18 expected
  keys were added and that each new value equals its source. +20 lines per bundle.
- 1 key (`sign.org.settings.show.back`) already existed with the same text: repoint only.
- 1 key (`sign.org.registration.telephone.create.verification_code_sent`) already existed with
  different text. Following the rule used for the Auth half, the ORG text is kept, so the Base ORG
  telephone registration page now shows "確認コードをSMSで送信しました。" / "Verification code sent by
  SMS." instead of the longer app text.
- 20 call sites repointed in 5 files under `app/controllers/base/org/`.
- Guard: `test/security/invariants/base_org_translation_namespace_invariant_test.rb` fails when a
  Base ORG controller or helper references a `sign.app` or `base.app` key.

## Verification

- Guard Red: with the controllers reverted to HEAD, 1 run, 1 failure.
- `bin/rails test` over both translation-namespace guards, `test/initializers/locale_bundle_integrity_test.rb`,
  `test/initializers/locale_test.rb` and the Base ORG avatars, identity email/telephone
  registration, MFA reset and welcome/dashboard controller tests: 99 runs, 708 assertions,
  5 failures, 0 errors, 0 skips.
- All 5 failures are in `test/controllers/base/org/welcome_dashboard_authority_slice_1c_test.rb`.
  The same file run with this change reverted (HEAD locales and controllers): 18 runs, 5 failures.
  They are pre-existing, not caused by this change.
- `bundle exec i18n-tasks missing`: no missing translations.
- RuboCop on the 6 changed Ruby files: no offenses.

Not done: Base COM (removed with its controllers in the COM authentication removal); the full test
suite was not run.
