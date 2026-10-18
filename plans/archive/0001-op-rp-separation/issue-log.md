# Implementation Issue Log

> Archived snapshot, generation 0001 (originally `seven.md`). Non-normative and not evidence; see
> [README](./README.md).

## R1-WU01 — Authentication-context propagation

Date: 2026-10-16

### Issue

The first narrow R1-WU01 verification run reported one failure in
`test/controllers/concerns/browser_rp_authentication_test.rb`. The new context-mismatch case
declared an `authentication_context` override but did not pass that value to
`AuthenticationTokenService.encode`. The test therefore minted a Normal token and did not exercise
the intended mismatch boundary; the product failure was not reproduced.

### Resolution

The test now passes the case's explicit context to the encoder. The Core Browser credential encoder
also now derives and emits the strict context from its token record, and its integration coverage
asserts the emitted `authn_ctx` claim.

### Verification

The affected suite was rerun after the correction:

```text
135 tests, 693 assertions, 0 failures, 0 errors, 0 skips
```

The result was obtained against HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001` with the existing
uncommitted application and test changes present. This is narrow implementation evidence only; it
does not close `AT-R1-01` or any release Gate.

## R2-WU01 — Local test preparation found retained open rows

The first `bin/rails db:test:prepare` after adding the waiting-slot migrations stopped at the app
Ticket migration. The migration intentionally refuses to select a winner from retained open rows;
the test database contained five such rows, including two rows for actor `4ywtGJkqoplEiyKfBeF4x`.
The migration reported the IDs and state IDs and did not install the app constraints. The com and
org test databases had already applied their new migrations in that run.

This is the expected populated-data guard from `one.md` section 6.1: a future populated target needs
the approved earliest `started_at, id` reconciliation through the named writer, with loser rows
cancelled and audited. The current development/test data is disposable under section 1.2A, so the
authorized recovery is to rebuild the local test targets from migration history before rerunning
preparation. No application behavior was inferred from the partial test preparation.

### R2-WU01 — Direct constraint probe required a NULL hardening correction

The first direct database probe showed that the waiting-slot `CHECK` expression used
`waiting_slot = 1` without an explicit `IS NOT NULL` predicate. PostgreSQL permits a `CHECK` whose
result is `UNKNOWN`, so an open row with `waiting_slot = NULL` was not rejected. The same probe also
confirmed that the first migration had replaced the existing state-timestamp constraint, so the
timestamp invariant was restored as a separate forward constraint before verification continued.

The waiting-slot expression now explicitly requires `waiting_slot IS NOT NULL AND waiting_slot = 1`
for open states. Hardened forward migrations replace the earlier local constraint, and the existing
state-timestamp constraint is retained and validated. The disposable local test databases were
rebuilt again from migration history; development and test schemas now report `smallint`, the actor
partial unique index, and both validated check constraints for all three realms.

The model suite and the existing session-limit/root-login concurrency selection then passed:

```text
15 runs, 82 assertions, 0 failures, 0 errors, 0 skips
35 runs, 949 assertions, 0 failures, 0 errors, 0 skips
```

## R2-WU03 — Existing state facts rejected free-capacity completion

The R2-WU03 design permits a browser-bound Waiting flow to continue after natural sign-out or expiry
has freed capacity, without selecting or revoking an existing session. The existing
`chk_*_resolution_state_timestamps` constraints required `selected_at IS NOT NULL` for every
`RESOLVED` row, so the legal `PENDING -> RESOLVED` completion could not be persisted with the
existing columns.

Forward migrations now keep the existing state and timestamp columns while allowing a resolved row
to retain a null selection when no purge was needed. Selected completions retain their existing
selected facts. The constraints were installed as `NOT VALID`, validated in separate migrations, and
`bin/rails db:migrate` passed for app, com and org in the local development databases. This is a
source/schema consistency correction required by one.md section 7.2; no historical rows were deleted
or rewritten.

## Verification — parallel Rails test preparation acquired one migration lock

An independent model test and controller test were started in parallel while each Rails test process
ran the repository's automatic `db:test:prepare`. One process applied the pending local test
migrations and the other stopped before its tests with `ActiveRecord::ConcurrentMigrationError` from
the migration advisory lock. The model suite completed successfully; the controller suite was rerun
serially after this observation. This entry records the invocation condition, not an application
behavior failure; migration-backed test commands are run one at a time for the remaining
verification.

## R2-WU04 — Parallel worker database clone initialization

The first combined R2-WU04 verification command used the repository default worker count. The test
harness began rebuilding the 16 process-specific database clones in `ParallelTestDatabaseCloner` and
did not reach test execution during the observation window. The process was interrupted before any
application assertion ran. This was test-environment setup contention, not an authentication result.

The same nine-file command was rerun with `PARALLEL_WORKERS=1`, which skips the worker-clone path
and completed with 143 tests, 1,047 assertions, 0 failures, 0 errors and 0 skips. All subsequent
Rails verification in this unit uses one worker and is run serially. The interrupted invocation was
against HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001` with the existing dirty worktree and the
R2-WU04 changes present.

## R2-WU04 — Test assertion helper mismatch

The first run of the callback coverage regression used `assert_not_match`, which is not available in
this repository's Minitest helper surface. The test failed before evaluating the controller content.
The assertion was changed to Minitest's `refute_match`; the complete focused run then passed. This
was a test-only harness mismatch, not a product behavior failure.

## R2-WU04 — Verification command named a missing test file

The post-cleanup focused command named
`test/controllers/base/app/identity/step_up_authentication_test.rb`, which is not present in this
repository. Rails stopped while loading the test list, before any test assertion ran. The actual
integration coverage is `test/integration/step_up_authentication_test.rb`; the command was corrected
to use the repository's existing paths. This was a verification invocation error, not an application
behavior failure.

## R2-WU05 — Broad contract run exposed stale expectations

The first broad R2-WU05 contract invocation reached three assertions that still described the
pre-ACTIVE-only behavior. The legacy status-103 OIDC test expected a local `423 Locked` response,
but the open authorization endpoint correctly treated the invalid credential as absent and returned
the OIDC `login_required` error to the validated callback for `prompt=none`. The model-refusal test
created historical status-103 rows and expected them to consume the model ceiling, which conflicts
with R2-WU04's preserved historical-row/read-only rule; that setup therefore issued successfully and
did not open a resolution. The test contracts are being updated to assert the current OIDC callback
behavior and to exercise the actual ACTIVE-row ceiling with revoked device sessions, while
preserving the no-issuance and no-history-rewrite assertions.

The corrected three-file verification then passed with 19 tests, 769 assertions, 0 failures, 0
errors and 0 skips. The two Flipper middleware duplicate-registration messages were warnings from
the test boot and did not affect the result.

The complete R2-WU05-focused rerun then passed with 187 tests, 1,417 assertions, 0 failures, 0
errors and 0 skips. It used `PARALLEL_WORKERS=1` after the earlier worker-clone initialization
observation. The run included the session-limit admission and promotion paths, cooldown boundaries,
model ceilings for all three token classes, root-login establishment, and the corrected historical
status-103 OIDC contract.

## R3-WU02 — CI workflow database names could not be written

The source configuration and local CI preparation list were updated to the `op_base_*` database
names. The two remaining references in `.github/workflows/ci.yml` could not be changed: both a
direct write and `apply_patch` were rejected by the filesystem with `Read-only file system`. The
file was left untouched; no permission, mount, or bypass operation was attempted. CI workflow
execution and external repository writes are outside the currently approved local scope, so this
remains an R3-WU06 verification blocker.

## R3-WU06 — Source rename is complete, but the CI workflow remains stale

Date: 2026-10-16

### Facts

The Rails source, database configuration, local CI preparation list, environment examples, migration
directories, abstract records, concrete grant models, fixtures, current documentation, and local
development/test database catalog now use the `op_base_*` naming. The two remaining
`app_ticket`/`com_ticket`/`org_ticket` references in `.github/workflows/ci.yml` could not be written
because the filesystem rejects writes to that path with `Read-only file system`. The workflow was
not chmod-ed, remounted, or bypassed.

The R3 isolated rebuild and focused behavior checks do not remove this blocker: CI workflow
execution and external repository writes are outside the approved local scope. A repository owner
must update the workflow or provide a writable checkout before CI can be verified against the new
database names.

### Status

OPEN. Local source and local database work can continue; CI completion and release acceptance stay
blocked on the unwritable workflow file.

## R3-WU07 — Full Rails suite is not green in the current worktree

Date: 2026-10-16

### Facts

The fresh isolated R3 fleet `20261016r3a1` completed the full Rails suite with:

```text
15376 runs, 127961 assertions, 12 failures, 12 errors, 0 skips
```

The failures were concentrated in the current authentication/session changes: session-limit OIDC
flows returned 400/410 instead of the expected continuation responses, Core Browser RP session tests
returned 401, the StepUp resolver test double did not implement `active_status?`, the architecture
baseline reported a new concern-hook offense, and the reviewed `StandardError` rescue inventory
count changed. The Core session subset was rerun serially and reproduced its four 401 failures in 12
runs / 34 assertions, so the result is not only parallel-worker contention.

The R3 rename-specific focused suite passed with 64 runs / 322 assertions and no failures, errors,
or skips. Therefore no direct failure was observed in the R3 table/model rename boundary, but the
complete implementation cannot be claimed green until the current authentication/session failures
and their accepted R1/R2 contracts are resolved or explicitly accepted.

### Status

OPEN. Do not claim the full one.md implementation or a release Gate PASS from the partial R3 result.

## R3-WU08 — Global schema drift check remains non-green

Date: 2026-10-16

### Facts

The three R3 schema dumps individually matched the repository's schema-drift normalizer against the
isolated target databases. The global `db:verify_no_schema_drift` task still reported sixteen paths:
the three intentional, currently uncommitted R3 dump changes and thirteen non-R3 database dumps
whose live schemas do not match their tracked files. The task also reports any changed dump path
from the current dirty worktree by design.

The local R3 catalog itself was verified after cutover: nine old development/test OP databases are
absent, nine new target databases exist, target active sessions are zero, and every target has its
new grant table without its old table. This proves the R3 database rename locally but does not close
the repository-wide schema-drift check.

### Status

OPEN for repository-wide verification. The R3-specific dump comparison is RESOLVED; the remaining
non-R3 drift and the intentional uncommitted dump paths must be handled before a global schema
verification result can be reported as clean.

## Follow-up — current isolated Rails suite

Date: 2026-10-16

The authentication/session corrections recorded after the earlier R3-WU07 observation were verified
on the fresh isolated R3 fleet `20261016r3a1`. The full Rails suite completed with **15,376 runs,
130,675 assertions, 0 failures, 0 errors and 0 skips** using eight workers. The earlier R3-WU07
application-test failure is resolved for this worktree.

This result does not close the separate R3-WU06 CI workflow blocker or the R3-WU08 global schema
drift result. The CI workflow still contains old database names and remains unwritable in this
checkout; the global drift task still has the previously recorded non-R3 and intentional uncommitted
dump differences.

Status: R3-WU07 **RESOLVED**; R3-WU06 and R3-WU08 remain **OPEN**.

## R5-WU02 — Protocol foundation is locally coherent; global drift verification is blocked

Date: 2026-10-16

### Facts

The additive R5-WU02 foundation is implemented for the three realm pairs. Zenith now has the
realm-specific authentication epoch and identity invalidation-intent tables. Each OP base database
has its initialized contract epoch, consumed-JTI replay table, logout flow/participant/receipt,
outbox and inbound-receipt tables, with realm checks, uniqueness, foreign keys and separately
validated constraints. The corresponding realm model classes and value validation are present. No
RP-local state or runtime logout activation was introduced by this packet.

The development migrations, Zeitwerk check, direct catalog/constraint inspection and focused
foundation tests passed. A fresh isolated fleet rebuild also completed for twenty disposable test
databases and twelve scoped HMAC roles. The full isolated Rails suite then passed with **15,381
runs, 130,799 assertions, 0 failures, 0 errors and 0 skips**. The six affected structure dumps were
regenerated from the current local databases.

The repository-wide `RAILS_ENV=development bin/rails db:verify_no_schema_drift` command did not
reach schema comparison. It stopped because the local `development_com_zenith_db` HMAC definer role
does not match the database-name-derived role expected by the verifier. This is the existing R3-WU08
local catalog/role-boundary issue; no role mutation, credential change or verifier bypass was
attempted.

### Status

R5-WU02 source and local disposable-database foundation: **IMPLEMENTED / LOCALLY VERIFIED**.
`AT-R5-02` is not claimed as a release or runtime activation PASS. R5-WU03 and later runtime packets
remain in progress, and R5 activation remains gated on effective role/secret isolation,
preactivation evidence and the applicable cell gates. The HMAC role mismatch and the existing
R3-WU06 unwritable CI workflow remain **OPEN** blockers for broader verification.
