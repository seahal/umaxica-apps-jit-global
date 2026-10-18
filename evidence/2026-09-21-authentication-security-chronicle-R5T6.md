# Authentication Security Chronicle Evidence

Date: 2026-09-21 UTC

Repository state: branch `feature`, HEAD `52efa31df2a28763ad405f604bb3ef0c416b3b93` at the
start of this slice. The worktree contained pre-existing user and implementation changes; they
were preserved. No AWS, Cloudflare, provider, GitHub, email, or SMS service was contacted.

## Change

`AuthenticationSecurityEventEmitter` now sends its accepted event taxonomy through the existing
`Chronicle.capture` boundary. The durable record uses the existing `security` retention policy and
the existing `ChronicleRecordPolicy` sanitization. The operational JSON log remains available through
`JitLogEvent` and is independently redacted. No database table, retention duration, provider
receipt ledger, or external configuration was added.

`reason_code` is preserved only when it is a bounded lower-case categorical value. Other long or
secret-like values continue to be filtered. A Chronicle write failure does not raise through the
emitter; the existing Chronicle fallback path is retained and the redacted operational event still
emits.

## TDD and verification

The new durable-record assertion was first run before the production change and failed because the
Chronicle count did not increase (`3 runs, 13 assertions, 1 failure`). After implementation and a
redaction-boundary correction, the focused suite passed:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/policies/chronicle_record_policy_test.rb \
  test/services/authentication_security_event_emitter_test.rb
24 runs, 84 assertions, 0 failures, 0 errors, 0 skips
```

The focused RuboCop check passed for the four changed Ruby files with no offenses.

The related Chronicle, authentication audit-writer, JWT anomaly, retention, and sanitization
regression set also passed:

```text
PARALLEL_WORKERS=1 bin/rails test <related audit/retention test set>
101 runs, 431 assertions, 0 failures, 0 errors, 0 skips
```

After the slice, the full Rails suite passed:

```text
bin/rails test
11,430 runs, 73,100 assertions, 0 failures, 0 errors, 5 skips
```

Additional checks:

- full `bin/rubocop`: the same three pre-existing offenses remain in
  `lib/umaxica/valkey/responsibility_urls.rb` and `lib/umaxica/valkey/settings.rb`; no offense was
  reported in the changed files;
- `bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: 0 errors and 0 security
  warnings;
- `bin/bundler-audit`: no vulnerabilities found;
- `bun run test`: 85 files and 1,065 tests passed;
- `bun run check`: formatting, lint, TypeScript, dead-code, and OpenAPI checks passed (four existing
  Knip configuration hints were reported);
- `git diff --check`: passed.

The repository's `bun audit` command could not reach the npm advisory endpoint because DNS resolution
was unavailable. No external service was retried. This is unverified, not a clean audit result.

The final Rails coverage command ran all tests successfully but failed the repository's existing
SimpleCov gates without changing them:

```text
COVERAGE=true bin/rails test test/
11,430 runs, 73,101 assertions, 0 failures, 0 errors, 5 skips
SimpleCov exit 2
line 95.97% (minimum 98%), branch 75.05% (minimum 90%), method 90.85% (minimum 95%)
```

This is a coverage-gate failure, not a test failure. Thresholds, exclusions, and skips were not
weakened. The lowest-coverage files are pre-existing broad controller/concern paths outside this
audit slice; they remain a release-gate follow-up.

## Residual boundary

JWT anomaly rows, enforcement events, retention-hold/purge occurrences, and authentication
security events have repository-side durable paths. Provider notification acceptance, delivery
outcome, retry, and permanent failure remain separate facts. The repository does not infer delivery
completion from queue enqueue and does not add a generic delivery ledger without an approved provider
contract and retention owner. Live provider delivery and external infrastructure remain unverified.
