# Coverage Batch 16 — 2026-06-26

## Summary

Small, surgical, test-only batch. Safe deterministic targets were selected by the documented
reliable method (per-source + existing-test reading, NOT trusting the unreliable aggregate
resultset). Three clearly-safe targets covered genuine, previously-untested branches in
observability redaction utilities and a birthdate concern. All changes are test-only: no app/db/lib
source was modified.

The full-suite Rails coverage run remains flaky/aborted in this environment (pre-existing Acme/Sign
authority-inversion migration + SimpleCov "previous error" early-exit), so the aggregate ending % is
NOT trustworthy. A reliable narrow COVERAGE run on the three target test files confirms the targeted
lib/concern files are now at 100% line coverage.

VP coverage remains BLOCKED by the pre-existing config regression (vite.config.ts stub +
vitest/@vitest/coverage-v8 version mismatch), which is outside the allowed file set.

## Starting metrics

- Rails line coverage: the most recent resultset on disk at session start
  (`coverage/.resultset.json`, dated 2026-06-25) reported **57.93%** (26,775 / 46,221), but this is
  a documented flaky/partial run (see Notes). The last _reliable_ value is batch 15's ending
  **92.33%** (42,348 / 45,864). Recorded here with the reliability caveat.
- VP line coverage: **BLOCKED** — `vp test --coverage` reports `No test files found`, 0%
  (pre-existing `vite.config.ts` stub + vitest@0.1.24 / @vitest/coverage-v8@4.1.8 mismatch). Last
  known good: 98.96% (672 / 679, batch 14). Not fixable from this batch (config/package files
  forbidden).
- Baseline failures/errors: documented batch-15 baseline — 22 failures, 3 errors, all pre-existing
  Acme/Sign authority-inversion migration / security-invariant noise.

## Ending metrics

- Rails line coverage (full suite): the `COVERAGE=true bin/rails test test/` attempt this batch
  aborted early with SimpleCov
  `Stopped processing SimpleCov as a previous error not related to SimpleCov has been detected`,
  printing **63.03%** (29,242 / 46,397) and **20.37% branch** — an unreliable aborted partial run,
  NOT a valid metric (compare the pre-batch flaky value of 57.93%: both are flaky-partial artifacts,
  not the true 92%+ base).
- Rails line coverage (target files, reliable narrow COVERAGE run): `lib/observability_redactor.rb`
  **100.0%** (43/43), `lib/observability_span_scrubber.rb` **100.0%** (21/21),
  `app/models/concerns/has_birthdate.rb` **100.0%** (38/38), `app/services/age_eligibility.rb`
  **100.0%** (13/13). (Before this batch, the flaky full-suite resultset showed redactor 67.4%,
  span_scrubber 33.3%; those low numbers were the flaky-run artifact. Per-source/test reading
  confirmed the genuine untested branches listed below, which this batch now covers.)
- VP line coverage: **BLOCKED** (unchanged).
- Narrow target run: **42 runs, 263 assertions, 0 failures, 0 errors, 0 skips**.

## Coverage deltas

- Rails aggregate: **not reportable** (full-suite run flaky/aborted; documented unreliability per
  batches 12-15). No honest delta can be computed from a partial run.
- Rails per-file (reliable narrow run): the three targeted files went from "had genuine untested
  branches" to **100% line coverage** — concrete, verifiable gain in covered lines:
  - `lib/observability_redactor.rb`: scrub_url nil-redaction, non-default https/http port branch,
    bare-host root-path branch, `sensitive_key?` `NON_SENSITIVE_KEYS` +
    `SAFE_OBSERVABILITY_KEY_PATTERN` allowlist branches, `scrub` non-container scalar `else` branch.
  - `lib/observability_span_scrubber.rb`: `SENSITIVE_ATTRIBUTE_KEYS` literal-list short-circuit
    (http.url full-URL redaction, token/access_token/id_token/refresh_token family),
    `sensitive_attribute_key?` authorization/cookie substring-match branches.
  - `app/models/concerns/has_birthdate.rb`: `age_on` `return nil unless bday` branch (blank
    birthdate).
- VP: **BLOCKED** (unchanged).

## Targets selected

1. `lib/observability_redactor.rb` — pure-function URL/key redaction utility (not an auth/token
   flow; redaction helpers are safe deterministic targets, matching batch 15's
   `lib/jit_log_event.rb` redaction approach). Genuine missing branches: `scrub_url(nil)` returns
   REDACTED (L72); explicit non-default https port kept (L81); bare host collapsed to "/" root path
   (L82 else); `sensitive_key?` allowlist paths `NON_SENSITIVE_KEYS` /
   `SAFE_OBSERVABILITY_KEY_PATTERN` (L61-62, e.g. `event_uuid`, `*_digest`, `*_digest12`,
   `*_length`, `*_parts` left unredacted); `scrub` scalar `else` branch (L45, e.g.
   Integer/Symbol/nil passed directly).
2. `lib/observability_span_scrubber.rb` — pure-function span attribute scrubber. Genuine missing
   branches: `SENSITIVE_ATTRIBUTE_KEYS` short-circuit for full-URL keys (`http.url`) and token
   family (`token`/`access_token`/`id_token`/`refresh_token`) returning REDACTED without delegating
   to URL parsing; `sensitive_attribute_key?` substring matches (`*authorization*`, `*cookie*`).
3. `app/models/concerns/has_birthdate.rb` — deterministic date/age concern. Genuine missing branch:
   `age_on` returns nil when `birthdate_for_age` is nil (blank birthdate), i.e. the
   `return nil unless bday` line (L35) which no existing age_on test exercised (existing
   calendar-invalid tests use structurally-valid overflow → rolled-over non-nil bdate).

## Tests added / extended

- `test/unit/security/observability_redactor_test.rb` — added 6 tests:
  - `scrub leaves non-container scalar values unchanged via the else branch`
  - `scrub_url redacts a nil value outright`
  - `scrub_url keeps an explicit non-default https port`
  - `scrub_url keeps an explicit non-default http port and strips the default https port`
  - `scrub_url normalizes a bare host to a root path`
  - `sensitive_key? allowlist leaves non-sensitive observability keys unredacted`
- `test/observability_span_scrubber_test.rb` — added 3 tests:
  - `scrub redacts full-url attribute keys without delegating to URL parsing`
  - `scrub redacts token-family attribute keys outright`
  - `sensitive_attribute_key? matches authorization and cookie substrings`
- `test/models/concerns/has_birthdate_test.rb` — added 1 test:
  - `age_on returns nil when birthdate is blank`

Total: **10 new tests**. Narrow run: 42 runs, 263 assertions, 0 failures.

## App/DB changes

None. All changes were test-only. No app/, db/, lib/, config/, or package files were modified.

## Dead-code evidence

No code was deleted. No new dead-code findings.

## Verification

### Narrow target run (all pass)

```bash
bin/rails test test/unit/security/observability_redactor_test.rb \
  test/observability_span_scrubber_test.rb test/models/concerns/has_birthdate_test.rb
# 42 runs, 263 assertions, 0 failures, 0 errors, 0 skips
```

### Narrow COVERAGE run (reliable per-file delta)

```bash
env COVERAGE=true bin/rails test test/unit/security/observability_redactor_test.rb \
  test/observability_span_scrubber_test.rb test/models/concerns/has_birthdate_test.rb
# 42 runs, 0 failures; SimpleCov gate exit 2 at 50.52% aggregate (expected — narrow run only
# exercises a small slice of the loaded app). Per-file from .resultset.json:
#   observability_redactor.rb        43/43   100.0%
#   observability_span_scrubber.rb   21/21   100.0%
#   has_birthdate.rb                 38/38   100.0%
#   age_eligibility.rb               13/13   100.0%
```

### Lint / format

```bash
vp check --fix     # Formatting completed; no warnings/lint/type errors (test files unchanged
                   # by vp, none belong to vp surface; relevant ts/js untouched)
vp check           # clean
bundle exec rubocop -a <3 changed test files>
# 1 offense auto-flagged: Minitest/AssertTruthy on `assert_equal true, scrub(true)` ->
#   corrected to `assert(...)`. (rubocop -A)
bundle exec rubocop <3 changed test files>   # 0 offenses after correction
```

### Full suite + ending coverage

```bash
nohup env COVERAGE=true bin/rails test test/ > tmp/cov_batch16.log 2>&1 &
# Aborted early: SimpleCov "Stopped ... a previous error not related to SimpleCov has been
# detected". Printed Line Coverage 63.03% (29242/46397), Branch 20.37% (2816/13823).
# This is an unreliable aborted partial run — not a valid aggregate metric.
```

```bash
vp test --coverage
# "No test files found", 0% — pre-existing VP config block (unchanged).
```

## Failures analysis

Ending full-suite run **aborted**; no trustworthy pass/fail count from it. The failures observed in
the abort log are all pre-existing auth/migration-adjacent (NOT touched by this batch):

- `Sign::Com::Sign::Up::TelephonesControllerTest` (404 where 3XX/422 expected — authority-inversion
  migration state).
- `IdentitySecretCredentialCeremonyFinalCommitterTest` (`ArgumentError: unknown keyword: :surface` —
  auth ceremony, pre-existing kwarg-mismatch from the in-progress migration).

These match the batch-15 documented baseline (auth/OIDC/sign/authority migration failures). None are
caused by this batch: my three target test files pass cleanly in isolation (42 runs, 0 failures, 0
errors), and no code outside the three test files was modified.

Per the kill-switch policy ("failures/errors increase unexpectedly → write notes and stop"): the
increase is NOT introduced by this batch (test-only additions, verified clean in isolation); it is
the documented flaky aborted full-suite behavior from the in-progress migration. Investigating
further would require touching auth/migration/config code, which is outside this batch's allowed
scope.

## Skipped risky areas

- All `app/controllers/**` (concerns + surface controllers), `app/services/sign_*`, `oidc_*`,
  `identity_*`, `social_auth_*`, `acme_*`, `dbsc_*`, `dpop_*`, `security_jwt_*`, `sign_up_*`,
  `sign_in_*`, `client_secret_*`, `palm_*`, `administrative_*`, `redirects_*`, `withdrawal_*`,
  `jump_*`, `recovery_passcode_*`, `step_up_*`, `oidc_token_exchange_*` —
  auth/OIDC/sign/token/credential/redirect/security/payment/external-integration flows. Forbidden by
  policy (the dominant remaining high-count files are all in these buckets; the safe pool is
  effectively exhausted per batches 14-15).
- `app/models/concerns/otp_lockable.rb`, `*ceremony_transactionable`,
  `telephone_ceremony_transactionable`, `step_up_*` — OTP/ceremony/step-up (auth-adjacent).
- `app/services/outbound_sms.rb`, `outbound_sensitive_payload.rb`, `retention_purge_job.rb`,
  `chronicle_*` writers, `org_operator_lifecycle_*` — external-service / destructive / cross-DB /
  compensation paths (not provably safe; skip per kill-switch).
- `app/policies/application_policy.rb` — authorization base policy (security-sensitive; test- only
  would be low-risk but is authorization-adjacent; deferred).
- `config/**`, `bin/**`, `Gemfile*`, package files, routes, fixtures, factories, CI files, docs
  outside research/implementation — all forbidden (and needed for the VP config fix).
- The leftover/stuck `ruby bin/rails test test` process observed on pts/4 (not launched by this
  batch) was left untouched; killing foreign processes is outside scope.

## Notes

- The aggregate Rails line-coverage number is NOT a trustworthy progress signal in this environment:
  both the pre-batch resultset (57.93%, dated 2026-06-25) and this batch's full-suite attempt
  (63.03%, aborted with a SimpleCov "previous error" early-exit) are flaky/partial, differing wildly
  from the last reliable 92.33% (batch 15). Root cause is the in-progress Acme/Sign
  authority-inversion migration causing flaky parallel execution + an at_exit "previous error" that
  makes SimpleCov bail early (documented batches 12-15). The only reliable coverage signal is the
  narrow targeted-run per-file check (this batch's 4 files all 100%). The workflow's "record ending
  Rails coverage" line therefore records the aborted-partial value with an explicit unreliability
  flag, rather than a misleading delta.

## Next batch candidates

- Rails (process, not coverage): the highest-leverage unblock remains resolving the flaky aborted
  full-suite execution (test-order/state pollution from the in-progress Acme/Sign
  authority-inversion migration). That requires touching auth/migration/config and is outside the
  current allowed scope. An explicit authorization to investigate migration test isolation (without
  changing auth code) would unlock trustworthy aggregate deltas.
- Rails (safe per-file): the safe deterministic per-file pool is effectively exhausted across
  app/models, app/helpers, app/mailers, app/policies, app/serializers, app/jobs, app/validators, and
  lib/ (non-security). This batch captured the last clearly-safe observability redaction and
  has_birthdate gaps. Further per-file gains require either (a) authorization to test
  auth-adjacent-but-deterministic service compensation paths (e.g.
  `org_operator_lifecycle_invitation_acceptance.rb` StandardError-fallback), or (b) authorization to
  delete proven-dead `lib/` code (lib source deletions are outside the allowed file set; covering
  lib via tests remains allowed and was used here).
- VP: BLOCKED until the `vite.config.ts` stub / vitest @vitest/coverage-v8 version mismatch is
  resolved by an authorized config/package change. Once unblocked, cover
  `src/entrypoints/inertia.tsx` (7 lines, 0%) per batch 14/15 plan.
