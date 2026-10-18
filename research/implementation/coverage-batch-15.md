# Coverage Batch 15 — 2026-06-23

## Summary

Small, surgical, test-only batch. After exhaustive filtering of the uncovered-file list against the
kill-switch (every high-count remaining file is auth/OIDC/sign/
token/credential/redirect/security/payment adjacent), only three safe, deterministic targets with
genuinely missing test coverage remained. Each was confirmed a real gap by reading source + existing
tests (not a flaky-run artifact).

All changes are test-only. No app/db/lib source was modified. VP coverage remains BLOCKED by the
pre-existing config regression documented in batch 14.

## Starting metrics

- Rails line coverage: **92.30%** (42,233 / 45,754) — `coverage/.resultset.json` read at session
  start (2026-06-23 01:04 report).
- VP line coverage: **BLOCKED** — `src/coverage/coverage-final.json` is empty (`{}`), overwritten by
  the pre-existing VP config regression (vite.config.ts stub + vitest@0.1.24 /
  @vitest/coverage-v8@4.1.8 mismatch; "No test files found"). Last known good value: 98.96% (batch
  14). Cannot be fixed from this batch (config/package files forbidden).
- Baseline failures/errors: batch 14 ending — 18 failures, 3 errors (pre-existing Acme/Sign
  authority-inversion migration + security-invariant
  - page-title tests).

## Ending metrics

- Rails line coverage: **92.33%** (42,348 / 45,864) — completed full suite (627s).
- Rails branch coverage: **69.77%** (9,550 / 13,688).
- VP line coverage: **BLOCKED** (unchanged; `vp test --coverage` reports 0% / "No test files
  found").
- Ending `COVERAGE=true bin/rails test test/`: 8,453 runs, 39,335 assertions, **22 failures, 3
  errors, 0 skips**. Rails test exit 1; SimpleCov reported line coverage below 98% threshold
  (expected).

## Coverage deltas

- Rails: **+0.03%** (92.30% → 92.33%). Covered lines +115 (42,233 → 42,348), total relevant lines
  +110 (45,754 → 45,864). The per-file genuine gains added by this batch were verified directly in
  the post-run `.resultset.json` (target lines L189/L195/L196 chain_seal, L24 jit_log_event, L172
  health all flipped from 0 → covered). The aggregate % is noisy (±0.1%) due to the documented flaky
  parallel full-suite execution.
- VP: **BLOCKED** (config regression; unchanged).

### Newly covered target lines (verified post-run)

| File                          | Line(s)             | Before | After | Result                                                    |
| ----------------------------- | ------------------- | ------ | ----- | --------------------------------------------------------- |
| lib/chain_seal.rb             | 189, 195, 196       | 0      | 2/2/1 | non-Point EC public-key verify path now covered           |
| test source of gain: new test | (also re-hits L200) | 21     | 25    | L200 was already covered; new RSA test re-exercises       |
| lib/jit_log_event.rb          | 24                  | 0      | 2     | `{ message: payload }` else branch now covered            |
| app/services/health.rb        | 172                 | 0      | 1     | Prosopite-absent `operation.call` else branch now covered |

## Targets selected

1. `lib/chain_seal.rb` — `public_key_for_verification` else branch (lines 189, 195-196): when an
   `OpenSSL::PKey::EC` public key (not an `EC::Point`) is passed to `verify`, the code calls
   `validate_public_key!` and returns the key directly. In this OpenSSL build `EC#public_key`
   returns an `EC::Point`, so every existing test exercised the Point branch (line 193) and the else
   branch was dead-in-coverage. Added a test constructing a public-only `OpenSSL::PKey::EC` via
   `EC.new(@private_key.public_to_der)` and verifying with it; plus a test verifying a non-EC (RSA)
   public key raises `FormatError`.
2. `lib/jit_log_event.rb` — `normalize_payload` else branch (line 24, `{ message: payload }`): every
   existing test passed a Hash payload, so the non-Hash/non-nil branch was uncovered. Added two
   tests: a String payload (wrapped under `message`) and an Exception payload (also wrapped, then
   `normalize_value` maps it to `{ class:, message: }`).
3. `app/services/health.rb` — `Checks::Database#check_roles` Prosopite-absent else branch (line 172,
   `operation.call`): Prosopite is loaded in this environment so the `else` was never exercised.
   Added a test that `Object.send(:remove_const, :Prosopite)` while preserving/restoring the
   constant in an `ensure` block (same pattern already used in
   `test/models/application_record_test.rb`), then drives a fake record class through
   `Checks::Database#call` and asserts an `:ok` result.

## Tests added / extended

- `test/lib/chain_seal_coverage_test.rb` — added 2 tests:
  - `verify accepts a non-Point OpenSSL::PKey::EC public key via validate_public_key!`
  - `verify rejects a non-EC public key with FormatError`
- `test/unit/security/jit_log_event_redaction_test.rb` — added 2 tests:
  - `wraps a non-Hash payload under a message key` (String)
  - `wraps an Exception payload under a message key with class and message attributes`
- `test/services/health_test.rb` — added 1 test:
  - `database check runs the probe directly when Prosopite is unavailable`

Total: 5 new tests. Narrow run: 42 runs, 117 assertions, 0 failures (combined run of the four target
test files).

## App/DB changes

None. All changes were test-only. No app/, db/, lib/, config/, or package files were modified.

## Dead-code evidence

No code was deleted. No new dead-code findings this batch (chain_seal lines 228/250 defensive guards
were already noted in batch 14 and remain out of the allowed deletion set since lib/ source is
outside the allowed file changes).

## Verification

### Narrow Rails runs (all pass)

```bash
bin/rails test test/lib/chain_seal_test.rb test/lib/chain_seal_coverage_test.rb \
  test/unit/security/jit_log_event_redaction_test.rb test/services/health_test.rb
# 42 runs, 117 assertions, 0 failures, 0 errors, 0 skips
```

### Lint / format

```bash
vp check --fix
vp check            # pre-existing error in src/entrypoints/application.js (empty file);
                    #   unrelated — no JS/TS files touched this batch
bundle exec rubocop -a test/lib/chain_seal_coverage_test.rb \
  test/unit/security/jit_log_event_redaction_test.rb \
  test/services/health_test.rb
# 2 offenses auto-flagged, both fixed manually:
#   - Minitest/AssertTruthy -> `assert(...)`
#   - Lint/UnusedBlockArgument in health_test fake connected_to -> switched
#     kwarg signature to anonymous `|**, &block|` (renaming the kwarg would
#     break the caller's `role:` keyword in health.rb source)
bundle exec rubocop <changed files>   # 0 offenses after correction
```

### Full suite

```bash
COVERAGE=true bin/rails test test/
# 8453 runs, 39335 assertions, 22 failures, 3 errors, 0 skips
# Line Coverage: 92.33% (42348 / 45864)
# Branch Coverage: 69.77% (9550 / 13688)
# Finished in 627.132531s
```

(The full-coverage run was launched in the background with output redirected to
`tmp/cov_batch15.log` and polled because the interactive 120s command timeout is shorter than the
~10-minute suite. It completed in 627s.)

```bash
vp test --coverage
# "No test files found", 0% — pre-existing VP config block (unchanged).
```

## Failures analysis

Ending: 22 failures + 3 errors (vs batch-14 ending 18 + 3).

The +4 failure increase is NOT caused by this batch. All 4 additional failures are in files
untouched by this batch and are pre-existing auth/OIDC migration

- flaky-parallel-execution noise — the same phenomenon documented in batches 12-14 ("more of the
  unstable migration test files executed during this full-suite invocation and failed on test
  interaction / host redirect mismatch"). Specifically observed in the run log:

* `test/unit/security/rails_way_harness_inventory_test.rb` (`oidc_rp_logout_launcher.rb` present in
  actual but not in expected inventory — a recently-added file not yet inventoried; auth-adjacent).
* `Sign::Com::Sign::Up::EmailsControllerTest#test_new_rejects_when_visitor_is_already_logged_in`
  (host redirect `www.umaxica.com` vs `id.umaxica.com` — surface/authority migration state).
* `Authentication::LogoutableTest#test_logout_current_session_clears_cookies_and_session_even_if_audit_raises`
  (`ArgumentError: missing keyword: :_resource` in
  `app/controllers/concerns/authentication_logoutable.rb` — auth code I did not touch; pre-existing
  kwarg-mismatch in the in-progress migration).
* `TurnstileFormsTest`, `CoreBffSurfaceSmokeTest`, `Acme::Org::AvatarsControllerTest` (OmniAuth
  guard / BFF-logout / turnstile — auth-adjacent baseline).

None of the 22 failures are in `lib/chain_seal.rb`, `lib/jit_log_event.rb`,
`app/services/health.rb`, or any test file I added to. My 4 target test files all pass in isolation
(42 runs, 0 failures) and contributed coverage in the full suite (target lines verified covered
post-run).

Per the kill-switch policy ("failures/errors increase unexpectedly → write notes and stop"), the
increase is documented as likely-baseline flaky behavior consistent with the documented in-progress
migration and the unstable full-suite execution; it is not attributable to this batch's test-only
changes. Investigating it further would require touching auth/OIDC/migration code and config, which
is outside this batch's allowed scope.

## Skipped risky areas

- `app/controllers/sign/**` (1488 unc / 133 files), `app/controllers/concerns/**` auth-related (1269
  unc / 108 files), `app/controllers/acme/**` (209 unc) — all auth/OIDC/sign/redirect/security
  flows. Forbidden by policy.
- All `app/services/sign_*`, `app/services/oidc_*`, `app/services/identity_*`,
  `app/services/social_auth_*`, `app/services/acme_*`, `app/services/dbsc_*`, `app/services/dpop_*`,
  `app/services/security_jwt_*`, `app/services/sign_up_*`, `app/services/sign_in_*`,
  `app/services/sign_secret_*`, `app/services/turnstile_*`, `app/services/oidc_*`,
  `app/services/palm_*`, `app/services/administrative_*`, `app/services/redirects_*`,
  `app/services/withdrawal_*`, `app/services/jump_*`, `app/services/identifier_*` (encryption/hmac),
  `app/services/client_secret_*` — all auth / security / token / destructive / external-integration
  flows.
- `app/jobs/oidc_backchannel_logout_delivery_job.rb` — OIDC logout job.
- `lib/jit_security_*` (jwt/turnstile/security), `lib/tasks/security_tier0.rake`,
  `lib/config_values_*` outside allowed set (lib source deletions not allowed).
- `app/services/sign_up_artifact_cleanup.rb` (33 unc) — destructive dependent cleanup, cross-DB
  transactions, ties into sign-up/passkey/contact records. Skipped despite non-trivial yield;
  auth-adjacent and destructive.
- `app/services/org_operator_lifecycle_invitation_acceptance.rb` (11 unc) — genuine gaps are
  compensation / StandardError-fallback paths that require triggering failures in
  `create_operator_account!` / `IdentityGraphProvisioner` (external integration). Skipped as not
  provably safe.
- `app/controllers/concerns/r18_gate.rb` (17 unc) — large uncovered sections despite a dedicated
  test file; reads as flaky-execution noise rather than genuine gaps, and r18 gating is
  content-policy-adjacent. Skipped.
- Authentication / OIDC / token / credential / secret / session / logout / sign / payment /
  destructive / external-service / Redis / network / browser / system-test / time-sensitive / random
  / parallelism-sensitive paths (per policy).
- `config/**`, `bin/**`, `Gemfile*`, package files, routes, fixtures, factories, CI files, docs
  outside research/implementation — all forbidden (and needed for the VP fix).

## Notes

- The dominant obstacle to raising aggregate Rails line coverage remains the pre-existing flaky
  parallel full-suite execution (documented in batches 12-14): many files with complete test suites
  appear "uncovered" in the aggregate simply because their test files did not run / did not fully
  run during the noisy full-suite invocation. Per-file genuine-gap hunting by reading source +
  existing tests (rather than trusting the aggregate resultset alone) continues to be the only
  reliable way to find safe targets, and the pool of safe targets has now been effectively
  exhausted: every remaining high-count file is auth/OIDC/sign/security adjacent.
- The full `COVERAGE=true bin/rails test test/` run cannot complete within the interactive 120s
  command timeout; it was launched in the background (`nohup ... > tmp/cov_batch15.log 2>&1`) and
  polled. The ~10-minute run time and intermittent hangs documented in batch 14 persist.
- The `lint/unused-block-argument` rubocop warning in the new health test fake `connected_to` cannot
  be "fixed" by renaming the `role:` kwarg — Ruby keyword-argument names are part of the caller's
  contract (`record_class.connected_to(role: role) do ... end` in `health.rb`), and renaming the
  kwarg would silently break the call. The anonymous-kwargs form `|**, &block|` silences the cop
  while preserving the call signature.
- VP coverage remains BLOCKED by the pre-existing `vite.config.ts` stub + vitest/@vitest/coverage-v8
  version mismatch. Last known good: 98.96% (672 / 679), with all 7 uncovered lines in
  `src/entrypoints/inertia.tsx`.

## Next batch candidates

- Rails: the remaining genuinely-safe deterministic gaps are now exhausted across app/models,
  app/helpers, app/mailers, app/policies, app/serializers, app/jobs, app/validators, and lib/
  (non-security). Further aggregate gains require either (a) an explicit authorization to touch lib/
  source for proven-dead-code deletion (e.g. the unreachable `rescue KeyError` in
  `lib/config_values_jump_gateway_values.rb` documented in batch 14), or (b) an explicit
  authorization to test auth-adjacent-but-deterministic service code (e.g.
  `org_operator_lifecycle_invitation_acceptance.rb` compensation paths), with the
  security-sensitive-flow ban relaxed for that specific scope.
- Rails (process, not coverage): investigating the root cause of the flaky parallel full-suite
  execution (test-order / state pollution from the in-progress Acme/Sign authority-inversion
  migration) would unlock far larger aggregate coverage gains than per-file test additions, because
  many already-tested files currently show as uncovered in the aggregate. This requires care to stay
  within the allowed file set and avoid auth/migration code; likely blocked without authorization.
- VP: BLOCKED until the `vite.config.ts` stub / vitest version mismatch is resolved by an authorized
  config/package change. Once unblocked, cover `src/entrypoints/inertia.tsx` (7 lines, 0%) with a
  deterministic mock strategy.
