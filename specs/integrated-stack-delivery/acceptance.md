# Integrated stack delivery — process and transition acceptance

This document defines change-specific procedural and migration criteria for the approved M/I/A/F/O/E
integration and its editorial refinement. It does not add business policy, implementation permission
or a new workflow engine. Durable behavior belongs to the domain criteria linked from
[the acceptance index](../../docs/checklists/integrated-stack.md); Luna's single execution
instruction is [nine.md](../../nine.md). Results belong in `evidence/`, never permanent checked
boxes here. Local IDs are stable; qualify them with this path. No retrospective static inspection
can establish that a past Red or full gate actually ran.

## PROC-1 — Current checkout and protected scope

- Basis: M01–M03/M06, I01/I02, A00/A02/D-1, F01, E20, C01–C15.
- Before edits, identify actual repository/branch/full HEAD and staged/unstaged/untracked/ignored
  state. Read applicable root rules and owning specs/ADRs; separate observations from approved
  contracts and rejected historical proposals. Work stays in the current tree, without
  reset/clean/stash/worktree, remote writes, production actions or unapproved destructive
  operations.
- Verify a contemporaneous non-secret baseline record and compare final owned/unowned changes. A
  historical path/count/version/report or a new document commit does not establish the current code
  snapshot. Equal HEAD alone is insufficient when relevant code is dirty.
- References: [root rules](../../AGENTS.md), [spec lifecycle](../README.md), nine Sections 2–4; new
  execution evidence is required. The editor's validation record is not implementation evidence.

## PROC-2 — Required DB guarantee versus authorized mechanism

- Basis: I04/I07/I08, A04/D-3/D-4, C11; prerequisite of P0/P2.
- Before implementing each permanent-ID or ownership invariant, record required DB guarantee,
  current enforcement, exact ADR/approval scope and whether an already approved mechanism suffices.
  If not, identify the minimum missing decision and hold only that implementation scope. Callbacks
  alone do not prove raw SQL protection; Avatar trigger authorization is not a blanket identifier
  exception.
- Inspect [migration rules](../../.agents/harnesses/rules/generic/migrations.mdc) and
  [trigger boundary](../../adr/database-trigger-usage-boundary.md), plus existing scoped realm proof
  approvals. This criterion authorizes no extra trigger, counter, SQL, data repair or destructive
  action.
- Evidence must show the mapping preceded affected edits; a completed implementation is not proof of
  prior authorization. Unrelated verified work can proceed only with current required full gates.

## PROC-3 — TDD and recurring full gates

- Basis: M04/M05, I12, F10, O12, E18/E19, C01.
- For each observable behavior, record its permanent Acceptance ID before Red. Actual intended Red
  precedes minimal Green and refactoring; environment/syntax failure is not Red. Existing correct
  behavior may use a current regression test without fabricated failure. No after-the-fact
  expectation changes, private-interface tests or weakening coverage/constraints/assertions.
- Gate 0 runs after safety/migration checks and before feature changes. Both full Rails and
  non-watch Vitest run at the earliest slice completion, three TDD iterations, phase completion or
  transverse change, and after regression repair; Gate 4 tests final state. Three means small
  iterations, not giant features/phases. Reconfirm commands/package manager in current config;
  shards must cover all tests before advancement. Never convert full verification into a final-only
  exception.
- Compare exact failed cases/causes/seeds/conditions, not counts alone. Separate pre-existing
  failures, new regressions, coverage deficits and environment failures. Missing chronology is
  NOT_RUN/BLOCKED for this procedural criterion, even if the current code later passes. Check
  command/results/evidence with HEAD and dirty scope; no such implementation execution is asserted
  here.

## PROC-4 — Holds stop unverified accumulation

- Basis: M05–M07 and the editorial refinement of Gates 0–3.
- Given a domain decision hold, only its dependent branch waits while independently testable work
  with current full gates may proceed. Given unavailable/unfinished Gate 0 or any mandatory full
  gate, new feature edits stop throughout the shared tree: only read-only work, acceptance-document
  work, already authorized environment recovery and last-slice verification preparation continue.
- No source-only prototype exception remains. Preserve/report existing unverified work but do not
  add another feature or build on it. Resume after actual focused Red/Green or existing-behavior
  check and required full gates. New regression stops feature work until causal repair, focused
  tests and both full suites run again. Reporting BLOCKED alone is not permission to continue
  coding.
- Check chronological diffs/evidence and actual gate state; code alone cannot establish this
  criterion. Revised P10a/b, P11a/b, P12a/b and P3b primary-control prerequisites must match
  graph/table/report.

## PROC-5 — Criteria, references and independent judgment

- Basis: M08–M10, I13/I14, A14–A16, F09/F12, O11/O13, E17–E20.
- Before each slice read affected criteria; before Red map its expected behavior; during work
  replace planned test references with actual checks/evidence; at exit reconcile specification,
  criteria, code, references, diagrams and full/doc gates. IDs persist; supersession records
  reason/successor. Failure is not a reason to delete/weaken a requirement.
- Missing durable criteria, critical broken links or uncommitted acceptance updates leave
  documentation/ handoff incomplete. Report implemented, verified, documented and committed states
  separately. A later investigator uses current evidence; Luna neither waits for routine independent
  approval nor calls its own testing independent acceptance. Existing explicit owner/security-review
  requirements still apply.
- Check requirement crosswalk completeness and real references, safe documentation checker output
  and evidence provenance. No static source review substitutes for COMMIT/concurrency/export/mount
  behavior.

## PROC-6 — Restricted document commit

- Basis: editorial authorization; replaces blanket commit prohibition only for owned document hunks.
- Given checked ownership, stage only nine.md, natural-language acceptance definitions, necessary
  minimal indexes/document rules and safe evidence changed by the editor/Luna. Preserve unrelated
  staged/unstaged/untracked/ignored work and other authors' same-file hunks. No broad add/commit -a,
  amend/reset/clean/stash, application/test/migration/dependency commit or schema-drift concealment.
- Hooks/signing/permissions/protected mounts run normally; no bypass or configuration change. If a
  safe document-only commit is impossible, report COMMIT_BLOCKED with paths/cause/minimum remedy.
  Editing, staging or git ls-files is not persistence proof. No push/PR/GitHub mutation follows the
  local commit.
- Inspect actual commit object/full hash/path list and blobs. Evidence identifies actual code HEAD
  plus dirty code, not a fictional full implementation snapshot at a document commit. Independent
  reader must distinguish document persistence from implementation completeness and remote
  synchronization.

## MIG-1 — Identifier migration and sequence safety

- Basis: I09–I11/I14, E19/E20, C02/C05/C12; P6/P12a, independent of Avatar's domain hold.
- Given real typed inventory and aggregate data/consumer checks, a synthetic isolated
  expansion/backfill/ constraint/read cutover preserves issued public IDs, relationships and
  external consumers. Restarted bounded backfill does not overwrite valid IDs or invent/delete
  ambiguous duplicates; no truncation, forced casts or historical migration rewrite. Mixed-version
  writers/locks/index failure and recovery have explicit disposition. E's no-compatibility waiver
  does not reset unrelated data or Avatar history.
- Sequence ownership/type/max/increment/cycle/is_called/cache/parallel writes and actual replication
  allocation are checked without diagnostic nextval/automatic setval. Seed/import/restore does not
  rewind allocation; fixed catalogs need not acquire a sequence. Partition uniqueness is judged at
  its real scope, not waived with a composite PK or removed constraint.
- Check isolated pre/post migration data and references, idempotent operational task, actual
  catalog, rebuild/dump/recovery evidence. New complete drill references are planned; no real-data
  application is authorized. Ordinary schema drift from uncommitted migrations stays reported, not
  hidden by commit.

## MIG-2 — Six Avatar drafts and operational conversion

- Basis: A00/A11/A14–A16, D-1/D-9, C03/C04; P0/P7/P12b.
- Before any explicit/implicit migration, audit exact current paths, full contents, provenance and
  applied versions of the six drafts historically under
  `specs/avatar-organization-ownership/migration-drafts/`. Four generator stubs must not be recorded
  as applied; tracked drafts are not deletable under the old untracked-cleanup allowance. Preserve
  useful partial work and never edit applied migration history.
- In a new disposable catalog, normal completed migrations register functions and triggers together,
  reverse their own objects correctly, and rebuild/dump/restore successfully. Conversion is a
  separate inventory/dry-run/bounded idempotent operational task preserving owner, actual intervals,
  valid transfer states, known actor and public identities. Ambiguous rows stop without guessed
  owner/date. Equal public strings in different concrete families are not automatically collisions.
- Check the [existing spec's exact draft inventory](../avatar-organization-ownership/spec.md)
  against actual files/catalog, then planned conversion/reconciliation tests and evidence. No
  automatic reuse/ rollback/drop of another author's old disposable catalog or production
  application.

## MIG-3 — Disposable COMMIT and concurrency verification

- Basis: A13/A15, D-11; applies to all tests needing irreversible Avatar history.
- Given a uniquely identified test-run/worker database owned by the harness, apply real migrations
  and execute independent connections and real COMMIT with triggers at RC/RR/Serializable as
  applicable. Invalid states reject deterministically and retries leave history consistent; ordinary
  transactional fixtures or mocks do not establish deferred constraints.
- Cleanup removes only that verified disposable database. No trigger suppression or DROP/TRUNCATE
  against shared developer/test data. Without verified isolation/privileges report BLOCKED, not a
  substitute successful mock. A required full-gate outage also invokes PROC-4.
- Check harness identity/ownership guards and actual creation/transactions/cleanup evidence. Full
  new concrete isolated acceptance is planned; existing concurrency tests need applicability review.

## MIG-4 — Avatar cutover barrier and forward recovery

- Basis: A11/A12/A15, D-9/D-10; P12b depends on P9/P10a/P10b/P11b.
- After all actual Avatar/Group consumers, data and relevant background writers are reconciled and
  controlled, activate legacy write prevention in isolation. Actual ordinary application role cannot
  INSERT/UPDATE/DELETE/TRUNCATE legacy ownership; necessary historical reads may remain.
- Prefer effective role privileges with separate owner/maintenance roles. If the actual role
  topology cannot enforce this, only the narrowly authorized named rejecting trigger is allowed. No
  barrier before required backfill/writer migration, no automatic old-table drop, no post-cutover
  legacy authority fallback. Forward-only recovery preserves history. Unresolved Group semantics
  blocks this cutover, not P10a, P11a or P12a.
- Check real role privileges and four write verbs, reconciliation and failure/recovery drill;
  comprehensive barrier/runbook execution is planned. No production cutover, physical Avatar/history
  deletion or assumed PII retention decision is authorized.
