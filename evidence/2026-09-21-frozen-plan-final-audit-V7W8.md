# Frozen plan execution audit

Date: 2026-09-21 UTC

Repository: `seahal/umaxica-apps-jit-global`

Branch: `feature`

HEAD at audit: `52efa31df2a28763ad405f604bb3ef0c416b3b93`

The worktree contained pre-existing user and implementation changes. They were preserved; no
reset, clean, commit, history rewrite, GitHub write, deployment, production/shared database
mutation, Cloudflare change, or provider delivery was performed.

## Plan validation

The existing machine result in `/tmp/umaxica-frozen-plan/freq-validation.json` was re-read. It
reports 70 canonical source rows, 70 canonical FREQ rows, zero duplicate or unmapped rows, zero
placeholder/range-only rows, zero unmapped adversarial findings, zero errors, and `result: PASS`.
The frozen plan remains unchanged. Its `NOT_STARTED`/`NOT_RUN` fields are plan metadata and were
not rewritten to manufacture completion claims.

## Executed verification

The Rails environment used the repository-supported devcontainer file:

```text
UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
```

The exact requested preflight completed after `LocalEnvironment.load!`:

```text
PostgreSQL test target: 10.89.0.3/32:5432 admin=db version=17.7 (Debian 17.7-3.pgdg12+1) test_databases=646
Valkey rate_limit: valkey-kvs:6379 db=4 ping=PONG version=7.2.4
Valkey auth_state: valkey-kvs:6379 db=6 ping=PONG version=7.2.4
```

The test credential key was present; its contents were not read or printed. A preliminary helper
check was attempted before loading `LocalEnvironment` and reported a missing port variable; that
was a check-order error, not a service failure. The exact preflight above is the authoritative
result.

The following repository-side checks completed:

- focused Chronicle security-event tests: 24 runs, 84 assertions, 0 failures, 0 errors, 0 skips;
- related Chronicle, audit-writer, JWT anomaly, retention, and sanitization tests: 101 runs, 431
  assertions, 0 failures, 0 errors, 0 skips;
- SMS lifecycle audit focused tests: 8 runs, 56 assertions, 0 failures, 0 errors, 0 skips;
- SMS and related audit regression tests: 74 runs, 339 assertions, 0 failures, 0 errors, 0 skips;
- full Rails suite after the SMS compatibility fix: 11,434 runs, 73,121 assertions, 0 failures,
  0 errors, 5 skips;
- JavaScript tests: 85 files, 1,065 tests passed;
- JavaScript checks: formatting, lint, TypeScript, dead-code, and OpenAPI checks passed;
- targeted RuboCop for changed Ruby files: passed;
- full RuboCop: three pre-existing offenses remain in
  `lib/umaxica/valkey/responsibility_urls.rb` and `lib/umaxica/valkey/settings.rb`;
- bundled Brakeman: 0 errors and 0 security warnings;
- Bundler audit: no vulnerabilities reported;
- `git diff --check`: passed.

The first full Rails run after adding SMS audit facts found one changed-area compatibility error:
the existing `Outbound::SmsTest` provider double returned boolean `true`, while the new audit path
assumed a structured provider response. The implementation was narrowed to enrich structured
responses only; the focused, related, and full suite results above are after that fix. No test was
weakened or removed.

The coverage-enabled Rails run executed all tests but failed the repository's existing SimpleCov
gates: line 95.97% / minimum 98%, branch 75.05% / minimum 90%, method 90.85% / minimum 95%.
No threshold, exclusion, assertion, or skip was weakened. `bun audit` could not reach the npm
advisory endpoint because DNS resolution was unavailable and is therefore unverified.

## Final audit disposition

- FREQ-0065 through FREQ-0069 have repository-side implementation and focused/full-test evidence;
  CSRF, preflight discipline, bounded Valkey access, exact replay cleanup, and token-endpoint
  re-lock behavior were not weakened by this audit.
- FREQ-0070 is machine-validated by the existing traceability result above.
- FREQ-0064 is **PARTIAL**: authentication security events now have a sanitized durable Chronicle
  record under the existing security retention policy, with a separate redacted operational log.
  JWT anomaly persistence and bounded hold-aware retention paths remain covered by existing tests.
  Provider acceptance, delivery outcome, retry, and permanent failure are distinct facts and remain
  unimplemented/unverified because no provider callback/retry/retention contract was approved.
  Taxonomy entries without real callers were not fabricated.
- The aggregate coverage-gate failure and the three repository-wide RuboCop offenses remain
  release-gate follow-ups; they are not silently attributed to or excused by this slice.
- Live provider, email/SMS, Cloudflare/Tunnel, Solid Queue deployment, production registration,
  and external key verification remain outside repository-side evidence.

## Security conclusion

The repository-side hardening slice is test-green for the changed behavior and does not justify
claiming full release readiness. The remaining FREQ-0064 contract and coverage/static follow-ups
must be resolved or explicitly accepted in a later review before a final unconditional GO.
