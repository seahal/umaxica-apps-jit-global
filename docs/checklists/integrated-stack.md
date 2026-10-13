# Integrated stack acceptance index

This is the independent investigation entry point for the approved UMAXICA stack integration: opaque
identifiers, organization-owned Avatars, authentication phase integrity, Email observability, and
realm-separated contact identifiers/OTP/dead history. The domain criteria below state what must hold
and how to judge it; they are neither a progress log nor a new source of business-policy authority.
They preserve the user-approved contracts and applicable ADRs. Existing code never weakens them.

Luna's single executable instruction was `nine.md` in the repository root; it was removed from the
working tree after that delivery was accepted and remains in Git history. An investigator can start
here without that prompt or chat: the domain criteria retain the expectations, exceptions, sources
and inspection methods. One-time procedure/migration criteria live in the owning change document,
not in permanent behavior checkboxes. This index is a crosswalk for this accepted change, not a
global requirement registry, new harness, DSL or test runner.

## Domain and process owners

| Owner                                                                                   | Stable local IDs           | Scope                                                                                             |
| --------------------------------------------------------------------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------- |
| [Persistent identifiers](identifier-contracts.md)                                       | ID-1–ID-8                  | PK, classification, generation, permanence, collision, indexes, external compatibility and guards |
| [Contact identifiers](contact-identifiers.md)                                           | CONTACT-1–CONTACT-9        | Six realm/channel policies, keys, proof, live uniqueness and internal dead history                |
| [Authentication flow integrity](authentication-flow-integrity.md)                       | FLOW-1–FLOW-6              | HTTP instance/phase admission, terminality, races, response and audit                             |
| [Avatar ownership](avatar-ownership.md)                                                 | AV-1–AV-9                  | Concrete temporal authority, four transfers, registry, Grants, Groups and deferral                |
| [Email observability](email-observability.md)                                           | MAIL-1–MAIL-6              | Filtering, standard delivery, pre-export control, collector and read-only configuration           |
| [Delivery and transition criteria](../../specs/integrated-stack-delivery/acceptance.md) | PROC-1–PROC-6, MIG-1–MIG-4 | Worktree/authority, TDD/gates/holds, documents/commits, isolated migrations/cutover               |

Keep existing AUTH-_, SESSION-_ and AUTHZ-* IDs in their functional checklists intact. At editorial
inspection, authentication.md, session-management.md and authorization.md existed as another
contributor's untracked work; this document commit does not claim to persist those files. Their
accepted underlying authority remains independently accessible in the tracked
[authentication boundary](../../.agents/harnesses/rules/generic/authentication-boundaries.mdc),
[root-login ADR](../../adr/root-login-establishment-boundary.md),
[Base/Auth ADR](../../adr/base-auth-ceremony-and-seven-rp-boundary.md) and
[Action Policy conventions](../security/action-policy-conventions.md). The flow criteria specialize
existing browser-binding requirements without renumbering or replacing the broader criteria. Luna
must update planned references when actual checks are implemented; do not invent missing paths.

## Independent investigation

1. Identify repository, branch, full HEAD, staged/unstaged/untracked changes and precise scope.
   Treat dirty code as part of the investigated state. Read root AGENTS and selected rules. A
   document-only commit is not a reproducible snapshot of another contributor's uncommitted
   implementation.
2. Read the applicable domain IDs and linked approved sources. Use source/surface/actor/operation
   scope to decide applicability. Where an older spec records rejected options, apply the explicit
   approved decision preserved in these criteria; record any remaining material conflict.
3. Inspect current producers, consumers, actual tests, configuration and relevant DB enforcement.
   Start from the listed real test paths, then confirm which scenarios they actually cover. A file's
   existence, historical checkbox or implementer's self-report is not evidence of acceptance.
4. Check each existing evidence record's full revision, dirty scope, environment, command and
   coverage. Old PASS applies only there; source/test changes and different configuration may
   require reruns.
5. Run necessary authorized local checks with synthetic data; record a criterion-specific
   disposition and cited observation. No production access, real secrets, external sends or
   destructive shared-DB operations are authorized here. Inspect commands for DB preparation/export
   side effects first.
6. Report behavioral and procedural acceptance separately, preserving incomplete subconditions.
   Static inspection cannot prove concurrency, deferred real COMMIT, effective runtime mounts or
   emitted export boundaries. Missing run chronology cannot prove past Red/Green or full-gate
   cadence.

Use existing result semantics when the owning spec defines them; otherwise use this minimal
vocabulary in a revision-scoped evidence record, never permanent checkmarks in these definitions:

| Result         | Meaning                                                                                |
| -------------- | -------------------------------------------------------------------------------------- |
| PASS           | All applicable subconditions in the stated scope have sufficient current observations. |
| FAIL           | Observed behavior contradicts an applicable criterion; cite input/result and scope.    |
| PARTIAL        | Some identified subconditions have evidence; list missing or failing parts explicitly. |
| BLOCKED        | Required decision, permission, safe isolation or environment prevents a named check.   |
| NOT_RUN        | Applicable check has not been run; do not imply a reason or success not established.   |
| NOT_APPLICABLE | Approved contract excludes this particular scope; cite its specification basis.        |

Unimplemented, inaccessible or difficult is never NOT_APPLICABLE. A useful result row is:
`qualified criterion ID | realm/operation | result | observed fact | command/test/evidence | limitation`.
Results go in [evidence](../../evidence/), with full code HEAD and relevant uncommitted state under
[root evidence rules](../../AGENTS.md). Evidence defines no future guarantee. Definitions have no
current PASS by default, and this editorial work performs no independent application acceptance.

## Requirement crosswalk

Original namespaces retain their meaning: M is integration/execution instruction (01–10), I
identifier implementation (01–14), A Avatar authorization (00–16), F grouped authentication
hardening (01–12), O observability (00–13), E contact/OTP/history (01–20). Each grouped range
includes every integer in that range. IDs below point to definitions in the owner table, not claims
of implemented tests. Behavior and process are separate columns. Accepted existing behavior stays
covered; absence of an implementation is not removal of a requirement.

| Source requirement | Domain criteria / observable subject                         | Procedure or scoped disposition                                                         |
| ------------------ | ------------------------------------------------------------ | --------------------------------------------------------------------------------------- |
| M01–M03            | All five owner documents; observed versus intended contracts | PROC-1/2; single implementation prompt retained                                         |
| M04–M05            | No new domain behavior                                       | PROC-3/4; both full suites throughout                                                   |
| M06–M08            | No new domain behavior                                       | PROC-1/2/4/5; decision scope, dependencies, traceability                                |
| M09–M10            | All owner criteria                                           | PROC-5/6; complete instruction and critical review                                      |
| I01–I02            | ID-1–ID-8 scope preserved                                    | PROC-1/2; security/continuity/consistency judgment                                      |
| I03–I05            | ID-1/2/3/4/6/7                                               | PROC-2; external exceptions are scoped, not new PK exceptions                           |
| I06–I08            | ID-2/3/4/5/6/7                                               | PROC-3; distinct generation/storage/legacy acceptance                                   |
| I09–I11            | ID-1/3/6/7                                                   | MIG-1; no unapproved destructive migration                                              |
| I12–I14            | ID-8 and regression for ID-1–ID-7                            | PROC-3/5/6, MIG-1; current evidence required                                            |
| A00/A02            | AV-1 local target                                            | PROC-1, MIG-2; old six-untracked-file snapshot replaced by actual status                |
| A01/A05            | AV-1/2                                                       | MIG-3; organization-only temporal persistence                                           |
| A03                | AV-8                                                         | P10b/MIG-4 held only if Group meaning lacks authority                                   |
| A04                | AV-2/3                                                       | PROC-2, MIG-2/3; narrow trigger/counter approval                                        |
| A06                | AV-7/8                                                       | P10a independent; Group cutover still requires P10b                                     |
| A07                | AV-9                                                         | P11b; personal-attribute erasure policy held, physical Avatar/history deletion excluded |
| A08/A09            | AV-4/5                                                       | Registry gap rejected; keyless additive transition explicit                             |
| A10                | AV-5/6/7/8                                                   | MIG-4 waits for all actual Grant/Group writers                                          |
| A11/A12            | AV-1/2 remain invariant                                      | MIG-2/4; operational backfill and post-verification barrier, no production cutover      |
| A13                | AV-2/3/4/6 dynamic proof                                     | MIG-3; isolated COMMIT mandatory, no shared cleanup                                     |
| A14–A16            | AV-1–AV-9                                                    | PROC-1–PROC-6, MIG-2–MIG-4; English scoped final report                                 |
| F01                | FLOW-1                                                       | PROC-1/2; current ceremony inventory                                                    |
| F02                | FLOW-2/3                                                     | Legal reload/advance/cancel/callback retained                                           |
| F03                | FLOW-2/3                                                     | Safe refusal versus unsafe HALT=930                                                     |
| F04                | FLOW-3/5                                                     | Absorbing terminal and committed work retained                                          |
| F05                | FLOW-4                                                       | No binding substitution or purpose reuse                                                |
| F06                | FLOW-1/4                                                     | Explicit restart, no forced uniform principal timing                                    |
| F07                | FLOW-3/5                                                     | PROC-3; actual race and side-effect proof                                               |
| F08                | FLOW-2/3/6                                                   | Safe response/no-store/durable audit                                                    |
| F09                | FLOW-6                                                       | PROC-5; current docs/diagrams, historical UML by ownership                              |
| F10                | FLOW-1–FLOW-6 regression coverage                            | PROC-3/4; old full-suite ban superseded by C01                                          |
| F11                | FLOW-2/3                                                     | PROC-2, MIG-1; minimal additive references/resourceful routes                           |
| F12                | FLOW-1–FLOW-6                                                | PROC-5/6; report actual full runs, obsolete non-run claim retired                       |
| O00/O01            | MAIL-1/3                                                     | PROC-1; installed source/options reconfirmed                                            |
| O02–O04            | MAIL-2/3                                                     | P1a/P1b primary controls precede Email proof diagnostics                                |
| O05–O08            | MAIL-2/4/5                                                   | Static collector/mount and dynamic remount separately assessed                          |
| O09/O10            | MAIL-6                                                       | Sentry/live/production excluded; future deployment criteria deferred                    |
| O11–O13            | MAIL-1–MAIL-6                                                | PROC-3/5/6; direct setup checks, no setup suite cases                                   |
| E01–E04            | CONTACT-1/6                                                  | Shared stateful OTP policy superseded                                                   |
| E05/E06            | CONTACT-4/5                                                  | Distinct fresh consumption/original receipt, Step-Up separate                           |
| E07/E08            | CONTACT-2/3                                                  | PROC-2; scoped key maintenance, no global fallback                                      |
| E09                | CONTACT-6                                                    | Real six-model uniqueness/race tests                                                    |
| E10–E13            | CONTACT-7/8                                                  | MIG-1; no dead namespace reservation or global matching                                 |
| E14–E16            | CONTACT-9                                                    | Personal-data/hold/legal policy separate from product UI                                |
| E17/E18            | CONTACT-1–CONTACT-9                                          | PROC-3/5; old shared-policy recommendation superseded                                   |
| E19/E20            | CONTACT-1–CONTACT-9                                          | PROC-1/3/4/6, MIG-1; no broader reset/remote authority                                  |

## Approved-decision and exception crosswalk

This is navigation to retained interpretations, not a second decision-making authority. Exact
C01–C15 and the business contracts in Sections 5–9 are retained in the committed instruction; the
operational mount example is corrected for shared-source labeling. All observable consequences
needed for investigation are in the criteria above.

| Decision | Criteria and retained effect                                                                      |
| -------- | ------------------------------------------------------------------------------------------------- |
| D-1      | PROC-1/MIG-2: actual checkout, no redirection to historical branch/repository.                    |
| D-2      | AV-8/MIG-4: Group meaning is conditional, never guessed owner authority.                          |
| D-3/D-4  | AV-3/PROC-2/MIG-3: minimal approved integrity DDL/counter and real concurrency proof.             |
| D-5      | AV-7: explicit N:M Grants, not renamed exclusive Bindings.                                        |
| D-6      | AV-9: observable idempotent deferral; privacy policy remains unresolved.                          |
| D-7      | AV-4: no cross-family idempotency/cardinality gap.                                                |
| D-8      | AV-5: canonical UUID v4/v7 keys, scoped additive legacy path.                                     |
| D-9      | MIG-2: separate operational backfill, preserve known facts and stop ambiguous rows.               |
| D-10     | MIG-4: verified-cutover DB write barrier, no automatic old-table removal.                         |
| D-11     | MIG-3: isolated committed-transaction tests and safe cleanup.                                     |
| C01      | PROC-3/4: full-suite ban replaced by recurring Rails and Vitest gates.                            |
| C02      | MIG-1/2/4: E waiver never authorizes shared resets or Avatar/public-ID loss.                      |
| C03      | PROC-1/MIG-2: draft provenance/status/applied state rechecked.                                    |
| C04      | AV-4/5/7, MIG-3: rejected Avatar proposals are not acceptance alternatives.                       |
| C05      | ID-3/7, AV-5, CONTACT-4: semantic ID exceptions and binding preservation.                         |
| C06      | ID-3/AV-1: concrete public cross-DB references; no fictional distributed FK.                      |
| C07      | FLOW-2/3: strict request contract overrides generic redirect/reentry recovery.                    |
| C08      | CONTACT-4/FLOW-5: original-operation receipt is not fresh consume or stale-phase permission.      |
| C09      | MAIL-2/4/5, PROC-3: direct setup verification without setup-only unit tests.                      |
| C10      | MAIL-2/6: internal framework payload versus exported/logged data; broad closure remains separate. |
| C11      | PROC-2/AV-3: no expanded trigger/raw-SQL authority.                                               |
| C12      | ID-7/MIG-1, CONTACT-4/5: bounded explicit I/A transitions, no E legacy fallback.                  |
| C13      | AV-2/9, CONTACT-7/9: ownership history versus irreversible dead history.                          |
| C14      | MAIL-6/PROC-1: separate E/F authority does not expand observability scope.                        |
| C15      | AV-8/MIG-4: Group conversion decision held only in its real dependency branch.                    |

## Maintenance and discovery

Keep local IDs stable. Replace/merge/retire only for an approved contract change with reason and a
successor reference, not a failing test. Add actual test/procedure/evidence links as Luna
implements; keep planned/not-yet-implemented labels until those references exist. Do not copy test
bodies or a second full implementation spec here. The existing knowledge checker discovers
`docs/checklists/*.md`; this index is also directly linked from the committed nine.md. Existing
unrelated index/checklist work remains with its author and is not silently included in this document
commit.
