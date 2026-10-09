# Coverage Batch 14 — 2026-06-23

## Summary

This batch targeted GENUINELY uncovered code paths in safe, deterministic library and concern files.
All changes were test-only (no app/db/lib source modifications).

A key finding this batch: the Rails `.resultset.json` aggregate is heavily skewed by pre-existing
flaky parallel test execution. Many files that appear "uncovered" in the report (e.g.
`safe_promotional_cta_url.rb`, `application_policy.rb`, `sign/common_helper.rb`,
`sign/org/sign_ups_helper.rb`, `has_birthdate.rb`) actually have COMPLETE existing test suites —
their test files simply did not execute during the flaky full-suite run. This batch therefore
focused on files where careful source-vs-test reading confirmed branches with NO existing test
coverage, rather than chasing aggregate numbers inflated/deflated by flakiness.

Six target files reached 100% line coverage; two more reached near-100% with only defensive/dead
lines remaining.

## Starting metrics

- Rails line coverage: **92.34%** (41,997 / 45,479 relevant lines) — from batch-13 report
  (coverage/.resultset.json, 2026-06-22).
- Rails branch coverage: ~69.7% (from batch-12/13).
- VP line coverage: **98.96%** (672 / 679 lines) — from src/coverage/coverage-summary.json read at
  session start (2026-06-20 report). NOTE: this report was later overwritten by an empty
  `vp test --coverage` run (see VP block below).
- Baseline failures/errors: pre-existing failures from in-progress Acme/Sign authority-inversion
  migration plus security-invariant and page-title tests (see TEST_FAILURE_TRIAGE_2026-06-20.md).
  Batch 13 recorded 10 failures, 3 errors.

## Ending metrics

- Rails line coverage: **92.31%** (42,238 / 45,779 relevant lines) — from completed full suite
  (624s).
- Rails branch coverage: **69.73%** (9,493 / 13,614 branches).
- VP line coverage: **BLOCKED** — `vp test` / `vp test --coverage` find no test files and report 0%
  due to a pre-existing config regression (see VP block). Last known good value: 98.96% (672 / 679).
- Ending `COVERAGE=true bin/rails test test/`: 8,439 runs, 39,286 assertions, 18 failures, 3 errors,
  0 skips (exit 2 due to SimpleCov 98% threshold).

## Coverage deltas

- Rails: **-0.03%** (92.34% → 92.31%). Covered lines INCREASED by 241 (41,997 → 42,238), but total
  relevant lines increased by 280 (45,479 → 45,779) and the flaky full-suite run still did not
  execute every pre-existing test file. The aggregate percentage is therefore noisy (±0.1%) and does
  NOT reflect the real per-file gains, which are significant and verified by isolated narrow runs.
- VP: **BLOCKED** (98.96% → unmeasurable; pre-existing config regression).

### Per-file improvements (verified via post-run .resultset.json + narrow runs)

| File                                           | Before (unc) | After (unc) | Result                                                    |
| ---------------------------------------------- | ------------ | ----------- | --------------------------------------------------------- |
| lib/chain_seal.rb                              | ~20          | 6           | EC::Point verify path + canonicalize rescue newly covered |
| lib/observability_redactor.rb                  | 2            | 0           | 100%                                                      |
| lib/observability_span_scrubber.rb             | 1            | 0           | 100%                                                      |
| lib/config_values_origin_value.rb              | 3            | 0           | 100%                                                      |
| lib/config_values_host_family_values.rb        | 6            | 0           | 100% (new test file)                                      |
| lib/config_values_jump_gateway_values.rb       | 3            | 1           | near-100% (1 dead line, see dead-code)                    |
| app/models/concerns/chain_sealable.rb          | ~16          | 0           | 100%                                                      |
| app/models/concerns/telephone_normalization.rb | 1            | 0           | 100%                                                      |

## Targets selected

1. `lib/chain_seal.rb` — `create_public_key_from_point` (EC::Point public-key verification path,
   lines 193 + 204-218) and `canonicalize` rescue (line 138) had no test coverage. Added EC::Point
   verify (valid, mismatched, wrong-curve) and canonicalize-rescue tests.
2. `lib/observability_redactor.rb` — `scrub_url` `URI::InvalidURIError` rescue (line 85) was
   uncovered. Added an unparseable-URI test.
3. `lib/observability_span_scrubber.rb` — `scrub_attribute` non-sensitive-key branch that delegates
   to `ObservabilityRedactor.scrub` for Hash/Array/String values (line 38-39) was uncovered. Added
   nested-value scrubbing tests.
4. `lib/config_values_origin_value.rb` — `URI::InvalidURIError` rescue (line 57) plus fragment/path
   validation and host-normalization were uncovered or only flakily covered. Added focused tests.
5. `lib/config_values_host_family_values.rb` — NO test file existed. Added a new test file covering
   `build` (production + non-production), all `*_origins` helpers, ENV overrides, scheme-adding, and
   the `KeyError` rescue (line 99).
6. `lib/config_values_jump_gateway_values.rb` — NO test file existed. Added a new test file covering
   `build`, jwks-URI derivation, revoked-kids parsing (lines 26-27), and production `KeyError`.
7. `app/models/concerns/chain_sealable.rb` — block provider (`chain_seal_key_provider &block`, lines
   16-17), missing payload method raise (line 62), and missing column writer branch (line 42 false)
   were uncovered. Added three tests.
8. `app/models/concerns/telephone_normalization.rb` — `remove_domestic_zero_after_country_code`
   fallback return (line 187) was uncovered. Added an international-prefix-without-domestic-zero
   test.

## Tests added / extended

- `test/lib/chain_seal_test.rb` — added 6 tests: EC::Point verify (valid), mismatched EC::Point,
  wrong-curve EC::Point, `canonicalize` FormatError, `seal` non-canonicalizable payload, direct
  `to_h`.
- `test/unit/security/observability_redactor_test.rb` — added 2 tests: unparseable URI in
  `scrub_url` (REDACTED), non-HTTP string passthrough.
- `test/observability_span_scrubber_test.rb` — added 2 tests: non-sensitive key with String value,
  non-sensitive key with Hash/Array values.
- `test/lib/config_values/origin_value_test.rb` — added 3 tests: fragment/path rejection,
  unparseable URI rejection (InvalidURIError rescue), host normalization.
- `test/lib/config_values/host_family_values_test.rb` — NEW file, 5 tests.
- `test/lib/config_values/jump_gateway_values_test.rb` — NEW file, 6 tests.
- `test/models/concerns/chain_sealable_test.rb` — added 4 tests: block provider, missing payload
  method, missing column writer, (existing static-provider test retained).
- `test/models/concerns/telephone_normalization_test.rb` — added 1 test: international-prefix
  numbers without a domestic zero.

Total: 23 new tests, 86 target-test runs, 190 assertions, 0 failures in isolated runs.

## App/DB changes

None. All changes were test-only. No app/, db/, or lib/ source files were modified.

## Dead-code evidence

No code was deleted. Two dead/defensive code findings documented (both in lib/, which is outside the
allowed file-change set, so they were NOT deleted — only recorded):

1. `lib/config_values_jump_gateway_values.rb` line 19-21 — the `rescue KeyError` branch that returns
   `"#{origin}/.well-known/jwks.json"` is UNREACHABLE. The preceding line is
   `raw = env.fetch("JUMP_GATEWAY_JWKS_URL", nil)`, which supplies a default (`nil`) and therefore
   NEVER raises `KeyError`. `Hash#fetch(key, default)` returns the default when the key is missing.
   Evidence:
   - No code path between the `fetch` and the `rescue` can raise `KeyError`.
   - The default-jwks-URI behavior is already covered by the ternary on line 18
     (`raw.present? ? ... : "#{origin}/.well-known/jwks.json"`), so the rescue is a redundant,
     unreachable duplicate.
   - Targeted tests pass with the rescue present; deletion is not possible from this batch (lib/ is
     outside allowed file changes). Recommend a follow-up batch with explicit approval to remove it.

2. `lib/chain_seal.rb` lines 228 and 250 — signature bytesize guards in `decode_signature` and
   `raw_to_asn1_signature`. `raw_to_asn1_signature` is only called from `verify_raw_signature` with
   a signature already validated to be exactly `ES384_RAW_SIGNATURE_BYTES` bytes by
   `decode_signature`, so the bytesize re-check on line 250 is unreachable in normal flow. These are
   defensive guards, not provably dead in all contexts (a future caller could bypass
   `decode_signature`), so they are left in place and only noted.

### Latent issue (not a dead-code deletion, an observation)

`lib/config_values_jump_gateway_values.rb` `build`: when `JUMP_GATEWAY_JWKS_URL` is set to a URL
with a non-root path (e.g. `https://jwks.example.test/keys.json`), `ConfigValues.build`
(`OriginValue`) raises `ArgumentError` because `OriginValue` rejects non-root paths (line 41 of
`config_values_origin_value.rb`). This `ArgumentError` is NOT rescued by the `rescue KeyError`
block, so it propagates uncaught. The intended jwks_uri path is therefore silently lost for any
path-bearing jwks URL. Recorded as an observation; fixing requires lib/ changes (outside allowed
set) and a design decision about whether jwks URLs should carry paths.

## Verification

### Narrow Rails runs (all pass: 86 runs, 190 assertions, 0 failures)

```bash
bin/rails test test/lib/chain_seal_test.rb test/lib/chain_seal_coverage_test.rb \
  test/unit/security/observability_redactor_test.rb test/observability_span_scrubber_test.rb \
  test/lib/config_values/origin_value_test.rb test/lib/config_values/host_family_values_test.rb \
  test/lib/config_values/jump_gateway_values_test.rb test/models/concerns/chain_sealable_test.rb \
  test/models/concerns/telephone_normalization_test.rb
```

### Lint / format

```bash
vp check --fix
vp check
bundle exec rubocop -a   # 7 offenses auto-corrected across new test files
bundle exec rubocop <changed files>  # 0 offenses after correction
```

`vp check` reports a pre-existing error in `src/entrypoints/application.js` (empty file,
`unicorn(no-empty-file)`) — unrelated to this batch (no JS/TS files touched). One rubocop
auto-correction (`Lint/Void` rewriting `scrub` to a nonexistent `scrub!` in
`observability_span_scrubber_test.rb`) was reverted to the project's existing void-context pattern
(`_ = ObservabilitySpanScrubber.scrub(span)`) and re-verified.

### Full suite

```bash
COVERAGE=true bin/rails test test/
```

```
8439 runs, 39286 assertions, 18 failures, 3 errors, 0 skips
Line Coverage: 92.31% (42238 / 45779)
Branch Coverage: 69.73% (9493 / 13614)
```

(The first full-coverage attempt timed out at 30 minutes and produced an incomplete 85.86% report;
the second attempt completed in 624s. SimpleCov merged the runs; the final computed line coverage is
92.31%.)

```bash
vp test --coverage
vp test
```

Both exit with "No test files found" and report 0% — pre-existing VP config block (see below). The
prior 98.96% report in src/coverage/ was overwritten by the empty run.

## Failures analysis

All 18 failures and 3 errors are pre-existing baseline failures, in:

- `Sign::App::Verification::EmailsControllerTest` (404s / job-count mismatches — Acme/Sign
  authority-inversion migration slices). Verified: these tests PASS in isolation
  (`bin/rails test test/controllers/sign/app/verification/emails_controller_test.rb`) and only fail
  in the full suite due to parallel test-interaction/state pollution from the in-progress migration.
  Not caused by this batch.
- `test/security/invariants/forbidden_patterns_invariant_test.rb` (cross-host redirect escape hatch
  in `oidc_callback.rb`).
- `test/unit/views/page_title_presence_test.rb` (`sign/shared/sign_outs/handoff.html.erb` missing
  page_title).

None of the 18 failures are in files touched by this batch. The failure count rose from 10
(batch 13) to 18 because more of the unstable migration test files executed during this full-suite
invocation and failed on test interaction — consistent with the flaky execution documented in
batches 12-13. My 8 changed test files all pass (86 runs, 0 failures in isolation; and they
contributed coverage in the full suite, confirming they ran cleanly).

## VP coverage block (kill-switch condition: config needed)

`vp test` and `vp test --coverage` are BLOCKED by a pre-existing config regression:

- A minimal stub `vite.config.ts` (6 lines, only `RubyPlugin()`, no `test` block) exists at the repo
  root, timestamped 2026-06-23 00:07 (created before this session). Vite/Vitest loads
  `vite.config.ts` in preference to the full `vite.config.js` (27KB, dated 2026-06-21) which
  contains the correct vitest config (`root: repoRoot`, `include: spec/**/*.{test,spec}.{ts,tsx}`,
  coverage settings).
- Because the stub has no `test` config, vitest defaults to running from `src/` (the Vite RubyPlugin
  root) with default include, and finds NO test files (the VP tests live in
  `spec/entrypoints/{react_islands,inertia}.test.ts`).
- Additionally there is a vitest/@vitest/coverage-v8 version mismatch (`vitest@0.1.24` vs
  `@vitest/coverage-v8@4.1.8`).
- Result: `vp test` / `vp test --coverage` exit with "No test files found" and 0% coverage. Running
  `vp test --coverage` overwrote the prior `src/coverage/` report (98.96%) with an empty report.

This cannot be fixed from this batch: `vite.config.ts` and package files are outside the allowed
file-change set (config/package files forbidden), and `bundle`/`pnpm`/network commands are
forbidden. Last known good VP coverage: **98.96%** (672 / 679 lines), with all 7 uncovered lines in
`src/entrypoints/inertia.tsx`.

## Notes

- The dominant obstacle to raising the AGGREGATE Rails coverage number is NOT missing tests — it is
  pre-existing flaky parallel test execution that prevents some test files from running during
  `COVERAGE=true bin/rails test test/`. Files confirmed to have complete tests but flaky-run
  "uncovered" status include: `safe_promotional_cta_url.rb`, `application_policy.rb`,
  `sign/common_helper.rb`, `sign/org/sign_ups_helper.rb`, `has_birthdate.rb`,
  `telephone_normalization.rb` (before this batch). Future batches should continue to verify
  "uncovered" lines against the actual test files by reading, not trust the aggregate resultset
  alone.
- The full-coverage run is slow and intermittently hangs (one 30-min timeout, one 624s completion).
  Budget accordingly.
- Remaining uncovered lines in `lib/chain_seal.rb` (lines 132, 189, 195-196, 228, 250) are
  defensive/hard-to-trigger: the OpenSSL rescue in `verify` (line 132), the non-EC::Point public key
  path (189/195/196 — in this OpenSSL build `EC#public_key` returns an EC::Point so the regular-key
  path is not exercised by the natural API), and the signature bytesize re-guards (228/250).
  Covering 195-196 would require constructing a non-Point `OpenSSL::PKey::EC` public key explicitly.

## Skipped risky areas

- Authentication / OIDC / token / credential / secret / session / logout / sign flows (all
  pre-existing failures in these areas left as baseline; no auth code touched).
- Payment or destructive flows.
- External service integrations (e.g. `outbound_sms_providers_aws_sns.rb`).
- Redis / network / browser / system-test paths.
- Time-sensitive, random, or parallelism-sensitive behavior.
- Framework callbacks and monkey patches.
- `config/`, `bin/`, `Gemfile*`, package files, routes, fixtures, factories, CI files (all
  forbidden; needed for VP fix — documented as blocked).
- lib/ source modifications (outside allowed file set; only lib/ TESTS were added).

## Next batch candidates

- Rails: cover `lib/chain_seal.rb` lines 195-196 by constructing a non-Point `OpenSSL::PKey::EC`
  public key (e.g. `OpenSSL::PKey::EC.new(der)`) and passing it to `verify`, to exercise the regular
  public-key validation path.
- Rails: investigate the flaky parallel execution root cause (likely test-order/state pollution from
  the Acme/Sign migration) — if a safe, test-only stabilization is possible, it would unlock
  aggregate coverage gains far larger than per-file test additions. Requires care to stay in the
  allowed file set and avoid auth/migration code.
- Rails: continue per-file genuine-gap hunting in safe lib/ files
  (`lib/jit_security_jwt_registry.rb` 12 unc, `lib/jit_security_jwt_keyring.rb` 10 unc — assess
  jwt/security sensitivity first), and `lib/jit_security_jwt_local_keyset_installer.rb` (15 unc).
- Rails: `app/models/concerns/chronicle_capturable.rb` and `app/models/chronicle.rb` show many
  flaky-uncovered lines; verify whether the existing `chronicle_capturable_test.rb` covers them when
  run, and add only genuine gaps.
- VP: BLOCKED until the `vite.config.ts` stub / vitest version mismatch is resolved by an authorized
  config/package change. Once unblocked, cover `src/entrypoints/inertia.tsx` (7 lines, 0%) with a
  deterministic mock strategy.
