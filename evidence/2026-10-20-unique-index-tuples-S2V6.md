# UniqueIndex C28–C31 — attempts, activations and receipts

Revision: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829` with extensive retained uncommitted changes
affecting these results. This is local/test evidence, not clean-HEAD or production evidence. The
previous goal turn made verified implementation progress (C14–C27); this continuation resolved nine
more reports.

## Changes and compatibility

| Cycle | Reports/models | Scope and unchanged contracts                                                                                                                                                                                                                       |
| ----- | -------------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| C28   |              2 | Create-time attempt_number uniqueness scoped by notification FK and delivery_generation. Existing lock/lease/retry/receipt writers unchanged. Notification find_or_create_by! indexes remain open.                                                  |
| C29   |              3 | Create-time client_id uniqueness scoped by contract_epoch. Existing epoch lock, named activation writer and enable/disable admission decisions unchanged.                                                                                           |
| C30   |              1 | Create-time attempt_number uniqueness scoped globally by origin_operation_id, including across owners. Reservation/reattempt locks and prior-operation replay unchanged; immutable facts and validate:false public-ID collision behavior preserved. |
| C31   |              3 | Create-time event_id uniqueness scoped by issuer/realm/client_id. event_type remains outside this DB key. Existing duplicate delivery and ActiveRecordError durable enqueue preserved.                                                              |

Four bounded causes, nine concrete models and four new test files/eighteen tests. No migration,
index, checker configuration, trigger, deletion, bulk data conversion,
authorization/retirement/session writer or DB-boundary change. Added attempt-number error labels in
the four existing locale bundles; reused existing client/event labels.

Each validator adds one indexed SELECT on validated creation, none on updates. C28/C30 keep
persisted terminal-fact transitions free of new preflight; C29 same-row toggling and C31
already-recorded duplicate delivery retain their existing paths. No throughput benchmark or
production query-plan measurement was performed. DB UNIQUE remains authoritative for races and
validation-disabled writes.

## Executed verification

Commands use `python3 tmp/database-consistency-20261019/run_tests.py STAGE TEST_FILES...` with the
configured local test DBs and one worker. The aggregate selected paths are retained locally in
`tmp/database-consistency-20261020/c28-c31-test-files.txt`; no source test or assertion was skipped
or removed.

| Receipt                       | Result                                                   |
| ----------------------------- | -------------------------------------------------------- |
| erasure-attempt-red-confirmed | 4 runs, 16 assertions, 2 failures, 0 errors, 0 skips     |
| erasure-attempt-green         | 41 runs, 147 assertions, 0 failures, 0 errors, 0 skips   |
| activation-unique-red         | 6 runs, 21 assertions, 3 failures, 0 errors, 0 skips     |
| activation-unique-green       | 20 runs, 54 assertions, 0 failures, 0 errors, 0 skips    |
| secret-issuance-unique-red    | 2 runs, 6 assertions, 1 failures, 0 errors, 0 skips      |
| secret-issuance-unique-green  | 44 runs, 861 assertions, 0 failures, 0 errors, 0 skips   |
| inbound-receipt-red           | 6 runs, 27 assertions, 3 failures, 0 errors, 0 skips     |
| inbound-receipt-green         | 18 runs, 70 assertions, 0 failures, 0 errors, 0 skips    |
| c28-c31-aggregate             | 124 runs, 1222 assertions, 0 failures, 0 errors, 0 skips |

- C28 initial test loading used nonexistent VisitorVisibility::USER; corrected only the new test to
  the existing VISITOR constant before confirming Red. The initial loading error is not a
  regression-test failure or passing verification.
- Raw duplicate writes are wrapped in savepoints and bypass validation. Tests also cover actual
  repeated attempt claims, retry ordinal increment, delivery-generation partitions, client/epoch
  partitions, false-state updates, operation/attempt and cross-owner boundaries, sender/event
  partitions and deliberate event_type exclusion.
- Existing concurrency tests passed for notification claims and Secret reservation capacity.
  Existing real admission gate, invalidation/redelivery, durable enqueue/sweep and
  identity/lifecycle security guards passed in the final aggregate: **124 runs/1,222 assertions,
  zero failures/errors/skips**.
- Formatting is limited to thirteen scoped model/test files. Final RuboCop: thirteen files, no
  offenses, exit zero. git diff --check also passed. No existing tests were weakened to satisfy
  lint.
- `bundle exec database_consistency` captured complete stdout/stderr in ignored
  `tmp/database-consistency-20261020/c31-after.*`; exit **1** for remaining findings. UniqueIndex
  **451 -> 442**. All enabled checkers ran with no internal error; CLI has 1,620 grouped failure
  lines. Raw processor capture completed successfully with **1,635 individual failures and one
  warning**. Every non-OK report maps to the retained ledger.
- No full Rails suite or production data/migration verification was performed. These models retain
  existing physical constraints; no production migration is needed for this slice.

## Reviewed holds and continuation

- Both notification models retain DB collision retry because
  PrivacyErasureRequestFlow#create_processor_notifications! uses find_or_create_by!. A uniqueness
  validator can convert a concurrent duplicate to RecordInvalid, defeating Rails' RecordNotUnique
  retry.
- ClientExternalIdentity's two effective-binding indexes remain unchanged:
  ClientExternalIdentityTest explicitly requires normal duplicate valid? then RecordNotUnique, and
  SocialAuthLinkHandler/SocialAuthLoginHandler translate RecordNotUnique into conflict behavior. The
  client index is not scoped by provider despite its legacy name.
- Three Op*Grant active-device/client indexes remain unchanged: OidcTokenExchangeCoordinator
  translates RecordNotUnique to RpSessionAlreadyExists and invalid_grant. No generic preflight was
  installed ahead of this contract.
- Three Op*ProtocolEpoch realm indexes express the singleton row already restricted to id=1;
  redundant model probes are not justified by a checker warning alone.
- BaseAuthAdmissionCoordinator#create_or_reuse_binding! retries RecordNotUnique; its parent bindings
  must not receive blanket uniqueness validators. Confirmation refs are assigned at attach/update,
  so adding creation-only validation there would not protect their actual write.
- Six session-limit resolution partial indexes have a potentially safe next slice: the existing
  issue! writer locks actor and parent, returns existing work and raises WaitingSlotOccupied before
  creation for another open flow. Their exact predicates differ (state_id in 10/20 versus
  waiting_slot=1), so they require separate candidate guards and all-surface tests. This is
  investigation, not completed implementation.

The goal remains active. **442 findings remain**; unreviewed open rows must not be described as all
impossible to fix or as completion of all safely fixable work.

## C32 continuation — session-limit partial uniqueness

- Same revision and retained dirty worktree as above. This section supersedes the earlier current
  counts and the earlier note that the six session-limit findings were prospective work.
- Three concrete models now have six exact partial validators: parent flow only for state_id in
  10/20; actor only for waiting_slot=1. Creation-only, with matching candidate guards. Expiry does
  not change index participation. Four locale bundles receive explicit actor/flow labels.
- New all-realm characterization and regression file: six tests. Red was six runs/30 assertions,
  three expected failures, no errors/skips. Actual issue replay, occupied-slot refusal, raw DB
  uniqueness and cancel/reissue already passed. Initial Green broad suite: 52 runs/375 assertions,
  zero failures/errors/skips.
- Final expanded suite: **52 runs/405 assertions, zero failures/errors/skips**, including each
  parent-only/actor-only collision, elapsed open candidates, terminal eligibility, actual issue
  replay, cancellation/reissue, all-realm controller refusal/gate, app/com root promotion and
  identity/lifecycle guards. Two new indexed probes on open creation, none on existing transitions
  or same-flow replay. State edges, named writers, cookie/audit control order and DB constraints
  remain unchanged. Test-only formatting subsequently split two long expressions without changing
  their values or assertions; final RuboCop: four scoped files, no offenses. git diff --check
  passed.
- Mermaid README summary still says code pending; concrete resolution diagrams and the lower
  detailed transition inventory describe the currently implemented waiting-slot invariant. Code and
  all-surface tests agree with those detailed documents. No new axis or edge was introduced; this
  pre-existing summary discrepancy is recorded rather than silently treated as new policy.
- Full default `bundle exec database_consistency` captured in `resolution-unique-after.*`, exit 1
  for remaining findings, no internal error. UniqueIndex **442 -> 436**. Raw capture via runner
  completed: **18,916 OK, 1,629 failures and one warning**; CLI has **1,614 grouped failure lines**.
  Every current non-OK report maps to the stable ledger. No exclusion/configuration changed.
- Combined C28–C32 progress: **fifteen reports, twelve concrete models, five bounded slices, five
  new test files/twenty-four tests**, zero migrations. The earlier C28–C31 aggregate passed before
  C32; C32's related suite then passed after adding those validators and labels. No full Rails suite
  or production data check was run. The complete safely-fixable review remains unfinished; **436
  findings remain**, with unreviewed consumers tracked honestly as open.
