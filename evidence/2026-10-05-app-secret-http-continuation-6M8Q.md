# App Secret continuation verification

Observed on 2026-10-05, UTC, against HEAD
`7de33215b055bc8f0f2721b86a04b428a049220e` with uncommitted implementation changes.
The existing worktree also contains unrelated uncommitted work.

All Rails commands below used `bundle exec ruby /tmp/umaxica-secret-db-task.rb test`
followed by the named test paths. The wrapper verifies the task-owned disposable
`codex_integrity_20261003secret_*` database fleet against its OID identity manifest.
Observed PostgreSQL server: 10.89.2.3:5432, version 17.7.

- `test/operations/client_secret_manual_reservation_issuer_test.rb`,
  `test/operations/client_secret_storage_confirmation_committer_test.rb`, and
  `test/operations/app_secret_step_up_binding_test.rb`: 22 runs, 383 assertions,
  zero failures, errors, or skips.
- `test/operations/client_secret_presentation_issuer_test.rb` and
  `test/integration/app_passkey_secret_session_step_up_test.rb`: 6 runs, 67 assertions,
  zero failures, errors, or skips. The integration evidence covers registration
  admission denial and direct setup requests. Its independent Passkey Step-Up case
  prepares synthetic verified evidence; it does not verify a WebAuthn signature.
- `test/operations/client_secret_claim_committer_test.rb` and
  `test/jobs/client_secret_audit_delivery_job_test.rb`: initially two errors
  (invalid actor surface and missing test retention policy). After correction:
  2 runs, 23 assertions, zero failures, errors, or skips.
- Route and sign-in page tests initially returned 35 runs, 757 assertions, two
  failures because two existing expectations omitted the new Secret method.
  Those expectations were updated to include the sixth authentication method.
  Rerun: 35 runs, 761 assertions, zero failures, errors, or skips. This includes
  app route presence and continued absence of Secret sign-in routes on com/org;
  it does not cover the other authentication behavior on those surfaces.

The test process lock initially prevented execution. The parent process had exited
but its remaining workers retained the file descriptor. The user authorized stopping
that test; terminating its workers released the lock and allowed the above execution.

These results establish specific operation and admission behavior, not completed
end-to-end Secret login, Passkey-linked delivery, physical recovery, concurrency,
browser history confidentiality, or comprehensive com/org regression coverage.
Those acceptance checks remain outstanding. Historical test totals are not reused.

## Additional HTTP execution

Subsequent execution on the same HEAD and dirty worktree:

- `test/integration/app_secret_login_journey_test.rb` and
  `test/operations/client_secret_passkey_reservation_issuer_test.rb`:
  23 runs, 602 assertions, zero failures, errors, or skips.
- The manual journey enables CSRF, issues through Base HTTP, verifies no lookup
  before confirmation, authenticates through the new Auth form, then completes
  through Base's canonical session boundary. It asserts matching durable receipt,
  consumed credential, Base cookie only, completion replay without another Token,
  and rejected reuse from a new regional (`us`) admission. Initial admission uses `jp`.
- Twenty-one signed-in registration cases cover A=0 through A=20 using real
  WebAuthn FakeClient signatures through public HTTP options and verification.
  Distribution, single-document presentation, atomic confirmation, nineteen-item
  present/confirmed notices, and twenty-item omission are asserted. Existing Step-Up
  freshness is setup evidence; these cases do not claim a real Step-Up ceremony.
- Reservation operation cases separately cover all A values, fixed retry deadline
  and allocation, and no candidate generation during reservation.
- `bun run typecheck` succeeded after adding distribution notice props.

The manual journey's first failure came from setup selecting an account after
recording Step-Up; the existing selector correctly revoked that authority.
The setup was corrected to select before recording scoped proof. A registration
challenge failure came from the test overwriting its browser cookies on every
request; requests now preserve the cookie jar while retaining authenticated bearer
headers. The subsequent failure at the redirect host exposed missing delivery
integration; implementing the app reservation and Base continuation fixed it.

- After cancellation integration and formatter corrections,
  `test/integration/app_secret_login_journey_test.rb` plus
  `test/operations/client_secret_manual_issuance_invalidator_test.rb` passed:
  29 runs, 548 assertions, zero failures, errors, or skips.
- Narrow RuboCop inspection of twelve new/changed Secret files initially reported
  363 offenses and corrected 333. Reinspection still reported 30 offenses,
  including method complexity and line length. Static checks are not yet clean;
  no thresholds or suppression rules were relaxed.

## Audit and purge fault execution

Observed at 2026-10-05T06:19:07+00:00 on the same HEAD and dirty worktree.
`bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/jobs/client_secret_audit_delivery_job_test.rb`
passed with 4 runs, 37 assertions, zero failures, errors, or skips.

The real lifecycle job delivered terminal audit before deleting a revoked Secret.
The deletion left an undelivered `secret.purged` source event, which a later real
delivery job persisted to Chronicle. Reexecution created no duplicate Chronicle
records. Lookup was already rejected before either job ran.

A temporary CHECK in the task-owned disposable source DB forced the acknowledgment
write to fail after the Chronicle write. The source transaction rolled back,
Chronicle retained exactly one event, and rescan acknowledged it without another
Chronicle row. The constraint was removed before retry and lives within the test's
rolled-back transaction; no shared database was altered.

An existing Chronicle UUID with a conflicting reason was rejected without marking
the source event delivered. Delivery now compares result, reason, actor, subject,
changeset and the already-checked action, operation, metadata and timestamp.

This verifies the tested revocation/purge and acknowledgment-failure paths. It does
not establish complete proof/outbox cleanup, every crash boundary, a running Solid
Queue deployment, signup delivery, or real-browser confidentiality.

Additional DELETE fault injection used a source CHECK rejecting `secret.purged`.
The real lifecycle job failed after attempting deletion; its source transaction
restored the credential and saved no purged outbox. Removing the CHECK allowed a
successful retry. Final job suite: 4 runs, 40 assertions, zero failures, errors,
or skips. Narrow RuboCop for the delivery job and its test passed with no offenses.

## Signup delivery connection

`bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/app_secret_signup_journey_test.rb test/operations/client_secret_passkey_reservation_issuer_test.rb`
passed with 3 runs, 232 assertions, zero failures, errors, or skips. The new HTTP
case enables CSRF, verifies telephone OTP, uses a real WebAuthn FakeClient registration,
and keeps the Passkey requirement pending until the dedicated document's two values
are explicitly confirmed. GET does not generate candidates. Confirmed values remain
unavailable while account signup is unfinished. Source authorization tests reject
another nonce and signed-in bootstrap reuse and preserve the same reservation on retry.

The first two new-test failures assumed 303 for existing telephone/OTP redirects;
those unchanged endpoints actually return 302. Their expectations now preserve the
existing redirect contract. The new Secret confirmation returns 303 explicitly.

This is the initial signup delivery case, not proof of the complete signup lifecycle
or all signup counts. Final activation must persist completion on the source side
so later cleanup of the short-lived signup flow does not disable saved Secrets.
That connection, cancellation cleanup, resumptions and signup count matrix remain
unfinished. `bun run typecheck` passed after adding the signup completion form props.

## Signup completion continuation — 2026-10-05T06:46:00+00:00

Same HEAD and uncommitted worktree; same guarded disposable PostgreSQL fleet.
The signup journey now starts with Base POST /sign and Auth admission, completes
telephone OTP, verified WebAuthn registration, explicit Secret presentation,
storage declaration and birthdate finalization. The first extended test correctly
exposed missing admission when started directly on the method endpoint. Starting
through Base exposed a separate handoff bug: Auth evidence was treated as failure
because signup checked only committed-session success. The app handoff now accepts
`proceed?` while preserving the com success predicate.

Source `signup_completed_at` and its outbox event commit after durable ticket
completion, with idempotent reconciliation in the lifecycle job. The lookup no
longer depends on the lifetime of the completed signup flow. The dedicated HTTP
case deletes its completed test flow and verifies that both saved credentials
remain eligible; clearing the recorded completion fact is rejected.

- `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/app_secret_signup_journey_test.rb test/integration/app_secret_login_journey_test.rb test/operations/client_secret_passkey_reservation_issuer_test.rb test/jobs/client_secret_audit_delivery_job_test.rb`: 29 runs, 695 assertions, zero failures/errors/skips.
- Dedicated signup rerun after completed-flow removal: 1 run, 32 assertions, zero failures/errors/skips.
- Migration `20261005063605` added the completion timestamp on the disposable app Zenith database only; `db:schema:dump:app_zenith` completed successfully.
- RuboCop on the issuance model, reservation issuer, lookup query and lifecycle job: four files, no offenses after correcting formatting.
- Combined signup/com email-birthdate regression run: 3 runs, 44 assertions, zero failures, one error. The com test reaches signup finalization without a local admission and raises `AuthCeremonySession::InvalidTransition`. This is not evidence of com regression success; diagnosis remains open.

Signup completion is stronger evidence than the initial delivery-only case above.
It does not prove the signup 0..20 HTTP matrix, cancellation/expiry cleanup,
resumption after every failure, actual root-session completion from signup,
browser confidentiality or comprehensive com/org regression. These remain open.

## Signup termination and candidate purge — 2026-10-05T06:53:09+00:00

Same HEAD, dirty worktree and disposable database identities. Public signup
cancellation now retires the source Secret batch after durable terminal flow
verification, before dependent signup cleanup. Lifecycle rescan reconciles terminal
flows independently of enqueue success. Retention runs this reconciliation before
generic ticket deletion. Confirmed-but-not-activated candidates and unconfirmed
candidates are discarded with reason-bearing source outboxes; no activation or
reuse follows cancellation, expiry or failure.

The signup HTTP test covers completed, canceled and expired outcomes after explicit
presentation and storage declaration. The cancellation operation test also proves
idempotent retry and zero active holdings. A real-job database test proves expired
unconfirmed candidates wait for Chronicle terminal delivery and then delete with a
surviving purged outbox. It uses an explicit one-microsecond test retention window,
not a production default or a sleep-dependent ordering assertion.

`bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/jobs/client_secret_audit_delivery_job_test.rb test/operations/client_secret_passkey_reservation_issuer_test.rb test/integration/app_secret_signup_journey_test.rb`:
10 runs, 361 assertions, no failures, errors or skips.

Initial new cancellation tests exposed the public operation's required actor
context and stale Client snapshot after existing dependent cleanup. They now use
the public anonymous actor context and do not reactivate the deleted pending actor.
The new retirement operation also required explicit Infinity handling when comparing
retention facts to timestamps. These errors were fixed before the successful run.

Other interruption points, signup distribution matrix, actual browser behavior,
concurrent issuance/login and comprehensive other-surface regression remain open.

## Signup distribution matrix and result notices — 2026-10-05T07:01:52+00:00

Same HEAD, uncommitted worktree and guarded disposable database fleet.
The signup HTTP matrix now covers all writer active counts A=0..20, with existing
holdings as setup facts and actual telephone OTP/WebAuthn registration endpoints.
A=0..18 adds two; A=19 adds one with presentation and completed-result notices;
A=20 has no candidates, encrypted payload or reservation and advances without a
new-value storage declaration. A direct presentation POST at A=20 is forbidden
without generating credentials. Resubmitting the persisted Passkey registration
creates no new Passkey, issuance or candidate batch. Completion, cancellation and
expiry cases from the previous section remain included.

- `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/app_secret_signup_journey_test.rb test/integration/app_secret_login_journey_test.rb`: 45 runs, 1376 assertions, zero failures/errors/skips.
- `bun run test spec/features/auth/signup/secret_distribution_notice.test.tsx spec/features/auth/auth_com_signup_screens.test.tsx`: two files, 23 tests passed. These DOM/component checks do not establish live-browser confidentiality.
- `bun run typecheck`: passed.
- RuboCop on `app/controllers/concerns/app_sign_up_checkpoint_page.rb`: one file, no offenses.
- `git diff --check`: passed.

A new assertion exposed the missing post-confirmation notice on the birthdate
checkpoint. App-only server props now carry the persisted batch result; the common
checkpoint component accepts an optional inline notice while com's existing props
remain valid. Initial nil expectations used `assert_equal`, which this repository
rejects; replacing those with `assert_nil` preserves the same no-notice contract.
Explicit undefined notice input also required matching TypeScript optional-property
typing under `exactOptionalPropertyTypes`.

The native plaintext document's cancel link only made a GET navigation. A focused
A=19 test against that implementation failed its protected DELETE form assertion.
The document now submits authenticated cancellation with a CSRF-bearing native
DELETE form. The final combined HTTP run includes that assertion.

Decision gates now separate fixed business rules, existing 15-minute Step-Up/flow
contracts and explicit proposed issuance/purge/outbox settings. Proof collection
remains implementation work as well as an unapproved operational value. Full
browser tests, concurrency/failure coverage, com/org HTTP regressions and cleanup
of legacy app dependencies remain open.

## Parallel login, Ticket rollback and session-limit outcomes — 2026-10-05T07:40:20+00:00

HEAD remains `7de33215b055bc8f0f2721b86a04b428a049220e`; the worktree includes
uncommitted task and unrelated changes. All database work used the same guarded
disposable fleet. No shared database application or external write occurred.

Separate PostgreSQL connections with queue barriers exercise two admitted browser
flows presenting one saved value. One claim and one claim audit persist. The HTTP
journey performs actual Base admission, Auth Secret submission and result handoff;
two parallel Base callbacks then produce exactly one new root token and one
matching receipt. The committed root token remains usable after Secret consumption,
and only Base receives its authentication cookie.

A real outer Ticket transaction rollback leaves the independently committed source
claim intact but loses Ticket's principal binding. The new test reproduced a
terminal reconciliation failure. Reconciliation now checks the persisted terminal
flow and its original browser ceremony before repairing only terminal ownership
and discarding the credential. It creates neither evidence, token nor receipt.
Terminal audits distinguish failed, expired and canceled outcomes; canceled reasons
require a persisted canceled ceremony.

Session-limit HTTP cases verify that a valid claim remains pending after partial
session revocation, continues only after sufficient capacity exists, and issues one
matching root token/receipt. The preexisting normal and total limits are unchanged.
Partial capacity now returns the existing limitation page with its inline notice
and 422 instead of incorrectly treating valid waiting as 410. Explicit Secret
cancellation fails the flow and cancels its ceremony under the Ticket flow lock,
then reconciles source retirement. A callback holding the pre-cancellation valid
browser locator is rejected by existing authorization and redirected to public
Base root; following that redirect returns 200 with no login cookie, receipt or
new token. This is stronger than rejecting a callback after merely clearing its
browser locator.

The coordinator thread's earlier fixture read could cache a principal-less flow
while worker threads committed its binding. Nontransactional parallel HTTP tests
clear that thread's query caches before observing worker writes. Production code
has no test-only cache or authorization branch. The previously failing randomized
seed was included in the final broader run.

- `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/app_secret_parallel_login_test.rb test/operations/client_secret_claim_concurrency_test.rb`: 5 runs, 95 assertions, zero failures/errors/skips.
- Broader run adding claim operation, existing login journeys and audit jobs with `--seed 43799`: 33 runs, 565 assertions, zero failures/errors/skips.
- RuboCop on the affected model, finalizer, limitation controller and both new test files initially found complexity and assertion-count violations. Validation responsibilities were extracted privately and HTTP outcomes split into separate public tests; no thresholds or assertions were removed. Final formatting corrections passed.
- `git diff --check`: passed.

These results do not establish expiry callback handling, every canonical Ticket
rollback point, OIDC Secret support, live-browser confidentiality or comprehensive
com/org regression. Proof-retention dependency guards and collection remain open.

### Flow retention dependency guard — 2026-10-05T07:47:40+00:00

HEAD remains `7de33215b055bc8f0f2721b86a04b428a049220e`, with uncommitted changes.
The real retention-job reproduction initially raised a Ticket foreign-key error
when deleting a flow referenced by its Auth ceremony. The job now locks app flow
batches and excludes references still owned by source claims, Auth ceremonies or
signup issuances. A batch-size-one test verifies that an unresolved claim's flow
survives while an unrelated due flow is deleted; lookup remains rejected and no
receipt or consumption is inferred. This conservative guard is implemented;
eventual bounded proof collection remains unfinished.

- `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/operations/client_secret_claim_concurrency_test.rb`: 3 runs, 30 assertions, no failures/errors/skips.
- Broader retention run initially had 9 missing-setting errors. Retention tests now explicitly supply proposed purge/outbox values rather than introducing production defaults.
- `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/jobs/retention_purge_job_test.rb test/operations/client_secret_claim_concurrency_test.rb`: 21 runs, 103 assertions, no failures/errors/skips.
- `bundle exec rubocop app/jobs/retention_purge_job.rb test/operations/client_secret_claim_concurrency_test.rb test/jobs/retention_purge_job_test.rb --format simple`: 3 files, no offenses.

All DB work used the guarded disposable `codex_integrity_20261003secret_*` fleet.
These results do not approve the proposed operational lifetimes or establish
complete proof collection, expiry callbacks or full surface regressions.

### Expired Secret callback and terminalization — 2026-10-05T07:53:30+00:00

HEAD remains `7de33215b055bc8f0f2721b86a04b428a049220e` with uncommitted changes.
The new real-HTTP test established rejection at the existing invalid-result
boundary (400), then reproduced `FlowInvalidTransition: cycle is expired` in
Secret reconciliation. `ClientSignInFlow#expire_sign_in!` now terminalizes only
expired, unissued app flows under the same Ticket row exclusion used by issuance.
It refuses live or completed flows. Reconciliation no longer invokes the ordinary
unexpired transition and preserves `flow_expired` across a prior Ticket commit.
Tests use actual DB time and protected Base/Auth browser admissions, with no
session-issuance mock, deadline extension or authentication bypass.

- Focused expiry HTTP run: 1 test, 22 assertions, no failures/errors/skips after correction.
- `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/app_secret_parallel_login_test.rb test/operations/client_secret_claim_concurrency_test.rb`: 8 runs, 138 assertions, no failures/errors/skips.
- Broader run adding claim operation, login journey and audit jobs, `--seed 43799`: initially 36 runs with 5 errors because tests assumed the security policy did not already exist. Audit tests now provision or reuse that prerequisite explicitly; production still requires `find_by!` and does not create missing policies.
- Final same broader command: 36 runs, 608 assertions, no failures/errors/skips.
- RuboCop passed the four expiry source/test files. The audit test file had nine formatting offenses, corrected without changing assertions or thresholds.

The state diagram/inventory records the app-only terminal mutation. Comprehensive
clock boundaries, simultaneous expiry versus issuance, OIDC, browser secrecy and
eventual proof collection remain open; this is not a full completion claim.

### Source registration prerequisite — 2026-10-05T07:56:42+00:00

HEAD remains `7de33215b055bc8f0f2721b86a04b428a049220e`, with uncommitted changes.
A public-operation reproduction created the durable cross-DB interruption
snapshot: completed signup Ticket, saved batch, pending source Client. It failed
because activation was accepted. Activation now checks registered source status
and existing login eligibility under the Client lock before writing its fact or
success outbox. The test checks refusal, unchanged audit/activation and unusable
value, then valid registration and idempotent activation of the same saved value.

An initial ACTIVE-only guard incorrectly rejected the existing finalizer's
VERIFIED_WITH_SIGN_UP state, producing 21 HTTP errors. Inspection of
SignAppUpTelephoneRegistrationFinalizer established that accepted current state;
the guard now accepts both registered states and retains the pending rejection.

- `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/operations/client_secret_passkey_reservation_issuer_test.rb test/integration/app_secret_signup_journey_test.rb`: final 26 runs, 1192 assertions, no failures/errors/skips. Includes every signup active count 0..20 and cancellation/expiry cases.
- RuboCop on the operation and test: 2 files, no offenses after formatting correction.

No shared finalizer or com/org registration contract was changed. This result
does not establish recovery of every cross-DB finalization interruption; lock-order
coordination and eventual proof collection remain open.

### Explicit audit-policy provisioning — 2026-10-05T08:00:19+00:00

HEAD remains `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Inspection
found no security-policy data migration/provisioning, although Secret delivery
requires that shared policy. The new `app_secret:provision_audit_policy` task
requires explicit `CHRONICLE_SECURITY_RETENTION_DAYS`; no default or request-time
policy creation was introduced. Operational approval of the duration is pending.

Executed through `/tmp/umaxica-secret-db-task.rb` against the guarded disposable
fleet, not a shared DB:

- Missing ENV: exit 1, explicit KeyError before any policy mutation.
- Initial create-or-find implementation failed existing-row model uniqueness validation; changed to find-or-create at this operator-only boundary.
- Explicit 365-day invocation: exit 0, verified existing policy, no overwrite.
- Explicit 364-day invocation: exit 1, existing-policy mismatch rejected.
- `CHRONICLE_SECURITY_RETENTION_DAYS=365 ... runner /tmp/app-secret-audit-policy-provision-check.rb`: exit 0. Within a disposable Chronicle rollback transaction, temporarily renamed the task-owned existing policy, invoked the real Rake task, verified newly created policy facts, then rolled back and verified original identity/duration and absence of the temporary row.
- First runner attempt encountered a transient jp/en YAML parse error. Subsequent direct Psych parsing of all four locale bundles passed without editing them, and the runner then succeeded.
- RuboCop: one task file, no offenses after formatting correction; diff whitespace check passed.

365 days is an explicit isolated verification value/proposal, not a new approved
shared security retention value. No schema or deployed DB was changed. Full
eventual proof/outbox collection and remaining feature acceptance are unfinished.

### Presentation entrypoint browser coverage — 2026-10-05T08:02:54+00:00

HEAD remains `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. New
`e2e/secret-presentation.spec.ts` executes the real Vite-served
`src/entrypoints/secret_presentation.ts` in Chromium with two synthetic values.
The existing live component fixture server was inspected and reused; no Rails
server or other existing process was stopped or reconfigured.

- `bun run test:e2e e2e/secret-presentation.spec.ts`: 3 tests passed, no retries/skips.
- Pagehide and persisted pageshow remove every displayed value; initial pageshow preserves the delivery.
- Native required-checkbox validation blocks submission without clearing the display; valid submission clears it.
- After submission, synthetic values are absent from document content, history state, URL, localStorage and sessionStorage as asserted at the relevant boundary.
- Oxfmt completed and Oxlint reported no diagnostics for the new file; `git diff --check` passed.

This is entrypoint browser coverage with dispatched lifecycle events, not an
authenticated Rails journey, actual browser back/forward restoration, production
CSP/response-cache validation or service-worker/analytics verification. Those
acceptance checks remain open. No synthetic result is reported as real delivery
authorization or a production confidentiality guarantee.

### Lost Ticket proof — 2026-10-05 UTC

HEAD remains `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree.
A public-operation failure test claims a saved value, then removes only its
task-owned disposable Ticket ceremony/flow to represent lost independent proof.
Reconciliation returns unknown: no consumption/discard audit, no receipt or new
token, no retention deadline or restoration, and another admitted flow cannot
accept the same value. This does not prove recovery of the lost evidence.

- `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/operations/client_secret_claim_concurrency_test.rb`: 5 runs, 50 assertions, no failures/errors/skips.
- RuboCop on the test file passed.

Inspection additionally confirmed OIDC primary evidence uses
`establish_oidc_authentication_evidence!` and the Base authorization-resume
boundary; the current Secret claim accepts only local SignInFlow/browser
admission. OIDC Secret wiring remains unfinished and requires its durable claim
and canonical issuance receipt to follow that existing boundary.

### App-only OIDC flow binding DDL — 2026-10-05T08:12:35+00:00

HEAD remains `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. The
ceremony schema enforces exclusive authorization/local-flow references. Rather
than weaken it, the app OIDC transaction now has an optional unique restrictive
FK to its Secret SignInFlow. This is preparatory persistence and association,
not completed OIDC Secret login. Existing com/org transaction models are unchanged.

- Both migrations were generated with the guarded Rails generator for app_ticket.
- Initial combined reference/FK definition was rejected by strong_migrations. The revised DDL creates its index concurrently, installs an unvalidated FK, and validates in a later migration.
- `db:migrate:app_ticket` succeeded on the disposable fleet only.
- `db:rollback:app_ticket STEP=2` reverted exactly these two new migrations; re-application succeeded. No legacy credential data restoration is claimed.
- `db:schema:dump:app_ticket` generated the app Ticket dump; no dump was manually edited.
- New public model persistence checks verify nullable association, unique ownership, missing target rejection and restrictive proof deletion. Real RetentionPurgeJob also preserves linked due flow proof.
- Model/OIDC tests: 12 runs, 186 assertions, no failures/errors/skips before the retention assertion was added.
- Final model/OIDC plus retention run: 30 runs, 261 assertions, no failures/errors/skips.
- RuboCop on both migrations, app transaction model, retention job and test: five files, no offenses after correction.
- `db:verify_no_schema_drift` exited 1 listing dirty dumps for app_ticket, app_zenith, avatar, chronicle, com_ticket, com_zenith, org_ticket, org_zenith and publishing. It checks committed dump differences; this uncommitted workspace does not satisfy that gate. No unrelated work was reset to make it pass.

OIDC claim admission, evidence linkage, Base issuance receipt and terminal
reconciliation wiring remain unfinished. The new association alone grants no
authentication authority and is not reported as feature completion.

### OIDC pending-flow binding operation — 2026-10-05T08:18:15+00:00

HEAD remains `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree.
Added `bind_oidc_flow!` to the existing claim operation rather than a parallel
class/framework. The failing public-operation test initially raised missing
method; implementation now persists the locator before future independent source
claiming. It re-reads availability under locks and validates persisted pending
transaction, ceremony purpose/reference and DB deadlines. Existing live flows
are reused only for the same Client. No claim, evidence or root token is issued.

- Claim tests plus existing separate-writer concurrency tests: 7 runs, 78 assertions, no failures/errors/skips.
- Final claim test run after adding different-Client and challenge-deadline refusal: 2 runs, 33 assertions, no failures/errors/skips.
- Assertions verify wrong value/wrong purpose do not create a flow; correct admission binds one; retry reuses; deadlines do not extend; exclusive ceremony reference is unchanged; credentials remain unclaimed.
- RuboCop on operation and test: 2 files, no offenses. Validation was extracted privately without direct private-method tests or gate changes.

This public internal operation has no HTTP caller yet. Actual OIDC claim,
authentication evidence, Base root issuance receipt and terminal reconciliation
remain unfinished, so this is partial implementation only.

### App OIDC source claim — 2026-10-05T08:23:47+00:00

HEAD remains `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added
`call_for_oidc!` to the existing claim operation, reusing the existing credential
claim facts and outbox. A failing public-operation test first reproduced the
missing method. The implementation binds the committed Ticket locator, then
claims under Client/authorization/flow/ceremony/credential locks. Model validation
independently reads the persistent OIDC relation, pending state and deadlines;
an arbitrary operation string or Ruby object type alone does not authorize claim.

- OIDC claim test verifies the exact credential/flow/browser references, irreversible lookup/re-submission refusal, and no authentication evidence or consumption inferred.
- A separately authenticated passkey transaction is refused with no new flow/outbox/claim; its actor and method remain unchanged, and the unrelated saved Secret remains usable.
- `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/operations/client_secret_claim_committer_test.rb test/operations/client_secret_claim_concurrency_test.rb test/integration/app_secret_parallel_login_test.rb`: 13 runs, 198 assertions, no failures/errors/skips.
- RuboCop initially rejected complexity; input validation was extracted privately without authorization bypass or threshold change. Final three-file run passed with no offenses.
- `git diff --check` passed.

OIDC Secret still has no HTTP claim/evidence caller or canonical Base receipt
finalization/reconciliation. Source claim support is internal partial implementation,
not a declaration that OIDC Secret sign-in succeeds. Local HTTP tests remain green.

### Retired route expectations and admission regression — 2026-10-05T08:29:35+00:00

HEAD remains `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Replaced
remaining app Secret POST-404 expectations in the OIDC journey, app controller
test and mixed-surface rate-limit test. Legacy GET remains 404; canonical actions
without browser admission reject the request without claims, tokens or OIDC
evidence. Com/org Secret route absence stays asserted.

- OIDC file: 6 runs, 42 assertions, no failures/errors/skips.
- First five-file run: 11 runs, 59 assertions, one failure. Existing Passkey rate-limit test received admission refusal (400) before reaching its expected 429 boundary.
- Updated that test to redeem a real Base-issued admission through the public HTTP helper; production controls and the 429/Retry-After contract remain unchanged.
- Final five-file run covering app/com/org Secret controller tests, authentication rate limit and OIDC journey: 11 runs, 66 assertions, no failures/errors/skips.
- RuboCop initially reported one assertion-spacing offense after the last edit; corrected without changing assertions or thresholds.

Full com/org Recovery/Emergency regression and successful OIDC Secret HTTP
claim/receipt wiring remain unfinished. These targeted tests do not prove them.

### OIDC Auth HTTP evidence and handoff — 2026-10-05T08:37:18+00:00

HEAD remains `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. A new
HTTP test first failed because Secret POST required a local flow. Auth POST now
dispatches admitted OIDC transactions to the existing claim operation and reuses
the uniquely bound claimed flow instead of creating another flow. Its existing
evidence API writes flow and ceremony facts together under Client/transaction/
flow/ceremony locks; Auth creates no session.

Initial HTTP wiring reached an unsafe dashboard redirect because the early result
path was computed before its locator advanced. The Secret OIDC branch now uses
the established post-advance sequence redirect helper, preserving verified handoff
rather than permitting an arbitrary external redirect. The existing handoff's
AMR is passcode, while ceremony/flow method is secret. Base uses the dedicated
flow reference plus the expected protocol method to select canonical Secret
issuance; it does not infer Secret from generic passcode evidence alone.

- OIDC plus existing local login journey after first correction: 29 runs, 469 assertions, no failures/errors/skips.
- Final command adding parallel local HTTP login tests after extracting the existing same-transaction receipt write privately: 33 runs, 567 assertions, no failures/errors/skips.
- New assertions verify Secret claim, Auth method, no Auth token creation/consumption, unusable raw value and correct signed OIDC handoff transaction actor/method/flow.
- RuboCop on both controllers, both concerns and HTTP test: five files, formatting corrections only after reducing the pre-existing enlarged commit method; no threshold changes.
- Whitespace check passed.

This verifies Auth evidence and handoff, not successful Base OIDC Secret root
issuance. Flow readiness, canonical OIDC receipt validation, session-limit resume
and terminal reconciliation remain unfinished. The canonical boundary refuses an
unready/mismatched flow rather than minting an unbound Secret root login.

### Receipt missing-claim regression — 2026-10-05T08:43:07.156432+00:00

HEAD: `7de33215b055bc8f0f2721b86a04b428a049220e`; uncommitted worktree. The initial receipt model run produced 4 runs, 6 assertions, 1 error: a legacy success example fabricated a completed token and flow without a persisted claim. Replaced that example with explicit rejection and no receipt insertion. Successful receipt creation remains covered through the real login integration boundary.

Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/models/client_secret_sign_in_receipt_test.rb test/integration/app_secret_parallel_login_test.rb`. Result: 8 runs, 107 assertions, no failures, errors, or skips; seed 37582. Disposable database manifest guard verified the task-owned fleet before execution. OIDC final Base issuance remains incomplete.

### Base OIDC issuance reproduction — 2026-10-05T08:44:41.201002+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Extended the real Auth Secret handoff integration example to POST its rendered result form to Base and require a new root token, consumption, and matching receipt. Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/oidc_initiated_sign_in_completion_test.rb --include "/saved Secret/"`. Initial run: seed 4974, 1 run, 16 assertions, 1 failure, no errors or skips; no token was issued. The diagnostic rerun produced 1 run, 15 assertions, 1 failure. Structured event `session.issuance.flow_rejected` reported `sign-in flow is not waiting for session issuance`. This is a retained failing acceptance test for unfinished Base OIDC integration, not a passing completion claim.

### Guarded OIDC readiness implementation — 2026-10-05T08:48:17.526702+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added app-only `ClientSignInFlow#prepare_secret_oidc_issuance!`, called from Base OIDC canonical issuance, and synchronized the client sign-in diagram/inventory. The operation locks the durable authorization transaction and flow and verifies actor, claim, completed Auth handoff, context and deadlines before changing dashboard state to issuance pending. HTTP assertions confirmed dashboard state, completed non-revoked/non-cancelled ceremony, authentication-handoff purpose, normal context, principal and authorization transaction reference. The same narrowed command as above remains failing: seed 4504, 1 run, 23 assertions, 1 error (`FlowInvalidTransition: Secret OIDC issuance binding mismatch`), no skips. This is partial implementation; the remaining binding mismatch and receipt/retirement connection are unresolved.

### OIDC Base successful commit — 2026-10-05T08:51:59.979346+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Localized the readiness rejection to the legacy Auth checkpoint writing `session_issued_at` even when it recorded authentication evidence only. App Secret OIDC checkpoints now preserve absence of token and issuance time; other paths retain their contract. Base advances the matching durable handoff into canonical issuance. Receipt validation supports the completed admitted OIDC ceremony and its persisted transaction/flow/actor binding. After the Ticket transaction commits, Base invokes the existing source retirement operation.

Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/oidc_initiated_sign_in_completion_test.rb test/models/client_secret_sign_in_receipt_test.rb`. Result: seed 22183, 11 runs, 82 assertions, no failures/errors/skips. HTTP assertions cover no Auth token, no premature issuance time, exactly one Base token, consumed source credential and matching receipt/token. Earlier runs failed at readiness, receipt validation and a stale test association; the passing run reloads persisted flow facts. OIDC cancellation, deadlines, session-limit continuation, concurrency, static checks and full regressions remain outstanding.

### OIDC result retry — 2026-10-05T08:53:13.788648+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Extended the public HTTP example with a retry of the same rendered Base result capability. It verifies unchanged root token reference, consumed timestamp, token count and receipt count. Narrowed Minitest command above: seed 59738, 1 run, 37 assertions, no failures/errors/skips. This is sequential continuation, not concurrent delivery evidence. Targeted RuboCop of the five changed source/test files failed with 15 offenses, including method complexity and checkpoint length; no thresholds were lowered. A duplicate redirect assertion was removed after this run; that final edit has not yet been rerun. Static cleanup and OIDC failure/concurrency coverage remain pending.

### OIDC validation responsibility cleanup — 2026-10-05T08:55:10.445986+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Extracted private transaction/ceremony checks on ClientSignInFlow, source claim matching on the receipt, and checkpoint dashboard handoff orchestration. All checks and lock scopes are retained; no thresholds, visibility bypasses or private-method tests were added. Targeted RuboCop command on `client_sign_in_flow.rb`, `client_secret_sign_in_receipt.rb`, Base app OIDC authorizations controller, `authentication_sequence_gate.rb`, and OIDC integration test: 5 files, no offenses.

Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/oidc_initiated_sign_in_completion_test.rb test/models/client_secret_sign_in_receipt_test.rb test/integration/app_secret_parallel_login_test.rb`. Result: seed 10684, 15 runs, 185 assertions, no failures/errors/skips. OIDC failure and concurrency coverage remains outstanding.

### Delayed expired OIDC result — 2026-10-05T08:56:39.799030+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added a public HTTP regression that submits a real Secret handoff result after the bound flow deadline. Initial test errored on the strict readiness invariant. Base now evaluates expiry using database time under the issuance flow lock and returns the existing generic login failure before invoking readiness. No broad exception rescue was added. The test verifies HTTP 400, unchanged token/receipt counts and claim operation, absent consumption/token and continued lookup rejection. Terminal claim retirement is still pending.

Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/oidc_initiated_sign_in_completion_test.rb test/models/client_secret_sign_in_receipt_test.rb`: seed 32310, 12 runs, 99 assertions, no failures/errors/skips.

### OIDC expired claim terminalization — 2026-10-05T08:59:22.945145+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Extended the delayed-result HTTP regression through the public claim finalizer. Initially it returned unknown for an OIDC ceremony. Reconciliation now locks Client, matching OIDC transaction, flow, credential in issuance order; terminal proof requires the persisted transaction/ceremony/flow correlation with no token, session issuance or Base finalization. Existing local ceremony proof is preserved. The test verifies abandoned outcome, failed flow, logical discard, unchanged claim, no consumed success, and repeated delayed HTTP refusal. This does not prove Chronicle delivery or physical deletion for that OIDC claim.

Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/oidc_initiated_sign_in_completion_test.rb test/operations/client_secret_claim_concurrency_test.rb`: seed 21253, 13 runs, 151 assertions, no failures/errors/skips. Targeted RuboCop: 2 files, no offenses. An earlier attempted command referenced nonexistent `test/operations/client_secret_claim_finalizer_test.rb` and failed to load; the actual existing concurrency test was located and run instead.

### Expired OIDC claim job delivery and purge — 2026-10-05T09:01:13.894605+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Extended the actual Secret Auth/Base HTTP expiry example through public terminalization, real lifecycle job and real audit delivery job. Purge refuses before terminal delivery; lifecycle delivers `flow_expired` terminal evidence to Chronicle before deleting the credential; a surviving undelivered purged outbox event is then delivered once and duplicate rescan adds no Chronicle row. Explicit test retention values and test security policy preparation do not approve operational values.

Narrow run: seed 51009, 1 run, 31 assertions, no failures/errors/skips. After formatting, command `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/oidc_initiated_sign_in_completion_test.rb test/jobs/client_secret_audit_delivery_job_test.rb`: seed 53872, 13 runs, 154 assertions, no failures/errors/skips. RuboCop corrected three assertion-spacing offenses, exit 0. Claim/receipt/issuance proof collection, OIDC cancellation, session-limit and concurrent callback checks remain unfinished.

### Terminal failed OIDC flow refusal — 2026-10-05T09:03:05.874142+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added a real handoff/result HTTP regression for a flow terminated through public `fail_sign_in!` before expiry. Initially readiness raised an invariant exception; Base now returns generic login failure for locked failed flows before readiness. The test verifies no token/receipt, no Secret lookup, public claim abandonment and `flow_failed` terminal audit. This verifies server-side terminal failure, not a user cancellation endpoint. A subsequent failing assertion used a stale fixture credential and was corrected to reload the persisted irreversible claim.

Targeted RuboCop corrected assertion spacing with exit 0. The combined HTTP and claim concurrency run is recorded in the following result.

Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/oidc_initiated_sign_in_completion_test.rb test/operations/client_secret_claim_concurrency_test.rb`; seed 52240, 14 runs, 171 assertions, no failures/errors/skips.

### OIDC session-limit acceptance regression — 2026-10-05T09:05:15.828531+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added a real Secret handoff/Base result test with existing root-token capacity full, followed by the public limitation PATCH and required matching receipt/consumption. Initial run (seed 1070) failed because flow remained issuance pending despite the limit redirect. Base now advances the app Secret flow to session-limit pending on the canonical refusal while retaining claim and no session. The next run (seed 63329) reached the limitation PATCH but failed: 1 run, 11 assertions, 1 failure, HTTP 410 instead of redirect. Successful promotion/receipt remains unimplemented/unverified. Inspection identified that the existing OIDC limitation promotion does not pass the bound Secret flow into canonical issuance; this must be connected before claiming completion. No test expectation was weakened.

### OIDC limitation promotion connection — 2026-10-05T09:08:17.544736+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Connected app OIDC limitation promotion to guarded Secret readiness and canonical issuance flow/method parameters, with source retirement after Ticket finalization. Added structured refusal diagnostics containing status/class/location and request ID, no credential or challenge. Current public HTTP acceptance remains failed (1 run, 12 assertions, 1 failure): resolution reached session_selected and issuance returned session_limit_pending. Inspection established that the limitation page checks total capacity while canonical issuance independently checks active-session capacity; removing one of MAX_TOTAL active tokens can still leave MAX_SESSIONS active tokens. This requires preserving both limits and rendering a continued capacity notice before a second selection, not relaxing canonical issuance or changing the successful expectation. Static cleanup and rerun remain pending.

### OIDC session-limit successful continuation — 2026-10-05T09:10:03.733038+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. The app limitation page now checks canonical active capacity as well as total capacity. The HTTP test starts with total capacity of active tokens: first selection returns 422 with the existing inline capacity notice, retains the claim and pending flow, and issues nothing; second selection opens active capacity and completes canonical root issuance with a matching receipt and consumed credential. Limits are unchanged. Narrow run seed 54558: 1 run, 19 assertions, no failures/errors/skips.

Combined command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/oidc_initiated_sign_in_completion_test.rb test/integration/app_secret_parallel_login_test.rb`; seed 7261, 14 runs, 238 assertions, no failures/errors/skips. Targeted RuboCop on both Base controllers and OIDC integration test: exit 0, 10 formatting offenses corrected. OIDC user cancellation and concurrent resolution/callback exclusion still require tests.

### OIDC user cancellation HTTP path — 2026-10-05T09:12:24.464482+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added the real limitation DELETE after Secret verification and session-limit refusal. Initially cancellation changed only the resolution and left flow pending. App Secret cancellation now locks Client, OIDC transaction, resolution and flow; rejects an already established root login; writes failed flow and canceled resolution together on Ticket, then retires the irreversible source claim through its existing finalizer. Promotion rechecks locked resolution openness/expiry. Source retirement independently verifies the persisted OIDC canceled resolution rather than trusting a supplied reason. Completed Auth evidence is not changed back to active or canceled.

Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/oidc_initiated_sign_in_completion_test.rb --include "/canceling OIDC/"`; seed 41865, 1 run, 19 assertions, no failures/errors/skips. Test verifies no existing-token or receipt count changes, failed flow, logical discard without consumed success, continued lookup rejection, old result HTTP 400 and flow_canceled audit. Broader tests, concurrent cancellation/issuance exclusion and static checks remain pending.

### Cancellation regression and static checks — 2026-10-05T09:14:00.830963+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Combined command `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/oidc_initiated_sign_in_completion_test.rb test/integration/app_secret_parallel_login_test.rb test/operations/client_secret_claim_concurrency_test.rb`: seed 45637, 20 runs, 307 assertions, no failures/errors/skips. RuboCop corrected formatting and recommended the equivalent direct exists query; final targeted scan of the four cancellation source/test files: no offenses. After the query edit, the cancellation HTTP test passed again (seed 1362, 1 run, 19 assertions). These runs cover existing local concurrency and OIDC sequential cancellation; they do not establish concurrent OIDC cancellation/result exclusion.

### Expired OIDC limitation prevents revocation — 2026-10-05T09:15:57.531437+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added a public PATCH regression for an expired bound Secret flow while its OIDC transaction and limitation challenge remain live. Initial behavioral run returned 422 after entering session revocation. Limitation admission now requires the matching unissued, unexpired session-limit-pending Secret flow before modification. Narrow command using `--include "/limitation refuses/"`: seed 15456, 1 run, 7 assertions, no failures/errors/skips; HTTP 410, all existing token status facts unchanged, no flow token. This sequential preflight guard does not prove race exclusion after admission; that remains required. Static checks and broader regression for this edit remain pending.

### Canonical session boundary regression — 2026-10-05T09:17:16.580682+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/controllers/concerns/auth/session_issuance_boundary_surfaces_test.rb test/controllers/concerns/auth/login_cooldown_surfaces_test.rb test/integration/root_login_establishment_flow_test.rb test/integration/oidc_initiated_sign_in_completion_test.rb`. Result: seed 48180, 72 runs, 581 assertions, no failures/errors/skips. This exercises the repository-required canonical issuance/cooldown/root establishment regressions across applicable surfaces plus Secret OIDC HTTP behavior. It is not a complete com Recovery or org Emergency/Step-Up regression claim. Targeted RuboCop of the expiry gate source/test: exit 0 after removing one unused test assignment and assertion spacing; these final non-behavior formatting edits were not separately rerun. Concurrent OIDC cancellation/result arbitration remains unverified.

### com Recovery and org Emergency regression — 2026-10-05T09:19:44.832652+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Ran the existing recovery top-up, Base com recovery reveal, org emergency continuity/policy/invariants/passkeys and emergency Step-Up prohibition tests. Initial group: seed 33607, 47 runs, 330 assertions, one missing com recovery-kind reference error. Preparing that existing com kind exposed an equally missing ACTIVE status reference. The com top-up example now prepares those two existing reference records in its test transaction, matching the established com contract. No com/org production code, shared count or app kind/status tables were changed. Narrow top-up test then passed: seed 28289, 3 runs, 106 assertions.

Final command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/services/recovery_passcode_top_up_test.rb test/controllers/base/com/identity/recovery_secrets_controller_test.rb test/concerns/auth/org_emergency_session_continuity_test.rb test/policies/org_emergency_access_policy_test.rb test/unit/security/org_emergency_access_invariants_test.rb test/controllers/auth/org/in/emergency/passkeys_controller_test.rb test/controllers/auth/org/verification/emergency_step_up_prohibition_test.rb`. Result: seed 38159, 47 runs, 423 assertions, no failures/errors/skips. The top-up regression verifies ten com credentials and no extra issuance on repeat. This group does not cover every com authentication method or all unrelated cross-surface behavior.

### Retired app kind/status model tests — 2026-10-05T09:22:31.320754+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Ran the three legacy app credential/kind/status model test files: 27 runs, 17 assertions, 24 errors from retired app reference tables. Removed kind/status-only tests and replaced the legacy credential file with current name boundaries, immutable Client/public identity and required owner/issuance/digest validation. Existing rebuild tests preserve exact 32-character input, digest matching, confirmation, irreversible lifecycle and no recovery-identity prerequisite. The required belongs-to failure exposed missing client/issuance attribute translations; added explicit labels in all four existing locale bundles. No removed app table/model was restored.

Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/models/client_secret_credential_test.rb test/models/client_secret_credential_rebuild_test.rb`; seed 61566, 13 runs, 108 assertions, no failures/errors/skips. Additional obsolete model/policy/seed references and database constraint coverage still require cleanup. Static checks for these edits remain pending.

### Remaining legacy reference inventory — 2026-10-05T09:24:05.596189+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Updated the shared credential invariant to distinguish app Client-owned fact-based Secret from unchanged com/org legacy kind rules, without removing those surface invariants. The app assertions require absence of retired kind/status/use-policy columns. Updated the bigint PK check to the current credential table and replaced a retired one-time-kind assertion with unconfirmed ineligibility.

Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/security/invariants/credential_security_routes_invariant_test.rb test/models/database_pk_type_test.rb`: seed 48112, 15 runs, 84 assertions, no failures/errors/skips. The broad model-only file was edited but not executed in this slice. Inspection found remaining obsolete model/concern/policy files, a shared concern test using the old app table, a signup checkpoint assertion and WithdrawalPersonalDataAnonymizer writing the removed app status. These must be connected/replaced before removing the last old classes; no completion claim is made.

### Withdrawal stale status reproduction — 2026-10-05T09:26:16.988847+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added an actual DB test through `WithdrawalPersonalDataAnonymizer.call`, with a legitimately withdrawn/terminated Client and pending issuance credential, requiring retained revocation/discard audit and authentication denial. Initial setup correctly rejected termination without finite withdrawn_at; the setup was corrected to satisfy that existing principal invariant. Public operation now reproduces `ActiveModel::UnknownAttributeError: user_secret_status_id` from the old app branch. Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/models/client_secret_credential_rebuild_test.rb --include "/withdrawal anonymization/"`; seed 38180, 1 run, 0 assertions, 1 error. This acceptance regression is intentionally retained pending the audited withdrawal transition; it is not a passing result. Management revocation cannot be reused blindly because its last-authenticator guard and confirmed/unclaimed eligibility differ from authorized account termination. Pending claims must retain their Ticket proof until terminal reconciliation.

### Audited withdrawal Secret transition — 2026-10-05T09:28:36.553129+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Replaced the obsolete app status update in WithdrawalPersonalDataAnonymizer with `ClientSecretCredential#commit_withdrawal_revocation!`. The source Client lock verifies actual termination, preserves irreversible facts, and atomically records withdrawal revocation. Unclaimed candidates become discarded with audit and configured retention. Claimed credentials retain infinite discard/purge eligibility until existing Ticket terminal reconciliation; no live proof is deleted or claim released. Candidate purge recognizes its credential-specific withdrawal terminal audit. Existing com branch is unchanged.

Public tests reject invocation for active Client, exercise real anonymization, and verify a claimed Secret keeps its flow proof until failure then retires. Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/models/client_secret_credential_test.rb test/models/client_secret_credential_rebuild_test.rb test/operations/client_secret_claim_concurrency_test.rb`; seed 64699, 21 runs, 181 assertions, no failures/errors/skips. Static checks, full existing withdrawal test modernization, issuance payload/confirmation cancellation and withdrawal Chronicle delivery remain unfinished.

### Withdrawal issuance payload cancellation — 2026-10-05T09:31:34.057032+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Extended public withdrawal DB test to require canceled issuance, erased opaque server payload and zero reserved capacity. Initial assertion failed; added ClientSecretIssuance#cancel_for_withdrawal! bound to locked terminated Client and same-source cancellation audit. Anonymizer serializes issuance cancellation and credential withdrawal under the Client lock. Confirmed and omitted issuance facts are preserved.

Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/models/client_secret_credential_rebuild_test.rb test/models/client_secret_issuance_test.rb test/operations/client_secret_claim_concurrency_test.rb`: seed 31605, 27 runs, 270 assertions, no failures/errors/skips. Targeted RuboCop on five source/test files: exit 0 after formatting corrections. These tests do not yet cover full withdrawal service/jobbing or real encrypted payload delivery/receipt cleanup.

### Withdrawal with no Secret state — 2026-10-05T09:33:04.308075+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added actual public anonymization behavior for a terminated Client without credentials or issuance. Initially the new Secret branch unconditionally required its retention setting and failed even when no Secret transition existed. It now checks presence under the Client lock before entering the Secret branch; no operational fallback value was added. The no-state path creates no credential, issuance or audit, while existing Secret paths continue to require explicit configured retention.

Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/models/client_secret_credential_rebuild_test.rb test/operations/client_secret_claim_concurrency_test.rb`; seed 59993, 18 runs, 156 assertions, no failures/errors/skips. This is withdrawal business behavior, not an environment-construction test. Full withdrawal regression/test replacement and static checks remain pending.

### Withdrawal candidate delivery and lifecycle deletion — 2026-10-05T09:38:38+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. The new job test initially failed (seed 3566, one error): it attempted to rewrite purge eligibility using a credential instance retaining its pre-withdrawal infinite discard time. Replaced this direct timestamp edit with public issuance cancellation and credential withdrawal transitions, supplying an explicit one-microsecond retention interval. No validation bypass or production timing default was introduced. The public anonymizer itself remains covered separately by real persisted model tests.

The test proves lookup rejection and payload removal, refusal to purge before terminal audit delivery, actual lifecycle-job delivery to Chronicle and credential deletion, survival of the purged outbox, and subsequent duplicate-safe delivery. Narrow command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/jobs/client_secret_audit_delivery_job_test.rb --include '/withdrawal candidate/'`; seed 4945, 1 run, 10 assertions, no failures/errors/skips. Combined command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/jobs/client_secret_audit_delivery_job_test.rb test/models/client_secret_credential_rebuild_test.rb test/models/client_secret_issuance_test.rb test/operations/client_secret_claim_concurrency_test.rb`; seed 13889, 34 runs, 332 assertions, no failures/errors/skips. Verification used the guarded disposable database fleet; shared databases were untouched. Complete withdrawal regression, receipt/issuance proof collection and the remaining browser/concurrency acceptance checks are still unfinished.

### Persisted withdrawal regression replaces obsolete app status mock — 2026-10-05 UTC

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Replaced the client-specific fabricated actor and credential records in `test/operations/withdrawal_personal_data_anonymizer_test.rb` with persisted Client, email, telephone, Passkey, TOTP, external identity, issuance and Secret. Removed the obsolete ClientSecretCredentialStatus expectation and client mock-builder. Visitor coverage and production com behavior were preserved. The public anonymizer test verifies anonymized identifiers, old identifier digest removal, existing credential revocation, external identity deletion, Secret lookup rejection, issuance cancellation and source terminal audit. Cross-database child deletion is invoked without a behavior mock but is not asserted with populated child rows in this example.

The initial real test exposed a false expectation in the former mock: Email validation regenerates a digest for its anonymized address instead of storing nil. The replacement asserts the original digest is removed and the replacement matches the anonymous address; production Email behavior was unchanged. Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/operations/withdrawal_personal_data_anonymizer_test.rb`; seed 56143, 2 runs, 35 assertions, no failures/errors/skips. The visitor example remains its existing isolated mock and is not evidence of a real com withdrawal transaction.

### Real Passkey Step-Up HTTP from a Secret-established session — 2026-10-05T09:47:06+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Replaced synthetic transaction verification and direct freshness commitment in `app_passkey_secret_session_step_up_test.rb` with Base POST admission, Auth GET/CSRF POST acceptance, actual gem-generated WebAuthn assertion through options/verification HTTP, Auth result handoff and Base completion HTTP. The root token fixture is explicitly Secret-established; this example does not itself perform initial Secret Sign in. The emitted Jump token destination is read to reach Auth, so this does not verify Jump gateway behavior or an actual browser.

Initial completion failed safely with 400: the first test attempt lacked the Base browser binding, and the subsequent authentication header helper replaced the browser Cookie header. Starting admission through Base and retaining its browser cookie when posting completion resolved the fixture error. No production authorization was loosened. Auth signature success alone leaves Base freshness unset; Base completion records Passkey freshness, consumes the transaction, preserves the root authentication method as Secret, and allows the registration authorization boundary to return its normal missing-registration-evidence response.

Commands: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/app_passkey_secret_session_step_up_test.rb --include '/separately bound/'`: seed 14419, 1 run, 13 assertions, no failures/errors/skips. Combined `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/app_passkey_secret_session_step_up_test.rb test/controllers/auth/step_up_admission_test.rb`: seed 39491, 13 runs, 194 assertions, no failures/errors/skips. Existing no-method registration/setup denials were retained. Full Secret login followed by successful management mutation or completed new Passkey registration in the same browser remains unfinished.

### Secret login followed by independent Passkey Step-Up and real management — 2026-10-05T09:51:32+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Extended the manual HTTP journey through actual Secret Sign in and root cookie establishment, the existing 302 management Step-Up prompt, Base POST admission, cryptographically verified emitted Jump destination, Auth Passkey signature verification, result handoff and Base completion using the original Base browser cookie. Without Step-Up, the management GET directs to verification and leaves freshness absent. Auth verification leaves freshness absent until Base completion. The same Secret-established root then adds one Secret, presents and confirms it, renames it and revokes it through HTTP. Lookup rejects both unconfirmed and revoked values; active count returns to zero while the root token remains active. The initial manual issuance still uses a scoped freshness fixture; this example is not a browser engine test or Jump gateway test.

The new rename request reproduced `ActionController::UnpermittedParameters`: top-level permit(:name) encountered CSRF and route parameters under strict parameter settings. SecretsController now extracts only the name slice before permitting it and uses scalar expect(:id) for owner-scoped loading. Existing name validation and ownership/Step-Up boundaries remain intact.

Narrow command `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/app_secret_login_journey_test.rb --include '/manual HTTP/'`: seed 39278, 1 run, 68 assertions, no failures/errors/skips. Combined command `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/app_secret_login_journey_test.rb test/integration/app_passkey_secret_session_step_up_test.rb`: seed 83, 26 runs, 497 assertions, no failures/errors/skips. RuboCop on the journey still reports existing long lines and the expanded single-journey assertion-count limit; no threshold or exclusion was relaxed. Formatting cleanup and a coherent test split remain required. Full real-browser secrecy, additional concurrency and remaining lifecycle collection acceptance requirements are unfinished.

### Direct management requests before independent Step-Up — 2026-10-05 UTC

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added direct create, rename and revoke HTTP requests before Step-Up in the actual Secret login journey. Each returns 401. Issuance and source outbox counts remain unchanged; name and revocation facts are unchanged and the root has no freshness. The same session subsequently completes actual Passkey Step-Up and the existing full management sequence. No session/freshness fixture is inserted after Secret login. The rename/revoke denial targets the already consumed login credential owned by the actor, proving the Step-Up guard precedes mutation even for an owned terminal row; active-credential-specific denial remains covered by separate boundary tests rather than this example.

Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/app_secret_login_journey_test.rb --include '/manual HTTP/'`; seed 55451, 1 run, 76 assertions, no failures/errors/skips. Current security documentation now distinguishes this verified HTTP journey from unfinished real-browser plaintext-residue checks. The previously recorded journey static-check failures remain unresolved.

### Shared legacy Secret concern no longer depends on app status — 2026-10-05 UTC

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Removed the obsolete ClientSecretCredentialStatus mapping from the shared SecretCredential concern. Replaced its persisted DummySecret using the rebuilt app table with the existing VisitorSecretCredential model and Visitor status/kind contract. The issuance test provides an actual verified Visitor email; the existing com identity prerequisite was preserved rather than bypassed. Shared status-predicate and unsupported-hook guarantees remain covered. The existing nonpersistent concern test uses Visitor status vocabulary instead of the removed app status vocabulary. No com/org production branch or distribution count changed.

Initial test migration failed because the visitors fixture has no `one` row, then because a newly created Visitor lacked the required verified contact. Both were corrected in test arrangement. Narrow pair: seed 7419, 10 runs, 33 assertions, no failures/errors/skips. Command including com top-up and Operator credential regression: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/models/concerns/secret_credential_concern_test.rb test/models/concerns/secret_credential_test.rb test/services/recovery_passcode_top_up_test.rb test/models/operator_secret_credential_test.rb`; seed 18771, 23 runs, 165 assertions, no failures/errors/skips. Obsolete app model/policy classes and the legacy signup checkpoint assertion still need final removal or replacement; this change does not claim that all old references are gone.

### Remove obsolete app kind/status classes and move signup completion guarantee — 2026-10-05 UTC

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Removed app ClientSecretCredentialKind, ClientSecretCredentialStatus, ClientSecretCredentialKinds and their empty policies after resolving remaining executable references. Removed the obsolete app fixture names from BaseIdentityCredentialManagementTest. The old mock-based signup finalization example expected Auth to create ClientToken and queried a deleted kind column. Its completion, account activation and credential count guarantees now live in the actual WebAuthn/Secret-confirmation signup HTTP matrix, with an explicit assertion that Auth finalization creates no root token. The remaining legacy checkpoint examples have not been modernized or rerun as a group; their correctness is not inferred from the replacement matrix.

Search `rg -n 'ClientSecretCredential(Kind|Status)|ClientSecretCredentialKinds|client_secret_credential_(kinds|statuses)' app test config` returned no matches. Historical migrations and documentation are outside this executable-reference search. Targeted A=0 completed signup: seed 51416, 1 run, 46 assertions, no failures/errors/skips. Full current signup matrix plus new credential and shared concern tests: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/app_secret_signup_journey_test.rb test/models/client_secret_credential_rebuild_test.rb test/models/concerns/secret_credential_concern_test.rb`; seed 18100, 40 runs, 1162 assertions, no failures/errors/skips. This includes A=0..20, cancellation and expiration. RuboCop on the changed Base identity test passed. The separate signup/login journey static-check debt and full fresh-build acceptance remain pending.

### Actual outer Ticket rollback cookie boundary — 2026-10-05T10:01:56+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added an app public `AuthenticationBase#log_in` test inside a real outer AppTicket transaction. It observes one tentative token row and no authentication cookies inside the transaction, rolls back through ActiveRecord::Rollback, and verifies no token-count change or access/refresh cookie afterward. No token-creation failure mock or private method invocation is used. The current implementation registers cookie publication on the outer transaction's after_commit; this test verifies rollback behavior, not a Secret-specific claim/receipt rollback or cross-database rollback consistency.

Narrow command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/controllers/concerns/auth/session_issuance_boundary_surfaces_test.rb --include '/outer Ticket rollback/'`; seed 57555, 1 run, 7 assertions, no failures/errors/skips. Required regression command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/controllers/concerns/auth/session_issuance_boundary_surfaces_test.rb test/controllers/concerns/auth/login_cooldown_surfaces_test.rb test/integration/root_login_establishment_flow_test.rb`; seed 33717, 61 runs, 422 assertions, no failures/errors/skips. Targeted RuboCop passed.

Inspection also confirms the unresolved OIDC limitation race: load_resolution checks the Secret flow before update selects/revokes a session, while selection/revocation are outside the later OIDC/flow issuance locks. Sequential expired-flow rejection is tested; cancellation/expiration after admission but before revocation still needs a barrier regression and an atomic guarded revocation boundary. No claim of concurrency completion is made.

### Guard Secret OIDC selected-session revocation under terminal locks — 2026-10-05T10:06:02+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added public `ClientSessionLimitResolutionTransaction#with_secret_revocation_authority!` and connected only the Secret OIDC limitation PATCH caller. Client, OIDC authorization, resolution and flow locks cover current actor/challenge/state/deadline validation and the selection/revocation callback. Cancellation uses the same order; canonical root issuance retains its independent final revalidation. The controller returns 410 when this authority is gone and leaves non-Secret paths on their existing behavior. No direct ClientToken creation was introduced.

Added public stale-object examples: a resolution loaded while open cannot execute its mutation callback after flow expiry, or after the HTTP cancellation commits. The initial test failed with the missing API (seed 41056); implementation then passed the OIDC group (seed 46119, 12 runs, 168 assertions). Combined command `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/oidc_initiated_sign_in_completion_test.rb test/integration/app_secret_parallel_login_test.rb`: seed 3681, 16 runs, 268 assertions, no failures/errors/skips. RuboCop on the model/controller passed after extracting private binding checks; these checks are reached only through the public boundary in tests. Updated the resolution diagram, transition inventory and security reference in the same change.

The guarded mutation boundary is implemented, but these new expiry/cancellation examples are sequential. The local parallel-login suite does not prove concurrent OIDC cancellation against selection or issuance. A separate-connection barrier test is still required before claiming that acceptance requirement complete.

### Separate-connection terminal-first resolution barriers — 2026-10-05 UTC

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added `test/operations/client_secret_resolution_concurrency_test.rb` without transactional fixtures. It holds the Client row lock, starts selection on a distinct PostgreSQL backend, confirms real blocking with pg_blocking_pids, commits cancellation or flow expiration, then releases the owner lock. The guarded public selection refuses its callback, the existing token stays active, and the flow has no issued token/time. The pending authentication/flow rows are explicit setup facts; this operation test does not perform Secret authentication, HTTP cancellation or a competing canonical root issuance. It complements, rather than replaces, the existing HTTP tests.

Initial arrangement failed a DB authentication-evidence CHECK because its setup omitted the matching event timestamp. After fixing that fact, polling timed out twice: Rails query caching retained the initial pg_blocking_pids result. Uncached observations resolved the barrier without adding sleeps or extending timeouts. Narrow cancellation run: seed 64267, 1 run, 11 assertions, no failures/errors/skips. Combined cancellation/expiration operation and OIDC HTTP command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/operations/client_secret_resolution_concurrency_test.rb test/integration/oidc_initiated_sign_in_completion_test.rb`; seed 19924, 14 runs, 191 assertions, no failures/errors/skips. Targeted RuboCop passed after formatting. Security reference and transition inventory now state the verified operation scope and remaining concurrent HTTP issuance requirement.

### Selection-first exclusion against cancellation — 2026-10-05T10:12:49+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Extended the public resolution-operation concurrency file with the opposite ordering. Selection enters its guarded callback first. Cancellation on a distinct PostgreSQL backend is observed blocked on the Client lock, while selection marks its chosen session and revokes that token. After selection releases its locks, cancellation commits resolution cancellation and flow failure. The flow has no issued token/time and the actor still has only the pre-existing, now revoked session row. This does not exercise a root issuance callback or actual HTTP cancellation; its setup and scope are the same explicit persisted pending-flow facts as the terminal-first tests.

Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/operations/client_secret_resolution_concurrency_test.rb`; seed 11927, 3 runs, 33 assertions, no failures/errors/skips. RuboCop formatted the new test and exited successfully with all reported offenses corrected. No sleeps, private-method calls or authorization bypass were added.

### Withdrawal retention timestamp boundary — 2026-10-05 UTC

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Reviewed explicit lifetime settings and confirmed the reservation API already rejects nonfinite/nonpositive durations. Found that credential withdrawal only compared truthy timestamp inputs. Added a public regression covering nil, empty string, zero, integer, array, object and infinity in either timestamp, plus equal and immediately reversed Time boundaries. The initial test failed (seed 9991) with a generic comparison error. Withdrawal now requires Time or ActiveSupport::TimeWithZone values and strictly ordered retention times before entering any mutation/audit transaction. It introduces no new operational TTL or fallback.

Command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/models/client_secret_credential_test.rb test/operations/withdrawal_personal_data_anonymizer_test.rb`; seed 55507, 7 runs, 120 assertions, no failures/errors/skips. The genuine withdrawal/anonymization path remains green. Proof/receipt collection remains unimplemented and its proposed retention remains unapproved; this input fix is not completion of that lifecycle requirement.

### Prevent OIDC purge from erasing unresolved Secret evidence — 2026-10-05 UTC

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Inspection found the existing generic OIDC expiry purge could delete an authorization transaction still needed by an irreversible Secret claim. Added the real purge operation to the delayed-result HTTP example before claim terminal reconciliation. It reproduced early deletion (seed 4538, assertion failure). App candidate transactions now use bounded, locked Ticket batches and exclude flows referenced by Source claim rows or Ticket receipts, as well as authorization rows with session-limit resolutions. Source checks are reads without source row locks, avoiding a reverse lock acquisition; expired locked authorizations cannot accept a new claim. The com/org delete branches are unchanged. This is dependency protection, not completed proof collection.

Narrow command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/oidc_initiated_sign_in_completion_test.rb --include '/expired OIDC Secret flow rejects/'`; seed 55397, 1 run, 32 assertions, no failures/errors/skips. Broader operation/job/HTTP command: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/operations/oidc_authorization_transaction_purger_test.rb test/jobs/oidc_authorization_transaction_purge_job_test.rb test/integration/oidc_initiated_sign_in_completion_test.rb`; seed 35121, 16 runs, 184 assertions, no failures/errors/skips. Targeted RuboCop corrected two formatting offenses successfully. Updated security reference and OIDC diagram/inventory. Receipt, resolution, issuance and other dependent-proof collection remains unfinished and requires explicit bounded retention.

### OIDC dependency release and surviving successful receipt — 2026-10-05T10:26:24+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Extended the expired-claim HTTP example to run the public OIDC purger after terminal Chronicle delivery and credential deletion: the authorization transaction is now deleted when no dependency remains, while the terminal and purged Chronicle records survive. Narrow command `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/oidc_initiated_sign_in_completion_test.rb --include '/expired OIDC Secret flow rejects/'` passed with seed 45584, 1 run, 35 assertions, no failures/errors/skips.

Extended the successful Secret OIDC HTTP example with an explicitly configured one-second purge delay and the real lifecycle job. After the consumed credential is physically deleted, the successful Ticket receipt remains, its authorization transaction survives the expired-transaction purge, and the established root token remains active. The bounded clock wait observes the configured retention deadline, not a concurrency ordering. Narrow command `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/integration/oidc_initiated_sign_in_completion_test.rb --include '/saved Secret records OIDC/'` passed with seed 8049, 1 run, 40 assertions, no failures/errors/skips.

Broader command `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/operations/oidc_authorization_transaction_purger_test.rb test/jobs/oidc_authorization_transaction_purge_job_test.rb test/integration/oidc_initiated_sign_in_completion_test.rb` passed with seed 10085, 16 runs, 191 assertions, no failures/errors/skips. `bundle exec rubocop app/operations/oidc_authorization_transaction_purger.rb --format simple` passed, one file without offenses. Corrected the operation's outdated comment that asserted expired transactions were never read. Receipt, resolution and issuance collection remains unfinished; these results verify dependency protection and release, not complete proof retention or browser secrecy.

### Retired unconfirmed allocation collection — 2026-10-05T10:29:45+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added public ClientSecretIssuancePurger and connected bounded candidates to ClientSecretLifecycleJob. It holds Source Client and issuance locks, retains credential dependencies, checks retirement deadlines and existing holds/enforcement, and requires both delivery acknowledgment and terminal Chronicle rows. DELETE and a surviving secret.issuance_purged source outbox commit together. The event is explicitly allowed; no schema or operational TTL change was needed. Confirmed/omitted batches and Ticket receipt/flow collection remain unfinished.

The new public-operation assertion first failed with missing ClientSecretIssuancePurger (seed 53990). After implementation, `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/jobs/client_secret_audit_delivery_job_test.rb` passed: seed 48690, 6 runs, 60 assertions. Tests verify a pending credential blocks issuance deletion, the retired issuance is deleted after credential collection, and its surviving event reaches Chronicle. Combined audit-job/OIDC HTTP command passed with seed 34211, 18 runs, 238 assertions, no failures/errors/skips. After adding an explicit real-lifecycle issuance-deletion assertion, the withdrawal example passed with seed 11136, 1 run, 11 assertions.

`bundle exec rubocop app/operations/client_secret_issuance_purger.rb app/jobs/client_secret_lifecycle_job.rb app/models/client_secret_audit_outbox.rb --format simple` passed, three files without offenses, after extracting the private Chronicle comparison reached through the public purge operation. Updated the issuance diagram, transition inventory and security reference. Full hold/crash/boundary coverage for the new allocation collector remains to be added; these results do not establish complete proof collection.

### Allocation hold and rollback coverage — 2026-10-05T10:32:11+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Public allocation purge tests now verify that a retired, candidate-free allocation remains until terminal Chronicle delivery, legal hold prevents deletion, an outer Source rollback restores both the deleted row and pre-delete outbox count, and a subsequent retry commits exactly one allocation-purged event. A separate example preserves confirmed and omitted facts with finite retention timestamps; these require their own future collector. No successful application behavior was mocked and no private method was called.

Narrow command `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/jobs/client_secret_audit_delivery_job_test.rb --include '/retired allocation waits/'` passed, seed 32958, 1 run, 10 assertions. Full audit-job file passed, seed 3738, 8 runs, 77 assertions, no failures/errors/skips. RuboCop initially reported five blank-line offenses only; formatting was corrected without changing expectations or thresholds. Exact retention-deadline boundary coverage, enforcement-case coverage and complete remaining proof collection are still outstanding.

### Collected operation replay refusal — 2026-10-05T10:34:57.439468+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Inspection found that removing an issuance could make reservation retries allocate anew. Added a public manual-operation test that reserves with explicit microsecond lifetimes, expires through the real invalidator, delivers its audit and physically collects the allocation. Replaying the same operation initially created another allocation instead of raising Denied (seed 16077). Both manual and Passkey reservation callers now refuse operations with surviving issuance_purged source events. Future outbox collection must retain these replay barriers while their operation remains acceptable; that collection is not implemented yet.

Command `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/operations/client_secret_manual_reservation_issuer_test.rb test/operations/client_secret_passkey_reservation_issuer_test.rb test/jobs/client_secret_audit_delivery_job_test.rb` passed, seed 15294, 21 runs, 534 assertions, no failures/errors/skips. Targeted RuboCop corrected formatting/guard-style offenses successfully without changing assertions or thresholds. Updated security reference and transition inventory. The new collected-operation replay scenario is verified for manual reservations; equivalent full Passkey collected-batch replay coverage remains outstanding.

### Signup and signed-in collected Passkey replay — 2026-10-05T10:36:37+00:00

HEAD `7de33215b055bc8f0f2721b86a04b428a049220e`, dirty worktree. Added public Passkey reservation coverage for both signup and signed-in operations. Each case reserves with explicit microsecond lifetimes, runs the actual expiry invalidator, delivers the terminal audit, physically collects the issuance and retries with the original still-current signup nonce/flow or independent registration Step-Up. No allocation is recreated. The test also checks the retired-allocation error message so rejection from another admission prerequisite cannot falsely satisfy it.

Full command `bundle exec ruby /tmp/umaxica-secret-db-task.rb test test/operations/client_secret_passkey_reservation_issuer_test.rb` passed, seed 59764, 4 runs, 238 assertions, no failures/errors/skips. After adding the explicit rejection-reason assertions, the narrow collected-Passkey example passed, seed 56608, 1 run, 10 assertions, no failures/errors/skips. Targeted RuboCop corrected four formatting offenses successfully. Security documentation now records this verified public-operation scope. Complete browser replay behavior and bounded collection of the surviving replay barriers remain unfinished.
