# Core access refusal preserves independent refresh

Executed 2026-10-04, completed 02:50:20 UTC (Etc/UTC).
Rails branch: `feature`; HEAD: f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5.
The shared worktree had 323 dirty paths at continuation start and 329 at completion.
Results include uncommitted changes, including concurrent agent work; they are not
clean-commit CI results. Edge was inspected read-only at main
185dd076404011ed391b2b550091be3fd7939ba0, with 38 dirty paths. No Edge code or
deployment setting was changed in this increment.

## Finding and repair

`CoreBrowserApiBoundary#reject_core_browser_cookie!` deleted both RP access and
refresh cookies after an access refusal. A correctly signed access token beyond
the configured JWT leeway reproduced removal of an independently valid, persisted
RP refresh credential. The source RP row remained valid, but its browser credential
was lost. The repair removes only refresh-cookie deletion from that refusal path.
The existing 401 problem, access-cookie deletion and unauthenticated Actor state
are preserved. Refresh presence confers no authentication and causes no GET
rotation. The same rule applies to malformed access, without a new public failure
classification. Explicit POST still verifies refresh, root session and account.

The old Core pair-deletion paragraph in
`adr/invalid-browser-credential-recovery.md` is explicitly superseded for access
refusal by the later integrated continuity requirement. Root auth, preference,
logout and refresh replay contracts were not modified. Current behavior and
remaining browser limits are recorded in `docs/security/core-browser-request-boundary.md`.

## Tests and commands

The existing `/tmp/umaxica-secret-db-task.rb` wrapper verified the task-owned
twenty-database manifest and writer ownership on PostgreSQL 17.7 before running
Rails tests. No shared or production database was changed.

- Red: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test
  test/integration/core_access_refusal_refresh_retention_test.rb`:
  **1 test, 7 assertions, 1 failure**, showing refresh removal. An earlier
  construction placed expiry inside existing JWT leeway; that was a test-input
  mistake, not a product Red. The corrected test exceeds the configured leeway.
- The extended three-surface journey passes **1 test, 123 assertions**. Each
  surface presents real signed expired access and malformed access with its own
  real persisted RP refresh. Access is refused, no actor is returned, refresh
  remains, and the RP row is unchanged. The test then obtains CSRF from the
  passive session endpoint, sends the existing exact-Origin refresh POST, checks
  real digest rotation and an empty 204, and accepts the newly issued access on
  the next GET. Forgery protection is enabled and restored within the test.
  No success/issuer/rotation/verification mocks or private-method calls are added.
- Regression: wrapper `test` with the new journey,
  `core_browser_api_boundary_test`, `core_browser_origin_boundary_test`,
  `core_rp_cookie_surface_contract_test`, com session controller test,
  `core/auth_boundary_test`, OpenAPI Core session contract and forbidden Rails
  patterns guard: **47 tests, 468 assertions, zero failures/errors/skips**.
- `bundle exec rubocop app/controllers/concerns/core_browser_api_boundary.rb
  test/integration/core_access_refusal_refresh_retention_test.rb`:
  **2 files, no offenses**. No new suppression or gate reduction.
- `git diff --check`: PASS.

The test bounds the real root sessions by a deadline and verifies that rotation
does not extend that bound, RP public identity or authentication time. An initial
fixture gave the root an infinite deadline and the RP a shorter renewable expiry;
it was corrected to exercise the declared root absolute-expiry invariant. No TTL
or rotation policy was changed to make the test pass. Each surface gets a fresh
integration session; replacing an expired Rack::Test cookie clears its retained
deletion metadata before presenting the next value. Assertion messages avoid
printing raw refresh credentials or digests.

## Limits and remaining work

Application boundary: the scoped Rails refusal repair and regression pass.
Login continuity: the existing explicit Rails HTTP continuation is proven on
app/com/org; actual browser-triggered continuation is NOT_RUN. No new automatic
refresh request, timer, endpoint, GET renewal, old-generation acceptance, grace
window, response-loss recovery, token storage or rotation protocol was added.
Concurrency, delayed/reversed responses and logout competition are not proven
by this sequence; an old access deletion response may still compete with a newer
response and needs separate investigation under the refresh gates.
Deployment readiness: NOT_RUN; public routing/CDN cutover remains outside this
local increment. No actual browser, external gateway or full repository suite ran.

The inspected app settings Passkey registration still lacks a durable authorization
transaction explicitly covering Secret delivery. Saved Passkey existence is not
used as Step-Up evidence. Neither its shared recovery path nor new Secret delivery
was changed in this increment; the combined authorization and payload shape gates
remain open.
