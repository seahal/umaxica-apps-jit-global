# Acceptance follow-up implementation (items 1–10 of the 2026-10-15 judgment)

- Base: `dcb58ea81` on `feature`; final commit of the code changes `e4ee9dabd`, documentation
  `975d9a535`. Each item was committed separately with its targeted tests passing.
- Actor: Claude Opus 5.5 (claude-opus-5-5). User GO given in session on 2026-10-15.
- Databases: standard Rails development/test databases only; the isolated fleet is retired and its
  cases are EXCLUDED (`three.md` CHG-009). No reset, migration, external write or push.
- Source judgment: `evidence/2026-10-15-two-md-acceptance-judgment-J4R8.md`.

## Changes

| Item | Commit                                | Cases                  | Change                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ---- | ------------------------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1, 3 | `01ca0edf6`                           | AT-008, AT-003, AT-009 | Completion wording states the global result with no end time; a failure after the parent COMMIT (origin cleanup or AppTicket progress, at the origin or at Base) shows the global result with "cleanup incomplete" (200) instead of "not completed" (422) or 404; an unreadable parent or lost COMMIT is indeterminate (503, no retry); unused end-time `success` key and the access-expiry plumbing removed. `AcmeLogoutTransactionCoordinator.parent_revoked?` reads the parent on the realm Ticket writer. |
| 2    | `2de7f5017`                           | AT-008                 | `resource_id`, `token_id` and `error_message` removed from the shared sign-out primitive's logs.                                                                                                                                                                                                                                                                                                                                                                                                              |
| 4    | `494292e08`                           | AT-002                 | The primitive takes a `precondition:` evaluated after locking the parent Device Session; Base re-checks authority and root binding there and stops with the IdP session error when it no longer holds.                                                                                                                                                                                                                                                                                                        |
| 5    | `a1b38f0f4`                           | AT-002, AT-009         | New `test/integration/oidc_rp_logout_binding_partitions_test.rb`: rotated root accepted; other family, regressed generation, other device, substituted identifiers refused; GET/HEAD inert; forged CSRF and cross-site refused; intent expiry at −1 s / 0 / +1 s; COMMIT before expiry with expired continuation; intent reuse per RP session and browser; proof filtered and absent from redirects. Shared helper `test/support/browser_rp_logout_flow_helper.rb`.                                           |
| 6    | `1e7f5a42b`                           | AT-008, AT-050         | Defect found by the new tests: `SecurityConsumedJti.consume!` wrote on the reading role during GET, so every safe-request Browser RP refresh failed with `ReadOnlyError` and sent the user to sign-in. It now writes on the writer.                                                                                                                                                                                                                                                                           |
| 6    | `1110d75c8`                           | AT-048, AT-050, AT-052 | New `test/integration/tech_org_sign_in_test.rb` and `test/integration/tech_org_access_revocation_test.rb`. Tech has no protected unsafe action, so the unsafe refresh path has no Tech subject; the safe path is covered, including a positive control.                                                                                                                                                                                                                                                       |
| 7    | `9d7b9fc0f`                           | AT-003                 | New `test/services/parent_sign_out_callers_test.rb`: selected-session, all-sessions, account emergency, risk and credential-transition callers revoke parent and RP rows with no enqueued job. 59 caller test files: 663 runs, 0 failures.                                                                                                                                                                                                                                                                    |
| 8    | `4420a24a4`, `b2a753da9`, `e4ee9dabd` | AT-008, AT-031, AT-029 | No invented 100-year expiry; `rake_eager_load` only for `CI=true`; deprecation subscriber logs `rails.deprecation.unrecordable` (error class only) instead of raising into the request.                                                                                                                                                                                                                                                                                                                       |
| 10   | `975d9a535`                           | —                      | `docs/security/logout-session-management.md` records the parent-derived displays.                                                                                                                                                                                                                                                                                                                                                                                                                             |

## Verification

- Full Minitest at `e4ee9dabd` (code identical to HEAD; only docs followed):
  `env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test`: 15,286
  runs, 129,697 assertions, 0 failures, 14 errors, 0 skips, 972 s. All 14 errors are
  `committed tests require run-owned worker receipts` (Avatar, EXCLUDED by CHG-009). No
  `StrictLoadingViolationError`. Clean under CHG-009.
- Vitest `bun run test`: 100 files, 1,156 tests passed.
- Strict Loading (AT-055/056), executed in the test environment: default `true`, mode `all`, action
  `raise`, `verbose_query_logs` true, log level info (1); unloaded `belongs_to` and `has_many` both
  raise `StrictLoadingViolationError`; `includes` succeeds for both (records created and rolled
  back). Development keeps `n_plus_one_only` / `raise`, unchanged.
- `CI` matrix for AT-031 (executed): unset/false/1/empty → false, true → true; `bin/rails -T`
  starts.
- Railties default rows (executed or Rails source at `rails-ba3572c87404`): AT-026 nonexistent
  environment exits 1 with `missing_environment_file`; AT-030 `warn_about_missing_controllers`
  present, no warning task added; AT-032 DevTools route is Rails' internal route, no app route;
  AT-034 no bulk `Rails.app` replacement in the diff; AT-035 revision readable, no guard added;
  AT-036 console executor default on, query cache off unless `-q`; AT-037 Rack::Sendfile from Rails'
  default stack, no config change; AT-038 no query wrapper; AT-040 invalid plugin subcommand exits
  1; AT-041 no locale initialization change; AT-042 banner default true, `--no-banner` available.
  All PASS.
- AT-013: 44 sign-in test files (Auth app, Social, Passkey, Secret, Email OTP, org emergency
  Passkey): 287 runs, 0 failures; the Device retirement commits touch no Device Session, DBSC or
  device-management file. e2e was not run.
- AT-057: drafts stay under `specs/avatar-organization-ownership/migration-drafts/`, outside every
  `migrations_paths`; applied migrations differ from the baseline only by the frozen string
  directive; two new migrations were added by the plan.
- Avatar tests (75 files): 467 runs, 0 failures, 14 errors, all the excluded guard.
- AT-062/063/065 selectors (`avatar_retention_purge_test`, `avatar_ownership_transfers_test`,
  `avatar_transfer_reservation_test`, the three backfill tests): 51 runs, 0 failures, 2 errors; both
  errors are the concurrent cases stopped by the excluded guard.

## Updated results

| Result                                                          | Cases                                                                                                                                                                                                                                                                       |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PASS                                                            | AT-002, 003, 009 (automated parts), 012, 013, 014, 016, 018–023, 026, 030, 031, 032, 034–038, 040–042, 045, 046, 047, 048, 049, 050, 051, 052, 054, 055, 056, 057, 058, 061, 062, 063, 064, 065, 066, 070, 071 (062, 063, 065: sequential cases; concurrent cases EXCLUDED) |
| Automated part passes; user browser or production check remains | AT-001, 004, 005, 006, 007, 008, 010, 011, 015, 017, 024, 025, 029, 074, 075, 078                                                                                                                                                                                           |
| EXCLUDED (CHG-009)                                              | AT-053, 059, 060, 067, 068, 069, 072, AT-039 migration replay, fleet parts of 062, 063, 065, 073                                                                                                                                                                            |
| Open                                                            | AT-073 closure; AT-076 needs an independent reviewer; AT-077 has three earlier `[CHECKPOINT]` commits                                                                                                                                                                       |

## Not changed, for the user's decision

- AT-029 `truncated` is still set when content was only redacted; changing it alters the fixed field
  list of AT-029.
- `OidcConnectionRevoker` has no application caller (tests only).
- e2e (Playwright) was not run.
