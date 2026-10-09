# UMAXICA STACK — Integrated Implementation Instruction

Prepared for Codex Luna 5.6 Max. This is one self-contained implementation instruction, not a
request for another audit or a series of prompts requiring separate approval. Implement the
authorized local changes below, verify them in small increments, and preserve unfinished acceptance
honestly. The preparation and editorial revision of this document did not implement application
changes or run application tests.

Roles are separate: the editor maintains this instruction and durable acceptance definitions; Luna
implements, performs TDD/full verification and maintains their references; a later investigating AI
independently evaluates code, tests and revision-scoped evidence. Luna's self-verification is not
that independent acceptance. Waiting for an investigator's reply is not a routine next-slice
approval gate; existing explicit security-review/owner approvals remain required.

Start acceptance reading at [Integrated stack acceptance](docs/checklists/integrated-stack.md). It
links the permanent domain criteria and change-specific process criteria. This file remains the
single executable implementation instruction; those documents define observable requirements, not
additional prompts or reports of permanent success.

## 1. Outcome, scope, and non-goals

Deliver five coordinated contracts in the currently checked-out Rails/PostgreSQL application:

1. Database-local bigint primary keys and correctly classified, non-secret opaque identifiers.
2. Concrete, temporal organization ownership of Avatars, safe transfers, and explicit access Grants.
3. Server-authoritative authentication flow-instance/phase enforcement.
4. Email secret protection before observability export, with collector defense in depth.
5. Realm-separated Email/Telephone identity, ceremony-owned OTP proof, and dead identifier history.

Complete code, additive migrations where needed, tests, fixtures/seeds, current documentation,
accepted ADR amendments, executable regression guards, and operational procedures. Existing partial
implementations are starting points, not evidence of completed acceptance. Preserve working behavior
and public identities except where an explicit scoped decision below replaces the old contract.

Use only the existing local worktree. Preserve staged, unstaged, untracked, and ignored user work.
Do not create a Git worktree, switch to an older checkout, reset, clean, automatically stash,
discard another contributor's edits, rebase, merge, push, create a PR, or edit GitHub directly.
Local commits are restricted to the editor's or Luna's own document changes under Section 14.1: this
instruction, durable acceptance criteria, necessary minimal document indexes/rules and safe
validation/acceptance evidence. Application code, tests, migrations, dependencies, unrelated
settings and other contributors' changes remain outside commit authority. This exception does not
authorize committing schema changes to silence drift checks. No production deployment, production
data access, production secret changes, external-service configuration changes, or unapproved
destructive operation is authorized. Inspect remote configuration for context without changing it. A
repository-name mismatch is not permission to switch repositories.

Do not redesign unrelated frontend, routing, authentication methods, queue topology, Noticed, SMS
architecture, providers, templates, Rails version/pinning, Sentry, or production infrastructure.
Frontend/API/job/event changes are included only when required by one of these contracts. The
separate Edge repository is not a prerequisite; inspect it only if an actual affected contract
requires it and it is already available, and require explicit scope authorization before external
writes.

## 2. Authority, source register, and resolved conflicts

### 2.1 Source register

The source IDs below refer to the five complete instructions supplied with the integration request.
Their normative content is consolidated in Sections 5–9; the executor does not need the chat text.

| Source | Supplied instruction                                                                  | Internal requirement IDs                      |
| ------ | ------------------------------------------------------------------------------------- | --------------------------------------------- |
| M      | Integrated prompt generation, sections 1–10                                           | M01–M10                                       |
| I      | Identifier design implementation, sections 1–14                                       | I01–I14                                       |
| A      | Avatar Organization Ownership authorization, sections 0–16 and final rule             | A00–A16, D-1–D-11                             |
| F      | Authentication ceremony security hardening                                            | F01–F12, grouped by the named contracts below |
| O      | OTP email observability remediation, sections 0–13 and completion                     | O00–O13                                       |
| E      | Email/Telephone identifiers, OTP, dead history, sections 1–20 and absolute conditions | E01–E20                                       |

Priority: this integration request's explicit decisions and the scoped supplied approvals;
applicable accepted ADRs and current external protocol contracts; accepted open specs and durable
checklists; current explanatory docs; historical plans/research. Resolve scope and explicit
supersession before using dates. Code, schema dumps, tests, and historical reports describe
implementation, not normative authority. A current defect is not a specification. A checked box or
prior green report is not a current test result.

Read root `AGENTS.md` and its Task Rule Index at execution time. Load its selected rules before each
affected slice. In particular, use the Rails, security, fail-fast, data-shape, migration, lifecycle,
controller/routing/surface, session issuance, Concern, testing, static-invariant, ENV, i18n,
observability, replacement, and knowledge-ownership rules in their actual scopes. Do not invent a
second harness location. Repository prose, comments, test names, and final implementation reports
are English; the required Japanese HTTP response is customer-copy localization.

### 2.2 Conflict decisions

| ID  | Competing sources and current evidence                                                                                                                            | Adopted decision, reason, and affected risk                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| C01 | M requires periodic full suites; I/E also require full Rails; F repeatedly forbids them.                                                                          | M explicitly governs this integration and calls delayed full regression the previous failure. Supersede F's suite prohibition. Keep F's small named-file selections for local TDD; run both full suites at the gates in Section 12. The final report must state actual full-suite runs, not repeat F's obsolete non-execution claim.                                                                                                                                                                                                                                                        |
| C02 | I/A preserve data and identities; E says its undeployed identifier data need not remain compatible and permits a reset assumption.                                | E's clean replacement applies only to its Email/Telephone proof/key contract. No dual-read/global-key/HOTP fallback there. It does not authorize resetting the current shared databases or deleting Avatar history, public IDs, unrelated data, or others' work. Rebuild only newly created, verified disposable test databases. Real-data reset/destructive cutover requires a concrete separately approved recovery plan.                                                                                                                                                                 |
| C03 | A reports six untracked migrations at HEAD 809ed576; actual HEAD has six tracked drafts outside Rails discovery.                                                  | Use actual paths and tracking state in Section 3. Do not delete them under the old untracked-file allowance. Complete/rework tracked drafts in scope, preserving useful work; do not restore incomplete files to migration discovery. Revalidate per-database applied versions.                                                                                                                                                                                                                                                                                                             |
| C04 | Avatar spec still proposes Binding-only access, an idempotency gap, required arbitrary-format keys, and shared-DB trigger suppression.                            | A D-5/D-7/D-8/D-11 explicitly reject these proposals. Use separate Grants, one reservation registry, additive UUID v4/v7 client keys, and disposable COMMIT tests. Amend the spec before model/DB changes. No trigger suppression to clean shared data.                                                                                                                                                                                                                                                                                                                                     |
| C05 | I standardizes self-controlled opaque IDs as NanoID; A explicitly specifies UUID idempotency keys; existing OTP ADR/code uses UUID transaction/generation values. | Transfer idempotency UUID is an explicit scoped API contract, not a resource PK. Secrets/protocol-bound values remain excluded. Do not declare all ceremony UUIDs external exceptions: classify each. Self-controlled non-secret ceremony IDs must enter I's migration inventory; preserve existing binding semantics and avoid invalidating issued proof. New generation randomness that is a security capability is classified by entropy/purpose, not name. Existing accepted UUID binding shapes require a documented consumer migration before replacement, not a blind regex rewrite. |
| C06 | I disallows new cross-DB bigint references; A draft discusses Persona/Agent bigint links and ownership-period IDs.                                                | Concrete organization/subject references crossing databases use their existing public identity contracts; local Avatar/period/registry FKs remain bigint. Do not claim remote FK or distributed-transaction guarantees. Existing violating references are migration work, not permanent exceptions.                                                                                                                                                                                                                                                                                         |
| C07 | F adds strict phase refusal; older lifecycle ADRs describe redirect reentry or active conflict preservation.                                                      | Same-phase reload remains valid. A contradictory safe HTTP request returns 409 without workflow mutation; a browser-authorized, attributable active-flow mutation violation halts that original flow, including pre-login ceremonies. Apply only the strict exception, not a lifecycle big-bang rewrite. Update affected ADRs/diagrams with runtime facts.                                                                                                                                                                                                                                  |
| C08 | E requires single-use OTP; accepted local ADR preserves bounded original-operation verification receipts.                                                         | Retain the existing receipt contract: first consumption succeeds once; a still-valid immutable receipt may reconcile only the original authorized pending operation. It is not second consumption, deadline extension, fresh authentication, or permission to submit an old phase. F's phase gate runs before proof/receipt admission.                                                                                                                                                                                                                                                      |
| C09 | O requests configuration contract checks; current root rule forbids Minitest/Vitest subjects that merely construct environments.                                  | Preserve every O acceptance criterion. Test application filtering/export/delivery behavior; execute boot, Compose rendering, Alloy validation and mount checks as direct non-suite checks recorded in evidence. Do not add source-text/setup-only Minitest or Vitest cases. Existing security invariants stay.                                                                                                                                                                                                                                                                              |
| C10 | O's older ADR/plan calls for broader event and production investigation; current O forbids private Rails patches, Sentry changes, live sinks and production work. | Current O defines local remediation scope. Preserve Rails' internal delivery payload semantics; stop raw content entering application logging/export. A framework-internal MIME notification may still exist. Do not claim it was eliminated. Amend ADR/plan to distinguish local acceptance from deferred production/privacy review, without claiming the historical broad remediation gate closed.                                                                                                                                                                                        |
| C11 | A permits narrowly necessary trigger DDL/counters; generic migration rules restrict raw SQL.                                                                      | A D-3/D-4 explicitly authorize only ownership-integrity DDL and necessary concurrency counters, plus D-10's named fallback write barrier. Prefer Rails declarative constraints; document each exception. This is not blanket SQL, backfill, audit-trigger, or identifier-trigger permission. Existing E ADR authorizations remain scoped to their named identifier/proof protections.                                                                                                                                                                                                       |
| C12 | I/A require bounded compatibility; E forbids legacy layers; replacement rule permits explicitly required transitions.                                             | Keep transitions only for named I/A consumers, with owner, validation and exit condition. E's old OTP/global-key paths are retired coherently; no silent fallback anywhere. Preserve applied migration history rather than rewriting it to hide old contracts.                                                                                                                                                                                                                                                                                                                              |
| C13 | A preserves ownership history; E creates history only at irreversible identifier purge.                                                                           | These are different domains. Avatar history is continuous ownership authority and cannot be physically deleted here. Dead identifier history is internal pseudonymous evidence, never live authority; it supports authorized retention/legal deletion. Do not build one generic history mechanism.                                                                                                                                                                                                                                                                                          |
| C14 | O forbids OTP/authentication/SMS changes within observability work; E/F require them.                                                                             | Phase P1 changes only logging/export/configuration. E/F changes happen in their separately authorized later phases with their own acceptance. Their authorization is not scope expansion of P1. Sentry and external/live operations remain excluded globally.                                                                                                                                                                                                                                                                                                                               |
| C15 | Avatar spec recommends deriving Group account context from owner, but describes independent selected-account semantics.                                           | A D-2 is conditional. Preserve the independent meaning until evidence establishes equivalence. No automatic owner derivation, routing redesign, or extra owner authority. Block only this conversion if a genuine domain choice remains.                                                                                                                                                                                                                                                                                                                                                    |

### 2.3 Judgment and bounded unresolved items

Autonomously decide names, local responsibility placement, test partitions, existing-pattern usage,
and reversible implementation details that preserve these contracts. Use security, then business
continuity, then code consistency to choose between admissible alternatives; prefer the smaller,
less coupled, testable, recoverable option. Record the decision and rejected alternative in the
owning spec/ADR, not a new approval ceremony.

Do not invent authentication models, ownership semantics, public contract changes, or irreversible
data policy. Only the following known questions remain evidence-dependent:

- Group account semantics: establish consumers and domain meaning. If distinct concrete
  relationships cannot be selected from existing authority, record the exact alternatives and block
  P10b's Group conversion, not Grants, OTP, observability, or the ownership prototype.
- Avatar personal-data retention: attribute/media/handle erasure or anonymization periods are not
  approved here. Implement deferral and document policy needs; do not delete Avatar/history or
  assume indefinite PII retention.
- Migration/cutover environment and authoritative data mappings: unknown owners/dates stop
  individual rows; unavailable isolated DB privileges invoke the verification hold below, not
  permission to accumulate untested source work.
- Material public API/partition/legacy-ID conflicts discovered by the inventory: state the
  conflicting invariant, concrete consumers, smallest safe alternative, and decision needed. Never
  waive the invariant to mark completion.

Distinguish three execution states:

- **Decision hold:** only the dependent scope is held. An independent phase may proceed if all of
  its required tests and shared-worktree full gates are executable and current.
- **Verification hold:** Gate 0 or a required full gate is unavailable or unfinished. Stop new
  feature edits across this shared worktree, including otherwise independent branches. Continue
  read-only investigation, acceptance-document maintenance, already authorized environment recovery
  and preparation to verify the last slice. Recording NOT_RUN/BLOCKED does not authorize more code.
- **New regression:** tests ran and exposed a new failure. Stop new feature edits and follow Gate 3;
  repair the common cause, focused tests and both full suites before advancing.

There is no source-only prototype exception in this revised execution plan. Existing unverified
prototype work is preserved and recorded, but cannot be a foundation for further feature edits.
Resume only after actual intended Red/Green (or an existing-behavior regression check where no new
behavior is needed) and required full gates. A document or environment-recovery edit is not a Green
iteration. No extra implementation prompt is required for an unblocked phase.

## 3. Preparation snapshot and mandatory startup investigation

### 3.1 Observed during preparation

All values, paths, versions and source observations in this section describe the original
preparation, not the latest checkout. Reconfirm them at implementation startup. The editorial
revision does not refresh runtime facts or promote old test results to current evidence.

Snapshot: 2026-10-09, `/home/global/workspace`, branch `feature`, HEAD
`13f27059c874e607bbe246cdf532b832691012fa`, origin `https://github.com/seahal/umaxica-app-jit`. One
`git status --porcelain=v1` observation counted 84 changed/untracked paths. Rules, skills, README,
CI, docs, research, specs and two test files had pre-existing edits; this is a moving worktree. Do
not use that count as a cleanup target.

Ruby `4.0.7`, Bundler `4.0.22`, and Bun `1.4.0` commands ran successfully. `Gemfile.lock` records
Rails `8.2.0.alpha`, Nanoid `2.0.0`, Argon2 `2.3.3`, and OTel ActionMailer `0.8.1`. `bundle show`
located the installed ActionMailer instrumentation and Rails checkout; their relevant source was
inspected. Compose pins Alloy `v1.19.2`. No DB connection, migration state, test suite, production
topology, runtime mount, exporter, or live delivery was verified during preparation. The
managed-environment status tool was unavailable. These limitations are not successful checks.

| Area               | Observed source evidence                                                                                                                                                                                                                          | Current disposition                                                                                                                        |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Opaque IDs         | `app/models/concerns/public_id.rb` calls `Nanoid.generate(size: 21)` in create callbacks and validates maximum 21, not standard storage capacity 25; it accepts an already supplied value.                                                        | Partial; no complete generator/DB/classification/collision acceptance established.                                                         |
| Avatar             | `AvatarOwnershipPeriod`/`AvatarOwnershipTransfer` still use surface-discriminated legacy references; the ownership spec remains paused with rejected proposals.                                                                                   | Legacy implementation and incomplete drafts; approved replacement is unimplemented in these inspected paths.                               |
| Flow enforcement   | `SignFlowBindingCodec` supports only app/com sign-up and signs kind/surface/public ID, without phase/version/expiry. `SignUpPhaseViolationEnforcer` evaluates under a lock, releases it, then calls termination.                                  | Partial. Recheck endpoint phase binding and race behavior; code shape suggests an atomicity question, not a proven exploit.                |
| Session issuance   | `AuthenticationBase#commit_login_session!` and `lock_sign_in_flow_for_issuance!` retain flow locking, actor/token/state checks. All three Ticket dumps contain unique non-null `token_id` indexes.                                                | Existing protection to retain and test. Index uniqueness is not alone proof of one-flow/one-session issuance.                              |
| HALTED             | Concrete sign-in state and sign-up status classes already define 930 and terminal mappings; an app sign-up integration test exists.                                                                                                               | Implemented in some paths, unverified here. Older docs claiming HALTED is absent are stale candidates.                                     |
| OTP separation     | Independent `EmailOtpPolicy` and `TelephoneOtpPolicy` exist; both still expose identifier HOTP storage/initialization methods. Telephone schemas contain `otp_last_sent_at`.                                                                      | Partial; remove remaining proof responsibility only after caller inventory. Do not recreate an already removed OtpLockable implementation. |
| Realm keys/history | Realm provider, fingerprint verifier, six history models and contract/purge/concurrency tests exist. ADR records six-key/keyring and extensive ceremony work.                                                                                     | Implemented portions, incomplete verification. Historical pass counts are not this execution's evidence.                                   |
| Observability      | Filter initializer still has ambiguous short Symbols; OTel registers ActionMailer without transforms; common application config search found no mailer logger policy. Alloy redacts URL/auth/token attributes but lacks explicit mail attributes. | Required remediation remains in the inspected configuration.                                                                               |
| Devcontainer       | Read-only `.github`, `bin`, `.devcontainer` mounts exist; no `podman/alloy` directory overlay was found.                                                                                                                                          | Required mount change remains; effective runtime mount unverified.                                                                         |

The source review was targeted, not an exhaustive audit of every caller/table/ADR. All supplied
instructions were integrated; remaining local inspection is explicitly required below. Do not
present uninspected rows or historical source reports as current verified implementation.

### 3.2 Exact Avatar draft gate

All six files below were read completely and are **tracked** under
`specs/avatar-organization-ownership/migration-drafts/`, outside migration discovery:

| File                                                                      | Observed content                                                               | Required disposition                                                                                                                                                          |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `20261009180016_add_avatar_ownership_write_lock_counters.rb`              | Adds `btree_gist` and bigint counters to Avatar/Group.                         | Preserve/review; prove counter necessity and extension reversal ownership.                                                                                                    |
| `20261009180021_create_avatar_concrete_ownership_periods.rb`              | Concrete period tables, exclusions, functions/triggers, Binding-period fields. | Preserve useful integrity work; replace rejected Binding-as-Grant design, bound remote IDs, audit concurrency/initial boundary/down ordering and existing-table index safety. |
| `20261009180026_create_avatar_group_concrete_ownership_periods.rb`        | Empty `create_table` body.                                                     | Incomplete generator stub, not a no-op: it would create a table. Keep quarantined until correct concrete design is ready.                                                     |
| `20261009180032_create_avatar_concrete_ownership_transfers.rb`            | Empty `create_table` body.                                                     | Replace with approved registry/four-detail design before discovery.                                                                                                           |
| `20261009180037_validate_avatar_binding_ownership_period_foreign_keys.rb` | Empty `change`.                                                                | Reconcile obsolete Binding proposal; do not apply an empty migration.                                                                                                         |
| `20261009180042_create_avatar_purge_deferrals.rb`                         | Empty `create_table` body.                                                     | Complete only if existing deferral facilities are insufficient.                                                                                                               |

The current spec reports a previous disposable catalog applied the counter migration before failing
on a non-concurrent binding index. That is historical evidence, not this session's DB observation.
Do not infer that these versions have never run anywhere. Never edit an applied migration. If any
draft version has entered a retained database's history, use forward repair for that database and a
fresh disposable catalog for clean rebuild acceptance. Do not roll back or drop someone else's old
test catalog. No schema-loading, preparation, migrate task, or implicit test-driven migration may
run until all six are re-audited and their discovery/application status is safe.

### 3.3 Startup checklist

Before production-code edits:

1. Record `pwd`, `git remote -v`, `git branch --show-current`, `git rev-parse HEAD`,
   `git status --short`, and staged/unstaged ownership summaries. Inspect any configured URL
   redirects without dumping credentials. Preserve the initial diff and identify overlapping
   collaborator edits without stashing or copying secret files.
2. Read `README.md`, root rules, `specs/README.md`, knowledge architecture, and current owning
   specs. Reconcile `specs/avatar-organization-ownership/spec.md` with D-1–D-11 before its model/DB
   changes. Preserve historical provenance, explicitly superseding the rejected options.
3. Inspect `package.json`, Bun lockfile, Gemfile/lock, `config/ci.rb`, Rails test entrypoints, test
   DB preparation behavior, and actual environment readiness. Do not print `.env`, credentials,
   connection passwords, secret bindings, or runtime environment dumps.
4. Map configured database roles, writers/readers, ownership, migration paths and schema formats.
   Identify a test-only connection before any DB write. Read-only catalog/aggregate queries must not
   call `nextval`, `setval`, apply DDL, or expose PII. Do not treat EXPLAIN ANALYZE as read-only.
5. Audit the six drafts and all pending relevant migrations before allowing Rails test preparation.
   Do not run `bin/setup`, global `db:prepare`, or `bin/ci` blindly: they may mutate databases.
6. Before P2 edits, map each required DB invariant (especially permanent-identifier immutability) to
   current enforcement, the exact accepted ADR/approval scope, and whether an already authorized
   mechanism suffices. Read `adr/database-trigger-usage-boundary.md`, the migration rules and C11.
   An application callback does not establish a DB guarantee. If extra trigger/raw-SQL permission is
   needed, hold that invariant's implementation, name the smallest missing decision and retain
   unrelated verified work. This inventory grants no new SQL/trigger or destructive authority.
7. Produce the compact inventories in Section 4, then run Gate 0. If required verification cannot
   run or finish, record the exact failure and follow the verification hold in Section 2.3. Do not
   start another feature or source-only prototype to work around the gate.

## 4. Required inventories and traceability

Keep results in the existing owning specs/plans and actual-result evidence, not `.agents/goals/` or
an invented governance framework. The following inventories are finite implementation prerequisites,
not independent large audits:

- **Identifier inventory:** each actual app-owned table including tables without loaded models;
  database, owner, SQL PK type/width, sequence/identity, candidate ID columns, eight semantic roles
  from Section 5, authority/format/length, null/blank/default, uniqueness scope, immutable fields,
  index definition/state/collation, producer, readers, all writers, API/job/event exposure, cross-DB
  consumers, and exception category. Include status/catalog tables and framework ownership.
  Explicitly inspect the current PublicId concern and dispersed generation, Operator human-entered
  codes, Preference/Passkey null/default/length/index contracts, Passkey external_id/public_id/
  webauthn_id roles, Token/TokenUsage/DeviceSession public_id/sid/jti/family values, and Ceremony/
  Chronicle self-generated UUIDs. These are candidates to confirm, not pre-established defects.
- **Ceremony matrix:** surface and credential family; entry route/verb; authoritative object; flow
  creation and principal-discovery time; Rails session locator versus DB state; one-time artifacts;
  phase checker; GET/mutation/reload/multi-tab/replay behavior; issuance/finalization point; cleanup
  and audit ownership. Cover sign-in/up Email, discoverable passkey, Google/Apple, org normal Entra
  and emergency, MFA, capacity child, checkpoint, selector, and Auth/Base/OIDC handoff where
  present. Unsupported combinations stay unsupported; do not invent methods to fill the table.
- **OTP matrix:** six concrete identifiers, purposes and real issuer/verifier/resend/finalizer/
  notifier/worker callers; current proof storage, attempt budget, binding, deadline, consumption,
  retained receipt and cleanup. Separate Email from Telephone and Step-Up from ordinary OTP.
- **Avatar matrix:** all four transfer directions, concrete actor/organization families, current
  Binding purpose, management versus use permissions, Group account readers, provisioning and
  retention paths; local versus remote database references and lock order.
- **Observability matrix:** app/com/org mailers, interceptor, Noticed/jobs, filter authority, Rails
  subscribers, OTel transforms/exporter/scrubber, Alloy routes and mounts. Use synthetic secrets
  only.
- **ARE/retention matrix:** current encrypted attributes and their domain owner, keyrings/rotation;
  six histories and all raw/bulk/ordinary purge paths, legal holds and cross-database cleanup.

For every requirement maintain: source ID, adopted/merged/changed/retired/held disposition, reason,
current implementation category, phase, public acceptance test/check, and evidence pointer.
Categories are verified in this execution, implemented but unverified, partial,
accepted/unimplemented, obsolete, conflicting, retired, or decision-dependent. Do not remove an
implemented requirement from regression coverage. Preserve unique exceptions when merging duplicate
requirements.

### 4.1 Requirement-to-phase coverage

The grouped rows below cover every numbered source section. Each row's acceptance is expanded in
Sections 5–9 and its checks in Sections 10–13. The permanent
[requirement crosswalk](docs/checklists/integrated-stack.md#requirement-crosswalk) maps every source
ID to domain criteria or process acceptance, including held/excluded/superseded scopes. All are
adopted/merged unless the disposition states otherwise. Existing code does not change that
disposition. P10/P11/P12 remain parent IDs; their independently assessed child phases below replace
the old combined execution units.

| Requirement       | Acceptance / disposition                                                                                                                 | Phase and verification                                                    |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| M01–M03           | One executable plan, honest inventory and reasoned conflict decisions; implementation instructions inside sources apply to the executor. | P0; inventory and C01–C15 review.                                         |
| M04–M05           | Small TDD and full regression before accumulation.                                                                                       | Every phase; Gates 0–4.                                                   |
| M06–M08           | Explicit judgment boundaries, dependencies, resumable progress and no lost exceptions.                                                   | Sections 2/4/10/14; acceptance ledger.                                    |
| M09–M10           | All eleven requested output components and critical self-review.                                                                         | This document; Section 15.                                                |
| I01–I02           | Actual checkout, protected worktree, bounded local research and security/continuity/consistency decisions.                               | P0, all phases.                                                           |
| I03–I05           | bigint PK, NanoID21/varchar25, B-tree, role-aware scoped uniqueness, documented genuine external exceptions.                             | P2/P6; DB and public-boundary tests.                                      |
| I06–I08           | Single generator mechanism, explicit compatibility, DB immutability, bounded correct collision retry, index/collation correctness.       | P2/P6; create/bulk/direct-SQL/collision tests.                            |
| I09–I11           | Safe PK/sequence/partition/order, protocol separation and minimal staged migration without lost references.                              | P6/P12a; isolated rebuild/migration/consumer checks.                      |
| I12–I14           | Boundary tests, executable guards, ADR/guidelines, evidence and truthful complete report.                                                | P2–P13; Gates 1–4.                                                        |
| A00/A02, D-1      | Actual checkout and six-draft gate, superseding the old 77-path/untracked snapshot.                                                      | P0; exact file/version disposition.                                       |
| A01/A05           | Organization-only, concrete temporal uninterrupted ownership; all identities and transfer directions preserved.                          | P7/P8; direct SQL and real COMMIT tests.                                  |
| A03, D-2          | Distinguish Group account meaning; legacy fields are never alternative owner authority.                                                  | P10b/P12b; consumer matrix; conditional conversion may be held.           |
| A04, D-3/D-4      | Narrow trigger/counter approval, actual attachments, explicit SQLSTATE and MVCC safety.                                                  | P7; inventory plus concurrent transactions.                               |
| A06, D-5          | Explicit N:M generation-bound Grants, separate Bindings, no revival after O1→O2→O1.                                                      | P10a; authorization tests.                                                |
| A07, D-6          | Observable idempotent purge deferral; Avatar/history physical deletion excluded; privacy policy held.                                    | P11b; repeated-job tests.                                                 |
| A08/A09, D-7/D-8  | Registry prevents cross-family pending/key duplicates; canonical UUID v4/v7 keys with bounded keyless compatibility.                     | P9; concurrent registry/cardinality/replay/API tests.                     |
| A10               | Request/Accept/Cancel, five-day validity, revalidated authority/generation, single locked DB instant, atomic local transfer.             | P9/P10a/P10b; four-family transfer and expiry tests.                      |
| A11/A12, D-9/D-10 | Independent idempotent operational backfill and verified-cutover write barrier; no automatic legacy removal.                             | P12b; dry-run/reconciliation/role and trigger tests.                      |
| A13, D-11         | Isolated real COMMIT/concurrency/rebuild, no destructive shared cleanup.                                                                 | P7 onward; RC/RR/Serializable tests.                                      |
| A14–A16           | Staged delivery and full persistence/concurrency/auth/compatibility/migration report.                                                    | P0/P7–P13; final acceptance.                                              |
| F01               | Current ceremony/surface/route/state investigation and preserved session authority.                                                      | P0/P4; inventory, current issuance tests.                                 |
| F02               | Same-phase reload/advance/cancel/callback remain legal; strict contradictory requests.                                                   | P4/P5; HTTP matrix.                                                       |
| F03               | Safe-method 409/no mutation versus attributable unsafe-method HALT=930.                                                                  | P4/P5; HTTP/state/audit tests.                                            |
| F04               | Absorbing terminal state, no artifact/session resurrection or destruction of committed success.                                          | P4/P5; replay/cleanup tests.                                              |
| F05               | Server-verifiable instance and phase/generation binding, original A isolated from new B.                                                 | P4/P5; tampering/cross-surface/A→B tests.                                 |
| F06               | Explicit new-flow start, no GET workflow mutation, no forced universal sign-in flow creation.                                            | P4/P5; family-specific entry tests.                                       |
| F07               | Lock/reload/check/transition, two-tab races and side-effect suppression.                                                                 | P4/P5; real concurrency, counters/delivery assertions.                    |
| F08               | Uniform plain-text refusal, no-store and safe durable halt audit.                                                                        | P4/P5; response and audit tests.                                          |
| F09               | ADR/security docs/Mermaid/runtime agreement, historical UML changed only if authoritative.                                               | P4/P5/P13; diagram/inventory review.                                      |
| F10               | Public-interface TDD, EP/BVA, focused selections, preserve test_helper.                                                                  | P4/P5; Gate 1; full-suite ban changed by C01.                             |
| F11               | Additive reference data only if absent; resourceful existing routes and no GET mutation.                                                 | P4/P5; migration/routes checks.                                           |
| F12               | Report concrete model/binding/terminal/artifact/issuance evidence and exact commands/counts.                                             | P13; full-suite non-run sentence retired by C01.                          |
| O00–O01           | Installed API inventory; sensitive and non-sensitive filter contracts.                                                                   | P0/P1a; filter behavior and source inspection.                            |
| O02–O04           | Shared mailer logger nil, formal allowlist transforms, retained scrubbers and standard delivery.                                         | P1b; boot and synthetic delivery/export tests.                            |
| O05–O08           | Alloy secondary redaction, directory read-only mount, startup loading, named Rails.event subscriber only.                                | P1c; direct config validation/evidence; setup-test method changed by C09. |
| O09–O10           | Sentry unchanged; no live verification or production topology; future acceptance recorded.                                               | P1/P13; diff and docs.                                                    |
| O11–O13           | Existing ADR/plan updates, TDD and narrow scope; delivery/retry/interceptor retained.                                                    | P1; local acceptance distinct from historic broader closure.              |
| E01–E04           | Six models, separate channel stateful policy, persistent failed attempts, explicit Telephone timestamp.                                  | P3a; six-model boundaries.                                                |
| E05–E06           | Ceremony-owned keyed random proof, full binding, atomic single-use; Step-Up separate.                                                    | P3b–P3d; cross-flow/race/delivery tests.                                  |
| E07–E08           | Six live HMAC keys and realm ARE keyrings; no old-key fallback, rotation retained.                                                       | P3a; crypto/normalization/boot/rotation checks.                           |
| E09               | DB live uniqueness and delete/create/reuse race invariants in all realms.                                                                | P3e/P11a; real PostgreSQL tests.                                          |
| E10–E16           | Six minimal dead histories at physical purge only; keyed Argon2id, no global lookup, internal pseudonymous data.                         | P11a; schema/purge/visibility/retention tests.                            |
| E17–E18           | Superseded shared policy documented and complete public-boundary security coverage.                                                      | P3/P11a; ADR/docs/EP/BVA.                                                 |
| E19–E20           | Focused then full verification, no new global identity/stateful abstraction or remote/production actions.                                | Gates 0–4/P13.                                                            |

## 5. Identifier contract (I)

### 5.1 Types, meanings, and exceptions

- Every UMAXICA-owned ordinary persistent table, including reference/status/catalog tables, uses a
  single bigint PK named `id`. Actual bigint identity/bigserial qualifies. Fixed-ID catalogs need
  not have sequences. Framework/extension-owned tables retain their dependency contract; record
  ownership rather than relabeling application tables as external.
- Internal PKs stay database-local. New URL/API/external/cross-DB references use the appropriate
  public identity, not numeric PKs. Check signed references, cookies, cursors, jobs, logs, caches,
  events, object-store references and JSON/JavaScript numeric precision. Signing/Base64 is not
  encryption or authorization.
- Self-controlled, non-secret opaque identifiers use NanoID with new issuance length 21, bounded
  string/varchar storage normally 25, cryptographic randomness and the library's actual alphabet. No
  binary/char conversion, chronology, region, tenant or sequential business meaning. Apply by role,
  not `public_id` spelling; no gratuitous new ID columns or wholesale renames.
- Identify resources by logical issuing domain + resource kind + identifier. If the entrypoint/model
  fixes the first two, do not duplicate them in columns. Generic jobs/events/cache keys/resolvers
  must preserve context. Physical DB/host names, region, language and current organization are not
  issuer defaults. Allowlist concrete kinds and validated issuers; never constantize arbitrary
  input.
- Classify each candidate as (1) owned permanent resource ID, (2) reference, (3) shared
  session/family/ correlation ID, (4) result created on success, (5) expiring current-token/state
  relation, (6) externally governed value, (7) human-entered code, or (8) secret/protocol value.
- Owned permanent IDs require NOT NULL, nonblank, correct-scope UNIQUE across logical deletion and
  database-enforced immutability. References/shared IDs do not automatically get single-column
  uniqueness. Results remain NULL until they exist; conditional requiredness/immutability follows
  their lifecycle. Current-token pointers may legitimately change. Do not conflate these roles.
- Preserve protocol/provider identifiers, PKCE, WebAuthn credential IDs,
  secrets/verifiers/challenges, CSP nonce, refresh verifiers, and cryptographic keys with their
  required format, entropy and life. Format authority, not merely generator identity or an
  `external_id` name, decides the exception. External native UUID need not become varchar; it still
  cannot become an app-owned internal PK. Preserve provider/issuer/tenant/audience/RP association
  uniqueness, case, length and comparison.
- Document every genuine external exception in a short code comment naming the value and ADR, the
  owning ADR with source/rationale/alternatives, and the identifier guidelines with table/column,
  format/length/uniqueness/comparison. Unknown upstream maxima stay explicitly unknown with existing
  safe size bounds; do not invent them or truncate values to 25. Do not add a mapping/ID merely to
  make external values look compliant.

### 5.2 Generation and writers

Reuse or extend one appropriate common generator mechanism after inspecting Nanoid 2.0.0's source.
Keep resource/session/JWT/family meanings and lifetimes separate. Preserve existing sound
randomness; no custom PRNG, time-derived ID, case conversion, or new cryptography.

Distinguish canonical new issuance (21), storage capacity (25), and explicitly supported old
formats. Test generation at 21 and storage/input boundaries separately. Do not issue arbitrary 1–25
values or force a universal DB length=21 CHECK that invalidates supported history. Remove
unjustified unbounded or oversized self-controlled fields only after data/consumer checks. Preserve
externally referenced long IDs under a concrete bounded compatibility exception; no truncation or
reissuance.

Ordinary create APIs must not accept arbitrary self-assigned resource IDs. Explicit import paths are
separate and authorized. Update model/DB constraints, reference columns, schemas, URL checks,
frontend constraints, fixtures, seeds and all writers consistently. Never generate missing IDs on
read/update or add production test-only exceptions. Cover create with validations disabled and bulk
insert/upsert; explicitly provide IDs or let the DB reject missing/invalid values. Detect bulk skip
cardinality losses instead of silently reporting every requested row inserted.

The final collision guarantee is the DB unique constraint. Regenerate only an internally issued new
ID whose exact named uniqueness constraint collided. Preserve unrelated uniqueness errors, external
IDs and import-supplied IDs. Retry with a finite explicit bound, recovering the failed transaction/
savepoint before retry and avoiding duplicate notification effects. An `exists?` check is not a
guarantee. Do not confuse random collision retry with business-request idempotency.

Permanent IDs never move to another resource. Preserve URL/token/cookie/audit/cross-DB references.
Test update/update_columns/update_all/upsert/raw SQL rejection with explicit errors. Respect delete,
restore, recreate, merge and transfer semantics without inventing a global permanent ID ledger.

For sid/jti/grant_jti/result_jti/family/transaction values, trace issuing, storing, validating and
revoking owners before standardizing generation. Do not designate DeviceSession as the sid source
merely because its name seems appropriate. Preserve what changes on reissue/rotation/revocation;
updating a current-token pointer differs from reusing one JWT identity. A format-only change does
not authorize mass session revocation or rejection of valid issued tokens. If a demonstrated
security defect requires revocation, minimize the affected set and document its operational
handling. Legacy compatibility must be tied to issuer, purpose and authentication, never a
shape-based multi-table search or weaker-verification fallback. Remove duplicate IDs or split human
codes only for a proven semantic/security/continuity benefit, not visual consistency.

### 5.3 Database and migration checks

B-tree is the standard identifier index. Replace actual unjustified Hash indexes by a measured safe
change; leave unrelated GIN/GiST/BRIN alone. Accept an equivalent valid unique B-tree index rather
than duplicating it. Inspect key expressions/order, uniqueness, predicate, INCLUDE, validity,
readiness/live state and lookup conditions. Composite or partial uniqueness is not unconditional
single-ID uniqueness; an INCLUDE column is not a key. References get indexes justified by queries,
not by an `_id` suffix. Cross-shard local UNIQUE is not global DB enforcement; preserve existing
resolution architecture without inventing a central ID service.

NanoIDs compare case-sensitively without normalization. Audit database/column/index/application
agreement and collision consequences before any collation/index rebuild. No unconditional COLLATE.
Aggregate NULL/blank/length/duplicate/collation/consumer checks before stricter constraints, without
dumping secrets or personal values. Remove blank defaults only after all write paths work.

For non-bigint PKs use safe expansion, correspondence, reference migration and validated cutover;
never DROP/TRUNCATE or force-cast strings. Inspect sequence ownership, type/max/increment/cycle,
explicit inserts/seeds/import/restore, position/is_called/cache/concurrent writers and actual
replication/failover. Do not probe with nextval or repair with automatic setval. Seeds/restore must
not rewind allocation; MAX(id) alone is insufficient proof. Retain fixed catalogs without sequences.

Inventory partition parents/children/keys and actual PK/unique scope only if present. Do not
introduce partitioning or silently adopt a composite PK/remove integrity constraints to evade a
conflict. Business time uses appropriate timestamps; ID order is not commit time. Existing safe
keyset tie-breakers may remain with opaque stable cursor contracts. Sequential PKs do not remove
NanoID secondary-index costs; optimize only from bounded isolated measurements.

Use new migration history, not edits to applied migrations. Separate restartable, bounded-memory
backfills from schema migrations; never overwrite legitimate IDs or delete ambiguous duplicates.
Choose only necessary expansion/writer/backfill/validation/index/read-cutover/removal stages.
Account for mixed app versions, locks/time, failed concurrent indexes and rollback/forward-fix. No
unexplained `safety_assured`, `if_exists` failure swallowing, or unapproved real-data application.

Create/update the existing owning identifier ADR, guidelines and executable harness; only if absent
use `adr/identifier-contract.md`, `docs/reference/identifier-conventions.md`, and
`.agents/harnesses/rules/project/identifiers.mdc`. Wire the rule through root AGENTS and the
executable checks into current CI. Prefer schema introspection and one small semantic classification
SSOT. Detect unclassified new candidates, generation bypass, non-bigint app PK, inappropriate
bounds, missing owned-ID constraints/immutability, invalid/wrong indexes, unexplained Hash,
undocumented external exceptions, producer/reference mismatch and new cross-DB bigint contracts.
Column-name regex and historical migration UUID occurrences are discovery hints, never semantic
verdicts.

## 6. Realm identifiers, OTP, and dead history (E)

### 6.1 Policy and key ownership

Keep ClientEmail/ClientTelephone, VisitorEmail/VisitorTelephone, OperatorEmail/OperatorTelephone
under their existing Client/Visitor/Operator realms. Same email/telephone may independently occur in
app/com/org. No global uniqueness/identity correlation, shared parent identifier model, stateful
IdentifierRecordContract, shared Email/Telephone lifecycle, or global lookup authority.

Finish independent Email and Telephone policy series. `OtpLockable` and historical recommendations
to share it are superseded; reuse only pure CSPRNG/HMAC/constant-time/numeric-generation primitives.
Do not move attempts, lockout, resend, cooldown, attempt windows, lifecycle, retention or purpose
semantics into shared policy. Keep channel-specific policy constants and timing protections.

Failed attempts persist through first issuance, resend, replacement code/secret, expiry, cancel and
logical retirement. An admitted wrong code increments atomically. Only successful normal consumption
may reset according to the channel's explicit contract; retained receipt replay does not reset later
failures. Preserve existing destination abuse budgets and finite locks. Telephone in every realm
uses explicit `otp_last_sent_at`, never `created_at`. Preserve existing channel expiry/retry values
unless this contract specifically changes behavior. Test 0, 1, MAX−1, MAX, MAX+1, resend below/at
MAX, success, expiry and cancellation. Do not cite the old X-049 uncertainty as authority to ignore
the requirement; verify the remaining implementation rather than claiming an old bug is still
present.

Live normalized lookup keys are exactly:

```text
APP_EMAIL_ADDRESS_HMAC_KEY
COM_EMAIL_ADDRESS_HMAC_KEY
ORG_EMAIL_ADDRESS_HMAC_KEY
APP_TELEPHONE_NUMBER_HMAC_KEY
COM_TELEPHONE_NUMBER_HMAC_KEY
ORG_TELEPHONE_NUMBER_HMAC_KEY
```

Select by concrete model or explicit validated realm/channel, never implicit request host. Missing
required keys fail closed. No `EMAIL_ADDRESS_HMAC_SALT`/`TELEPHONE_NUMBER_HMAC_SALT` fallback. Same
normalized value is stable within realm/channel and different across realms. Preserve scoped
emergency rotation so a com Telephone incident does not rotate app/org or Email. Follow existing
restricted maintenance authorization; do not grant ordinary writers permission to modify finalized
identity binding. Required ENV reads use one-argument fetch; optional reads have explicit nil paths.
No secret values in errors/evidence and no code defaults to make tests boot.

Use the existing accepted ARE decision: six identifier models use realm-specific current-write/
previous-read keyrings, while other inventoried PII keeps its separately owned keyring. Read
`docs/security/identifier-encryption-inventory.md` and revalidate the current model/attribute list;
the ADR's reported 51 models/108 attributes is historical, not a mandatory count. Do not silently
assign shared AvatarMoniker/AccountAccessEvent data to app by physical DB location. Existing names:
`{APP,COM,ORG}_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, corresponding
`_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`, and optional JSON-array
`_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS`. Preserve old-owning-realm read/new-current write
rotation and fail-closed malformed configuration; identifier ciphertext never tries a global key.
Keep normal test boot via approved test configuration, not ad hoc extra per-command secrets.

### 6.2 Ceremony proof and transport

Move remaining `otp_private_key`, `otp_counter`, `otp_expires_at` proof and obsolete serialized
context off persistent identifiers after every caller is migrated. Reuse the six existing concrete
Email/ Telephone ceremony transaction models. Bind transaction, generation, purpose/operation,
actor, original browser/session, candidate/destination, finite expiry and consumption structurally.
An OTP issued for sign-in cannot authorize withdrawal/recovery/sign-up/registration or another
actor/session. Existing Step-Up Email remains independently session-bound; no forced consolidation.

Use secure random six-digit codes with an independently keyed verifier, not reconstructible HOTP
secret+counter or raw DB OTP. Use existing approved crypto utilities, constant-time comparison and
atomic row-locked consumption. At most one concurrent fresh verification succeeds. Keep candidate
and destination failure admission, original deadlines and invalidation semantics. Separate proof
verification from original-operation retained evidence as C08 requires; never slide a receipt
deadline or turn consumed proof into a new success.

The accepted local ADR already defines generation-bound encrypted Email/SMS delivery, keyed receipt
fields, and proof immutability triggers. Retain these contracts rather than replace them with weaker
single-use flags. Match current exact envelope/tuple/version consumers before edits. Terminal proof
bindings/timestamps cannot be erased or extended by raw SQL. Ordinary parent completion stays legal.
No hidden HOTP/old encoding fallback or challenge recreation after terminality.

Migrate each real issuance/resend/verification/finalization/worker path one purpose and channel at a
time. Preserve Auth ceremony versus Base session authority, Root/browser binding, bootstrap parent,
destination binding and current credential policy. Worker checks cancelled/expired/superseded proof
immediately around actual transport, including expiry during rendering. Codes travel only through
the existing encrypted delivery material, never plaintext job arguments/logs. Retain Noticed,
surface mailers, interceptors and delivery/retry semantics. A source commit followed by Ticket
failure is not a distributed rollback; retry may reconcile only the original immutable receipt/audit
provenance.

### 6.3 Live uniqueness and irreversible history

Enforce normalized live uniqueness in each realm's DB. Test normalized-case/whitespace Email and
equivalent formatted Telephone under concurrent create, delete/create, conflict rollback and future
dead-ID reuse. Use semantic status constants, not literal status IDs. Test Visitor/Operator as well
as Client, and channel behaviors separately.

Reuse the existing six independent histories; do not create duplicates:

| Models                                         | Identity FK  |
| ---------------------------------------------- | ------------ |
| ClientEmailHistory, ClientTelephoneHistory     | `user_id`    |
| VisitorEmailHistory, VisitorTelephoneHistory   | `visitor_id` |
| OperatorEmailHistory, OperatorTelephoneHistory | `staff_id`   |

Their interface is exactly `id`, owning identity FK, `fingerprint`, `attached_at`, `detached_at`,
`created_at`, subject to verified actual FK naming. No public ID/status/updated_at/address/number/
live digest/encrypted identifier/live-row reference. No shared parent model. History existence means
irreversibly dead; it is not a temporal live SSOT like Avatar ownership.

At permitted physical purge, lock/reload owner and live identifier, recheck
holds/deadlines/protection, derive fingerprint from persisted original PII, INSERT history, DELETE
live row, COMMIT in the same owning DB transaction. Logical deletion, recoverable retention and
pending cancellation create no history. Preserve original PII until authorized archive formation; do
not fingerprint replacement dummy data. Refusal/rollback leaves neither an orphan history nor a
missing source. Repeated/concurrent purge archives one actual removal, not duplicate attempts.
Raw/bulk purge bypasses must be identified and routed through the owned lifecycle or refused; do not
claim callbacks protect arbitrary SQL.

Use six distinct `{APP,COM,ORG}_{EMAIL,TELEPHONE}_HISTORY_KEY` secrets, separate from live HMAC
keys: normalized identifier → realm/channel-domain HMAC → randomly salted Argon2id. Reuse
`IdentifierHistoryFingerprintVerifier` and pinned existing costs (`t_cost: 3`, `m_cost: 16`,
`p_cost: 4` were observed), inspecting current security tests before any change. No plain SHA
digest, reversible fingerprint, cross-user `find_by_fingerprint`, single fingerprint index or
fingerprint uniqueness. Multiple registration/purge histories for the same value are valid.
Candidate matching is explicitly identity-scoped and authorized; histories never participate in
login/recovery/live uniqueness and never resurrect identifiers.

History is pseudonymous personal data, not anonymous. Limit use to internal lifecycle/security/abuse
investigation, explicitly authorized Operators and formal legal/audit/privacy procedures. Exclude
ordinary Web/BFF/native/public API, user export/activity, MCP and
advertising/recommendation/profiling. Product invisibility is not an assertion of legally absolute
nondisclosure. Retain purpose limitation, minimal data, bounded policy-driven storage,
confidentiality and privacy by default as design requirements; this document makes no jurisdictional
legal determination. No IP/UA/domain/country prefix/suffix/request params or ad hoc history
`legal_hold` flag. Reuse retention/hold infrastructure. Ordinary histories are append-only;
authorized legal/retention deletion remains possible. Whole-Identity erasure follows the existing
accepted hold/protection contract and cannot be mistaken for identifier-only purge. Do not execute
any real-data erasure as part of implementation verification.

Update the existing realm ADR/spec and current docs; annotate still-present old shared-policy plans
as superseded. The named `plans/rails-model-gentle-creek.md` and `checklist-4-swift-map.md` are
historical references whose absence must be reported, not recreated from memory.

## 7. Authentication phase contract (F)

### 7.1 Preserve the current authority and discover actual entrypoints

Read the current root-login ADR including its final amendments, lifecycle vocabulary/state-machine
ADRs, `docs/security/idp-flow-lifecycle.md`, sign-in/sign-up sequence docs, relevant backlog and
surface/routing/session rules. Rediscover actual locators, models, gates and handlers with `rg` in
`app`, `lib`, `config`, `test`, `db`; exclude temporary checkouts/vendor copies as current app
evidence. Trace `SignInCycleLocator`, `SignUpCycleLocator`, `SignUpSessionState`, `FlowSignIn`,
`FlowSignUp`, state machines, `SignUpStepGate`, `AuthenticationSequenceGate`, and the actual
successors if renamed.

Preserve `AuthenticationBase#establish_signed_in_session!`, `log_in`, `commit_login_session!` and
`lock_sign_in_flow_for_issuance!` authority, actor-before-Ticket locking, expiry/phase/token checks,
database constraints, cooldown, capacity checks and post-commit browser effects. Do not rewrite
final issuance as a supposed zombie-session fix. Add enforcement before irreversible side effects
and retain the final locked recheck. Prove one flow cannot issue multiple sessions through behavior;
a unique token_id prevents duplicate associations but alone does not prevent rewriting a flow to a
second token.

Use current session-limit child transactions bound to `SESSION_ISSUANCE_PENDING`, as the accepted
root-login ADR amendment requires. Do not reintroduce its superseded `SESSION_LIMIT_PENDING` parent
authority, RESTRICTED placeholder sessions, bootstrap exemptions or weak callback recovery.

Auth remains ceremony-only; Base remains session/OIDC authority. Principal discovery differs by
Email, discoverable passkey, social, Entra and emergency; retain the correct existing primary
ceremony/external transaction as authority instead of creating every SignInFlow at `/sign` or
inventing principal=nil flows without demonstrated need.

### 7.2 Request classification and binding

Allow normal same-phase reload/reentry, defined current-to-next advance, explicit user cancellation,
and valid one-shot external callbacks under their current correlation/nonce/state contracts. Browser
Back, bfcache DOM display and History API events are not security authority. No JavaScript history
monitor, client-only guard or new frontend state machine is needed.

For a contradictory flow-instance/phase GET (and HEAD with normal HTTP no-body semantics): return
409, preserve no-store, and change no DB or session workflow state. Do not redirect to the current
step or an error page, regenerate challenges/OTP/provider transactions, advance, issue sessions, or
terminalize on a safe method. Read-only refusal may record an appropriately sanitized observation,
not a lifecycle transition.

For a validly attributable state-changing request contradicting its active original flow's phase/
generation: recheck under the authoritative lock and transition via the owned writer to HALTED=930
with `phase_regression` or `phase_violation`. It is system action, not CANCELLED or FAILED. Do not
renumber/reuse existing state IDs, add reference rows per request or perform a big-bang lifecycle
migration. HALTED is absorbing: no ACTIVE or different terminal transition, session/challenge
issuance, or late callback resurrection. Infrastructure failure is not itself evidence of a phase
violation.

A missing, malformed, forged, wrong-surface or unowned binding grants no authority to mutate a flow.
Refuse it without halting whichever flow a session happens to point to. Resolve only the original,
authorized request-bound flow. Old A's request must not halt new B; A terminal observation leaves B
alone, and B's correctly bound requests can complete normally.

Each phase-bound request must let the server establish original instance and expected phase/version/
generation, plus purpose/surface/expiry where applicable. Reuse existing Rails signed/opaque
capability primitives; never raw locator nonce in URL/HTML/log/Referer, unsigned phase authority,
raw DB ID authority, OAuth state, PKCE, CSRF or `pt` reuse. The currently inspected codec signs only
instance context; endpoint identity may establish a phase, but does not establish stale
generation/expiry. Prove sufficiency per endpoint and extend only missing binding fields using the
existing primitive. Keep the locator's browser nonce as separate authorization. Rails-generated
action/href/endpoint URLs or existing request bodies can carry the binding; filter it from
telemetry.

An explicit restart uses existing non-GET resourceful actions, creates a new instance/public
ID/nonce/ generation, and applies the existing sanctioned terminal event to the old active instance.
Merely displaying an entry GET must not overwrite/cancel/halt a flow. No user intent means no
CANCELLED. Do not introduce non-resourceful verb routes or an unbounded compatibility redirect.

### 7.3 Atomicity, irreversible effects, and response

Lock/reload/check/transition are one authoritative atomic decision. Inspect the current enforcer's
released-lock interval before `SignUpTermination`; close any proven race through the lifecycle
owner, respecting existing lock order. Cleanup is a consequence, not authority. A late request
cannot erase a committed account, revoke a committed valid session as a substitute for HALT, or roll
completed work back. Terminality and source/Ticket compensation must respect actual database
boundaries.

Validate before OTP sends, challenge creation, actor changes, provider handoff,
session/refresh/device issuance. Reuse safe artifact invalidation/consumption primitives. If
terminal admission alone makes an artifact unusable, prove every consumer checks it; do not invent
physical artifacts to delete. Queued delivery must honor the terminal/generation checks from
Section 6.

For GET and unsafe phase-refusal responses, the final contract is:

```text
HTTP status: 409 Conflict
Media type: text/plain
Body: 戻るはだめです
Cache-Control: preserve the Auth no-store policy
Location: absent
```

The Japanese string is intentional required localized customer copy. Use an explicit translation key
with that exact Japanese value, including on affected JSON endpoints when the violation contract
applies; do not add identifiers/phases/reasons or an HTML fallback. Preserve separate established
non-phase error contracts. HEAD sends the same status/headers but no body by HTTP semantics.

HALT requires safe durable audit according to Chronicle/security audit ownership: surface, safe flow
public correlation, reason, request ID/time and safe expected/actual classification if needed. No
OTP, raw email/telephone, nonce, credential ID, signed capability, token or secret in logs, spans,
errors or evidence. A generic application log is not automatically an authoritative audit record.
Keep audit failure/retry semantics explicit without pretending a cross-database audit is atomic.

### 7.4 Mandatory regression matrix

Through public HTTP/flow interfaces, test:

- Current-phase GET/reload success; past/future GET refusal with unchanged flow/session state; exact
  status/body/media type/no-store and no redirect.
- Past/future bound mutation HALT; repeated HALTED mutation, late external callbacks, issuance and
  resend/challenge requests cannot revive or create effects.
- Old A form after explicit B start leaves B intact; B completes. Two tabs advancing/submitting an
  old phase, same-mutation duplicate, lock waits and generation races preserve strict semantics.
- Missing/malformed/expired/wrong-surface/wrong-flow/terminal binding; reachable
  null/empty/zero/NUL, encoding and size sentinels. Expiry immediately before, at and after the
  deadline.
- Applicable app/com/org Email, discoverable passkey, Google/Apple, Entra normal/emergency, MFA,
  capacity, checkpoint, selector and OIDC handoff paths. Do not infer all-family coverage from app
  OTP.
- Repeated back/forward server requests do not multiply sessions or pending flows; no additional
  OTP, challenge, provider transaction, refresh/device session after mismatch.
- Completed sign-up account survives old-page submission; final issuance remains one-flow/one-token;
  first consumption versus original receipt replay is distinct; HALT audit is safe and attributable.

Inspect the existing named test candidates before use, including state machine/step-gate/refusal,
cycle-locator/policy, sequence-gate, app/com OTP, passkey, all sign-in controller,
issuance-boundary, cooldown and root-login integration tests. Select a few relevant files per TDD
slice; never reach private methods with reflection/send, widen visibility, add test-only wrappers or
modify `test/test_helper.rb` for this hardening. Gate 2 still runs the full suites.

Update runtime-owned lifecycle docs/ADRs and affected axes in `docs/mermaid/README.md` and
`idp-state-machine-transition-inventory.md`. Inspect all actual `idp-*.mmd` affected axes and at
least `sign-app-sign-in`, `sign-com-sign-in`, `sign-org-sign-in`, `sign-app-sign-up`,
`sign-com-sign-up`. GET 409 is not a HALTED edge. Distinguish implemented states from target
vocabulary. Locate references to both `docs/uml/{signin,signup}.txt` and
`docs/reference/uml/{signin,signup}.txt`; amend only documents that actually own current behavior,
not every historical password/telephone artifact.

## 8. Avatar ownership and transfer contract (A)

### 8.1 Concrete temporal persistence

An Avatar has exactly one organization owner throughout its valid history: Enterprise in app or
Bureau in org. No individual or fractional ownership. Ownership, membership, management authority
and Avatar-use authorization remain separate. com gains no Avatar dependency. Preserve Avatar,
Persona/ClientPersona, Agent, Enterprise and Bureau identities in every transfer.

Use concrete Enterprise/Bureau ownership-period tables, shared Ruby interfaces only. No polymorphic
Rails persistence, STI, type+ID owner/subject pairs, discriminated generic relationships, or
exclusive arcs. Cross-DB organization/subject references use concrete public references, bounded
according to their issuer contract. Local references remain real concrete FKs.

Each period has immutable Avatar, owner and finite start; end strictly exceeds start. Intervals are
`[valid_from, valid_to)`, final end is positive infinity, with no overlap/gap, exactly one current
owner and one uninterrupted history across both concrete families. Closed history cannot ordinarily
be changed/deleted or truncated. New Avatar and initial period commit in the same Avatar DB
transaction with a boundary consistent with creation. Do not invent timestamps for historical data.

Use CHECK/FK/UNIQUE/EXCLUDE where sufficient and minimal deferred cross-table integrity enforcement
at COMMIT. A partial current UNIQUE or per-family exclusion alone cannot prove cross-family
continuity. Direct SQL and independent concurrent connections must be safe. Follow A D-3/D-4's
explicit narrow trigger authorization: integrity only, no business
workflows/audit/notifications/silent correction, no arbitrary data backfill. A dedicated
lock/version counter is permitted only when required to make stale-snapshot writes fail correctly
and proven with real transactions; it is never owner authority.

For every trigger document invariant, tables, events, lock order/mode, SQLSTATE and firing test.
Attach function and trigger in the same migration, reverse attached objects before dependencies,
register exact trigger inventory, and narrowly amend `adr/database-trigger-usage-boundary.md`. Check
deadlocks, lock upgrades, recursion, READ COMMITTED, REPEATABLE READ and SERIALIZABLE anomalies.
Approximately twenty triggers in the old spec is not a target count.

### 8.2 Registry, concrete details, and request semantics

Retain Request/Accept/Cancel and all four concrete families: Enterprise→Enterprise,
Enterprise→Bureau, Bureau→Enterprise, Bureau→Bureau. A shared type-neutral registry owns operation
public identity, global idempotency-key reservation, Avatar identity and cross-family pending
uniqueness/state. It contains no polymorphic owner/actor/detail reference. Each of four concrete
detail tables holds its actual source/destination/authority references and one registry FK. Enforce
exactly one appropriate detail per committed registry and one registry per detail, including direct
SQL and simultaneous cross-family insertions. Use local uniqueness/FKs and a narrowly scoped
deferred cross-table check serialized through the registry where needed; do not introduce
`transfer_type + transfer_id` or an exclusive arc to avoid the check. Bind immutable request facts
in their concrete detail; generic operation kind alone must never dynamically resolve an arbitrary
owner/actor model.

Registry public IDs follow I's NanoID contract; client idempotency keys follow the explicitly
approved canonical lowercase 36-character UUID v4/v7 contract. Reject unsupported versions/malformed
or noncanonical keys according to the documented API boundary, without arbitrary string fallback.
New clients provide one stable key per request. Persist/compare key, authorized concrete initiator,
operation kind, Avatar, immutable inputs and resulting operation identity. Same authorized request
returns the same identity/result; changed inputs/initiator are rejected without disclosing another
actor's result. A per-table index/advisory-lock/eventual reconciliation gap is unacceptable.

Preserve old keyless callers through an explicitly documented additive transition; a fresh server
key each retry is not client idempotency. Identify every legacy caller and its removal/adoption
condition. Keep controller/transport changes minimal. A result read permission is distinct from
permission to execute another transfer. Cancelled/expired operations never resurrect.

### 8.3 Acceptance, Grants, and Group consequences

Retain the five-day request validity. At acceptance resolve immutable operation, lock/reload
relevant Avatar and current generation, revalidate source and destination authority, pending state
and expiry, then use one consistent Group/Avatar lock order across all writers. An initial lookup is
not authority; if discovering a Group requires lock reordering, restart acquisition in the
documented total order and revalidate all facts rather than acquiring contradictory locks.

After locks, select one database-derived instant for both old-period end and new-period start.
Refuse clock regression that violates strict order without changing history. In one Avatar DB
transaction: close old period, create new period, record its result identity, complete transfer and
apply required Grant/Group consequences. This is not atomic across Zenith/Avatar databases; preserve
current remote authority verification and document its actual consistency limits. Successful retry
finds the same committed result rather than performing a second transfer.

Bindings remain their existing exclusive assignments unless an independently justified migration
changes that purpose. Do not simply drop 1:1 indexes or add period IDs and call Bindings Grants.
Introduce explicit lifecycle-aware N:M access Grants for the concrete Persona/Agent and owner
families actually supported. Each identifies Avatar, concrete subject, issuing concrete ownership
period or approved immutable non-polymorphic generation, capability, validity/revocation, granting
authority and audit. Prefer explicit subject/period combination tables over a new generic owner
supertype. Audit selectors, provisioning and policies. Management/transfer authority stays distinct
from use. After O1→O2→O1, prior Grants stay historical and ineffective; a new authorized Grant is
required.

For Group account columns, determine whether they represent owner, creator, account or selected
workspace context. Derive only demonstrably identical facts from concrete ownership; otherwise
retain separate concrete relationships without invented domain meaning. Legacy account fields are
temporary data only, never alternative ownership authorization. Prepare eventual Phase G removal
after every reader/data migration; no automatic removal in this task. Group access must not silently
survive incompatible ownership transitions. Preserve app initial and org optional provisioning.

### 8.4 Retention, cutover, and recovery

Inspect `RetentionPurgeJob` and existing deferrals first. Ensure Avatar history never disappears
through bulk purge. Reuse deferral facilities or add `avatar_purge_deferrals` only if needed:
explicit reason, Avatar, idempotent observation, actionable/auditable state and no duplicate PII.
Repeated jobs must neither silently skip obligations nor endlessly emit the same FK error without
state. Do not perform physical Avatar/history deletion. Inventory personal attributes/handles/media
requiring future policy separately from ownership integrity.

Backfill is an independent operational task: inventory, dry-run, bounded restartable conversion,
reconciliation and cutover. Preserve concrete owner, actual intervals, valid transfer states, known
originating actor and public identities. Ambiguous/missing facts stop that row with a safe report.
Same public string in two explicitly different concrete organization families is not itself a
collision. Control every relevant writer/background job before final cutover. After consumer cutover
there is no silent fallback to old ownership authority.

Activate a database-level legacy write barrier only after verified backfill and writer migration.
Prefer effective ordinary-role REVOKE/least privilege with separate migration/backfill ownership;
verify the app is not an owner/superuser that bypasses the barrier. If role topology cannot enforce
it, D-10 permits a named narrow rejecting trigger with ADR exception. Test INSERT/UPDATE/DELETE/
TRUNCATE as the real ordinary application role. Keep necessary historical reads; do not drop legacy
tables. Prepare a forward-only post-cutover recovery runbook; no production cutover here.

Real deferred-COMMIT tests require a newly created disposable PostgreSQL database/instance whose
unique run/worker identity and ownership are verified. Apply normal completed migrations with real
triggers; use independent connections and actual COMMIT. Cleanup may drop only that harness-owned
disposable database, never a shared developer/test catalog. Do not disable triggers/constraints for
cleanup. If privileges are unavailable, record blocked tests, not mock-based substitutes. Prove
deterministic error/retry behavior, not only sequential happy paths.

## 9. Email observability contract (O)

### 9.1 Rails parameter filtering

`config.filter_parameters` is the sensitive-key authority. Retain meaningful broad password/token/
secret/credential/OTP/auth/cookie filters; replace ambiguous short substring keys with
exact/boundary regexes based on actual key inventory. At minimum investigate `code`, `uid`, `rt`,
`pt`, `der`, `state`. Use `/\Acode\z/i`-style matching; design uid/provider_uid boundaries from real
keys rather than blindly using a sample regex. Preserve nested behavior and avoid unnecessary filter
expansion.

Positive cases: passwords, client_secret, otp/otp_code, access/refresh/id token, authorization_code,
code, rt, pt, state, real uid/provider_uid variants, credential_id. Negative cases must remain
useful: reason_code, status_code, http_status_code, guid, public_id, provider, order, sort, support,
attempt_count, event_uuid. Test both the filtered value and retained non-secret values through the
public filtering boundary. Keep flow/OTP transport capability keys protected.

### 9.2 Standard ActionMailer and formal OTel options

Use one common Rails public setting, normally `config.action_mailer.logger = nil` in
`config/application.rb`, and verify boot yields `ActionMailer::Base.logger == nil` in actual
supported environments. Installed Rails source assigns the logger default via an on-load hook and
later applies explicit action_mailer options through setters; recheck ordering and concrete-mailer
overrides. Raw email content is not application logging data. Do not patch LogSubscriber, override
deliver_mail/ set_payload_for_mail/private APIs, mutate MIME, or implement a custom delivery stack.

Retain test/SMTP adapters, `perform_deliveries`, deliver_now/deliver_later semantics, Noticed,
app/com/org mailers, retry behavior and `OutboundEmailSuspensionInterceptor`. Test success,
suspension, failure and retry with synthetic messages without sending externally.

Installed `opentelemetry-instrumentation-action_mailer` 0.8.1 formally provides:

```text
notification_payload_transform
process_payload_transform
email_address: :omit
```

Use transforms that always return a newly selected Hash with a fixed safe allowlist. In this
version, the deliver transform receives the gem's transformed string keys such as `email.x_mailer`,
not the original symbol-keyed Rails notification. The process transform receives its process
payload; inspect the installed subscriber path before choosing key types. Returning a non-Hash from
deliver transform causes the gem to use its unfiltered transformed payload: test against that
failure mode.

Adopt the minimal deliver allowlist `email.x_mailer` and process allowlist `mailer`, `action`,
provided values are actual controlled class/action names. Omit `email.message_id` initially: it is
optional and not needed for this contract; add it only with demonstrated controlled generation and
no PII/input. Explicitly set supported `email_address: :omit` as secondary protection. Exclude
subject, to/from/cc/ bcc, args, arbitrary headers, URLs, raw mail/MIME/body, OTP/token and
provider-response content. Test unknown future payload keys are not exported, not just known
denylisted examples.

Keep `ObservabilityRedactor` and `ObservabilitySpanScrubber` as defense in depth. Only minimal
alignment changes are authorized; do not redesign them or substitute them for the export allowlist.
Test the actual emitted/captured span boundary with synthetic data and in-memory capture rather than
claiming a transform configuration alone proves absence across every sink. Do not send verification
telemetry to Grafana/Tempo/Loki/SES/Sentry or external collectors.

### 9.3 Collector, mounts, and documentation

Keep Rails→OTLP→Alloy→Tempo/Prometheus routing and startup config loading. Extend existing
`otelcol.processor.attributes` secondary deletion to mail subject/address/body/raw/MIME/args and
token/OTP attributes that an upstream regression could emit. Use only syntax supported by pinned
Alloy `v1.19.2`, verified with available local source/binary validation; do not guess options or
substitute an unverified current online version. Rails sanitizes before export; Alloy is secondary.

Add a nested directory bind in `.devcontainer/compose.yaml`:

```yaml
- type: bind
  source: "./podman/alloy"
  target: "/home/global/workspace/podman/alloy"
  read_only: true
  bind:
    selinux: Z
```

Use the real root-first Compose project resolution, following the existing guarded mount pattern.
Retain the Alloy container's read-only config file source. Host-managed policy remains readable but
not writable from core. Do not bypass a currently read-only mount to edit host configuration; finish
an exact patch and report that application as blocked if this environment cannot write the source.
The user will rebuild/recreate; do not publish reload/management ports, send SIGHUP, add Rails
config notifications, or implement reload API machinery. Effective remount after recreation is not
proven by a YAML edit; state pending runtime acceptance separately.

Keep the existing name-filtered CSP `Rails.event` subscriber and its invariant. Do not
indiscriminately subscribe framework events or forward action_mailer raw debug events to sinks.
Rails structured subscriber `filter_payload: false` is not permission to monkey-patch framework
internals.

Update the existing OTP observability ADR/plan and `docs/security/observability-boundary.md`, plus
an index/note only if necessary. State production topology is not built, not that production is
remediated or an incident was confirmed. Future deployment acceptance: no raw mail/MIME or OTP/
verification/recovery/access/refresh/id secrets in persistent sinks; pre-export Rails controls plus
collector controls; explicit production retention, access control, config distribution and predeploy
verification. No production Alloy/stdout/Loki/Tempo/Grafana/IAM/retention/reload implementation.

Sentry initializer, filtering, PII configuration, inspection and tests remain untouched. Do not
close broader historical remediation acceptance that still depends on excluded verification; record
the local scope delivered and the remaining separately owned gate.

## 10. Ordered implementation phases

Each phase below is a collection of small independent TDD slices, not permission for a giant edit.
Before a slice choose one public behavior, name its concrete test file and first failing assertion,
and record its preconditions. Default maximum is three Red→Green→Refactor iterations before a full
gate; a completed slice/phase or transverse change triggers the gate sooner. Every slice includes
its affected docs/diagram/acceptance update so later documentation work cannot hide contract drift.

Dependencies (a plus sign means all listed predecessors; P10/P11/P12 are parent labels):

```text
P0 → P1a → P1b → P1c
P0 → P2 → P3a
P1a + P1b + P3a → P3b
P3a → P3c
P3b + P3c → P3d → P3e → P4 → P5
P2 + P5 → P6
P0 + P2 → P7 → P8 → P9
P9 → P10a
P9 + Group semantic evidence → P10b
P3e → P11a
P8 → P11b
P6 + P11a → P12a
P9 + P10a + P10b + P11b → P12b
all required child-phase acceptance + final gate → P13 completion
```

Default execution follows numerical order among ready phases; child phases can be selected by their
actual prerequisites. Decision-held P10b does not hold P10a, P11a or P12a. P11b does not depend on
identifier proof/history completion. P12b still waits for Group semantics because the same transfer,
Group authorization and legacy ownership writers must be reconciled before Avatar cutover. No Avatar
cutover may ignore a held Group reader/writer. P9 can finish its registry/period mechanics without
claiming the full AV-6 transfer acceptance: Grant/Group consequences remain obligations of P10a/P10b
and must pass before P12b cutover. This is staged verification, not a weaker transfer contract. A
held child prevents its parent's overall completion, not truthful completion of another child. P13
can prepare a partial report at any time but cannot declare the whole delivery complete while
included criteria are held.

P3b requires P1a's positive/negative filtering and P1b's common logger policy plus actual synthetic
pre-export allowlist/delivery verification, with their full gates current. P1c's collector syntax/
Compose static checks are a separate acceptance item, not a substitute for those primary controls.
User recreation and runtime read-only mount verification remain a separate P1c dynamic item. P3b may
use isolated in-memory logging/export and the test delivery adapter while that remount is pending;
it must not send synthetic secrets to an unverified live collector. P1c is not a blanket predecessor
for P3b. Missing required full suites still invoke the global verification hold in Section 2.3.

P2 includes the DB-enforcement/authority map before touching any dependent invariant. P3c learns
only pure-primitive lessons from Email and has no stateful-policy dependency on P3b. P7 must
demonstrate real integrity before P8/P9 depend on it; no source-only prototype substitutes for this
prerequisite. When children touch the same RetentionPurgeJob, shared writer or authorization
boundary, serialize those edits and run the relevant neighboring regressions and both full suites.
Record any additional actual consumer dependency in the owning spec and this graph/table together;
do not invent a domain change or delete a safety dependency to make work appear independent.

| Phase                                | Purpose, concrete scope and prerequisite                                                                                                                                                                                                | First Red / direct check                                                                                                                   | Acceptance, tests and exit                                                                                                                                                                                                            |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P0 — reconcile and baseline          | Current Git/env/rules; six draft audit; inventory; amend Avatar spec and governing conflicts. No model/schema edit before reconciliation and DB guarantee/approved-mechanism mapping.                                                   | Direct read-only checks, then Gate 0; no artificial test for planning/setup.                                                               | Snapshots, conflict dispositions, command catalog, current failure list and protected-worktree inventory recorded. No incomplete migration discovered/applied.                                                                        |
| P1a — filter behavior                | Filter initializer and existing `test/unit/security/filter_parameter_logging_test.rb`; real nested keys.                                                                                                                                | `reason_code` is retained while `code` and nested secrets are filtered.                                                                    | All positive/negative keys and boundaries pass; no unnecessary lost observability. Gate 2 at slice end.                                                                                                                               |
| P1b — mail export                    | Common mailer setting, OTel initializer, existing scrubbers, concrete mailers/interceptor; P1a and installed source inspected.                                                                                                          | Synthetic OTP/subject/args absent from captured application log/span while test delivery succeeds; direct boot policy check.               | All three surfaces, unknown payload keys, suspension/failure/retry and existing delivery semantics verified; no private override. Immediate full gate after common config.                                                            |
| P1c — collector/mount/docs           | Alloy and devcontainer configuration; P1b.                                                                                                                                                                                              | Direct pinned Alloy config validation and rendered Compose mount check; no setup unit test.                                                | Supported redaction, correct source/target/read_only, no reload changes; runtime remount explicitly unverified until recreate. ADR narrowed and future production criteria recorded. Full gate after build/config change.             |
| P2 — identifier foundation           | PublicId concern, existing Nanoid mechanism, model/test classification and prospective new schemas; P0 and the per-invariant DB-enforcement/authority map. Hold only an invariant needing new permission; no blanket trigger authority. | New internal issuance is 21 and ordinary public create cannot inject an arbitrary owned ID; exact collision discrimination test if absent. | Generator mechanism, eight-role manifest and exception categories established; targeted public-ID/collision tests and immediate shared-Concern full gate. No broad automatic model rewrite.                                           |
| P3a — channels and keys              | Independent policies, six identifier models, realm key provider/rotation and ARE inventory; P2.                                                                                                                                         | Resend at existing failures preserves count; cross-realm equal normalized input yields distinct digest; add only missing regressions.      | MAX boundaries, explicit Telephone timestamps, independent policy and rotation tests pass. Boot/key wiring direct evidence; full gate per slice.                                                                                      |
| P3b — Email proof                    | Concrete Email ceremony/issuer/verifier/finalizer/notifier/mailer paths, APP/COM signup/signin and applicable recovery/withdrawal/registration; P1a/P1b/P3a with the primary-control evidence specified above, not pending P1c remount. | Wrong purpose/session code refused without consumption, followed by valid original consume; later retry is receipt, not fresh success.     | Migrate one purpose per slice; fault/deadline/delivery tests prove keyed binding and no HOTP fallback. Source/Ticket fault consequences recorded. Full gate per slice.                                                                |
| P3c — Telephone proof                | Independent Telephone ceremonies and existing bound SMS transport; P3a, Email design lessons only as pure primitives.                                                                                                                   | Concurrent verification consumes at most once; resend preserves attempt count and original expiry.                                         | Each supported realm/purpose, independent lockout/cooldown, original binding and stale worker refusal verified. No shared stateful policy. Full gate per slice.                                                                       |
| P3d — proof retirement               | Remaining policies, six identifier schemas/fixtures, all legacy proof/envelope readers/writers; P3b/P3c and complete consumer inventory.                                                                                                | Public paths work with no identifier HOTP fields; obsolete payload rejected through real consumer.                                         | Remove legacy runtime methods coherently; prepare forward schema retirement, applying destructive drops only in verified disposable DB or separately approved scope. Do not edit applied history. Full schema gate.                   |
| P3e — live identifier integrity      | Six models, source constraints, current purge interfaces; P3d.                                                                                                                                                                          | Two normalized-equivalent concurrent creates yield one live identity binding; conflicting transaction rollback stays usable.               | Email/Telephone in all realms; delete/create/reuse and status partitions verified with actual PostgreSQL. Immediate shared-model/schema gate.                                                                                         |
| P4 — authoritative phase core        | Codec/gate/enforcer/state writer/audit and app/com signup entry/step paths; P3e.                                                                                                                                                        | Stale bound mutation racing an advance cannot affect committed completion; old A submission leaves B intact.                               | Locking decision atomic, signed original instance/phase/generation, exact GET refusal, non-GET halt and safe audit. Existing issuance retained; immediate security full gate.                                                         |
| P5 — family/surface coverage         | Sign-in locators/gates, primary ceremonies, callbacks, MFA/capacity/checkpoint/selector, finalization; P4.                                                                                                                              | Choose next actual family from matrix: stale phase request creates no artifact/session and refuses without touching replacement flow.      | One family/surface per slice, explicit unsupported cells, all Section 7 cases and diagrams; no new credential method. Immediate full gate after each shared boundary.                                                                 |
| P6 — identifier consumers/DB         | Inventory-driven model/column/index/PK/sequence changes, APIs/jobs/events and current ceremony IDs; P2/P5.                                                                                                                              | Next concrete owned-ID DB bypass or consumer-format mismatch fails at public boundary.                                                     | One meaning/consumer group per slice; external exceptions and existing IDs preserved, correct indexes/constraints, no remote bigint addition. PK/sequence/partition work isolated and verified; full gate per schema slice.           |
| P7 — ownership integrity prototype   | Six reworked drafts, trigger ADR and isolated DB harness; P0/P2, reviewed complete migrations only.                                                                                                                                     | Real COMMIT with cross-family overlap/gap/missing owner fails with expected SQLSTATE; sequential and concurrent valid chain commits.       | Initial/closed-history/adjacency/direct-SQL/RC/RR/Serializable invariants proven. Stop downstream ownership implementation acceptance if fundamental integrity cannot be enforced. Full gate after schema/prototype slice.            |
| P8 — concrete ownership models       | Avatar/period associations, ownership resolver/provisioning, concrete remote public references; P7.                                                                                                                                     | New Avatar without an owner cannot commit; valid app/org provisioning preserves all identities and com has no dependency.                  | Concrete model/Ruby interfaces and single owner authority replace obsolete alternatives; account/Group unresolved semantics not guessed. Full gate after resolver/model slice.                                                        |
| P9 — registry and transfer           | Shared registry plus four concrete detail models and Request/Accept/Cancel, minimal transports; P8.                                                                                                                                     | Concurrent same-key requests across two families cannot create two operations; changed payload/initiator is refused.                       | Direct-SQL cardinality, global pending/key uniqueness, four directions, five-day boundaries, generation/authority rechecks, atomic periods and retry result semantics; keyless transition documented. Immediate full gate.            |
| P10a — Grants (P10)                  | Existing Binding semantics, concrete N:M Grants/policies/provisioning; P9. Group conversion is not a prerequisite.                                                                                                                      | Grant from first O1 period stays ineffective after O1→O2→O1 while a new authorized Grant works.                                            | Management/Binding meaning preserved; concrete subject/period/capability checks and N:M success, no revival. Full authorization/model gate; Group effects separately remain P10b.                                                     |
| P10b — Group semantics (P10)         | Account/owner reader and writer conversion; P9 plus authoritative Group semantic evidence.                                                                                                                                              | Distinct selected-account context survives an ownership change without becoming an alternative owner authority.                            | Actual semantics preserved; incompatible Group access refused; all consumers reconciled. Hold this child when a domain choice is missing; it blocks Avatar cutover P12b, not P10a. Full gate after each affected writer/policy slice. |
| P11a — dead identifier history (P11) | Six histories, identifier purgers and legal/retention holds; P3e. No Avatar prerequisite.                                                                                                                                               | A refusal after history INSERT rolls back archive and physical removal together.                                                           | Minimal schema, original-PII fingerprint, internal visibility, reuse and concurrent purge/create behavior across six models; authorized whole-owner semantics preserved. Focused real-DB checks and full gate per lifecycle slice.    |
| P11b — Avatar deferral (P11)         | RetentionPurgeJob and existing/new concrete deferral; P8. No identifier-history prerequisite.                                                                                                                                           | Repeated eligible Avatar purge records one actionable deferral without deleting Avatar/history.                                            | Observable idempotent state and preserved history; personal-data policy remains explicitly undecided. Serialize shared retention edits with P11a and run neighboring tests plus full gate.                                            |
| P12a — identifier transition (P12)   | Identifier inventory, bounded backfill/consumer transition and recovery; P6/P11a. No Avatar decision dependency.                                                                                                                        | Repeated isolated migration preserves issued identifiers/references; ambiguous data stays unchanged and reported.                          | Fresh migration/schema verification, constraints and sequence safety, documented compatibility exits and rollback/forward-fix. No broad reset or real-data application. Full gate after each transition boundary.                     |
| P12b — Avatar transition (P12)       | Operational backfill, writer quiescence, legacy barrier and forward recovery; P9/P10a/P10b/P11b.                                                                                                                                        | Repeated isolated backfill preserves history; ambiguous row is refused; ordinary-role writes fail only after verified cutover.             | Rebuild/dump/restore including triggers; all ownership/Group writers controlled; INSERT/UPDATE/DELETE/TRUNCATE barrier tested. No production cutover or automatic Phase G deletion. Full gate per transition boundary.                |
| P13 — acceptance and handoff         | All executable guards/docs/checklists/diagrams/evidence and complete current diff; predecessor gates.                                                                                                                                   | Run actual final commands, not a new artificial Red.                                                                                       | Gate 4; every requirement has evidence or explicit incomplete disposition, no new regression and no false global completion. Final report in Section 14.                                                                              |

Suggested current test starting points, not preclaimed results:
`test/models/concerns/public_id_test.rb`, `test/models/dead_identifier_history_contract_test.rb`,
`test/models/dead_identifier_destroy_test.rb`, `test/models/realm_identifier_encryption_test.rb`,
`test/lib/identifier_history_fingerprint_verifier_test.rb`,
`test/operations/dead_identifier_purge_test.rb`,
`test/operations/dead_identifier_purge_concurrency_test.rb`,
`test/integration/sign_up_phase_regression_app_test.rb`,
`test/policies/sign_up_step_gate_refusals_test.rb`, `test/services/sign_up/state_machine_test.rb`,
`test/operations/avatar_ownership_transfers_test.rb`,
`test/operations/avatar_ownership_transfers_concurrency_test.rb`, app/org transfer controller tests,
`test/models/enforcement_triggers_test.rb`, filter/redactor/span-scrubber tests and retention job
tests. Confirm each exists and still exercises the boundary, adding missing public tests beside its
owner.

## 11. TDD execution rules

For every observable behavior slice:

1. Before changing code, read the applicable permanent criteria via the integrated index. Identify
   preserved criteria, missing criteria and any explicitly authorized contract updates. Before Red,
   map the observable expectation to its stable Acceptance ID; do not derive it afterward from code.
   Select the smallest meaningful public HTTP/model/operation/DB interface and explicit test file.
2. Red: add the missing behavior test and run it. Verify the intended assertion or expected
   constraint fails. Syntax, missing fixture, pending migration, unavailable DB, boot or dependency
   failure is not Red. Repair environment only within authorized scope and record it separately.
3. Green: make the smallest production change satisfying that contract. No adjacent cleanup or broad
   redesign. If the required behavior already passes, retain the regression and classify it
   honestly; do not manufacture a defect or rewrite correct code.
4. Refactor: keep tests green while improving local naming/responsibility/duplication. A pure
   structural change may use existing meaningful regression tests rather than an artificial new
   failing case.
5. Run direct and necessary neighboring tests. During verification replace planned references with
   actual tests/direct procedures and revision-scoped evidence; never mark unrun criteria PASS.
6. At slice end reconcile criteria, owning spec, implementation and test references; run Gate 2 when
   due and safe document-consistency checks. Commit only owned document hunks under Section 14.1.
   Missing criteria, broken material references or uncommitted acceptance updates keep documentation
   and handoff incomplete even if implementation and tests are separately complete. No
   independent-AI reply is needed for the next otherwise-ready slice.

Use FIRST, DAMP, EP/BVA and public-interface testing from the actual harness. Cover below/at/above
every reachable length, retry, duration, counter and classification boundary, and appropriate
missing/empty/zero/NUL/type/malformed-encoding sentinels. Use nearest reachable values with a reason
when a mathematical boundary cannot occur. Keep equivalent partitions proportionate.

Verify DB constraints through writes that bypass validation, using savepoints/separate transactions
so an expected SQL error does not poison later assertions. Real DB concurrency/COMMIT acceptance
cannot be mocked. Deterministically inject generator collisions at the public dependency boundary;
large random samples do not prove no collision or cryptographic quality. No private method testing,
test-only production branch, placeholder/TODO/skipped behavior test or asserting implementation text
instead of the contract. Environment construction uses direct execution/evidence, not suite tests.

## 12. Full regression gates and commands

### Gate 0 — before application changes

After the six-migration and test-DB safety checks, establish the baseline:

```bash
bin/rails test
bun run test
```

`package.json` currently defines `test` as non-watch `node node_modules/vitest/vitest.mjs run`; Bun
is the declared package manager. Recheck at execution rather than substituting npm/yarn or watch
mode. Record full HEAD, relevant dirty-worktree state, run ID/seed, exact command, exit status,
elapsed time, test counts, runs/assertions where reported, failures/errors/skips and coverage
outcome. A tool not reporting a count is recorded as unavailable, not invented. Separate existing
behavior failures, coverage threshold failures and environment/boot failures. Compare the
identities, causes, seeds, commands and environments of failures, not just their counts: equal
totals do not prove no new regression. An incomplete suite cannot establish that classification.

If pending migrations or unsafe DB configuration prevent this baseline, stop the test invocation
before implicit mutation. Record a blocked baseline, complete authorized isolated setup, then run
it. Do not apply quarantined Avatar drafts to make baseline proceed. Full suites run against
verified test-only databases; never against an existing developer catalog just because its name
looks familiar. A blocked or unfinished Gate 0 invokes Section 2.3's shared-worktree verification
hold before any feature implementation. Re-run it successfully or classify fully executed baseline
failures before starting TDD; unexplained failures are not a usable baseline.

### Gate 1 — each iteration

Run named-file Rails/Vitest tests for direct and adjacent behavior. Examples are selections, not a
replacement for current path discovery:

```bash
bin/rails test test/services/sign_up/state_machine_test.rb test/policies/sign_up_step_gate_refusals_test.rb
bin/rails test test/models/dead_identifier_history_contract_test.rb
```

Capture intended Red and subsequent Green; no next iteration on unexplained new failure.

### Gate 2 — recurring full verification

Run **both** `bin/rails test` and `bun run test` at the earliest of:

- completion of a coherent implementation slice;
- three completed TDD iterations since the last full gate;
- phase completion;
- immediately after a change to routing/shared controller, authentication/authorization/session,
  schema/shared model, common Concern/base/service/generator, API contract, test environment or
  build configuration, after its focused tests are green and before more feature edits.

This deliberately adopts the stronger full-suite cadence across all five workstreams. It supersedes
the embedded authentication prompt's prohibition and any default skill suggestion to avoid regular
whole-suite runs. Do not batch three large features under the label of three iterations.

Measure cost, but do not silently skip a gate. If full suites are materially expensive, optimize the
runner/isolation or divide execution into non-overlapping shards that together run every test before
more feature work. Record shard commands and combined counts. The maximum remains three iterations
and one slice; any proposed relaxation requires an explicit changed testing decision, not an agent
assumption. An unavailable or unfinished gate invokes the shared-worktree verification hold in
Section 2.3: no new feature edits, including otherwise independent phases. A fully executed gate
with only individually matched pre-existing failures is recorded as such, not as Green; new or
unexplained failures invoke Gate 3. Coverage failures remain a separate acceptance limit.

### Gate 3 — restore a known tested state

On new regression, stop new feature work. Compare the last green boundary, exact diff and test seed;
group failures by shared initializer/schema/fixture/authority/contract cause. Reproduce the smallest
causal failure, fix it, run the focused reproducer and affected neighbors, then rerun both full
suites. Do not scatter unrelated fixes over hundreds of symptoms. Preserve concurrent contributors'
changes; if attribution is ambiguous, record that ambiguity and coordinate only the overlapping
work.

Do not reset/clean the tree to recover. Revert only your own precisely identified hunk if it is safe
and does not discard another edit; otherwise fix forward. Do not delete assertions, lower coverage,
exclude files, add skip/pending/only, broaden allowlists without contract grounds, swallow
exceptions, disable triggers, or weaken production behavior to appear green. Existing failures
remain separately tracked and do not license new ones. Pre-existing unrelated repairs need scope
authorization.

### Gate 4 — final current-state verification

Revalidate the actual command catalog from `package.json` and `config/ci.rb`. At preparation it
includes:

```bash
bin/rails test
bun run test:coverage
bun run check
bin/rubocop
bundle exec erb_lint --lint-all
scripts/check-repository-knowledge
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

`bun run check` currently covers format checking, lint, typecheck coverage verification, typecheck,
deadcode and OpenAPI lint/bundle comparison. Review any generated-file command and preserve existing
bundle edits; record intentional uncommitted code differences rather than hiding them with a code
commit. Owned acceptance-document persistence follows Section 14.1 independently. Run the current CI
security/invariant selections; run `bin/bundler-audit` and `bun audit` only with permitted network
access and record blocked network/database freshness separately. Dependency outdated reports in CI
are informational, not authorization to upgrade packages.

Run the current build and Rails boot checks in safe test/local configuration when applicable to the
configuration/API changes. Inspect commands before using them: production-mode asset compilation is
not production deployment, but it must not contact production services or load production secrets.
Run actual DB schema/trigger introspection, migration rebuild/dump/restore and isolated concurrency
checks required by I/A/E. Do not execute `bin/ci` wholesale before reviewing its DB create/prepare
and server/exporter side effects. `db:verify_no_schema_drift`, if still used, compares dumps to the
index: intended uncommitted migrations can produce a nonzero result. Preserve the result and explain
its diff; do not commit application/schema changes, stage others' work, or weaken the verifier to
call it green. Section 14.1 permits owned document commits only and does not alter schema-drift
results.

For O, directly verify available boot behavior, Compose path/mount declarations and pinned Alloy
syntax locally. No live external sink/mail/production verification. If user recreation has not
occurred, effective read-only mounting remains explicitly unverified even if static validation
passes.

## 13. Acceptance evidence and completion semantics

No phase is verified merely because files exist or the next phase started. Every requirement row
must point to actual current execution evidence or a precise blocker. Record a short flat
`evidence/YYYY-MM-DD-<topic>-XXXX.md` when useful, with full commit hash, affected uncommitted
state, commands, database/run identity, observed counts/errors, scope and limits. No raw secrets,
personal data, whole logs, screenshots, binaries or planned checks described as completed.

Final acceptance is judged against the actual permanent criteria linked from
[the integrated index](docs/checklists/integrated-stack.md), not this summary or Luna's self-report.
Behavior definitions and execution results remain separate. The index defines independent-reader
procedure and result states; the change-specific process criteria require chronological evidence,
not retrospective static inference of a Red run. Stable IDs are never deleted or weakened to make
failing code pass; replacements retain reason and successor references.

Final acceptance includes:

- I: all actual app tables classified, correct PK/ID/constraints/index semantics, existing issued
  IDs and external protocols retained, generation/collision/immutability/bulk paths proven,
  executable guards in the existing test/CI path.
- E: six-realm/channel behavior covered, independent policy and explicit issuance times, no durable
  reconstructible/raw OTP, atomic consumption and cross-flow refusal, keyed realm
  isolation/rotation, no legacy fallback, six minimal internal histories and correct
  purge/reuse/hold races.
- F: actual supported ceremony matrix covered, safe request refusal without mutation, attributable
  unsafe violation halts original flow, A/B isolation, terminality, audit, no side-effect growth,
  committed success preserved and final session authority unchanged.
- O: filter positive/negative tests, common logger policy, standard delivery/interceptor/Noticed,
  safe in-memory export allowlist, scrubbers and validated Alloy secondary rules, declared read-only
  mount with runtime disposition, no Sentry/live/production changes, future deployment criteria.
- A: organization-only concrete temporal integrity and immutable history, real COMMIT/concurrency,
  four transfer directions with registry cardinality/global keys, generation-bound N:M Grants,
  app/org provisioning and com separation, deferrals, safe backfill/cutover barrier/recovery.

Keep four exception classes separate: justified permanent external/protocol exception, temporary
consumer compatibility with exit condition, unresolved existing violation, and unverified fact. Do
not reclassify every violation as a permanent exception. An isolated DB limitation means the
database invariant is unverified, not complete. Excluded production deployment is not required for
local implementation completion, but included unverified concurrency or Group semantics prevents
claiming that domain's implementation acceptance complete. Evaluate P10a/P10b, P11a/P11b and
P12a/P12b separately; an incomplete child keeps parent/global acceptance open. P1c static validation
and effective post-recreation runtime verification are separate dispositions. Document definitions,
working-tree saves, local document commits and independent acceptance are four different states.
Missing durable criteria, broken required references or COMMIT_BLOCKED document changes prevent
closing the affected documentation/handoff obligation. Owner/security-review closure requirements
already recorded in broader remediation plans are not satisfied by self-certification.

## 14. Progress, restart, and final report

Use existing owning change specs/plans (Avatar, realm identifiers, observability) for progress; add
an appropriately scoped owning spec only where the significant I/F change has none. This file stays
the single execution instruction; supporting records are evidence/current knowledge, not extra
prompts. Maintain stable local acceptance IDs and cross-references rather than a new global
requirements system.

At every completed slice record: requirement IDs, exact behavior delivered, touched files, migration
version/discovery/application disposition by database, last Red/Green/full-gate commands and
outcomes, iterations since full gate, unfinished acceptance, and the next concrete test. Record
non-trivial choices/rejected alternatives in their owning ADR/spec; optional provisional handoff
context belongs under `research/implementation/`, not a transcript. Promote durable behavior to
docs/checklists and update current Mermaid axes with code; historical evidence is not rewritten to
match new behavior.

### 14.1 Restricted document persistence

The user's editorial authorization permits and requires local commits of only the editor's/Luna's
own changes to `nine.md`, the permanent natural-language acceptance documents, necessary minimal
indexes/document rules and non-secret document-validation/acceptance evidence. It supersedes earlier
blanket commit bans only for these hunks. Application/test/migration/dependency/unrelated
configuration commits, push, PR creation, GitHub editing and Git worktrees remain unauthorized.

Before staging, inspect staged/unstaged/untracked/ignored state and actual path/hunk ownership.
Never use `git add .`, `git add -A` or `git commit -a`; never include existing staged changes or
another contributor's edits. Use explicit owned paths/hunks. `nine.md` was ignored at preparation:
its explicit persistence authorization permits adding that exact document without changing unrelated
ignore rules. Preserve all other work. Inspect hooks for effects before committing; do not bypass
hooks, signing, permissions, read-only mounts or protections, and do not change
credentials/signature/host settings. A hook that cannot safely run within scope or safely stage only
owned hunks is a persistence blocker. No reset/clean/stash/amend/history rewriting is allowed.

If isolation, hooks, signing or permission prevent committing, finish the document edits and record
COMMIT_BLOCKED with paths, cause and smallest resolution. Do not call a saved/staged/tracked file
committed. After success inspect the actual commit object and changed blobs, record the full hash
and exact paths, and verify unrelated index/worktree state remains preserved. Do not imply a local
commit was pushed. A document-only commit is not a reproducible snapshot of uncommitted application
code; evidence must still identify the tested code HEAD and relevant dirty state.

### 14.2 Resume and reporting

After interruption:

1. Recheck Git HEAD/status and ownership of changed files; compare to the saved slice without reset.
2. Read latest owning progress/evidence and actual diff. Revalidate changed dependencies and DB
   identity/migration state before rerunning mutation or cleanup. Do not repeat an operation just
   because its tool response was lost; inspect its result first.
3. Reconcile source claims with tests/schema, recover any incomplete migration/index/cutover safely,
   and run the last relevant focused check.
4. Read each child-phase state and permanent Acceptance ID; do not turn a held P10b into a P10a or
   P11a blocker, or omit P10b from Avatar cutover. Reconfirm P3b's primary-control prerequisites.
5. If the last full result is stale, missing, unfinished or covers a different shared worktree,
   re-run the required full gate before any new feature edit. If unavailable, obey Section 2.3;
   there is no source-only workaround. Resolve new regressions under Gate 3.
6. Reconcile acceptance links, pending document commits and their actual commit objects. Resume the
   next genuinely ready child phase; document-only commits do not certify application execution.

Final implementation report is English and includes:

1. Repository/branch, starting and ending full HEAD, protected working-tree state, delivered
   behavior and effect on users/data. List full owned document commit hashes and exact included
   paths, or COMMIT_BLOCKED and the minimum remedy; confirm no push and no unauthorized code commit.
2. Requirement/phase acceptance and unresolved blockers; decisions/reasons/alternatives, including
   C01's periodic full-test override and remaining scoped compatibility/privacy decisions.
3. Major files, schema/migration versions and the exact disposition of all six Avatar drafts.
   Applied versus prepared-only migrations/backfills, isolated versus real-data verification.
4. Identifier classification/exceptions with ADRs, PK/sequence/index/constraint results and consumer
   compatibility; invariant-to-enforcement mapping, including triggers/SQLSTATE and isolated tests.
5. Avatar D-1–D-11 implementation, all four directions and app/org/com behavior, Grant/Group
   semantics, cutover/write barrier and forward recovery; separately authorized future actions.
6. Actual before/after flow/phase authority, preserved issuance defenses, proven replay gaps,
   binding, GET/mutation distinction, HALT storage/transition/audit, A/B separation, artifact
   rejection and committed-account protection, updated ADR/docs/Mermaid.
7. OTP old/new ownership, retired shared/HOTP paths, six HMAC/ARE configuration contracts, final
   history schemas, fingerprint method, purge transaction boundaries and security/retention
   invariants.
8. Rails public settings and installed OTel version/options, Alloy secondary rules/mount changes,
   delivery/interceptor preservation, pending rebuild/recreate effects and deferred production
   acceptance; Sentry and external sinks unchanged.
9. Every executed test/check command and observed counts/status/timing/coverage, baseline
   differences, exact failed/blocked/skipped/unrun checks and reasons. Distinguish reported historic
   passes from this execution. Full-suite success requires actual current full results.
10. Concrete remaining limitations, deployment ordering and recovery instructions. Avoid blanket
    "all verified", "no problems" or "complete" when included acceptance remains unverified.

Proceed with safe local implementation and verification rather than another indefinite review cycle.
On a design decision hold, finish independent work only while its tests and shared-worktree gates
are current. On a verification hold, restrict work as Section 2.3 requires. Present the smallest
precise decision or environment action needed; incomplete evidence is not permission to accumulate
code. Approval is required only for an actual unapproved consequential action, not routine TDD,
reversible implementation, or already authorized narrow trigger work.

## 15. Preparation review and execution safeguards

The integration review resolved these defects in the source combination before handoff:

- An embedded full-suite prohibition would defeat the main request: C01 and Gates 0–4 replace it.
- Old Avatar draft location/tracking and rejected D-5/D-7/D-8/D-11 plans could cause accidental
  migration/application: exact current draft inventory and P0/P7 gates replace those assumptions.
- A global reset could destroy unrelated Avatar/ID work: E's compatibility waiver is narrowly
  scoped, with disposable verification and real-data destructive approval preserved.
- A blanket NanoID replacement could corrupt secrets, UUID idempotency and existing ceremony
  bindings: semantic classification and consumer migration precede schema tightening.
- Strict flow enforcement could erase committed signup or halt a new flow: original binding,
  terminal absorption, atomic state checks and public regression cases are required.
- Existing bounded OTP receipts could be mistaken for replay permission: fresh consume and original
  pending-operation reconciliation are separate and both remain behind phase admission.
- A naive OTel lambda using symbol keys or returning nil could fail open: installed 0.8.1 transform
  semantics, fixed Hash allowlists and emitted-boundary checks are explicit.
- Setup-only tests could violate repository rules while still failing to prove a mount: direct local
  validation/evidence replaces them without dropping the read-only acceptance criterion.
- Plan checkboxes and older evidence could masquerade as current passes: the preparation snapshot
  explicitly states no runtime tests/DB checks were performed and every phase retains its gates.
- A single unresolved privacy/Group question could block everything or be silently guessed: only its
  dependent subtask remains held, and no global completion claim may conceal that limit.
- Coupled proof, phase, identifier and ownership changes could require repeated redesign: P2 fixes
  classification first, P3 proof before P4/P5 guards, P7 integrity before P8–P10 domain consumers,
  and P12 cutover only after all writers/retention consumers are ready.

The editorial refinement also checks that verification holds stop new feature edits across the
shared tree, that P10/P11/P12 child dependencies agree everywhere, that P3b requires proven primary
Email controls rather than a pending collector remount, and that DB mechanisms are checked against
existing approval before P2. Durable criteria and independent-reader procedures now exist at the
linked paths. Restricted document persistence is required without expanding code/remote authority;
its success is verified from commit objects, separately from application acceptance.

Before marking execution complete, repeat these questions against the **final code and observed
results**, not this document's intentions. Repair discovered contradictions in the owning contract
and implementation while preserving authorization and the full-test cadence.
