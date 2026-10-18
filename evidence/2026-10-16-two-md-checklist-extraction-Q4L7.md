# two.md checklist extraction

- Commit: `58d2d80c5c0040cd20a125c5d4734c818d7ef0f4` on `feature`. The worktree held the user's
  uncommitted model and pgmem changes; they were not touched and the tests below ran against them.
- Actor: Claude Opus 5.5 (claude-opus-5-5). Standard Rails test database; no reset, migration,
  external write, e2e or browser check.
- Decision: the `one.md` plan was abandoned. Lasting behavior from `two.md` that this session
  verified was moved into `docs/checklists/`; `two.md` (gitignored, untracked) was then deleted.

## Command and result

`env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test <40 paths>`
covering the sign-out integration and caller tests, Palm and Tech controller and integration tests,
operator capability model and policy tests, Jump issuer, verifier, policy, surface, URL and receiver
tests, the six CSRF selector files, `xper_retired_hosts_test.rb`, the deprecation subscriber test,
`auth/route_naming_test.rb` and `auth/app/sign_ins_controller_test.rb`: 499 runs, 3,181 assertions,
0 failures, 0 errors, 0 skips, 27.9 s.

## Extracted

- New `sign-out.md` SIGNOUT-1–10 (AT-001–003, 006–011), `browser-rp.md` BRP-1–9 (AT-004, 005, 010,
  016, 046–052, 054, 078), `jump-handoff.md` JUMP-1–6 (AT-019–024).
- `authentication.md` AUTH-6 (AT-012, 013) and AUTH-7 (AT-045, 047); `authorization.md` AUTHZ-5
  (Tech delegation).

## Not extracted

- Unverified in this or earlier sessions, by the user's decision: browser acceptance, production-like
  boot, published JWKS limits (AT-024), AT-025, production queue inspection (AT-007), sign-out races
  and Inertia navigation, fleet-only cases (AT-053, 059, 060, 067–069, 072).
- Not lasting behavior: Railties default checks, environment settings (AT-031, 039, 055, 056),
  routing (owned by the routing ADR and rule), Avatar (already in `avatar-ownership.md`), governance
  (AT-076, 077), removal procedures (AT-014, 015, 017).
- AT-029 deprecation log format: verified by the run above but has no checklist owner yet.
