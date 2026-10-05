# Root login HTTP test migration

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication implementation and concurrent unrelated work. No commit, deployment, database rebuild or schema change.
- Database: owned isolated run `20261003auth6f3`, manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, preparation selected the isolated APP ticket copy, one worker. Commands ran sequentially.

Three existing `root_login_establishment_flow_test.rb` scenarios now exercise their correct public
boundary: normal login, session-limit refusal, and unauthorized session-limit access. The first
two use actual Base admission POST, a separate Auth browser cookie jar, real Email HOTP checking,
opaque result delivery and Base completion. Only Jump transport and Turnstile are substituted;
Auth root credentials are neither issued nor injected. Setup HOTP data is written through the
existing credential model API. The APP Email JSON success contract remains unchanged and held.

The normal case asserts no token or login audit on Auth, exactly one Base token and login audit,
the original authentication time, root anchor and device session, and the subsequent real
selector/dashboard navigation. The session-limit case verifies no Base token, root cookies,
login audit or RESTRICTED placeholder, exact waiting flow state, retained existing tokens and
the rendered Base session inventory. The unauthorized case requests the Base limitation endpoint
with principal identifiers but no flow locator and receives HTTP 410 without root credentials.

`bin/rails test test/integration/root_login_establishment_flow_test.rb --name '/normal_sign-in|at_the_session_limit|principal_id/'`
passed: **3 runs, 53 assertions, no failures/errors/skips**, seed 36517. Rails emitted a CLI notice
recommending `--include` instead of `--name`; subsequent selections should use the supported option.
RuboCop formatting corrections were applied. The final parsed-body adjustment uses the framework's
public HTML parser; no custom test helper or global test infrastructure was introduced.

The full seven-scenario root-login integration file is not green or fully migrated. Capacity
resolution, cancellation and cooldown still call the old admission-free Auth flow. An accidental
line selection included the old cooldown case and reproduced its missing-token error. No scenario
was removed, skipped or weakened. RESTRICTED-token rejection remains in the file. The retained
broader gate failure is described in `2026-10-04-auth-registration-entry-guards-3P7L.md`.

Passkey candidate persistence/response approval remains pending. No unapproved shape was implemented.
Full R01–R16 remains incomplete; browser checks are user-owned and OTP logging remediation is excluded.

## Capacity resolution and cancellation continuation

The capacity-resolution and cancellation scenarios now use the same actual Base admission/Auth
credential/Base completion boundary, with inline public HTTP requests and separate cookie jars.
Base resolution revokes exactly one selected existing token, issues exactly one new root token and
login audit, retains the original authentication time, and rejects duplicate issuance on repeated
submit. Cancellation preserves every existing token, creates no token or login audit, closes the
waiting flow, returns to Base neutral entry, refuses later management and rejects the old result.

The five migrated scenarios passed together:
`bin/rails test test/integration/root_login_establishment_flow_test.rb --include '/normal_sign-in|at_the_session_limit|principal_id|resolving_the_limit|cancelling_at_the_limit/'`:
**5 runs, 109 assertions, no failures/errors/skips**, seed 43417. RuboCop passed after one formatting
correction and `git diff --check` passed. Cooldown still requires migration; the seven-scenario file
and broader required gate are not yet claimed green.

## Cooldown and required gate completion

Cooldown now uses real Base admission/Auth verification/Base completion with separate cookie jars.
Two independent runs cover acceptance at 30 seconds and 30 seconds plus one microsecond. Each first
logs in and logs out, then refuses a new ceremony at 10 seconds and immediately below the boundary
(29.999999 seconds), retaining the original root anchor, no new token and full-window Retry-After.
The test controls Time.current and the public flow/continuity writer-clock APIs consistently; this
is deterministic HTTP evidence, not a browser or wall-clock PostgreSQL timing measurement. Timestamp
comparisons use the database's six-digit persisted precision. The old admission-free login test
helpers were removed. Legacy RESTRICTED-token refusal remains an independent negative test using
its pre-existing authenticated-header harness; it is not evidence of a genuine login journey.

The required command now passes:
`bin/rails test test/controllers/concerns/auth/session_issuance_boundary_surfaces_test.rb test/controllers/concerns/auth/login_cooldown_surfaces_test.rb test/integration/root_login_establishment_flow_test.rb`:
**59 runs, 401 assertions, no failures/errors/skips**, seed 19839. The original seven scenarios
remain, with cooldown expanded into two independently isolated boundary cases. RuboCop passed after
formatting corrections. This supersedes the earlier failed result for this specific gate; it does
not establish completion of the full authentication ledger or entire suite.
