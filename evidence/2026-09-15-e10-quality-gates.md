# E10 quality-gate and local CI checkpoint

Date: 2026-09-15

Repository: `seahal/umaxica-apps-jit-global`

Branch and HEAD: `feature`, `e9fa72ce5fc0c9e62c9a5a7a8233b477ba77f8b6`

The worktree remained intentionally dirty. No checkout, reset, clean, stash, stage, commit, push,
GitHub write, deployment, live IdP/mail/SMS/Turnstile request, or shared-data operation was
performed. The source was not edited while an individual measurement was running.

## Isolated resources

The verified PostgreSQL test endpoint was `primary.dns.podman:5432`; the run used the explicit test
database manifest `test_primary_db`, `test_app_ticket_db`, `test_com_ticket_db`, and
`test_org_ticket_db`. The verified Valkey endpoint was `valkey.dns.podman:6379`, with cache,
rate-limit, and auth-state responsibilities on logical databases 3, 4, and 5. The wrapper validated
those targets before Rails boot and removed only its run-scoped prefixes afterward. No development,
production, shared-user database, or broad Valkey database was reset, dropped, recreated, or
flushed.

## Commands and results

| Command                                                                                                                                           |     Exit | Result                                                                                                                                                                                                                                                                                                                                         |
| ------------------------------------------------------------------------------------------------------------------------------------------------- | -------: | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CACHE_REDIS_URL=.../3 RATE_LIMIT_REDIS_URL=.../4 AUTH_STATE_REDIS_URL=.../5 VALKEY_TEST_HOST=valkey.dns.podman VALKEY_TEST_PORT=6379 bin/ci`     |        0 | Final current-source run after the E0 edge-contract and HTML title assertion fixes: database preparation, JS checks/coverage, Ruby/ERB lint, bundler-audit, bun audit, Brakeman 8.0.6, loopback Rails boot, and Rails tests all passed. Rails: 13,058 runs, 79,090 assertions, 0 failures, 0 errors, 3 existing skips; seed 48755, 16 workers. |
| Same `bin/ci` with an inherited cache URL on logical DB 0                                                                                         | non-zero | Rejected before database preparation with the expected Valkey test-target configuration error; no unsafe connection was opened.                                                                                                                                                                                                                |
| `bun run test:coverage`                                                                                                                           |        0 | Node 24.20.0, Vitest 5.0.0/V8; 85 files, 1,057 tests; statements 100%, branches 99.63%, functions 100%, lines 100%.                                                                                                                                                                                                                            |
| `bun run check`                                                                                                                                   |        0 | Format, lint, typecheck, dead-code and OpenAPI lint/verify passed.                                                                                                                                                                                                                                                                             |
| `bundle exec rubocop --cache false && bundle exec erb_lint --lint-all`                                                                            |        0 | 4,799 Ruby files and 1,217 ERB files passed.                                                                                                                                                                                                                                                                                                   |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                                                                                  |        0 | Brakeman 8.0.6, 0 warnings and 0 errors.                                                                                                                                                                                                                                                                                                       |
| `bin/bundler-audit`                                                                                                                               |        0 | No known gem vulnerabilities in the available advisory database.                                                                                                                                                                                                                                                                               |
| `scripts/test-isolated bin/rails test test/tooling/evidence_layout_test.rb`                                                                       |        0 | 3 runs, 6 assertions, 0 failures, 0 errors, 0 skips; the run-scoped Valkey cleanup completed.                                                                                                                                                                                                                                                  |
| `scripts/test-isolated bin/rails test test/config/test_environment_edge_contract_test.rb test/config/test_environment_isolation_contract_test.rb` |        0 | 28 runs, 126 assertions, 0 failures, 0 errors, 0 skips; missing/unsafe PostgreSQL and Valkey settings, run namespace validation, and prefix cleanup failure paths were exercised without unsafe connections or broad deletion.                                                                                                                 |
| `scripts/test-isolated bin/rails test test/integration/html_title_contract_test.rb`                                                               |        0 | 20 runs, 612 assertions, 0 failures, 0 errors, 0 skips; each surface sweep attempted every candidate path, including surfaces with zero successful HTML responses.                                                                                                                                                                             |
| `scripts/test-isolated bin/rails test test/integration/auth_booster_test.rb`                                                                      |        0 | 10 runs, 27 assertions, 0 failures, 0 errors, 0 skips after removing an existing debug warning that printed authentication response cookies.                                                                                                                                                                                                   |
| `scripts/test-isolated env COVERAGE=true bin/rails test test/`                                                                                    |        2 | Final current-source run: 13,058 tests, 79,126 assertions, 0 test failures/errors and 3 existing skips; SimpleCov gate failed at line 98.38% (57,972/58,924), branch 87.88% (8,669/9,864), method 93.87% (10,064/10,721).                                                                                                                      |

The Rails coverage result is a real failed quality gate. Existing thresholds and file/group/drop
rules were not changed, and no skip, exclusion, assertion weakening, or `:nocov:` was added. The
ordinary Rails green result, JS coverage result, and Ruby SimpleCov result are separate
measurements.

## Implemented verification slices

The current worktree includes the E0 guard/transport repairs, Base local admission boundary,
authorization-code owner/link hardening, OIDC refresh reception and freshness persistence, the
canonical `/sessions` routes while retaining `/sign/out` and Core `/api/v0/session`, DPoP/DBSC/GUID
focused checks, and existing OTP/mail coverage. The GUID surface remains a transport-safe 404
bootstrap because its durable ownership and resolver store are not established; no speculative
database model was added. Physical DPoP/DBSC device interoperability was not performed.

The local CI result does not certify all 95 requirements, full auth-time provenance across every
ceremony, cross-store failure injection, Ruby coverage compliance, external advisory freshness,
physical protocol interoperability, GUID persistence ownership, or deployment readiness.
