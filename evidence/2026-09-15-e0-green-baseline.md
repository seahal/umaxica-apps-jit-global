# E0 quality-gate continuation — 2026-09-15

This section records the later implementation state; the historical E0 report below is retained
without being rewritten as a current result.

## Current source and safety boundary

HEAD remained `e9fa72ce5fc0c9e62c9a5a7a8233b477ba77f8b6` on `feature`. The worktree stayed dirty;
no checkout, reset, clean, stash, stage, commit, push, GitHub write, deployment, live provider
request, or shared-data operation was performed. Existing PgHero/Core/unrelated changes and
untracked files were preserved. The source changed during the first canonical CI run, so that run
is historical for the pre-fix source and is not used as the final CI baseline.

The verified PostgreSQL host was `primary.dns.podman:5432`; preparation scope was explicitly
limited to `test_primary_db`, `test_app_ticket_db`, `test_com_ticket_db`, and
`test_org_ticket_db`. Valkey was `valkey.dns.podman:6379`, with cache/rate-limit/auth-state on
logical databases 3/4/5 and run-scoped namespaces. Only the dedicated test databases were written:
the Blazer migration was applied to `test_primary_db`, and OIDC refresh-claim migrations were
applied to the three ticket databases. No development/production/shared database was reset or
flushed.

## Implemented repairs and tests

- `OidcTokenExchangeCoordinator` now accepts the standard `refresh_token` grant at the Base token
  endpoint. Refresh requests require registered-client ownership, an active parent/session,
  allowed `openid` scopes, the stored authentication event, and the applicable DPoP binding before
  one-time rotation. Missing authentication-event time fails closed.
- RP session rows persist the original OIDC `auth_time`, `acr`, `amr`, and nonce across the three
  ticket databases. Refresh advances token `iat` but preserves `auth_time`; the existing absolute
  session ceiling remains the upper bound.
- The public Base token concern forwards `refresh_token`; a regression test first failed with a nil
  forwarded value and then passed after the production fix.
- `OidcRefreshTokenIssuer` declares its public API explicitly; the architecture baseline test passes
  without changing the baseline inventory.

Focused E0/OIDC/refresh/authority/architecture tests passed with 132 runs and 3,655 assertions
(including 37 authority runs / 190 assertions). The refresh-claim migrations were run through
explicit app/com/org ticket migration tasks only. The full Rails suite subsequently passed with
13,020 runs and 78,876 assertions. The canonical CI Rails stage passed with 13,020 runs and
78,864 assertions.

## Quality-gate results

The canonical `bin/ci` run using the isolated wrapper and the four-database manifest passed after
the explicit-visibility fix. Rails reported 13,020 runs, 78,864 assertions, 0 failures, 0 errors
and 3 existing skips, and the CI process exited 0. The earlier architecture-baseline failure is
retained as historical evidence only.

The current explicit Rails coverage run completed 13,020 tests / 78,865 assertions with 0 failures,
0 errors and 3 existing skips, then exited 2 for the unchanged SimpleCov gates: line 98.36%
(`57,836/58,799`), branch 87.59% (`8,606/9,825`), method 94.05% (`10,070/10,707`). The coverage
result is a real red gate, not a baseline update. Formal Node-backed `bun run test:coverage` passed
85 files / 1,055 tests with statements/functions/lines 100% and branches 99.55%. Thresholds,
assertions, skips and exclusions were not weakened.

The current remaining gate work is Ruby branch/method coverage and any unavailable external
advisory/network checks. Physical DPoP/DBSC interoperability and full E1–E10 feature completion
are not claimed by this record.

# E0 test environment and Rails baseline

Date: 2026-09-15

Repository: `seahal/umaxica-apps-jit-global`

Branch: `feature`

HEAD at start and end: `e9fa72ce5fc0c9e62c9a5a7a8233b477ba77f8b6`

No checkout, reset, clean, stash, stage, commit, push, GitHub write, deployment, or external
provider request was performed. The worktree was intentionally dirty while this work ran. The
concurrent PgHero initializer/evidence and `plans/umaxica-global-open-misty-adleman.md` changes
were preserved as unrelated work.

## Isolated resources

The test wrapper was run with explicit test variables. PostgreSQL was read-checked at
`primary.dns.podman:5432`; the current database for the Rails runs was the dedicated
`test_primary_db`. Valkey was read-checked at `valkey.dns.podman:6379`, using logical databases
3 (cache), 4 (rate limit), and 5 (auth state). Credentials and full secret-bearing URLs are not
recorded here. The wrapper rejected missing or unsafe database/Valkey targets before Active Record
or the stores were opened.

The read-only schema check found the Blazer migration pending on `test_primary_db`. After the
database identity check, only migration `20260915000000_create_blazer_tables` was applied to that
dedicated test database. No development, production, shared user database, or base test database
was reset, dropped, recreated, or flushed. Parallel runs used the repository's existing dedicated
clone and lock mechanism.

The run/worker marker and cursor-complete Valkey cleanup were exercised. A child exit-37 test
returned exit 37 after cleanup, and a TERM test returned 143 after cleanup. No run marker remained
after the final cleanup. SIGKILL cleanup is not claimed; the documented recovery path remains an
explicit, post-process scoped cleanup.

During a deliberately failed non-escalated launch, standalone cleanup exposed that its script did
not load the `Unavailable`/`OperationError` classes before handling a connection failure. The
script now requires those error classes explicitly. The focused cleanup/evidence regression then
passed with 6 runs and 15 assertions.

## Guard and application checks

The following results are from the current source tree and explicit test resources:

| Check | Result |
| --- | --- |
| Ruby/shell syntax and `git diff --check` | exit 0 |
| E0 isolation, Valkey cleanup, outbound transport, strict Turnstile tests (one worker) | 36 runs, 100 assertions, 0 failures/errors/skips; exit 0 |
| E0 subset (two workers) | 9 runs, 31 assertions, 0 failures/errors/skips; exit 0 |
| `test/tooling/evidence_layout_test.rb` (final isolated retry) | 3 runs, 6 assertions, 0 failures/errors/skips; exit 0 |
| Focused Valkey cleanup plus evidence-layout regression after standalone-loader fix | 6 runs, 15 assertions, 0 failures/errors/skips; exit 0 |
| Authorization-code/OTP target | 147 runs, 752 assertions, 0 failures/errors/skips; exit 0 |
| Broader repaired regression set | 362 runs, 1,487 assertions, 0 failures/errors/skips; exit 0 |
| Full Rails suite, 16 workers, seed 24963 | 13,007 runs, 78,807 assertions, 0 failures, 0 errors, 3 existing skips; exit 0 |

The limited application repairs were evidence-driven: two OIDC test fixtures supplied the required
client/redirect/PKCE inputs, the Com sign-in error prop was restored, Com sign-up parameters now
match the submitted policy fields, authentication-event time has a typed claim reader, and stale
test harnesses use the strict injected Turnstile boundary. No authentication policy was weakened.

The first non-escalated attempt to run the evidence-layout test failed before assertions because
the sandbox could not resolve the already-authorized Podman-DNS host and could not open Valkey.
The same command was then retried with the required process-level network permission against the
same dedicated targets and passed as recorded above. This was an environment launch failure, not
an application assertion failure.

## Coverage and static checks

The final explicit Rails coverage command exercised 13,007 tests and 78,806 assertions with 0
failures and 0 errors but exited 2 because the configured SimpleCov gates were not met: line
98.36% (`57,708/58,666`), branch 87.75% (`8,578/9,775`), and method 93.91% (`10,042/10,693`).
No threshold, assertion, skip, or
exclusion was changed.

`bun run test` passed with 85 files and 1,055 tests. The formal entry point
`bun run test:coverage` now invokes the locked Vitest CLI through Node 24.20.0 (Bun remains the
package manager and ordinary test entry point) and exited 0 with 85 files and 1,055 tests:
statements 100% (`2,181/2,181`), branches 99.55% (`1,345/1,351`), functions 100% (`738/738`),
and lines 100% (`2,140/2,140`). The configured projects, provider, test population and 99%
thresholds were unchanged; the previous Bun V8 merge overflow is retained as historical evidence.

The following checks exited 0: full RuboCop (4,797 files), ERB lint (599 files), direct and wrapper
Brakeman scans (Brakeman 8.0.6; 859 controllers, 701 models, 97 templates, zero warnings/errors),
OpenAPI lint, OpenAPI verify, format check, Ruby/TypeScript type checks, and dead-code check.
Bundler-audit 0.9.3 updated a disposable advisory database containing 1,244 advisories (database
commit `f08b5bf5b2778201db0b69f0faa7a407e2476cb8`, updated 2026-09-13) and found zero results;
the command exited 0. `bin/ci` has not yet been run: its setup still uses a broad `db:prepare`
command and must first be changed to the verified test-only manifest/wrapper.

## Remaining status

The standalone Rails green baseline and formal JavaScript coverage are obtained and attributable
to this source/resource state. Ruby branch/method coverage and canonical `bin/ci` remain open
checks. This record does not claim completion of the all-95 feature plan or deployment readiness.

# Post-freshness implementation checkpoint — 2026-09-15

This section records the latest source state after the OIDC `prompt`/`max_age` freshness slice.
The historical measurements above are retained and are not merged into these results.

## Source and safety

HEAD remained `e9fa72ce5fc0c9e62c9a5a7a8233b477ba77f8b6` on `feature`. The worktree remained
intentionally dirty; no checkout, reset, clean, stash, stage, commit, push, GitHub write,
deployment, live provider request, or shared-data operation was performed. The full Rails and
coverage runs used 16 workers through `scripts/test-isolated` with the already verified
PostgreSQL test host and Valkey logical databases 3/4/5. The source tree and test resources were
not edited concurrently during each measurement.

## Implemented slice

The Base app/com/org authorization transactions now retain nullable OIDC `prompt` and `max_age`
values in the dedicated ticket schemas. The resolver accepts the supported `login` and `none`
prompts and non-negative integer max-age values, the Base authorization surfaces enforce the
authenticated-session freshness decision, and the RP callback passes the expected max-age to
ID-token verification. Missing or stale `auth_time` is rejected when max-age is requested. The
refresh grant, client-bound one-time rotation, original `auth_time`/`acr`/`amr`/nonce persistence,
and absolute session ceiling remain as described in the earlier section. These changes do not
claim full cross-surface auth-time provenance, replay failure-injection coverage, or physical
DPoP/DBSC interoperability.

## Current commands and results

The final read-only preflight, invoked through Bundler as the repository supports it,
`bundle exec ruby scripts/test-environment-check`, exited 0 and observed PostgreSQL
`primary.dns.podman:5432` with 646 `test_*` databases plus Valkey `valkey.dns.podman:6379` on
logical databases 3/4/5. A direct non-Bundler invocation was not used as evidence because this
workspace does not expose the application gems on the bare Ruby load path.

| Command | Exit | Result |
|---|---:|---|
| `scripts/test-isolated bin/rails test` | 0 | 13,038 tests, 78,947 assertions, 0 failures, 0 errors, 3 existing skips; 16 workers; seed 47560. |
| `scripts/test-isolated env COVERAGE=true bin/rails test test/` | 2 | 13,038 tests, 78,955 assertions, 0 failures, 0 errors, 3 existing skips; line 98.37% (57,904/58,863), branch 87.70% (8,637/9,848), method 93.83% (10,056/10,717). Branch/method gates remain below 90%/95%; no gate was changed. |
| `bun run test:coverage` | 0 | Node 24.20.0, Vitest 5.0.0/V8; 85 files, 1,055 tests; statements 100% (2,181/2,181), branches 99.55% (1,345/1,351), functions 100% (738/738), lines 100% (2,140/2,140). |
| isolated local `bin/ci` with the four-database manifest | 0 | Rails stage 13,038 runs / 78,924 assertions / 0 failures / 0 errors / 3 existing skips; JS coverage and configured static/security/OpenAPI stages passed. This CI run did not enable Rails SimpleCov. |

The final focused OIDC freshness/refresh/Base authorization set (`test/resolvers/oidc_authorize_request_resolver_test.rb`,
the transaction model, Base app/com/org authorization, RP callback/initiator/verifier, and token
exchange tests) exited 0 with 185 runs, 810 assertions, 0 failures, 0 errors and 0 skips (seed
61143, one worker). Targeted RuboCop over the 18 changed Ruby files exited 0 with no offenses.

The SimpleCov exit 2 is a real quality-gate failure, not a test failure and not a reason to lower
the thresholds. The JS coverage result is independent and formally green through the Node-backed
launcher. No test was skipped or deleted to obtain either result.

## Remaining work

E0 execution and the normal Rails baseline are attributable to this source state. Ruby branch and
method coverage remain `FAILED_CHECK`. Cross-surface auth-time provenance, authorization-code
owner/replay and partial-failure injection, full Auth/Base admission paths, DPoP/DBSC lifecycle
validation, and the broader E1–E10 feature slices remain open. Physical-device validation and
deployment are not claimed.
