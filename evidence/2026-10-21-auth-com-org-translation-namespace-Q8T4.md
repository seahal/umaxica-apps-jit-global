# Auth COM/ORG Translation Keys Moved to Their Own Surface Namespace

Date: 2026-10-21. Commit: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`. The worktree had other
uncommitted changes; the ones relevant here are the four locale bundles, 14 files under
`app/controllers/auth/{com,org}/` and the new invariant test named below.

## Finding

`Auth::Com` controllers referenced 69 `sign.app.*` / `views.sign.app.*` keys (88 call sites) and
`Auth::Org` one key (2 call sites), against `adr/i18n-explicit-translation-keys.md` (surface copy
under its own `sign.<surface>` namespace). First noticed on the COM telephone sign-up Turnstile
failure message.

## Change

- 60 keys copied from `sign.app.*` to `sign.com.*` (one `views.sign.app.*` to `views.sign.com.*`)
  in `config/locales/{jp,us}/{ja,en}.yml` by line insertion. A script verified, per bundle, that no
  existing key or value changed, that exactly the expected keys were added, and that each new value
  equals its source. Where the source key was missing in a bundle, it was not added there either
  (today's gaps preserved; no new copy written). +271 lines.
- 81 call sites repointed to the new keys, plus 5 call sites whose `sign.com.*` / `sign.org.*` key
  already existed with the same text.
- 5 keys whose `sign.com.*` key already existed with different text were repointed to the COM text
  (owner decision A, 10 call sites); the COM pages now show that text:
  `registration.new.page_title`, `verification.new.title`, `verification.new.description`,
  `verification.edit.title`, `verification.setup.description`.
- Guard: `test/security/invariants/auth_surface_translation_namespace_invariant_test.rb` fails when
  an Auth com/org controller or helper references a `sign.app` key. It was run Red (10 offenders)
  before the last repoint and Green after.

## Verification

- `bin/rails test` over `test/controllers/auth/{com,org}`, COM/ORG-related integration tests, every
  test that touches locales or I18n, and the guard: 1263 runs, 11 failures, 0 errors. All 11 are in
  the pre-existing failure set of the full run before this change (session fixation containment
  groups G1/G3 in `one.md`); none is new.
- RuboCop: no offenses on the changed Ruby files.

Not done: Base COM/ORG controllers still reference app keys (`sign.app.*`, `base.app.*`: 81 keys);
the `us`-over-`jp` merge issue (one.md D-40) is unchanged.
