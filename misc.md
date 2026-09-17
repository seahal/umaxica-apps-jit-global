UMAXICA — Next-Cycle Investigation Register

Opened: 2026-09-15
Reference plan: resolved refactor.md / PLAN_PATH
Purpose: preserve architectural problems, potential vulnerabilities, performance concerns and verification gaps found while implementing the current cycle.

This is not an implementation-completion claim, a new scope expansion, or an approval to accept security risk. Existing required code-binding, admission, timestamp, OTP, and partial-failure fixes remain in the execution plan. Do not move them here merely to mark a phase complete.

The initial entries below are planning seeds derived from supplied reports, not findings reproduced in the new implementation run. The implementer must attach actual HEAD, file/symbol references and current test/measurement evidence when available. Preserve pre-existing user memo content; merge by root cause and stable ID. Record resolutions rather than deleting history.

Index

ID

Topic

Initial evidence/status

Current-cycle relationship

MISC-0001

Real-client DPoP and DBSC interoperability

Reported validation gap / OPEN

E5 must still complete automated protocol/runtime checks.

MISC-0002

Auth-path latency and contention under representative load

Measurement gap / OPEN

E1/E4/E7 correctness and bounded-query tests remain required.

MISC-0003

Deeper assurance, freshness and federation contract

Deferred design analysis / OPEN

E3 must preserve correct event time, actual methods and current accepted policy.

MISC-0004

Direct-entry UX beyond the fixed Base-local contract

Product refinement / OPEN

D-ENTRY and E2 are decided for this cycle, not blocked.

MISC-0005

Historical domain-time provenance

Conditional data-provenance gap / OPEN

E3/E7/E9 may not fabricate timestamps while waiting.

MISC-0006

Unrecoverable original ORG UI fragment

Known source limitation / OPEN

REQ-095 is explicitly deferred; REQ-051–056 remain implementable.

MISC-0007

Cross-store failure behavior under real failover

Operational-validation gap / OPEN

E1 must still fix known partial-failure defects and run isolated injections.

MISC-0001 — Real-client DPoP / DBSC interoperability

Category: security / interoperability. Evidence level: VALIDATION_GAP. Status: OPEN; physical validation deferred.

Evidence: Source S1 REQ-016–019 and S3 §§6, 11.G4, 16 report no representative physical/client validation. No new device test has been run while preparing this memo.

Abstract problem: A server can validate synthetic proofs correctly while a real browser/native client cannot retain, rotate or present the intended key throughout its lifecycle. Automated server tests do not establish end-to-end sender constraint.

Scope/preconditions: Intended DPoP clients and DBSC-capable browsers; profile restart, key loss, unsupported browser, renewal, logout and device expiry. Impact: potentially high for authentication availability or ineffective deployment assumptions. Likelihood/confidence: not measured; the evidence gap itself is reported.

Current containment: Keep established per-client policy, DBSC progressive enhancement, explicit unsupported paths, and no new global enforcement before compatibility evidence. An established DPoP constraint must not fall back to Bearer after proof failure.

Next-cycle question/test: Which actual client/browser/device combinations complete registration, authentication, proof renewal, logout, restart and failure recovery without weakening binding? Record versions, workload, negative cases and outcomes.

Exit: Representative matrix and key-ownership/recovery evidence support a specific per-client deployment decision. Related: E5, D-DPOP, REQ-018/019.

MISC-0002 — Authentication-path latency and contention

Category: performance / operations. Evidence level: MEASUREMENT_GAP. Status: OPEN.

Evidence: S2 B/C traces store read, atomic consume, DB work and family linking. It provides no representative p95/p99 latency or concurrency measurement. Add current symbol/round-trip/query measurements after implementation.

Abstract problem: Correct owner checks and transaction fencing can accumulate network round trips or serialize unrelated requests if lock scope is too broad. Removing checks for speed would be the wrong remedy.

Scope/preconditions: Parallel token exchange, refresh, multi-tab entry and per-actor/per-RP locks under intended network conditions. Impact: potentially moderate to high availability/latency impact. Likelihood: unknown; no invented latency numbers or budgets.

Current containment: Preserve all security checks; measure query counts and real isolated-store operations in current tests. Avoid request-wide locks spanning unrelated actors and unbounded provider calls where the current design permits narrower scope.

Next-cycle test: Capture workload/concurrency, sample size, p50/p95/p99, DB lock waits, allocations and Valkey round trips with an isolated representative dataset. Compare equivalent successful and rejected paths and falsify suspected bottlenecks before redesign.

Exit: Evidence identifies the dominant cost and supports a bounded optimization without changing protocol, replay or ownership semantics. Related: E1/E4/E7, REQ-084/092.

MISC-0003 — Deeper assurance and federation semantics

Category: architecture / security. Evidence level: DEFERRED_DESIGN. Status: OPEN.

Evidence: S1 REQ-013/014/019 intentionally bounds the current assurance work. This seed does not assert a newly discovered NIST-conformance failure.

Abstract problem: Product Step-Up, authentication event freshness, achieved assurance, actual methods, phishing resistance and federation assurance answer different questions. A shared label can accidentally imply a stronger authorization decision than the evidence establishes.

Scope: Base policy, ceremony evidence and claims, RP interpretation and UI/security documentation. Impact: potentially high if later policy conflates these axes. Likelihood: unknown without a complete requirement/protocol mapping.

Current containment: E3 preserves Base ownership, actual amr, explicit context and event time; retain existing SMS acceptance without overstating its properties. No new AAL/FAL policy is adopted from this memo.

Next-cycle question/test: Map each policy decision to required evidence, method, freshness and federation assumptions. Compare current code, accepted ADR and applicable primary standards; specify falsifying tests before proposing a policy change.

Exit: A reviewed contract separates the axes, retains explicit accepted risks, and supplies migration/validation criteria for any changed policy. Related: E3/E5, D-ASSURANCE.

MISC-0004 — Direct-entry UX refinement

Category: UX / architecture. Evidence level: DEFERRED_REFINEMENT. Status: OPEN.

Evidence: D-ENTRY in the final plan deliberately fixes Base-admitted local sign-in and same-realm Base-root completion. H2/H3 record the prior admission-less navigation mismatch.

Abstract problem: Presentation choices must not silently create a second authority or a fake relying party. Fine-tuning provider order, restart messaging or intermediate screens is separate from authority ownership.

Current containment: Implement E2 fully: no admission bypass, no fake RP, no duplicate ordinary login, same-realm Base completion and explicit restart. This entry does not defer that functional fix.

Impact/likelihood: UX friction is plausible but not yet measured; no confirmed security failure is claimed by this seed.

Next-cycle question/test: Using the implemented flow, assess anonymous entry, already-signed-in entry, failed/expired ceremony, multiple tabs and provider cancellation with representative users or browser traces. Preserve no-store/no-referrer and safe restart.

Exit: Any UX change has explicit entry/completion/retry semantics and leaves the adopted authority/session boundaries intact. Related: D-ENTRY, E2/E8, REQ-010/019.

MISC-0005 — Historical domain-time provenance

Category: data semantics / migration. Evidence level: CONDITIONAL_PROVENANCE_GAP. Status: OPEN; close as inapplicable if no affected historical records exist.

Evidence: S1/S3 distinguish authentication events, Base-session start, absolute expiry and AR persistence metadata. A reliable historical event source has not been established for every potential record.

Abstract problem: Schema completion can fabricate domain history when persistence timestamps are copied into event fields without proof.

Scope/preconditions: Existing data requiring a new semantic timestamp or migration; do not assume production data exists merely because a migration is being written. Impact: high for freshness decisions, lower for an optional historical display. Likelihood: depends on actual retained data; unknown until inventory.

Current containment: No invented auth_time; require reauthentication when trusted evidence is missing. Use Unknown/omit unsupported optional history. Initialize new records from genuine transitions. Never reset shared databases to conceal missing provenance.

Next-cycle test: Establish what datasets exist, which durable source can prove each event, and whether a proposed mapping is valid. Exercise migration on disposable representative records; separate known from unknown rows.

Exit: Proven reconstruction or an explicit unknown/reauthentication policy with tested, non-destructive data handling. Related: E3/E7/E9, REQ-045–049/081.

MISC-0006 — Missing original ORG fragment

Category: requirements provenance. Evidence level: OBSERVED_SOURCE_LIMITATION. Status: OPEN; explicitly deferred.

Evidence: The recovered original plan's REQ-095 says its underlying ORG UI input was truncated. The full 95-row ledger itself is available and hash-verified; only the original hidden fragment is not recoverable from that ledger.

Abstract problem: Filling a missing requirement from a later summary can manufacture product intent.

Current containment: Implement the explicit available ORG requirements REQ-051–056 and the final cycle decisions. Do not add invented signup/provider/label behavior attributed to the missing text. Do not block unrelated work.

Impact/likelihood: Unknown content means unknown impact; this is not evidence of a vulnerability.

Next-cycle question: Recover the original untruncated user instruction when available, then compare only actual differences with implemented behavior.

Exit: Exact source recovered and differences adjudicated, or user explicitly retires the missing fragment. Related: REQ-095, E10.

MISC-0007 — Cross-store correctness under real failure modes

Category: reliability / security. Evidence level: OPERATIONAL_VALIDATION_GAP. Status: OPEN.

Evidence: S2 C / S3 ADV-004 report ignored family-link outcomes and independent PostgreSQL/Valkey effects. Those known defects are required E1 fixes, not deferred by this entry. Attach E1's actual state/failure-test results here when available.

Abstract problem: Isolated exception injection may not represent ambiguous network acknowledgements, replica/failover state, process death or delayed cleanup across independently durable stores.

Scope/preconditions: Selected deployment topology, pending issuance, owner-scoped replay, compensation and later refresh generations. Impact: potentially high if a failure loses revocation state or affects the wrong generation. Likelihood: not measured for the real deployment.

Current containment: E1's positive required-link check, no reopening of uncertain consumed codes, operation/generation fencing, owner-scoped forward recovery and no token success on unresolved required state. If these fail, mark the affected slice deployment-blocking; do not claim containment from this memo alone.

Next-cycle test: Against explicitly authorized isolated infrastructure matching the intended topology, exercise process death and network/failover ambiguity at each documented state boundary. Verify replay during pending issuance, response loss and late compensation against newer generations.

Exit: Observed failure outcomes match the implemented state contract and operational recovery procedure. Related: E1-T2/T3, REQ-020/059/062.

Template for newly discovered findings

MISC-NNNN — Concise root-cause title

Status: OPEN / MITIGATED / RESOLVED / SUPERSEDED.

Category: architecture / security / performance / data / contract / testing / operations / UX.

Evidence level: SOURCE_OBSERVATION / REPRODUCED_TEST / HYPOTHESIS / MEASUREMENT_GAP / VALIDATION_GAP.

First observed: date, phase and actual HEAD; update history separately.

Concrete evidence: file + symbol + line, or executed test/command and result. Identify supplied-report-only evidence.

Abstract problem: invariant or recurring design weakness, in one paragraph.

Scope and necessary preconditions: realm, actor, component, deployment conditions.

Impact magnitude: LOW / MEDIUM / HIGH / UNKNOWN, with explanation.

Occurrence likelihood and confidence: qualitative, with evidence; UNKNOWN unless supported.

Current containment and residual: actual implemented restriction, or explicitly none. Deployment-blocking: YES / NO / UNDETERMINED.

Why deferred: bounded reason; this is not risk acceptance.

Next-cycle analysis question: specific decision to resolve.

Confirmation/falsification test or measurement: data and safe environment needed.

Exit criterion: evidence sufficient to close the finding.

Related REQ/ADR/finding IDs and owner of the future decision.

Resolution history: append actual patch/test/evidence when resolved; keep prior observations.

Do not log secrets, raw bearer artifacts or personal data here. Do not write speculative statistics. Do not store a production exploit as a reproduction. A new severe confirmed flaw is contained/fixed in the affected slice or explicitly left deployment-blocking; it is never silently reclassified as harmless next-cycle work.

MISC-0008 — Current shell does not prove isolated Rails test services

Status: MITIGATED for the verified host; CI service provisioning remains OPEN.

Category: testing / operations.

Evidence level: VALIDATION_GAP.

First observed: 2026-09-14, E0, HEAD `430ac354ba06c9d22885e1e69d027a7a1b1d5280`.

Concrete evidence: The current process environment resolves both PostgreSQL host variables to `primary` and `AUTH_STATE_REDIS_URL` to `redis://valkey:6379/2` (credentials were not inspected or recorded). `config/environments/test.rb` replaces Rails cache and rate-limit stores, but does not change auth-state Valkey. `config/database.yml` has distinct `test_*` database names but inherits the shared default PostgreSQL user. `compose.yaml` defines persistent PostgreSQL and Valkey volumes. `AuthorizationCodeStore#default_connection`, `OpaqueAdmissionStore#default_connection` and `SignOutNoticeStore#default_connection` use fixed auth-state namespaces; direct store tests use suite-specific namespaces, but those parameters are not applied by these default application constructors. The Turnstile verifier is injected suite-wide; `OutboundHttpStub` is opt-in and no global egress-deny hook was found in `test/test_helper.rb`. Docker, Podman, Valkey/Redis server and PostgreSQL server binaries are unavailable in this shell. No database or Valkey endpoint was probed or mutated.

Rechecked during the current authorized-plan continuation on 2026-09-14 at HEAD `430ac354ba06c9d22885e1e69d027a7a1b1d5280`: Rails tests, coverage, route boot, and `bin/ci` remain unrun; this continuation only ran an isolated 34-test React interaction file and syntax checks. The environment findings above remain unclosed, so no Rails baseline or Rails verification is claimed.

Abstract problem: Test mode must not inherit a development auth-state endpoint or share an unscoped auth-state keyspace with developer flows. Separate PostgreSQL database names and Redis logical database numbers do not by themselves prove process-level isolation.

Scope and necessary preconditions: Rails tests that load fixtures, perform database cleanup, or use a default auth-state store in this shell. Impact magnitude: HIGH if such a run is allowed to write to the current development Valkey DB. Occurrence likelihood and confidence: UNKNOWN; the test paths exist, but no Rails test was executed here. Deployment-blocking: UNDETERMINED; this finding blocks Rails verification in this execution environment, not a claim about production behavior.

Current containment and residual: No Rails boot, Rails test, route command, CI, database/Valkey probe, server, or provider request was made. Do not use the current `/2` URL for test execution. A dedicated disposable local service, or an explicitly proven test-only target with scoped cleanup and run/worker key isolation, is still required. The standard `test_*` database names and test-only direct-store namespaces are useful evidence but do not close the Valkey gap.

Why deferred: The current shell has no container runtime or local datastore server binaries to construct an isolated disposable target, and service identity has not been verified. This is an environment limitation, not acceptance of test-to-development contamination.

Next-cycle analysis question: Can the supported development setup provision a disposable test PostgreSQL/Valkey pair, or should the test harness pass suite/worker namespaces through every default auth-state store without adding test-only application behavior?

Confirmation/falsification test or measurement: Before boot, print only sanitized effective target identities; prove all test database names and any cleanup targets are test-prefixed; prove every Valkey write is directed to a dedicated disposable instance or run/worker namespace; demonstrate external egress is stubbed/denied. Then run the focused auth-state tests and parallel test harness without `FLUSHDB`/`FLUSHALL` and verify no development keys/databases change.

Exit criterion: E0-T1/T3 isolation proof is recorded and a current Rails baseline runs only against disposable/test-scoped resources. Related: E0-T1–T3, REQ-064/066/069. Owner: current implementation run.

Resolution history (2026-09-15): reachable dedicated PostgreSQL/Valkey targets were verified
before Rails boot, all effective test databases were checked, and run/worker cleanup was exercised
without FLUSHDB/FLUSHALL. The corrected local `bin/ci` accepted only explicit responsibility URLs
for Valkey DBs 3/4/5 and completed its Rails/static/security stages. The original shell limitation
is resolved for this host-authorized run; CI service provisioning on another host remains a
separate validation item. See `evidence/2026-09-15-e0-green-baseline.md`.

MISC-0009 — Canonical Bun-runtime Vitest coverage merge overflows

Status: RESOLVED for the repository coverage entry point; the historical Bun-runtime failure is
retained below.

Category: testing / tooling.

Evidence level: REPRODUCED_TEST.

First observed: 2026-09-14, E0, HEAD `430ac354ba06c9d22885e1e69d027a7a1b1d5280`.

Concrete evidence: `bun run test` exited 0 with 85 files and 1,057 tests after the RootLanding admission-action tests were added. The former `bun --bun vitest run --coverage` exited 1 while merging V8 coverage, with `RangeError: Maximum call stack size exceeded` in `@bcoe/v8-coverage` 1.0.2. The tracked `test:coverage` script now invokes `node node_modules/vitest/vitest.mjs run --coverage`; on Node 24.20.0 it exited 0 with 85 files/1,057 tests and current statements 100% (2,184/2,184), branches 99.63% (1,354/1,359), functions 100% (739/739), and lines 100% (2,143/2,143). The V8 provider, projects, test population and thresholds are unchanged. The command was run with the locked dependencies and its result is the current formal JS coverage evidence. The earlier 1,055-test metrics remain historical for the pre-test-addition source.

Abstract problem: The package's forced Bun runtime and the locked V8 coverage merger may disagree on coverage range data, so ordinary test success cannot substitute for the required coverage gate.

Scope and necessary preconditions: `bun run test:coverage` and the JavaScript coverage step in `bin/ci`. Impact magnitude: MEDIUM for repository verification; no product-runtime effect was observed. Occurrence likelihood and confidence: HIGH for the current Bun 1.4.0/Vitest 5.0.0 environment because the failure reproduced once; behavior under other supported environments is UNKNOWN. Deployment-blocking: YES for claiming the configured JS coverage/CI gate passed, not a deployment security finding.

Current containment and residual: Bun remains the package manager and ordinary test runtime; only the coverage launcher uses Node because the locked V8 provider requires a compatible Node runtime. The historical Bun merge failure is not suppressed or converted to success. Ruby coverage and canonical CI remain separate open gates.

Resolution: The formal launcher was changed to an explicit Node/Vitest invocation after checking the locked Node/Vitest/coverage versions and confirming the same configured projects and thresholds.

Next-cycle analysis question: Does the overflow occur for a minimal Bun/Vitest coverage selection or only after full two-project parallel coverage merging?

Confirmation/falsification test or measurement: Compare one-node-project and one-component-project subsets, then a single-worker full suite, under the locked Bun and Node runtimes with coverage reports in `/tmp`; inspect `@bcoe/v8-coverage` inputs without modifying thresholds. Any proposed script change must preserve the same Vitest projects, test population, and coverage gates and make the `bin/ci` coverage stage green.

Exit criterion met: the canonical repository coverage entry point completes the same test population and enforces all configured thresholds without stack overflow, skipped tests, altered exclusions or changed thresholds. Related: E0-T2, E10-T1, REQ-069. Ruby coverage and `bin/ci` are separate work.

MISC-0010 — E0 isolated Rails service checkpoint

Status: MITIGATED for the current host-authorized test run; CI service provisioning remains OPEN.

Category: testing / operations.

Evidence level: REPRODUCED_TEST.

First observed: 2026-09-15, E0 environment implementation, HEAD `7bee4819ffe2a402c63a04af2a368bfcaf253c0d`.

Concrete evidence: A read-only preflight against `primary.dns.podman:5432` exited 0 and observed
PostgreSQL 17.7, administration database `db`, and 646 `test_*` databases. Read-only Valkey
probes against `valkey.dns.podman:6379` exited 0 for logical DBs 3, 4, and 5, each returning
`PONG` from Valkey 7.2.4. The test wrapper now requires an explicit PostgreSQL test host,
credentials, administration database, all three responsibility URLs, and a run identifier; it
does not fall back from `POSTGRESQL_TEST_HOST` to `POSTGRESQL_HOST`.

The wrapper command `PARALLEL_WORKERS=1 scripts/test-isolated bin/rails test
test/lib/umaxica/valkey/connection_and_cleanup_test.rb` exited 0 with 2 runs, 7 assertions,
0 failures, 0 errors, and 0 skips. Its final cleanup deleted only the run-scoped auth-state
prefixes and verified them empty. The E0 contract test exited 0 with 3 runs and 14 assertions.
The requested authorization-code and app/com OTP target run reached Rails and exited 1 with 147
runs, 725 assertions, 0 failures, 3 errors, and 0 skips; the errors are application/test
contract failures, not service-connectivity failures: two OIDC token-exchange helper calls omit
required client/redirect/PKCE keywords, and one com sign-in Turnstile test expects a missing
`form_errors` prop. Cleanup deleted 65 run-scoped keys.

A two-worker smoke plus contract run exited 0 with 5 runs and 21 assertions, confirming the
worker-scoped namespace hook and test database clone path without failures; its run-scoped
cleanup completed after both workers.

Implementation evidence: test boot validates Valkey DB assignments 3/4/5; application auth-state
stores include run and worker scope; parallel-clone administration now requires
`POSTGRESQL_DATABASE`; Action Mailer remains `:test`, SMS remains the `test` provider, the
Turnstile verifier remains the suite stub, and outbound HTTP tests use the existing Faraday test
adapter helper. No database was dropped/reset and no real provider request was made.

Remaining gap: this host has no container runtime or local datastore binaries, so the reachable
Podman-DNS services could not be started or inspected through a runtime CLI. The repository CI
workflow was not changed to publish a datastore port; a compliant CI service-network setup still
needs to provide the explicit test variables before the wrapper can be used there. Full Rails and
coverage runs were not used as E0 completion evidence; the target run remains red for the three
pre-existing application/test-contract errors above.

The full Rails run was subsequently executed with 16 workers through the wrapper: exit 1 after
452.716 seconds, 12,995 runs, 78,688 assertions, 4 failures, 15 errors, and 3 skips. This confirms
the service setup reached application tests; it is not a green application baseline. A following
SimpleCov run stopped before tests because Rails found the newly present untracked Blazer migration
pending. Its partial 52.02% line / 1.07% branch / 2.52% method numbers are explicitly not a
baseline. The Blazer migration, structure dump, and initializer changes were preserved as
unrelated work.

Exit criterion: keep the explicit test variables and run/worker namespace contract, provide a
non-published test service network for CI or an equivalent approved runner, and resolve or
separately classify the three application failures before claiming a green authentication suite.
Related: E0-T1–T4, REQ-064/066/069. Owner: current implementation run.

MISC-0011 — E0 guards, OIDC refresh reception, and quality gates

Status: PARTIALLY_COMPLETE — normal Rails/JS suites, local static gates, and canonical CI pass;
Ruby branch/method coverage remains below the unchanged gate.

Category: testing / security / operations.

Evidence level: IMPLEMENTED_AND_RUN_LOCALLY; current contract, target, full Rails, and component
checks have been executed on one stable source tree and dedicated test resource set.

First observed: 2026-09-15, E0 safety-guard continuation, HEAD `e9fa72ce5fc0c9e62c9a5a7a8233b477ba77f8b6`.

Concrete change: Rails test boot validates every effective test database configuration against
`POSTGRESQL_TEST_HOST`, `POSTGRESQL_PORT`, and a test-prefixed database before Active Record opens
a connection. `DATABASE_URL`/unsupported `*_DATABASE_URL` overrides are rejected rather than
silently ignored. Test Valkey responsibilities must use logical DBs 3/4/5 on the explicit
`VALKEY_TEST_HOST`/`VALKEY_TEST_PORT`. Run identifiers are claimed locally, cleanup refuses an
active claim unless explicit recovery is requested, and the wrapper preserves child status while
handling normal, failed, INT, and TERM exits. SCAN cleanup consumes all cursors and deduplicates
keys. The test Turnstile adapter and Faraday transport now fail closed unless a test supplies an
explicit response/test adapter.

Observed validation: the safe Rails configuration accepted 38 effective test configs and an
unsafe `DATABASE_URL` was rejected before a connection. The dedicated `test_primary_db` was
read-checked and migration `20260915000000_create_blazer_tables` was applied only after that
check; the three ticket databases received only the OIDC refresh-claim migrations. E0
contract/transport tests passed with 36 runs/100 assertions (one worker) and 9 runs/31 assertions
(two workers). OIDC/refresh focused tests and the Base token endpoint regression pass. The latest
Rails coverage run completed 13,020 tests/78,865 assertions with no test failures/errors, but
SimpleCov exited 2 at line 98.36%, branch 87.59%, method 94.05%.

Abstract problem: reachable test services are useful only when every Rails connection and provider
transport is proven to target an isolated, explicitly named test resource. A prior successful
preflight alone did not establish that invariant.

Coverage remains open only on Ruby dimensions: formal JS coverage exits 0 through the Node/Vitest
launcher with the configured thresholds. Ruby/Rails static checks, ERB lint, Brakeman 8.0.6
(including the wrapper), OpenAPI lint/verify, formatting, TypeScript, and dead-code checks pass.
Bundler-audit 0.9.3 updated its disposable advisory database and found zero results. A canonical
`bin/ci` run using the four-database manifest passed after the explicit visibility fix; Rails
reported 13,020 runs, 78,864 assertions, 0 failures, 0 errors, and 3 existing skips.

Remaining work: raise Ruby branch/method coverage without weakening gates and continue the E1–E10
slices. No real provider request or GitHub write was performed.

Resolution history (2026-09-15, post-freshness checkpoint): the current source completed the
normal isolated Rails suite with 13,038 runs / 78,947 assertions / 0 failures / 0 errors / 3
existing skips (seed 47560, 16 workers). A same-source SimpleCov run completed the tests but
exited 2 at line 98.37%, branch 87.70%, method 93.83%; the gate remains open. The isolated local
canonical `bin/ci` passed its configured non-COVERAGE stages with a Rails stage of 13,038 / 78,924
and the Node-backed formal JS coverage passed. These values supersede the earlier 13,020-run
measurements for current status; the earlier measurements remain historical evidence.

Final E0 recheck: `bundle exec ruby scripts/test-environment-check` exited 0 against PostgreSQL
`primary.dns.podman:5432` and Valkey `valkey.dns.podman:6379` DBs 3/4/5. Child failure and TERM
signal tests preserved exit status while running cleanup; no marker remained afterward. The
dedicated database contains the applied Blazer migration and was not reset or dropped. The
current detailed evidence is `evidence/2026-09-15-e0-green-baseline.md`.

MISC-0012 — OIDC refresh grant and authentication-event claim persistence

Status: IMPLEMENTED_LOCALLY; cross-surface/public failure injection remains OPEN.

Evidence: `BaseOauthTokenEndpoint` now forwards `refresh_token`; `OidcTokenExchangeCoordinator`
accepts the standard refresh grant, rotates a client-bound RP refresh usage, and reissues Access/ID
tokens with a new `iat` and the persisted authentication event time. Three ticket migrations add
nullable claim storage without touching development or production databases. The focused combined
set passed with 132 runs/3,655 assertions, including 79 refresh-service runs/345 assertions, 37
Base endpoint runs/190 assertions, and 3 architecture runs/3,078 assertions. The first endpoint
regression was RED because `refresh_token` was not forwarded; the current production fix is GREEN.

Residual: registered clients other than the exercised app path, DPoP-bound refresh, absolute-expiry
boundaries, concurrent rotation, and provider-level HTTP requests still need public integration
tests. Exit criterion: each registered Base surface accepts only its own rotated family, preserves
`auth_time`/claims, rejects replay/revoke/expiry/wrong-owner cases, and passes canonical CI and
coverage gates. Related: D-REFRESH, E3/E4, REQ-011/015/030/057/061/062.

MISC-0013 — OIDC prompt/max_age freshness persistence and verification

Status: IMPLEMENTED_LOCALLY; broad end-to-end policy coverage remains OPEN.

Category: authentication / OIDC / data contract.

Evidence level: IMPLEMENTED_AND_RUN_LOCALLY.

First observed: 2026-09-15, current feature worktree, HEAD
`e9fa72ce5fc0c9e62c9a5a7a8233b477ba77f8b6`.

Concrete evidence: `OidcAuthorizeRequestResolver` now normalizes the supported `login` and `none`
prompt values and non-negative `max_age`; the three authorization-transaction models persist
nullable `oidc_prompt`/`oidc_max_age` fields; Base app/com/org authorization endpoints use the
stored request to decide whether an existing authentication is fresh enough; and
`OidcIdTokenVerifier` rejects a missing or stale `auth_time` when a max-age constraint is present.
The RP initiator/callback carries max-age through pending flow state. Dedicated model, resolver,
Base endpoint, SSO initiator, callback and verifier tests pass, and the full Rails suite remains
green. The migrations were applied only to the verified dedicated ticket test databases.

Abstract problem: OIDC freshness is a protocol contract spanning request parsing, transaction
storage, Base admission, token claims and RP verification. A single endpoint branch or reader
does not prove that the original authentication event survives the full path.

Scope and necessary preconditions: all registered browser clients and app/com/org surfaces, with
isolated test databases and stubbed providers. Impact magnitude: HIGH if stale authentication is
accepted for a request requiring fresh authentication. Occurrence likelihood and confidence:
MEDIUM; the implemented slice is directly tested, but the complete cross-surface event provenance
and failure-injection matrix is not.

Current containment and residual: unsupported prompt combinations remain rejected; missing/stale
`auth_time` fails closed when max-age is required. No fallback to `created_at`, code issuance time,
exchange time or current time was added. Deployment-blocking: UNDETERMINED pending the remaining
cross-surface tests and review of the true Base authentication-event source.

Why deferred: the remaining work crosses Base/Auth admission, all RP registrations, reauthentication
and refresh, and must not be inferred from the new nullable fields alone.

Next-cycle analysis question: Does each successful Auth ceremony and SSO/re-authentication path
provide the same Base-accepted event timestamp to authorization-code issuance and refresh, and do
all registered RPs enforce the requested freshness at the public callback?

Confirmation/falsification test: use isolated app/com/org clients with authentication T0, code
issuance T1 and exchange T2 separated; assert ID/Access `auth_time` remains T0, refresh changes only
`iat`, `prompt=login` forces a new event, `prompt=none` returns the protocol error when needed, and
`max_age` rejects a stale or missing event without creating a session or code.

Exit criterion: the public cross-surface matrix and the auth-time source audit pass with no unsafe
timestamp fallback, while the unchanged Rails and coverage gates remain truthful. Related:
REQ-011/012/013/030/031, E3/E4.

MISC-0014 — Current canonical CI and Ruby coverage gate checkpoint

Status: PARTIALLY_COMPLETE — canonical non-COVERAGE CI is green; Ruby SimpleCov remains below
the existing branch/method/file/group/drop gates.

Category: testing / quality gate.

Evidence level: IMPLEMENTED_AND_RUN_LOCALLY.

First observed: 2026-09-15, current feature worktree, HEAD
`e9fa72ce5fc0c9e62c9a5a7a8233b477ba77f8b6`.

Concrete evidence: the corrected local `bin/ci` was run with the verified PostgreSQL test target
and explicit Valkey URLs for cache/rate-limit/auth-state logical DBs 3/4/5. It exited 0 after
database preparation, JS checks and coverage, Ruby/ERB lint, bundler-audit, bun audit, Brakeman,
loopback Rails boot, and Rails tests. The Rails stage reported 13,058 runs, 79,090 assertions,
0 failures, 0 errors, and 3 existing skips (seed 48755, 16 workers). A prior invocation with an
inherited cache URL on logical DB 0 was rejected before preparation; no unsafe connection was
opened.

The explicit Rails coverage run on the same source completed 13,058 tests with 0 failures/errors
but SimpleCov exited 2 at line 98.38% (57,972/58,924), branch 87.88% (8,669/9,864), and method
93.87% (10,064/10,721). The configured floors and file/group/maximum-drop rules were unchanged.
Formal Node/V8 coverage passed independently at statements 100%, branches 99.63%, functions
100%, and lines 100% for 85 files and 1,057 tests after the RootLanding admission-action tests
were added. The earlier 1,055-test CI measurement remains historical for the pre-test-addition
source. Bundler-audit found no known gem
vulnerabilities; no live provider was contacted.

Abstract problem: a green ordinary test suite and green JS coverage do not prove the Ruby coverage
gate or all feature contracts. Coverage deficits must be closed with behavior tests or verified
dead-code decisions, never by lowering thresholds, expanding exclusions, or adding empty tests.

Current treatment: retain the red SimpleCov result as an attributable measurement and continue
the E1-E10 public negative/concurrency/error-path tests. The remaining Ruby coverage work is not
a reason to discard the green ordinary suite or to claim full feature completion.

Exit criterion: a same-source Rails coverage run exits 0 with the existing dimensions and drop
rules, or each remaining exception has an evidence-backed production/dead-code decision reviewed
without changing the gate. Related: REQ-020/066/069, E9/E10.

MISC-0015 — Integration test debug output exposed authentication response cookies

Status: MITIGATED — the debug output was removed and the public integration test remains green.

Category: security / test observability.

Evidence level: REPRODUCED_TEST.

First observed: 2026-09-15 during the current-source canonical `bin/ci` run. The existing
`test/integration/auth_booster_test.rb` test `check auth allows authenticated` emitted a warning
containing the response body and access/refresh cookie values. The test did not need that output
for its assertions, and the CI log therefore contained credential-shaped values even though the
test endpoint is local.

Change: removed only the debug `warn` call; authentication behavior, cookie assertions, and test
setup are unchanged. The isolated regression run completed 10 runs and 27 assertions with zero
failures/errors/skips. No emitted value is retained in this memo or in evidence.

Residual: other test or dependency logging is not proven globally silent. A future test-support
audit should scan output paths for cookies, authorization headers, token bodies, and raw request
parameters without weakening the outbound-communication guard.

Exit criterion: the targeted test and canonical CI pass without credential-shaped debug output,
and the repository logging-boundary checks continue to pass.
