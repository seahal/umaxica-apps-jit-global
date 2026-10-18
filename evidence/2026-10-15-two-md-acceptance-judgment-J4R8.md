# two.md acceptance judgment from code and test execution

- Commit: `297addaed7333ef05f00059f64af08b579227e18` on `feature`. The worktree was clean.
- Actor: Claude Opus 5.5 (claude-opus-5-5), effort medium.
- Scope: judgment of every active case in `two.md` (AT-001 to AT-078 without the withdrawn AT-027,
  AT-028, AT-033, AT-043 and the on-hold AT-044: 73 cases). Earlier `evidence/` records were
  deliberately not used as a basis; the judgment rests only on the observations below.
- `one.md` SHA-256 `663bb1a858f537edde4da80e53631a73e08a8022c59123fb2df391601d4cbe4c`, `two.md`
  SHA-256 `7297a6e0eb52fc4df2768c926e084297e654f827c0acd83f0d462c6c8ae4086d`.
- No application, test or configuration file was changed. No database reset, migration, isolated
  fleet, external write or browser check was performed.

## Commands and results

- Selector run, standard test database:
  `env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test <55 paths>`
  covering the existing `two.md` selectors for sign-out, Device, Xper, Avatar, routing, Railties
  subscriber, CSRF, Jump (including the nine existing `jwks_controller_test.rb` files), Palm, Tech,
  operator capability and Prosopite. Result: 797 runs, 6,474 assertions, 0 failures, 11 errors, 0
  skips; exit 0 reported by the wrapper. All 11 errors are
  `RuntimeError: committed tests require run-owned worker receipts` in
  `AvatarConcreteOwnershipPeriodTest` (5) and `AvatarOwnershipTransfersConcurrencyTest` (6).
- `bin/rails routes` (development boot succeeded): Palm and Tech expose `/sign` GET/POST,
  `/oidc/callback`, `/sign/out`, `/sign/out/completion` and `/dashboard`; Tech has no JWKS route.
- `ruby scripts/check_frozen_string_literal_directives.rb`: 10 files under `bin/` lack the
  directive.
- Searches over `app`, `config`, `lib`, `.env*`, `.devcontainer`: no BCL symbol (comments in
  `config/routes/auth.rb` only), no Xper reference, no Device Sign In mock reference, no Palm native
  client, authenticator, coordinator or profile reference, no `offline_access`.
- Not run: e2e (Playwright), Vitest, the full Minitest suite, a production-like boot, Strict Loading
  diagnostics, migration replay.

## Results

| Result                                                                      | Count | Cases                                                                                            |
| --------------------------------------------------------------------------- | ----- | ------------------------------------------------------------------------------------------------ |
| PASS                                                                        | 12    | AT-014, 016, 018, 019, 020, 021, 022, 023, 045, 047, 051, 071                                    |
| Automated part passes; manual, production-like or listed residue unverified | 19    | AT-001, 004, 005, 006, 007, 010, 012, 015, 017, 024, 029, 046, 048, 049, 054, 070, 074, 075, 078 |
| FAIL                                                                        | 3     | AT-008, 039, 077                                                                                 |
| BLOCKED                                                                     | 12    | AT-011, 025, 053, 055, 056, 059, 060, 067, 068, 069, 072, 073                                    |
| Not judged (coverage missing or not re-verified)                            | 27    | AT-002, 003, 009, 013, 026, 030, 031, 032, 034–038, 040–042, 050, 052, 057, 058, 061–066, 076    |

PASS share: 12 / 73 (16%). Including the second row: 31 / 73 (42%). The second row is not PASS under
the `two.md` result rules.

Reasons for the non-PASS rows:

- AT-008 FAIL: the Browser RP completion page renders `sign.shared.sign_out.completed_description`
  ("Access will be unavailable after %{expires_at}") from the RP access `exp`
  (`app/controllers/concerns/sign_out_notice.rb:214`,
  `app/controllers/concerns/oidc_rp_logout_launcher.rb:478`); `two.md` requires that no output
  states an end time. The REQ-008 global wording is absent from the locale bundles, and the six
  states are not distinguished.
- AT-039 FAIL: the 10 `bin/` files above lack the directive.
- AT-077 FAIL: three `[CHECKPOINT]` commits break one commit per step; checkpoint `7d4e2d941`
  emptied the structure dumps, later restored by `fef6f6fb3`.
- AT-002 and AT-009: no test varies parent P2, another device, root family, regressed generation or
  HEAD on the Browser RP authority path, and none checks the 10-minute intent expiry
  before/at/after; existing boundary tests target the 5-minute staged end-session path.
- AT-050 and AT-052: `test/integration/tech_org_sign_in_test.rb` and
  `test/integration/tech_org_access_revocation_test.rb` do not exist; no refresh-path, database/key
  failure or Host-tampering Tech case was found.
- BLOCKED rows need the isolated fleet or the user's browser acceptance.

## Implementation findings for the user's decision

1. AT-008 wording and end-time output, above.
2. `AuthenticationLogoutCurrentSession` logs `resource_id`, `token_id` and `error_message`
   (`device_session_failed`, `cycle_unavailable`), against the REQ-008 log restriction.
3. After the parent COMMIT, a failed AppTicket progress write raises `RpSession::IssuanceRejected`
   and `OidcRpLogoutAuthority` answers a bare 404, hiding the committed sign-out (AT-003).
4. The authority and binding match runs before the Device → root → RP lock and is not repeated under
   it (REQ-002).
5. `sign_out_refresh_expires_at` substitutes `100.years.from_now` for an infinite `discard_at`.
6. `OidcConnectionRevoker` and session-limit `resolve!` call the primitive inside an outer
   transaction, so its COMMIT is a savepoint and the unknown-outcome re-read does not apply.
7. `DeprecationNotificationSubscriber` raises on malformed payloads in production, and sets
   `truncated` when content was only redacted.
8. `config/environments/test.rb` enables `rake_eager_load` for `CI=false`.
9. `test/fixtures/files/jump_fixtures_0_4_0.md` records the 0.3.0 fixture at the same source commit
   and path as the 0.4.0 fixture with a different hash.
10. `fail_sign_out_flow` writes inside an already aborted transaction and swallows its error.

## Plan findings for the user's decision

- `one.md` counts eleven callers of the shared parent sign-out primitive; 17 call sites exist.
- AT-024 names thirteen `jwks_controller_test.rb` files; nine exist and Tech has no JWKS route.
- `one.md` says the `:rp_session` revoker scope is not used by the flow; origin cleanup uses it.
- REQ-008 fixes the completion wording but the owner table omits `SignOutNotice`.
- Isolated-fleet cases and a clean full suite are unreachable under the standard-database-only
  constraint (CHG-003); fleet authorization was not a GO precondition.
- AT-039 assumes a writable `bin/`; it is a read-only mount.
- AT-009 rejects binding version 0, while version 0 stays valid for non-Browser-RP workflows.

## Estimate

Remaining agent work, excluding the user's browser acceptance: about 20–30 hours (wording and states
3–5, AT-002/003/009 tests and post-COMMIT display 5–8, Tech integration tests 3–4, Railties and
older Avatar re-verification 4–6, isolated-fleet runs and full suites 4–6 if authorized). This is an
estimate, not a measurement.
