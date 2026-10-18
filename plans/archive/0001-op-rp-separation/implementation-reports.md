# OP/RP Separation — Implementation Reports

> Archived snapshot, generation 0001 (originally `three.md`). Non-normative and not evidence; see
> [README](./README.md).

Status: **R1-WU01 implementation started under explicit I approval on 2026-10-16; reports below
record actual findings, not Gate completion**.

## Purpose

Record actual important discoveries during implementation of [one.md](./implementation-plan.md).
This is append-only report/decision history, not a substitute for reporting to the user or an
implicit specification amendment. Acceptance belongs in [two.md](./acceptance-definitions.md);
approved changes belong in [four.md](./addenda.md); non-normative notes belong in
[five.md](./notes.md).

Critical/High issues, contradictory accepted contracts and implementation-stopping conditions
require stopping the affected scope and notifying the user promptly. Preserve unaffected work and
report the exact stopped unit/cell. Do not silently invalidate decisions or record an unresolved
scope as complete. Ordinary implementation choices use the existing specification and engineering
judgment.

## IDs and Lifecycle

Use `REP-YYYYMMDD-0001`, incrementing uniquely within the date. A report's status is OPEN /
INVESTIGATING / AWAITING_DECISION / RESOLVED / WITHDRAWN. Resolution or correction is a new dated
follow-up entry referencing the original ID; preserve the original fact and decision record.
Evidence/result status remains separate from report status.

No implementation report is created for preparation of the planning documents. Current static design
review is in `one.md`, not a fictional implementation discovery here.

## Report Register

### REP-20261016-0001 — Prevent automatic reconstruction of the approved test fleet

- Discovery date: 2026-10-16 UTC.
- Release / Work Unit / Gate: R1 / R1-WU01 / AT-R1-01.
- Severity: Medium.
- Execution HEAD: `17903f7d121aa33efe29f2db9235c9aa5db4b001`; no application edits existed during
  the initial preflight. The ignored specification files had scoped approval-record updates.
- Facts: the twenty existing isolated databases in `tmp/acceptance-isolated-20261016w6n2.json`
  matched their recorded catalog OID, owner and identifying comment in READ ONLY transactions. All
  twenty writers' applied migration versions exactly matched current migration files. Their stored
  schema-dump digests did not match the current dumps. Rails' default test maintenance would
  therefore try schema reconstruction. The Rails pending-migration helper also attempted
  `CREATE TABLE IF NOT EXISTS` through the current initializer; READ ONLY protection refused it
  before any write. Raw read-only version comparison subsequently succeeded.
- Sources: `lib/umaxica/test_environment/database_safety.rb`,
  `config/initializers/schema_migration_if_not_exists.rb`, Rails
  `ActiveRecord::Migration.load_schema_if_pending!`, and the current isolated manifest. Evidence:
  [R1 execution record](../../../evidence/2026-10-16-r1-context-implementation-R1C1.md).
- Affected scope: ordinary automatic-schema-maintenance test invocation is stopped. No database
  reconstruction or migration is authorized.
- Options and cost/risk: use process-local `ActiveRecord.maintain_test_schema = false` after
  explicit raw migration-version/catalog verification, retaining DatabaseSafety (small verification
  cost, no schema preparation); or request reconstruction approval (unnecessary data mutation and
  scope expansion for this code correction).
- Recommendation: use the first option for these scoped tests. Recheck versions if migration files
  or HEAD change. This is a test invocation setting, not a production/configuration change or a
  bypass of DatabaseSafety.
- User decision: I granted for R1-WU01; separate D explicitly granted for one-worker R1 fixture
  writes on this exact existing isolated fleet. Creation, deletion, reconstruction, migrations and
  ordinary development/test database changes are excluded. No additional decision is needed for the
  chosen invocation within those bounds.
- User notification: reported in this session before execution; the user approved the exact target
  through the D question.
- Status: RESOLVED for the scoped invocation; Gate results remain separate. No conflicting accepted
  contract or Addendum.
- Re-entry condition: exact manifest identity and migration versions still match, one worker, and no
  schema preparation. Stop if any prerequisite changes.

## Entry Template

```text
Report ID: <REP-YYYYMMDD-nnnn>
Discovery date: <UTC date/time>
Release / Work Unit / Cell / Gate: <stable IDs and exact scope>
Severity: <Critical / High / Medium / Low>
Execution HEAD / dirty worktree scope: <full hash and relevant changes>
Facts discovered: <observed facts, separated from inference>
Source / ADR / evidence: <precise paths, symbols and observed result>
Affected scope and current stopped work: <explicit>
Conflicting accepted contracts, if any: <both sources and why incompatible>
Options: <concrete alternatives>
Cost and risk per option: <engineering/data/availability/security impact>
Codex recommendation: <option and rationale>
User decision required: <yes/no; reason, not routine implementation preference>
User notification: <actual message/date reference, or pending>
Status: <OPEN / INVESTIGATING / AWAITING_DECISION / RESOLVED / WITHDRAWN>
User decision: <exact actual decision/date/reference, or none>
Related Addendum ID: <ADD-ONE/ADD-TWO ID, or none>
Follow-up action / dependency / re-entry condition: <explicit>
```

## Follow-Up Template

```text
Follow-up to: <Report ID>
Date: <UTC>
New fact / actual decision: <source and exact scope>
Status change: <old -> new>
Approved Addendum / affected Work Units / Gates: <IDs or none>
Action and observed result: <actual completed work, or explicitly pending>
User notified: <actual reference>
Remaining stop condition: <explicit or none>
```

A resolved report permits re-entry only when its stated approved contract and verification
prerequisites hold. A record alone authorizes no DB operation, environment change, external write or
deployment.

## REP-20261016-0002 — R2-WU04 ACTIVE-only authentication boundary

- Discovery date: 2026-10-16 UTC.
- Release / Work Unit / Gate: R2 / R2-WU04 / AT-R2-04.
- Severity: Medium.
- Execution HEAD: `17903f7d121aa33efe29f2db9235c9aa5db4b001`; the worktree contained pre-existing
  uncommitted R1/R2 implementation, migration, documentation, test and evidence changes.
- Facts: credential authentication and issuance now require an ACTIVE, currently usable root across
  Browser RP, current-resource resolution, OIDC Access, Code/Refresh/reissue, Step-Up and credential
  ceremony boundaries. Historical status 103 remains readable but has no issuance or authentication
  writer. The old RestrictedSessionGuard, callback registrations, restricted refresh exception path
  and unused `Actor::Authentication#restricted?` state were removed. Three Base MFA reset
  controllers remain GET-only unavailable pages and deny historical 103/non-active sessions before
  the page.
- Sources: `app/controllers/concerns/browser_rp_authentication.rb`,
  `app/controllers/concerns/authentication_current_resource_resolver.rb`,
  `app/services/oidc_access_token_authenticator.rb`,
  `app/models/concerns/token_status_management.rb`, `app/models/concerns/rp_session.rb`, the three
  Base MFA reset controllers and `docs/mermaid/idp-state-machine-transition-inventory.md`.
- Action: removed dead old-status writers and guard paths after migrating consumers, preserved
  status 103 and historical token/audit rows, and added public refusal coverage for Browser RP,
  OIDC, Refresh, Step-Up and MFA reset boundaries.
- Verification: [R2-WU04 evidence](../../../evidence/2026-10-16-r2-wu04-6H2Q.md) records 232 Ruby
  syntax checks, `git diff --check`, and a serial focused result of 276 runs / 2,148 assertions with
  zero failures, errors or skips.
- Status: RESOLVED for the source implementation packet; AT-R2-04 and the R2 release Gates remain
  separate acceptance decisions and are not marked PASS here.
- Remaining dependency: perform the Gate's complete inventoried status/Waiting/MFA acceptance and
  R2-WU05 documentation and three-realm closure before claiming release completion.

## REP-20261016-0003 — R2-WU05 release closure packet

- Discovery date: 2026-10-16 UTC.
- Release / Work Unit / Gate: R2 / R2-WU05 / AT-R2-05, with release dependency AT-R2-REL.
- Severity: Medium.
- Execution HEAD: `17903f7d121aa33efe29f2db9235c9aa5db4b001`; the worktree retained the existing
  uncommitted R1/R2 implementation, migration, documentation, test and evidence changes.
- Facts: the route inventory shows the explicit POST Continue mapping for all three Base limitation
  surfaces, GET-only MFA reset routes, and the expected Base Edge/Core API refresh endpoints.
  Session-limit, cooldown, root-login, token-ceiling and three-realm promotion tests passed with 187
  tests / 1,417 assertions and no failures, errors or skips. The historical status-103 OIDC case
  returns the protocol `login_required` callback result under `prompt=none`; 103 remains readable
  historical data and does not authenticate or consume active capacity.
- Sources: [R2-WU05 evidence](../../../evidence/2026-10-16-r2-wu05-4J7N.md),
  `docs/security/session-limit.md`, `docs/checklists/authentication.md`,
  `adr/root-login-establishment-boundary.md`,
  `docs/mermaid/idp-state-machine-transition-inventory.md`, and the route/test files listed in the
  evidence.
- Status: RESOLVED for the source and documentation implementation packet. `AT-R2-05` and
  `AT-R2-REL` remain separate acceptance decisions; `two.md` still records them as NOT_RUN.
- Remaining dependency: execute the complete approved Gate procedures against the inventoried
  three-realm scope before starting the R3 release sequence. No deployment, external write,
  credential redistribution or Jump/Edge write was performed.

## REP-20261016-0004 — R3 OP/RP naming implementation and local cutover

- Discovery date: 2026-10-16 UTC.
- Release / Work Unit / Gate: R3 / R3-WU01 through R3-WU08 / local implementation evidence only.
- Severity: Medium.
- Execution HEAD: `17903f7d121aa33efe29f2db9235c9aa5db4b001`; the worktree retained the existing
  uncommitted R1/R2 implementation, documentation, tests and evidence while R3 was applied.
- Facts: the three ticket migration roots and structure dumps were moved to `op_base_app`,
  `op_base_com` and `op_base_org`; the abstract records and concrete RP session models were renamed
  to `OpBase*Record` and `Op*Grant`; current source/config/fixture references were updated; and
  forward migrations rename the three tables, indexes, constraints and sequences with explicit
  old/new state checks. Historical migration provenance remains unchanged.
- Local database action: under the standing local development/test authorization, nine old OP
  databases were dropped, six writer databases were created and migrated, three test replicas were
  cloned from their writers, and development seeds completed. Catalog verification found zero old
  databases, nine new targets, zero active target sessions, all three new grant tables, and no old
  grant tables.
- Isolated evidence: fleet `20261016r3a1` contained twenty identified test databases. Fresh rebuild
  migration preparation completed and recorded twelve scoped HMAC role receipts. The catalog
  contained the new grant tables, sequences, active indexes and renamed constraints, with no old
  grant tables, sequences or active indexes. The R3 focused suite passed with 64 runs / 322
  assertions / 0 failures / 0 errors / 0 skips. The full suite reached 15,376 runs but ended with 12
  failures and 12 errors in the current authentication/session worktree; those failures remain
  recorded in `seven.md`.
- Schema evidence: the three target dumps were regenerated from the isolated target and their
  individual normalized drift comparisons passed. The repository-wide drift task still reports the
  intentional uncommitted R3 dumps and thirteen non-R3 dump mismatches.
- Status: RESOLVED for the R3 source implementation and local database cutover packet. This report
  does not mark R3 acceptance or any release Gate PASS.
- Remaining dependencies: the CI workflow still contains old database names because its path is
  read-only in this workspace; the complete suite remains non-green; global schema drift remains
  open; and R4/R5 implementation and their approval-gated runtime work remain outstanding.

## REP-20261018-0001 — R5 verifier, Refresh and domain protocol continuation

- Discovery date: 2026-10-18 UTC.
- Scope: R5-WU04/WU05/WU08 and WU11-WU15 client failure boundaries; applicable local WU07/WU10
  races.
- Severity: High for the local credential-binding and uncertain predecessor-redispatch defects; no
  external exploit or deployed exposure was tested.
- Execution HEAD: `17903f7d121aa33efe29f2db9235c9aa5db4b001`; extensive pre-existing staged,
  unstaged and untracked R1-R5 work preserved.
- Observed facts: public-operation regressions reproduced installation of another subject's signed
  JWT, dispatch from an ended binding, numeric rather than integer epoch acceptance and
  malformed-domain-response exceptions. Source inspection also found the opaque-session versus
  primary-key lookup mismatch and loss of prior uncertain Refresh attempts across requests.
- Action: repaired exact local binding/liveness checks, public session lookup, writer selection,
  binding-before-session ordering and persistent exact-attempt recovery. Original deadlines remain
  fixed; no known predecessor is redispatched after installation or uncertainty. Migrated all
  current UserInfo consumers to the OP adapter, preserved OAuth-refusal versus dependency semantics,
  and rejected invalid domain JSON shapes. Updated public regressions, current Refresh
  documentation, durable checklist and the derived attempt diagram/inventory.
- Evidence: [R5 continuation](../../../evidence/2026-10-18-r5-protocol-continuation-R5C8.md).
- Verification: final focused protocol/local-concurrency suite 44 tests / 321 assertions, zero
  failures/errors/skips; affected Ruby lint and Zeitwerk passed. Evidence distinguishes the earlier
  full-suite checkpoint from the final source and records later results separately.
- User decision: implement the remaining authorized work; defer WU03A; change no Edge/Jump
  implementation; keep `two.md` acceptance unchanged. No new shape, credential redistribution,
  deployment, CI or external write was performed by this continuation.
- Status: RESOLVED for the reproduced source defects; programme completion and applicable full Gates
  remain OPEN. WU03A, independent receiving/real-path proof, measured recovery budget and
  cutover/activation-dependent work remain as explicitly documented acceptance limits.

### Follow-up to REP-20261018-0001 — Final source regression result

- Date: 2026-10-18 UTC; same HEAD and uncommitted scope as the report above.
- Actual result: final `bin/rails test --seed 42061` on the verified isolated fleet with eight
  workers passed **15,502 tests / 132,243 assertions / 0 failures / 0 errors / 0 skips**, exit 0.
  The 20 affected source/test file hashes matched before and after execution.
- Status: source regression verified for this worktree. Full acceptance and activation remain OPEN
  for the separately recorded deferred/runtime conditions; `two.md` is unchanged.
