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

| Area               | Observed source evidence                                                                                                                                                                                                                                                                                                                              | Current disposition                                                                                                                                                   |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Opaque IDs         | `app/models/concerns/public_id.rb` calls `Nanoid.generate(size: 21)` in create callbacks and validates maximum 21, not standard storage capacity 25; it accepts an already supplied value.                                                                                                                                                            | Partial; no complete generator/DB/classification/collision acceptance established.                                                                                    |
| Avatar             | `AvatarOwnershipPeriod`/`AvatarOwnershipTransfer` still use surface-discriminated legacy references; the ownership spec remains paused with rejected proposals.                                                                                                                                                                                       | Legacy implementation and incomplete drafts; approved replacement is unimplemented in these inspected paths.                                                          |
| Flow enforcement   | `SignFlowBindingCodec` supports only app/com sign-up and signs kind/surface/public ID, without phase/version/expiry. `SignUpPhaseViolationEnforcer` evaluates under a lock, releases it, then calls termination.                                                                                                                                      | Partial. Recheck endpoint phase binding and race behavior; code shape suggests an atomicity question, not a proven exploit.                                           |
| Session issuance   | `AuthenticationBase#commit_login_session!` and `lock_sign_in_flow_for_issuance!` retain flow locking, actor/token/state checks. All three Ticket dumps contain unique non-null `token_id` indexes.                                                                                                                                                    | Existing protection to retain and test. Index uniqueness is not alone proof of one-flow/one-session issuance.                                                         |
| HALTED             | Concrete sign-in state and sign-up status classes already define 930 and terminal mappings; an app sign-up integration test exists.                                                                                                                                                                                                                   | Implemented in some paths, unverified here. Older docs claiming HALTED is absent are stale candidates.                                                                |
| OTP separation     | Independent `EmailOtpPolicy` and `TelephoneOtpPolicy` remain responsible for lockout/failure policy only. Identifier-owned HOTP lifecycle methods and withdrawal proof writes were removed in the P3d runtime slice; legacy physical columns and structural empty-value initialization remain pending a complete forward schema-retirement inventory. | Partial; verify every remaining reader/fixture/constraint before dropping legacy columns. Do not recreate an identifier-owned proof path or silently fall back to it. |
| Realm keys/history | Realm provider, fingerprint verifier, six history models and contract/purge/concurrency tests exist. ADR records six-key/keyring and extensive ceremony work.                                                                                                                                                                                         | Implemented portions, incomplete verification. Historical pass counts are not this execution's evidence.                                                              |
| Observability      | Filter initializer still has ambiguous short Symbols; OTel registers ActionMailer without transforms; common application config search found no mailer logger policy. Alloy redacts URL/auth/token attributes but lacks explicit mail attributes.                                                                                                     | Required remediation remains in the inspected configuration.                                                                                                          |
| Devcontainer       | Read-only `.github`, `bin`, `.devcontainer` mounts exist; no `podman/alloy` directory overlay was found.                                                                                                                                                                                                                                              | Required mount change remains; effective runtime mount unverified.                                                                                                    |

The source review was targeted, not an exhaustive audit of every caller/table/ADR. All supplied
instructions were integrated; remaining local inspection is explicitly required below. Do not
present uninspected rows or historical source reports as current verified implementation.

### 3.1a Host preparation handoff and launch readiness

The final editorial review inspected the worktree at document HEAD
`c4d85867ced5fa261cc7a762d12851893038b7ca`. The user has already added the core `./podman/alloy`
directory overlay to `.devcontainer/compose.yaml`. YAML parsing confirmed `read_only: true`, the
corrected `---` header and preservation of all original mounts. The file was uncommitted; inspected
SHA-256 was `b537eb5250a1114b1149076676cd8cac707510d1b31b01c7feca18d37569b5f7`. This is a separate
later observation, not a rewrite of the original snapshot. Recheck the actual file, preserve the
user's change and do not add a duplicate mount or replace the workspace mount.

The user cannot recreate containers now. Do not restart/recreate them or bypass a protected mount.
This editor did not run Compose rendering, Alloy validation or effective mount tests. A separate
working-tree record reports Compose rendering elsewhere; read its exact scope before reuse, never
represent it as this review's execution. A YAML parser is not a Compose/runtime validator.

The added overlay still declares `selinux: Z`, while Alloy reads the same source through `ro,z`. For
SELinux-enforcing hosts, the private/shared distinction matters: the nested shared source needs
shared labeling, as reflected in Section 9.3's corrected example. Check both consumers and the
parent workspace's existing private relabel behavior when they are later recreated; syntax alone
cannot prove startup-order safety. No root mount/security policy is changed by this document. The
host owner applies the scoped configuration correction; no change to the protected Compose file or
the user's staging is authorized by this editorial review.

P1c remains split into source preparation, direct configuration validation, isolated processor
behavior and post-recreation mount verification. The user's host-only source preparation may precede
P1b; it is neither completed P1c nor a TDD iteration. The graph's P1b prerequisite governs the
remaining integrated verification, not this already-authorized preparatory edit. Finish Alloy policy
changes on the host before recreation where practical. If core cannot write the host-managed source,
prepare an exact minimal patch with its source hash and handoff instructions; do not use a writable
alias or remove the read-only overlay. A pending host action is recorded against MAIL-4/5, not as a
passed P1c. It does not itself invalidate completed Rails/Vitest gates or prevent independent
isolated work; unavailable required full suites still stop feature edits under Section 2.3.

Launch dispositions:

- **P0 investigation may start:** the instruction and permanent criteria exist. Revalidate the
  moving worktree, migration discovery, test isolation, safe test transport/export and command
  catalog. Coordinate overlapping writers; do not execute a full suite while another worker is
  changing its source/schema and then claim the result covers a stable final state.
- **Feature editing is conditional:** Gate 0 must actually finish with classified failures, and the
  selected slice must have its exact mechanism permissions and runnable focused/full checks. This
  review did not establish those runtime prerequisites or certify the model's future success.
- **Full completion is not currently pre-certified:** Group evidence, any uncovered permanent-ID DB
  enforcement permission, real isolated COMMIT/concurrency, MAIL-4/5 runtime checks and final checks
  must have their own dispositions. The repository knowledge checker currently fails on eight
  pre-existing `.claude/skills` adapters. Its owner must restore those adapters for that check to
  pass; do not repair unrelated harness work or relabel this failure as PASS. A documented unrelated
  document-check failure does not waive or replace any Rails/Vitest gate.

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
  Chronicle self-generated UUIDs. These are candidates to confirm, not pre-established defects. The
  read-only catalog starting point is `bundle exec rails identifiers:inventory` with a run-owned
  isolated test manifest. It writes a JSON report under `tmp/` and never reads application rows or
  changes schema/data. Its table/PK/sequence/index facts do not replace the required semantic
  classification, producer/consumer mapping, or external-exception review.
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

#### Post-decision addition — P6/P12a implementation aid and user decisions (2026-10-12)

This note records read-only observations that shorten the P6 inventory, followed by four user
decisions made on 2026-10-12 that close questions Sections 5.1–5.3 left open. The observations are
hints to reconfirm, not evidence. The decisions are scoped contract clarifications: they grant no
SQL/trigger authority, real-data operation or destructive permission beyond what this document
already grants. Every figure comes from the catalog report
`tmp/identifier-contract/final-inventory.json` (generated 2026-10-12T02:41Z against the run-owned
isolated fleet); the report is ephemeral and predates later migrations.

Catalog facts already collected by `identifiers:inventory`:

- 891 tables on 20 writer connections: 53 framework-owned (Rails, Solid Queue) and 838 still
  labelled `requires_owner_review`. Of those 838, exactly one has a non-bigint primary key:
  `org_zenith.staff_identity_audit_events` (`id` varchar).
- 2,592 name-based candidate columns across those 838 tables, but only 269 distinct column names. By
  type: 2,028 bigint, 550 varchar, 9 uuid, 4 int4, 1 bytea.
- 238 `public_id` columns: 183 `varchar(21)`, 52 unbounded `varchar`, and one each of `varchar(255)`
  (`app_zenith.clients`), `varchar(25)` (`org_zenith.operator_telephones`) and `varchar(16)`
  (`org_zenith.operators`). Five are nullable: `client_preferences`, `visitor_preferences`,
  `operator_preferences`, `client_passkeys` and `operator_telephones`.

Suggested order, to keep the semantic half finite:

1. Classify by distinct column name first, then confirm per table only where one name carries more
   than one meaning. The 269 names, not the 2,592 columns, are the unit of judgment.
2. Treat the bigint `*_id` columns as a single question: is each one a same-database reference, or
   does it cross a database boundary (C06)? Record only the crossings.
3. Spend producer/consumer tracing on the roughly 560 varchar/uuid candidates, where the eight roles
   actually differ: `public_id`, `*_public_id`, `*_ref`, `transaction_id`, `grant_jti`,
   `result_jti`, `jti`, `event_uuid`, `webauthn_id`, `external_id`, `state`, `code`.
4. Settle table ownership for the 838 `requires_owner_review` tables in the same pass, so that the
   classification SSOT and the unclassified-candidate guard (Section 5.3) can be written once.

User decisions. Record each in `adr/identifier-contract.md` and
`docs/reference/identifier-conventions.md`, and align the wording of ID-2 and ID-4 in
`docs/checklists/identifier-contracts.md`, before the dependent slice:

- **Existing `varchar(21)` stays.** The 183 existing `varchar(21)` `public_id` columns are not
  widened. Issuance is fixed at 21, so the column holds every issued value; this is the recorded
  reason, and it makes those columns a documented conforming capacity rather than a violation.
  Columns created from now on use capacity 25. P6 therefore contains no wide capacity migration.
  Storage-boundary tests use each column's actual bound (20/21/22 for these, 24/25/26 for new ones).
- **Unbounded and outlier columns are bounded to 25 after checking.** For the 52 unbounded
  `public_id` columns and the 255/16 outliers, aggregate maximum length and trace consumers in the
  isolated fleet first (Section 5.2). Bound a column to 25 only when no stored or accepted value
  exceeds it. A column whose values exceed 25, or which turns out to be a human-entered code or
  another non-owned role, keeps its bound and is recorded under its true exception category. Never
  truncate or reissue.
- **Nullable owned identifiers become NOT NULL in P12a.** For `client_preferences`,
  `visitor_preferences`, `operator_preferences` and `client_passkeys`, first confirm the column is
  an owned permanent identifier. If it is, follow the `operator_telephones` pattern: a bounded,
  restartable NULL-only backfill, then NOT NULL, rehearsed on the isolated fleet. Real-data
  application remains separately approved. This decision adds no immutability trigger: the approved
  one-table trigger exception still covers `operator_telephones` only, and any further
  database-enforced immutability stays a named decision hold under Section 3.3 step 6.
- **`staff_identity_audit_events`** is not a new decision: Section 5.3 already requires the staged
  bigint transition that preserves existing values and references. It belongs to P12a.

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

#### Post-decision addition — signal only, outside this implementation scope

The user has identified Rails 8.2's combined credentials API (`Rails.app.creds`) as the intended
configuration approach for the six HMAC keys listed above: environment values take precedence, with
Rails encrypted credentials supplying the same keys when environment values are absent; development
also includes Rails' supported `.env` lookup. Missing required keys must still fail closed, without
legacy global-key fallback or default secrets.

This note records a post-decision signal, not an additional implementation requirement. It is
excluded from this plan's implementation slices, acceptance criteria and acceptance tests. Do not
add credential-resolution work or tests to the current scope on the basis of this note, and do not
change existing configuration merely to match it. Any later adoption or verification belongs to a
separately scoped change; the current six-key isolation and fail-closed contracts remain in force.

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

Ensure exactly one nested directory bind in `.devcontainer/compose.yaml`; preserve the existing
workspace and other mounts. Section 3.1a records the user's already-added declaration. For this
source shared with Alloy, the intended SELinux label is shared `z`, not private `Z`:

```yaml
- type: bind
  source: "./podman/alloy"
  target: "/home/global/workspace/podman/alloy"
  read_only: true
  bind:
    selinux: z
```

Use the real root-first Compose project resolution, following the existing guarded mount pattern.
[Podman's volume documentation](https://docs.podman.io/en/v5.6.2/markdown/podman-run.1.html)
distinguishes shared `z` from private `Z`; confirm the actual host/provider and both consumers'
access under its SELinux policy, including parent-directory relabeling and recreation order. Retain
the Alloy container's read-only config file source. Host-managed policy remains readable but not
writable from core. Do not bypass a currently read-only mount to edit host configuration; finish an
exact patch and report that application as blocked if this environment cannot write the source. The
user will rebuild/recreate; do not publish reload/management ports, send SIGHUP, add Rails config
notifications, or implement reload API machinery. Effective remount after recreation is not proven
by a YAML edit; state pending runtime acceptance separately.

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

### 10.1 Implementation dependencies versus activation dependencies

The graph orders implementation/proof readiness; it does not authorize consumer cutover when a new
class exists. P8/P9 can build and test concrete models, registry and operations against synthetic
complete ownership data. They cannot replace current readers/writers for retained data before P12b's
inventory, backfill, reconciliation and writer-control checks. New transfer admission must not
become reachable before the P10a/P10b Grant/Group consequences it invokes are correct and commit in
the same Avatar transaction. Preserve existing authorized behavior until the explicit cutover; after
cutover no legacy authority fallback is permitted. Do not introduce a second owner SSOT, generic
feature-flag framework or silent dual-read to satisfy this staging rule.

Likewise, P6 proves identifier changes on isolated representative data before P12a applies the
consumer transition. P12a/P12b apply to verified disposable rehearsal here; production and shared
retained-data operations still require their separate authority. A synthetic migration rehearsal is
not a claim that existing data has been converted. Fixtures/provisioning and every admitted writer
must satisfy the new constraints at the same slice boundary; never activate an incomplete writer and
defer its predictable regressions to a later phase.

Before P7's first DB change, inspect the existing full-suite fixture/cloning/cleanup path as well as
the new real-COMMIT harness. Prepare uniquely owned disposable verification through existing
mechanisms; ensure immutable-history tests neither leak into shared catalogs nor rely on disabling
integrity triggers to clean them. An unavailable isolation mechanism is a verification hold, not a
reason to apply the prototype to a shared DB. This does not authorize editing the authentication
hardening's protected test_helper or bypassing constraints.

P2 includes the DB-enforcement/authority map before touching any dependent invariant. P3c learns
only pure-primitive lessons from Email and has no stateful-policy dependency on P3b. P7 must
demonstrate real integrity before P8/P9 depend on it; no source-only prototype substitutes for this
prerequisite. When children touch the same RetentionPurgeJob, shared writer or authorization
boundary, serialize those edits and run the relevant neighboring regressions and both full suites.
Record any additional actual consumer dependency in the owning spec and this graph/table together;
do not invent a domain change or delete a safety dependency to make work appear independent.

| Phase                                | Purpose, concrete scope and prerequisite                                                                                                                                                                                                      | First Red / direct check                                                                                                                   | Acceptance, tests and exit                                                                                                                                                                                                                                                                                                                                                                                      |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P0 — reconcile and baseline          | Current Git/env/rules; six draft audit; inventory; amend Avatar spec and governing conflicts. No model/schema edit before reconciliation and DB guarantee/approved-mechanism mapping.                                                         | Direct read-only checks, then Gate 0; no artificial test for planning/setup.                                                               | Snapshots, conflict dispositions, command catalog, current failure list and protected-worktree inventory recorded. No incomplete migration discovered/applied.                                                                                                                                                                                                                                                  |
| P1a — filter behavior                | Filter initializer and existing `test/unit/security/filter_parameter_logging_test.rb`; real nested keys.                                                                                                                                      | `reason_code` is retained while `code` and nested secrets are filtered.                                                                    | All positive/negative keys and boundaries pass; no unnecessary lost observability. Gate 2 at slice end.                                                                                                                                                                                                                                                                                                         |
| P1b — mail export                    | Common mailer setting, OTel initializer, existing scrubbers, concrete mailers/interceptor; P1a and installed source inspected.                                                                                                                | Synthetic OTP/subject/args absent from captured application log/span while test delivery succeeds; direct boot policy check.               | All three surfaces, unknown payload keys, suspension/failure/retry and existing delivery semantics verified; no private override. Immediate full gate after common config.                                                                                                                                                                                                                                      |
| P1c — collector/mount/docs           | Alloy and devcontainer configuration; P1b. Preserve the user's overlay; host application and runtime checks follow Section 3.1a.                                                                                                              | Direct pinned Alloy config validation and rendered Compose mount check; no setup unit test.                                                | Supported redaction, correct source/target/read_only, no reload changes; runtime remount explicitly unverified until recreate. ADR narrowed and future production criteria recorded. Full gate after build/config change.                                                                                                                                                                                       |
| P2 — identifier foundation           | PublicId concern, existing Nanoid mechanism, model/test classification and prospective new schemas; P0 and the per-invariant DB-enforcement/authority map. Hold only an invariant needing new permission; no blanket trigger authority.       | New internal issuance is 21 and ordinary public create cannot inject an arbitrary owned ID; exact collision discrimination test if absent. | Generator mechanism, eight-role manifest and exception categories established; targeted public-ID/collision tests and immediate shared-Concern full gate. No broad automatic model rewrite.                                                                                                                                                                                                                     |
| P3a — channels and keys              | Independent policies, six identifier models, realm key provider/rotation and ARE inventory; P2.                                                                                                                                               | Resend at existing failures preserves count; cross-realm equal normalized input yields distinct digest; add only missing regressions.      | MAX boundaries, explicit Telephone timestamps, independent policy and rotation tests pass. Boot/key wiring direct evidence; full gate per slice.                                                                                                                                                                                                                                                                |
| P3b — Email proof                    | Concrete Email ceremony/issuer/verifier/finalizer/notifier/mailer paths, APP/COM signup/signin and applicable recovery/withdrawal/registration; P1a/P1b/P3a with the primary-control evidence specified above, not pending P1c remount.       | Wrong purpose/session code refused without consumption, followed by valid original consume; later retry is receipt, not fresh success.     | Migrate one purpose per slice; fault/deadline/delivery tests prove keyed binding and no HOTP fallback. Source/Ticket fault consequences recorded. Full gate per slice.                                                                                                                                                                                                                                          |
| P3c — Telephone proof                | Independent Telephone ceremonies and existing bound SMS transport; P3a, Email design lessons only as pure primitives.                                                                                                                         | Concurrent verification consumes at most once; resend preserves attempt count and original expiry.                                         | Each supported realm/purpose, independent lockout/cooldown, original binding and stale worker refusal verified. No shared stateful policy. Full gate per slice.                                                                                                                                                                                                                                                 |
| P3d — proof retirement               | Remaining policies, six identifier schemas/fixtures, all legacy proof/envelope readers/writers; P3b/P3c and complete consumer inventory.                                                                                                      | Public paths work with no identifier HOTP fields; obsolete payload rejected through real consumer.                                         | Remove legacy runtime methods coherently; prepare forward schema retirement, applying destructive drops only in verified disposable DB or separately approved scope. Do not edit applied history. Full schema gate.                                                                                                                                                                                             |
| P3e — live identifier integrity      | Six models, source constraints, current purge interfaces; P3d.                                                                                                                                                                                | Two normalized-equivalent concurrent creates yield one live identity binding; conflicting transaction rollback stays usable.               | Email/Telephone in all realms; delete/create/reuse and status partitions verified with actual PostgreSQL. Immediate shared-model/schema gate.                                                                                                                                                                                                                                                                   |
| P4 — authoritative phase core        | Codec/gate/enforcer/state writer/audit and app/com signup entry/step paths; P3e.                                                                                                                                                              | Stale bound mutation racing an advance cannot affect committed completion; old A submission leaves B intact.                               | Locking decision atomic, signed original instance/phase/generation, exact GET refusal, non-GET halt and safe audit. Existing issuance retained; immediate security full gate.                                                                                                                                                                                                                                   |
| P5 — family/surface coverage         | Sign-in locators/gates, primary ceremonies, callbacks, MFA/capacity/checkpoint/selector, finalization; P4.                                                                                                                                    | Choose next actual family from matrix: stale phase request creates no artifact/session and refuses without touching replacement flow.      | One family/surface per slice, explicit unsupported cells, all Section 7 cases and diagrams; no new credential method. Immediate full gate after each shared boundary.                                                                                                                                                                                                                                           |
| P6 — identifier consumers/DB         | Inventory-driven model/column/index/PK/sequence changes, APIs/jobs/events and current ceremony IDs; P2/P5. Catalog facts start at `identifiers:inventory`; semantic ownership and consumer evidence must be reconciled before schema changes. | Next concrete owned-ID DB bypass or consumer-format mismatch fails at public boundary.                                                     | One meaning/consumer group per slice; external exceptions and existing IDs preserved, correct indexes/constraints, no remote bigint addition. PK/sequence/partition work isolated and verified; full gate per schema slice.                                                                                                                                                                                     |
| P7 — ownership integrity prototype   | Six reworked drafts, trigger ADR and isolated DB harness; P0/P2, reviewed complete migrations only.                                                                                                                                           | Real COMMIT with cross-family overlap/gap/missing owner fails with expected SQLSTATE; sequential and concurrent valid chain commits.       | Initial/closed-history/adjacency/direct-SQL/RC/RR/Serializable invariants proven. Stop downstream ownership implementation acceptance if fundamental integrity cannot be enforced. Full gate after schema/prototype slice.                                                                                                                                                                                      |
| P8 — concrete ownership models       | Avatar/period associations, ownership resolver/provisioning, concrete remote public references; P7.                                                                                                                                           | New Avatar without an owner cannot commit; valid app/org provisioning preserves all identities and com has no dependency.                  | Concrete model/Ruby interfaces proven; retained-data reader/writer activation waits for P12b. Account/Group unresolved semantics not guessed. Full gate after resolver/model slice.                                                                                                                                                                                                                             |
| P9 — registry and transfer           | Shared registry plus four concrete detail models and Request/Accept/Cancel, minimal transports; P8.                                                                                                                                           | Concurrent same-key requests across two families cannot create two operations; changed payload/initiator is refused.                       | Direct-SQL cardinality, global pending/key uniqueness, four directions, five-day boundaries, generation/authority rechecks, atomic periods and retry semantics proven in isolation; admission waits for P10a/P10b/P12b. Keyless transition documented. Immediate full gate.                                                                                                                                     |
| P10a — Grants (P10)                  | Existing Binding semantics, concrete N:M Grants/policies/provisioning; P9. Group conversion is not a prerequisite.                                                                                                                            | Grant from first O1 period stays ineffective after O1→O2→O1 while a new authorized Grant works.                                            | Management/Binding meaning preserved; concrete subject/period/capability checks and N:M success, no revival. Full authorization/model gate; Group effects separately remain P10b.                                                                                                                                                                                                                               |
| P10b — Group semantics (P10)         | Account/owner reader and writer conversion; P9 plus authoritative Group semantic evidence. The additive `avatar_group_concrete_ownership_periods` table, explicit source selector, and bounded inventory/backfill are part of this slice.     | Distinct selected-account context survives an ownership change without becoming an alternative owner authority.                            | Actual semantics preserved; incompatible Group access refused; all consumers reconciled. The legacy Group period is not excluded from the barrier; it remains the pre-cutover source and is replaced only after the concrete copy is verified. Hold this child when a domain choice is missing; it blocks Avatar cutover P12b, not P10a. Full gate after each affected writer/policy slice.                     |
| P11a — dead identifier history (P11) | Six histories, identifier purgers and legal/retention holds; P3e. No Avatar prerequisite.                                                                                                                                                     | A refusal after history INSERT rolls back archive and physical removal together.                                                           | Minimal schema, original-PII fingerprint, internal visibility, reuse and concurrent purge/create behavior across six models; authorized whole-owner semantics preserved. Focused real-DB checks and full gate per lifecycle slice.                                                                                                                                                                              |
| P11b — Avatar deferral (P11)         | RetentionPurgeJob and existing/new concrete deferral; P8. No identifier-history prerequisite.                                                                                                                                                 | Repeated eligible Avatar purge records one actionable deferral without deleting Avatar/history.                                            | Observable idempotent state and preserved history; personal-data policy remains explicitly undecided. Serialize shared retention edits with P11a and run neighboring tests plus full gate.                                                                                                                                                                                                                      |
| P12a — identifier transition (P12)   | Identifier inventory, bounded backfill/consumer transition and recovery; P6/P11a. No Avatar decision dependency.                                                                                                                              | Repeated isolated migration preserves issued identifiers/references; ambiguous data stays unchanged and reported.                          | Fresh migration/schema verification, constraints and sequence safety, documented compatibility exits and rollback/forward-fix. No broad reset or real-data application. Full gate after each transition boundary.                                                                                                                                                                                               |
| P12b — Avatar transition (P12)       | Operational Avatar and Group backfill, explicit `avatar_ids` plus `group_ids` cutover inventory, writer quiescence, legacy barrier and forward recovery; P9/P10a/P10b/P11b.                                                                   | Repeated isolated backfill preserves history; ambiguous row is refused; ordinary-role writes fail only after verified cutover.             | Rebuild/dump/restore including triggers; all ownership/Group writers controlled; INSERT/UPDATE/DELETE/TRUNCATE barrier tested. `AvatarOwnershipCutoverOperation` cannot establish the marker without an explicit Group inventory, and post-marker Group reads/writes select the concrete table without legacy fallback. No production cutover or automatic Phase G deletion. Full gate per transition boundary. |
| P13 — acceptance and handoff         | All executable guards/docs/checklists/diagrams/evidence and complete current diff; predecessor gates.                                                                                                                                         | Run actual final commands, not a new artificial Red.                                                                                       | Gate 4; every requirement has evidence or explicit incomplete disposition, no new regression and no false global completion. Final report in Section 14.                                                                                                                                                                                                                                                        |

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
   P11a blocker, or omit P10b from Avatar cutover. Reconfirm P3b's primary-control prerequisites,
   Section 10.1 activation boundaries and Section 3.1a's pending host/runtime handoff. Do not
   mistake the user's source edit, a new class or a past YAML check for activated acceptance.
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

The final adversarial pass additionally separates model/operation construction from writer/read
activation so P8/P9 cannot bypass P10/P12; makes fixture/isolation feasibility an early P7 check;
and records the user's source-only mount preparation without claiming runtime enforcement. The
shared-source SELinux example is corrected, not a change to a business/security acceptance contract.
Gate 0, permission mapping and later real execution remain conditions, so this review cannot promise
an uninterrupted or globally blocker-free implementation.

Before marking execution complete, repeat these questions against the **final code and observed
results**, not this document's intentions. Repair discovered contradictions in the owning contract
and implementation while preserving authorization and the full-test cadence.

## 16. Post-decision additions — observed risks before resumption (2026-10-12)

A read-only pre-acceptance review inspected the worktree at HEAD
`ccceabd05d2e3a8f923ce398046f99d026a5b78e` plus its uncommitted changes while implementation was
paused. No Rails or Vitest suite was run by that review. Each item below states an observation, the
existing clause that already governs it, and the expected handling. Observations are hints to
reconfirm against the current tree, not evidence and not acceptance results. Except for the one user
decision in 16.7, nothing here adds a requirement or authority; where an item and Sections 1–15
appear to differ, Sections 1–15 govern. The identifier decisions live in the Section 5.3 addition.

### 16.1 Phase-refusal copy is hard-coded on the sign-in side (F, FLOW-2)

`SignInPhaseBindingControllerSupport#refuse_sign_in_phase_request!` and `OrgNormalSignInTransaction`
render the Japanese refusal as a string literal. `SignUpFlowEntry` already renders
`errors.messages.phase_violation_refused`, and that key exists in all four locale bundles. Section
7.3 requires the explicit translation key with the exact Japanese value. Route both sign-in paths
through the existing key, forcing the Japanese locale as the sign-up path does, so the response body
does not vary with the request locale. Keep status, media type, no-store and absent Location
unchanged, and cover it in the P5 slice for the family being edited.

**Resume recheck (2026-10-12):** both sign-in refusal implementations now call
`errors.messages.phase_violation_refused` with `locale: :ja`; the App public-boundary test requires
that call and the exact response contract. The focused slice and the subsequent Rails/Vitest full
gates passed in `evidence/2026-10-12-auth-and-avatar-resume-R4M2.md`. This is implementation
evidence for the current dirty tree, not an independent acceptance result.

### 16.2 Registry transfer admission is already reachable (A, Section 10.1)

The app and org `AvatarOwnershipTransfersController` select the registry operations whenever the
request carries an `Idempotency-Key` header (`registry_request?`), and `transfer_kind=registry`
selects registry Accept and Cancel. New admission is therefore reachable now, before P10b and P12b
are complete. `RegistryAcceptOperation` removes Group memberships with a different owner and writes
the legacy period while `AvatarOwnershipPeriodSource.legacy?` holds; the review found no explicit
Grant step there and did not establish whether generation binding alone makes prior Grants
ineffective in that path.

Section 10.1 says new transfer admission must not become reachable before the Grant and Group
consequences it invokes are correct and commit in the same Avatar transaction. Before P12b, either
prove through the public HTTP interface that the registry path already satisfies that sentence
(O1→O2→O1 Grant non-revival and incompatible Group access refusal, in one Avatar transaction), or
keep registry admission unreachable until it does. Do not add a generic feature-flag framework or a
silent dual-read to do so (Section 10.1). Record which of the two was done in the owning spec.

**Resume recheck (2026-10-12):** the app and org public transfer controllers now reject registry
request/accept/cancel admission until `AvatarOwnershipCutover.established?` is true. The registry
operation tests therefore remain implementation tests, not evidence that pre-cutover admission is
active. P10b/P12b still require their own Group/Grant consequence and cutover evidence before the
marker can be established.

### 16.3 ORG live uniqueness has a different shape from APP and COM (E, CONTACT-6)

`client_emails`, `client_telephones`, `visitor_emails` and `visitor_telephones` enforce live
uniqueness with a partial unique index on the digest restricted to finalized, unreleased bindings.
`operator_emails` and `operator_telephones` instead carry a unique index on the digest wherever it
is non-NULL, and the ORG tables have no `binding_finalized_at`/`binding_released_at` columns. The
difference may be intended. Establish it rather than assume it: in P3e, show for ORG as well that a
logically retired identifier does not block a legitimate new live binding, and that delete/create
and dead-identifier reuse behave as Section 6.3 requires. Use semantic status constants, and do not
copy the APP/COM predicate onto ORG without evidence that the ORG lifecycle matches.

### 16.4 The realm plan still shows four unchecked acceptance items (E)

`specs/realm-separated-identifiers-and-dead-history/plan.md` leaves unchecked: the independent
Email/Telephone policy series, ceremony-owned keyed verifiers for every applicable route, atomic
hold-aware purge with database-enforced normalized live uniqueness, and the final documentation and
verification item. The legacy `otp_private_key`/`otp_counter` columns no longer appear in the
structure dumps and ceremony proof-immutability triggers exist, so part of this may be a stale
ledger. Reconcile each item against current tests and evidence: check a box only with a
revision-scoped evidence pointer, and name the missing public test for anything left open. This
closes P3a–P3e and P11a honestly; it is not new scope.

### 16.5 The six Avatar drafts need a final recorded disposition (A, C03, MIG-2)

The six files remain tracked under `specs/avatar-organization-ownership/migration-drafts/` while the
working migrations now live in `db/avatars_migrate/` under different versions. The spec's
"Historical draft disposition" table still describes them only as written or empty stubs. For each
draft record in the owning spec: the successor migration version or versions that replaced it, or
that it was abandoned and why; whether its version ever entered any retained database's history; and
that it stays outside migration discovery. Do not delete the drafts (C03) and do not restore them to
discovery. Section 14.2 item 3 of the final report depends on this table.

**Resume recheck (2026-10-12):** the independent Group transition inventory slice now classifies
legacy or concrete histories with a missing owner, invalid interval, wrong initial boundary, more
than one open period, or an interruption between adjacent periods as `conflict`/manual review. The
bounded backfill does not invent a boundary or establish cutover. The focused slice passed
`8 runs, 36 assertions, 0 failures, 0 errors, 0 skips`; the subsequent Rails and Vitest full gates
also passed. See `evidence/2026-10-12-avatar-group-inventory-S7H2.md`. This closes a migration
safety defect in the independent P10b preparation work; it does not resolve Group account meaning or
authorize P12b cutover.

### 16.6 Email observability host handoff status (O, MAIL-4/MAIL-5)

The host owner changed the `./podman/alloy` overlay label in `.devcontainer/compose.yaml` from `Z`
to `z` on 2026-10-12. The change is uncommitted and is the host owner's to commit. The static result
is recorded in `evidence/2026-10-12-alloy-overlay-label-static-check-K7R3.md`: merged Compose render
PASS, host has no SELinux. Still NOT_RUN: pinned Alloy syntax validation, the effective read-only
mount inside `core`, and collector processor behavior. The overlay is not mounted in the running
container, so `podman/alloy` is currently writable from `core`; do not write there. These dynamic
checks happen at the user's next recreation and are recorded against MAIL-4/MAIL-5; they do not
block isolated P3b work (Section 10).

### 16.7 Gate 4 static status, and one user decision on unrelated repairs

Run on 2026-10-12 against the paused tree, by the review:

- PASS: `bin/brakeman` (0 warnings), `bundle exec erb_lint --lint-all`,
  `scripts/check-repository-knowledge`, `bun run format:check`, `lint`, `typecheck:verify`,
  `typecheck`, `openapi:lint`, and an OpenAPI rebundle that left `openapi/` without differences. The
  eight-adapter knowledge-checker failure named in Section 3.1a no longer reproduces.
- `bin/rubocop` reported one remaining offense, `Metrics/AbcSize` on `verify_telephone_via_otp!` in
  `test/controllers/auth/app/up/checkpoint_passkeys_controller_test.rb`. The review replaced that
  helper's hand-built binding comparison with the file's existing
  `refresh_sign_up_flow_binding_from_redirect!`. RuboCop passes on that file. **The Rails tests in
  that file were not run after the edit**; run them before relying on it.
- `bun run deadcode` failed on two false positives (a manually started Vite fixture config, and
  `bin/rails` passed to `execFileSync`). The review added the config to `entry` and `bin/rails` to
  `ignoreUnresolved` in `knip.json`; `deadcode` then exits 0. Both edits are uncommitted and outside
  Luna's commit authority (Section 14.1).
- Not run by the review: both full suites, `bun run test:coverage`, the CI invariant selection, the
  server boot smoke, `bin/bundler-audit` and `bun audit`.

**Resume update (2026-10-12):** after the review, the affected focused authentication slice passed
(`30 runs, 259 assertions, 0 failures, 0 errors, 0 skips`), the four-worker Rails suite passed
(`15084 runs, 128057 assertions, 0 failures, 0 errors, 0 skips`), and Vitest passed (`99 files`,
`1140 tests`). These results do not close the remaining schema-drift, isolated
committed-transaction, host-runtime, Group/cutover, identifier-transition, or privacy-retention
dispositions.

Still open for Gate 4, from earlier evidence rather than this review: `db:verify_no_schema_drift`
reported `db/avatar_structure.sql` and `db/org_zenith_structure.sql` as dirty, which Section 12
expects for intended uncommitted migrations but requires to be explained per dump; and
`bun run test:coverage` exited non-zero on the existing 99% branch and function thresholds while all
tests passed.

### 16.8 Resume update — ORG Telephone NOT NULL transition (P12a, 2026-10-12)

Following Section 14.2, the ORG Telephone `public_id` transition was resumed as an independent P12a
slice. A public model contract first produced an expected Red because the existing
`operator_telephones.public_id` column was still nullable. A one-step metadata migration was
rejected by Strong Migrations; it was removed before application and replaced with two generated,
reviewed migrations. The first adds a `NOT VALID` `public_id IS NOT NULL` check. The second
validates the existing nonblank check and the new check before changing the column to `NOT NULL` and
removing both transitional checks. A stale NULL or whitespace value fails the transition; no
identifier is invented or rewritten by schema DDL. A reversibility rehearsal initially exposed that
the second migration's `down` restored only the nonblank check; the `down` was corrected to restore
both transitional checks, then exercised successfully in the run-owned database.

The migrations applied successfully to the run-owned test manifest. The focused ORG identity and
backfill slice passed `9 runs, 56 assertions, 0 failures, 0 errors, 0 skips`, and targeted RuboCop
reported no offenses. Because the final column contract forbids constructing NULL rows, the current
backfill tests assert that the retained operation is a post-cutover no-op and never regenerates an
existing identity. The pre-cutover NULL-only assignment, exact-constraint collision retry and
exhaustion behavior remain covered by the prior run-owned evidence
`evidence/2026-10-11-org-telephone-identity-backfill-K6V2.md`; that evidence is historical and is
not a production cutover claim.

The ORG and Avatar structure dumps were regenerated through the Rails schema-dump tasks. The
schema-drift command still reports both files as dirty because these intentional generated changes
remain uncommitted; this is recorded rather than treated as a clean committed-schema gate. The
combined focused migration/Group slice passed
`17 runs, 92 assertions, 0 failures, 0 errors, 0 skips`, and the corrected four-worker Rails full
gate passed `15085 runs, 128036 assertions, 0 failures, 0 errors, 0 skips`. Vitest passed
`99 files, 1140 tests`. See `evidence/2026-10-12-org-telephone-not-null-cutover-N8Q4.md` for
commands and limits.

This closes only the disposable-schema NOT NULL rehearsal for the ORG Telephone candidate. It does
not establish writer quiescence, proof-drain completion, consumer cutover, ORG delete/recreate
semantics, the remaining P12a identifier inventory, D-11 committed-transaction coverage, host Alloy
runtime verification, or the unresolved privacy-retention and Group-account decisions.

### 16.9 Resume update — owned preference and Client Passkey NOT NULL transition (P12a, 2026-10-12)

Following Section 14.2 and the post-decision P12a direction in Section 5.3, the four nullable
owned-identity candidates were handled as one bounded schema slice: `client_preferences.public_id`,
`visitor_preferences.public_id`, `operator_preferences.public_id` and `client_passkeys.public_id`.
The public model contract was established before the implementation. The explicit
`PublicIdNullOnlyBackfillOperation` assigns a NanoID-21 only to a selected pre-cutover NULL row,
preserves existing values and source attributes, uses bounded named-constraint retry, and is not a
normal read/create/update repair path. The final migrations add and validate `NOT VALID` checks,
then enforce `NOT NULL` and remove the temporary checks; each reverse path restores both checks and
nullable metadata. No existing identifier was truncated, regenerated or changed by schema DDL.

The focused P12a contract/operation/model slice passed
`54 runs, 159 assertions, 0 failures, 0 errors, 0 skips` with the run-owned isolated PostgreSQL
manifest. A controlled disposable pre-cutover NULL rehearsal assigned exactly one identifier
(`assigned: 1, missing: 0, generated_length: 21`) before the final constraints were restored. Three
migration down/up rehearsals passed. The fresh-schema inventory reported zero NULL and zero blank
values for all four columns. The Rails full gate after this slice passed
`15092 runs, 128072 assertions, 0 failures, 0 errors, 0 skips` with four workers, and Vitest passed
`99 files, 1140 tests`.

This closes only the isolated P12a NOT NULL rehearsal for these four candidates. It does not claim
real-data application, all-table identifier acceptance, permanent DB immutability, consumer cutover,
the remaining P12a inventory or a clean committed-schema gate. The durable acceptance definition is
[ID-4b](docs/checklists/identifier-contracts.md#id-4b--owned-preference-and-client-passkey-identities-become-required);
see `evidence/2026-10-12-identifier-transition-L3M7.md` for the bounded commands and limitations.

### 16.10 Resume update — staff identity audit-event bigint staging (P12a, 2026-10-12)

The remaining cataloged non-bigint application primary key was then resumed as an independent,
identity-preserving staging slice. `org_zenith.staff_identity_audit_events.id` remains the
authoritative string key while the additive migration
`20261012085039_convert_staff_identity_audit_events_to_bigint.rb` adds `legacy_id` and `id_bigint`,
and `staff_identity_audits.event_id_bigint`, with reviewed indexes. The first contract test produced
the expected Red against the empty migration; the implementation then provided a bounded restartable
`StaffIdentityAuditEventBigintBackfillOperation` with explicit dry-run mode. It keeps the old code,
maps audit references only when the event mapping exists, rejects conflicting or missing mappings,
and makes no PK/FK cutover claim.

The focused transition and operation tests passed
`4 runs, 28 assertions, 0 failures, 0 errors, 0 skips`. A run-owned migration down/up rehearsal
passed, including removal and recreation of all three additive columns and their indexes. The
synthetic mapping test preserved the string event code, assigned one bigint mapping, mapped the
audit reference exactly once, and was idempotent on repeat. A current run-owned dry run returned
zero missing and unresolved mappings. The additive stage is recorded in the durable `ID-4c`
acceptance condition and the identifier reference/workflow documents.

This does not establish the final bigint primary-key/foreign-key replacement, consumer migration,
real-data backfill, production/shared-data application or complete ID-1 acceptance. The next P12a
step must inventory every consumer and define a reviewed cutover/recovery boundary before any old
key is retired. Full Rails/Vitest gate results for this new schema slice must be recorded after the
required Gate 2 execution; those results are recorded in Section 16.11. The slice is focused- Green
and full-gate verified for the current staged schema, but not final-cutover complete.

### 16.11 Gate 2 result after staff-event staging (P12a, 2026-10-12)

The first Gate 2 recheck after the final staff-event test assertion observed one unrelated failure
in the existing `SignUpExpiryJobTest` timing case (`15096 runs, 128106 assertions, 1 failure`). The
named test passed separately with the same run-owned manifest using both one and four workers
(`6 runs, 16 assertions, 0 failures, 0 errors, 0 skips`). No application repair was made for that
unrelated observation. The first parallel process also refused worker-database cleanup while
transient connections were present; after the process ended, the four run-owned worker databases
were cleaned through the repository helper after ownership, identity, comment and
no-active-connection checks.

The required Gate 2 was then rerun with four workers against all twenty run-owned databases and
completed successfully: `15096 runs, 128109 assertions, 0 failures, 0 errors, 0 skips`. All four
worker receipts recorded completed cleanup. Vitest was rechecked with `bun run test` and passed
`99 files, 1140 tests`. Targeted RuboCop for the new operation and tests reported no offenses. The
initial schema-dump invocation without the repository-required `PARALLEL_WORKERS` environment
variable was an environment precondition failure; it was rerun with the verified isolated settings
and passed. The detailed final gate and failure classification are recorded in
`evidence/2026-10-12-staff-event-gate-final-P4C7.md`; the slice-specific schema evidence remains in
`evidence/2026-10-12-identifier-transition-L3M7.md`.

This Gate 2 result validates the current worktree against the staged schema; it does not convert the
generated structure dumps into a clean committed-schema result, and it does not close the remaining
P12a inventory, final staff-event PK/FK cutover, D-11 committed-transaction coverage, P10b/P12b
Avatar cutover, host Alloy runtime verification or privacy-retention decision.

### 16.12 Current P10a/P11a focused recheck (2026-10-12)

After the P12a Gate 2, the independently ready Grant and dead-identifier-history boundaries were
rechecked without changing their implementation. The selected public/model/operation collection
passed `124 runs, 857 assertions, 0 failures, 0 errors, 0 skips` with four workers against the
run-owned PostgreSQL manifest. The collection covered concrete Grant issuance/resolution and Group
membership authorization, dead-history lifecycle and visibility, realm encryption, and shared
public-generation behavior. See `evidence/2026-10-12-p10a-p11a-current-check-H7N5.md`.

This is current focused evidence only. It does not close the P11a cross-database purge/failure
matrix, P10b Group account semantics, D-11 committed-transaction isolation coverage, or the P12b
Avatar consumer cutover and legacy write barrier.

### 16.13 Resume update — P12a capacity inventory hold (2026-10-12)

After Gate 2, the read-only `identifiers:inventory` task was rerun against the current run-owned
20-database manifest. It inspected 892 tables without reading application rows. The current catalog
contains 238 `public_id` columns: 183 `varchar(21)`, 52 unbounded `varchar`, one `varchar(255)` on
`app_zenith.clients`, one `varchar(25)` on `org_zenith.operator_telephones`, and one `varchar(16)`
on `org_zenith.operators`. Aggregate length checks on the unbounded/outlier candidates found no
value above 25 in that disposable catalog.

This does not authorize one broad narrowing migration. The candidates carry different model and
consumer meanings, the operator's 16-character value is a separate human-entered code, and the
migration rules prohibit an unapproved `change_column`. The remaining P12a capacity work therefore
stays as a per-column semantic/consumer review; no value was truncated, regenerated or narrowed. The
bounded evidence and limitation are in `evidence/2026-10-12-identifier-capacity-inventory-V4D8.md`.
This hold affects the remaining identifier-transition branch only and does not block the current
P10a/P11a focused recheck.

### 16.14 Resume update — setting preference public-ID capacity checks (P12a, 2026-10-12)

The next independent P12a capacity slice covered the three setting-database preference identities:
`app_preferences.public_id`, `com_preferences.public_id` and `org_preferences.public_id`. A focused
contract first failed against the current schema because none of the named database checks existed
(`3 runs, 3 assertions, 3 failures`). The reviewed implementation adds one `NOT VALID`
`char_length(public_id) <= 25` check per table and a separate validation migration. It retains the
existing unbounded string representation for this additive transition, changes no issued value and
does not alter the NanoID-21 writer or model-level 21-character validation.

The focused contract plus the three existing setting preference model suites passed
`59 runs, 148 assertions, 0 failures, 0 errors, 0 skips` with four workers. Direct SQL attempted
against each table's persisted row was rejected by PostgreSQL inside a savepoint. All six migrations
were reversed and reapplied in the run-owned setting databases; the three setting structure dumps
were regenerated. The acceptance definition is
[ID-4d](docs/checklists/identifier-contracts.md#id-4d--setting-preference-identities-have-bounded-database-capacity),
with the implementation workflow recorded in [the DB workflow](docs/operations/db-workflow.md).

This slice closes only the three setting-preference capacity checks in the disposable schema. It
does not authorize a global `change_column`, narrow the remaining unbounded candidates, or close the
all-table identifier inventory, staff-event final PK/FK cutover, D-11 isolation matrix, P10b/P12b
Avatar cutover, host Alloy runtime verification or privacy-retention decision. The post-slice Gate 2
completed with Rails `15099 runs, 128124 assertions, 0 failures, 0 errors, 0 skips` using four
workers and Vitest `99 files, 1140 tests`; all worker receipts recorded completed cleanup. Detailed
evidence is in `evidence/2026-10-12-setting-preference-capacity-G6P2.md`.

### 16.15 Resume update — app/com principal public-ID capacity checks (P12a, 2026-10-12)

The next P12a capacity slice covered the clearly owned principal identities
`app_zenith.clients.public_id` and `com_zenith.visitors.public_id`. The ORG 16-character human code
was explicitly excluded. The contract test first failed because the two named database checks were
absent (`5 runs, 14 assertions, 2 failures`). The reviewed implementation adds one `NOT VALID`
`char_length(public_id) <= 25` check and a separate validation migration per owning database. It
keeps the current string type, NanoID-21 issuance and model validation unchanged.

The focused contract plus Client and Visitor model suites passed
`111 runs, 220 assertions, 0 failures, 0 errors, 0 skips` with four workers. Direct SQL oversized
updates were rejected inside savepoints, all four migrations were reversed and reapplied, and the
app/com schema dumps were regenerated. The post-slice Gate 2 then completed with Rails
`15101 runs, 128126 assertions, 0 failures, 0 errors, 0 skips` and Vitest `99 files, 1140 tests`;
all worker receipts recorded completed cleanup. See
[ID-4e](docs/checklists/identifier-contracts.md#id-4e--app-and-com-principal-identities-have-bounded-database-capacity)
and `evidence/2026-10-12-principal-capacity-G8R4.md`.

This closes only these two disposable-schema capacity checks. It does not authorize global column
narrowing, close the remaining identifier inventory or staff-event final PK/FK cutover, or resolve
D-11 isolation coverage, P10b/P12b Avatar cutover, host Alloy runtime verification or privacy
retention.

### 16.16 Resume update — classified self-controlled public-ID capacity checks (P12a, 2026-10-12)

The next independent P12a slice covered the explicitly classified, self-controlled non-secret
`public_id` columns in the current capacity inventory: the selected app/com/org Zenith records,
ticket and signal records, and Avatar groups, Avatars, group memberships and handles. The complete
table list is the `CAPACITY_TABLES` inventory in `test/models/public_id_capacity_contract_test.rb`;
provider/protocol identifiers, the ORG 16-character human code and unclassified remaining candidates
remain outside this slice. The metadata contract first failed against the current schema because the
42 newly listed checks were absent (`47 runs, 62 assertions, 42 failures`).

The implementation adds one named `char_length(public_id) <= 25` check per listed table through an
additive `NOT VALID` migration and a separate validation migration for each owning database. The
existing string columns, NanoID-21 issuance and model-level contracts remain unchanged; no value is
truncated, regenerated or case-converted. The first migration's reverse removes the check, while
reversing validation restores the unvalidated check so the transition remains ordered and explicit.

The focused metadata/direct-write contract passed
`47 runs, 146 assertions, 0 failures, 0 errors, 0 skips` with four workers against the run-owned
manifest. All seven remaining database groups were reversed and reapplied in order after an
app_zenith rehearsal; every down/up command exited zero. The eight affected structure dumps
(`app_zenith`, `com_zenith`, `org_zenith`, `app_ticket`, `app_signal`, `com_signal`, `org_signal`
and `avatar`) regenerated successfully, and the dumps contain the expected 42 new named checks in
addition to the earlier principal checks.

This closes only the listed disposable-schema capacity boundary. It does not authorize a global
`change_column`, close the remaining semantic/consumer inventory, establish public-ID immutability
for every table, complete the staff-event bigint primary-key/foreign-key cutover, or resolve D-11
isolation coverage, P10b/P12b Avatar cutover, host Alloy runtime verification or privacy retention.
The post-slice Gate 2 was then run against the same run-owned manifest with four workers: Rails
completed `15143 runs, 128254 assertions, 0 failures, 0 errors, 0 skips`, and `bun run test`
completed with `99 files, 1140 tests`. The four latest worker receipts all recorded completed
cleanup. The acceptance definition is
[ID-4f](docs/checklists/identifier-contracts.md#id-4f--classified-self-controlled-identifiers-have-bounded-database-capacity),
with the operational sequence in `docs/operations/db-workflow.md` and the focused evidence to be
recorded in `evidence/2026-10-12-public-id-capacity-gate-N9K4.md`. These are disposable dirty-
worktree results only; they do not close the remaining identifier inventory or the independent
P10b/P11a/P11b/P12b, D-11, host-runtime or privacy-retention holds.

### 16.17 Resume update — remaining clear self-controlled capacity extension (P12a, 2026-10-12)

The next P12a extension selected four more unbounded columns with clear self-controlled resource
meaning: `app_zenith.members.public_id`, `app_ticket.logout_transactions.public_id`, and
`avatar.post_versions.public_id` plus `avatar.posts.public_id`. The retired
`app_zenith.legacy_replaced_clients.public_id` table remains outside the slice pending a separate
consumer and retention review. The contract test first failed only for the four new checks:
`51 runs, 150 assertions, 4 failures, 0 errors, 0 skips`.

The implementation adds one named `char_length(public_id) <= 25` check and one validation migration
for each owning migration path. The app-principal migrations run through `app_zenith`, whose
connection owns both `db/app_principals_migrate` and `db/app_zenith_migrate`. Existing string types,
issued values and generation paths remain unchanged. The focused contract plus Member and
LogoutTransaction model suites passed `69 runs, 233 assertions, 0 failures, 0 errors, 0 skips`.

The three owning database groups were reversed and reapplied in order (validation down, additive
down, additive up, validation up), with every command exiting zero; `app_zenith`, `app_ticket` and
`avatar` structure dumps regenerated successfully. A first rehearsal command using the nonexistent
`app_principals` database task was rejected by Rails before any migration ran; the correct
`app_zenith` task then passed. The baseline and extension acceptance remain under
[ID-4f](docs/checklists/identifier-contracts.md#id-4f--classified-self-controlled-identifiers-have-bounded-database-capacity).

The post-extension Gate 2 then ran against the same run-owned manifest with four workers: Rails
completed `15147 runs, 128270 assertions, 0 failures, 0 errors, 0 skips`, and `bun run test`
completed with `99 files, 1140 tests`; all four latest worker receipts recorded completed cleanup.
This remains a disposable-schema capacity result only; it does not authorize global narrowing,
include the retired legacy table, close the remaining identifier inventory or staff-event final
cutover, or resolve D-11, P10b/P12b, host-runtime or privacy-retention holds. Detailed evidence is
in `evidence/2026-10-12-public-id-capacity-extension-V2J6.md`.

**User decision (2026-10-12):** when a failure that is unrelated to the five contracts blocks a Gate
4 command, Luna may make the smallest repair that lets that command pass. This is the scope
authorization that Gate 3 requires for pre-existing unrelated repairs, and it is limited as follows.
Classify the failure as pre-existing and unrelated first, with its cause, and record that in
evidence before repairing. Repair the cause; do not lower a threshold, exclude a file, skip or
delete a test, broaden an allowlist or weaken a check (Gate 3 still applies in full). Keep the
repair out of the files of an in-progress contract slice, and run both full suites afterwards as for
any other change. A repair that would need a design change, a dependency change or more than a small
local edit is reported instead of made. Commit authority is unchanged.

### 16.18 Resume update — staff identity audit-event bigint cutover (P12a, 2026-10-12)

Following the Section 5.3 primary-key transition requirements and the Section 14.2 resume procedure,
the staff identity-audit mapping was advanced from additive staging to its reviewed final key
authority. The consumer inventory found no application reader or writer for these model-less
catalogue tables beyond the persisted `staff_identity_audits` reference. The additive mapping was
therefore verified before the key swap; incomplete or conflicting mappings still fail closed.

The structural migration `20261012100000_cut_over_staff_identity_audit_event_bigint_keys.rb`
installs a temporary bigint FK, adds non-null checks without blocking writes, drops the old string
primary key, promotes the mapped bigint to `staff_identity_audit_events.id`, retains the original
code as `legacy_id`, renames the audit reference to bigint `event_id` while retaining
`legacy_event_id`, and reattaches the FK to the new primary key. The separate validation migration
`20261012100100_validate_staff_identity_audit_event_bigint_foreign_key.rb` validates the checks and
FK, sets the correspondence and reference columns non-null, and removes only the temporary checks.
The old string PK/FK and temporary mapping columns are not fallback authorities after cutover.

The focused transition and retained-operation collection passed
`5 runs, 39 assertions, 0 failures, 0 errors, 0 skips` with four workers against the run-owned
manifest. The isolated database was rehearsed through validation down, structural down, structural
up and validation up with one synthetic event/reference pair; its bigint IDs and both legacy codes
were preserved, and the synthetic rows were removed afterward. The final ORG schema dump was
regenerated through the repository task. The final catalog has a bigint
`staff_identity_audit_events.id` primary key, a validated bigint `staff_identity_audits.event_id`
FK, required `legacy_id`/`legacy_event_id`, and no `id_bigint`, `event_id_bigint` or old string FK.
The fixed catalogue does not gain an automatic sequence; the reviewed mapping supplies its IDs.

After this slice, the required Gate 2 was rerun against the same run-owned manifest with four
workers. Rails completed `15148 runs, 128275 assertions, 0 failures, 0 errors, 0 skips` in 335.118
seconds, and `bun run test` completed with `99 files, 1140 tests` in 12.83 seconds.
`db:verify_no_schema_drift` remains non-zero because eleven intended structure dumps are still dirty
in this uncommitted worktree; it is recorded as a classified drift result, not a clean
committed-schema claim. Targeted RuboCop reported no offenses.

This slice does not claim production/shared-data application, full ID-1 coverage, or completion of
D-11, P10b/P12b, host Alloy runtime verification or privacy-retention decisions. The durable
acceptance definition is
[ID-4c](docs/checklists/identifier-contracts.md#id-4c--staff-identity-audit-event-keys-have-an-identity-preserving-bigint-cutover);
the operational sequence is in `docs/operations/db-workflow.md`, and the slice evidence is in
`evidence/2026-10-12-staff-event-final-cutover-Q4T9.md`.

### 16.19 Resume update — P11b Avatar retention deferral recheck (2026-10-12)

Following Section 14.2, the next genuinely ready child phase was P11b because it depends on P8 and
has no identifier-history or Group-account prerequisite. The existing `RetentionPurgeJob` and
`AvatarPurgeDeferral` implementation was rechecked through the public job boundary. An eligible
Avatar with ownership history remains present, its ownership and moniker history remains present,
and repeated runs update one reason-scoped deferral instead of deleting or silently skipping the
obligation. An ownerless Avatar is refused by the database ownership invariant and cannot be treated
as purgeable. Concurrent deferral attempts converge on one row under the named unique pair and row
lock.

The focused Avatar/retention collection passed
`21 runs, 89 assertions, 0 failures, 0 errors, 0 skips`; the adjacent dead-identifier concurrency
and cross-database child-purge collection passed
`38 runs, 180 assertions, 0 failures, 0 errors, 0 skips`. Targeted RuboCop inspected six affected
job/model/test files with no offenses. The preceding current Gate 2 remains the authoritative full
gate for this unchanged runtime slice: Rails
`15148 runs, 128275 assertions, 0 failures, 0 errors, 0 skips` and Vitest `99 files, 1140 tests`.

This closes the disposable P11b deferral behavior only. The personal-data retention duration and
final deletion/anonymization policy remain unresolved; no physical Avatar/history deletion is
authorized. P12b still waits for P10b Group semantics, writer control, backfill/reconciliation and
the legacy write barrier. Evidence is in `evidence/2026-10-12-p11b-retention-deferral-R8L2.md`.

### 16.20 Resume update — contact purge and dead-history current check (P3e/P11a, 2026-10-12)

The next focused recheck covered the six realm/channel dead-history models and their public purge
boundaries. It exercised schema/visibility invariants, protected and held refusal, repeated salted
history, physical reuse, duplicate purge, independent-connection purge/reuse races, OTP failure
retention, realm/channel HMAC rotation and maintenance isolation, and realm encryption rotation. The
collection passed `109 runs, 1046 assertions, 0 failures, 0 errors, 0 skips` against the run-owned
four-worker manifest. This supports the current live uniqueness/dead-history behavior in the
disposable databases without changing the approved separate Email/Telephone policy design.

The result does not close every CONTACT-4/5 ceremony route, complete the remaining source/fixture
legacy-proof inventory, or establish a full cross-database failure campaign. Those conditions remain
explicit rather than being inferred from focused purge and cryptography tests. Evidence is in
`evidence/2026-10-12-contact-purge-current-check-L6P4.md`.

### 16.21 Resume update — Avatar ownership concurrency current check (P7/P9, 2026-10-12)

The concrete-period, transfer-registry concurrency and trigger-inventory selection was rerun after
the P11b check using independent PostgreSQL connections at the applicable isolation levels. It
passed `28 runs, 101 assertions, 0 failures, 0 errors, 0 skips` on the run-owned four-worker
manifest. This current result supports the isolated period/trigger subconditions and confirms that
the earlier concurrency implementation remains executable after the P12a staff-event changes.

It does not establish the full Avatar transfer consumer cutover, Group semantics, writer quiescence,
dump/restore acceptance or the P12b marker. Evidence is in
`evidence/2026-10-12-avatar-concurrency-current-Q2F6.md`.

### 16.22 Resume update — P3d proof-retirement schema assertion and Gate 2 (2026-10-12)

Following Sections 5.3 and 14.2, the proof-retirement slice was rechecked before any new feature
edit. `test/models/otp_failure_retention_test.rb` now asserts against the PostgreSQL schema that the
six concrete Email/Telephone identifier tables no longer contain `otp_private_key`, `otp_counter` or
`otp_expires_at`, and that the APP/COM source tables no longer contain `sign_up_otp_context` or
`credential_registration_otp_context`. The focused collection of that contract with the two existing
proof-database contracts passed `43 runs, 958 assertions, 0 failures, 0 errors, 0 skips` on the
run-owned four-worker manifest.

The required current Gate 2 then passed against the same manifest: Rails completed
`15149 runs, 128291 assertions, 0 failures, 0 errors, 0 skips` in 338.524 seconds, and
`bun run test` completed with `99 files, 1140 tests` in 12.91 seconds. All four worker receipts
reported completed cleanup; a read-only PostgreSQL check found zero worker databases and zero active
sessions afterward. The evidence is `evidence/2026-10-12-p3d-proof-retirement-gate-C6M4.md`.

This re-establishes the shared-worktree Gate 2 after the schema assertion was added. It does not
close the full CONTACT-4/5 route and legacy-proof inventory, the cross-database partial-failure
campaign, D-11's complete committed-transaction/isolation matrix, P10b Group account semantics, P12b
Avatar cutover/write barrier, the remaining P12a semantic inventory, host Alloy runtime verification
or the privacy-retention decision. The realm plan remains unchecked for any item whose route-level
or cross-database evidence is still missing; this schema assertion alone is not completion of P3d.

### 16.23 Resume update — P11a cross-database partial failure and retry (2026-10-12)

After the current Gate 2 was re-established, the next independent P11a gap was exercised through the
public `RetentionCrossDatabaseChildPurge` service. New tests inject a second-child database failure
for Client, Visitor and Operator actors. In each case the first child deletion remains committed,
the second child remains for retry, a retry removes only that child, and a further retry is a no-op.
This verifies the accepted partial-failure model without pretending that separate PostgreSQL
databases have a distributed transaction.

The focused collection passed `10 runs, 33 assertions, 0 failures, 0 errors, 0 skips`; targeted
RuboCop inspected both test files with no offenses. The required post-change Gate 2 passed with
Rails `15152 runs, 128317 assertions, 0 failures, 0 errors, 0 skips` in 322.100 seconds and Vitest
`99 files, 1140 tests` in 12.80 seconds. Three receipts initially lacked their completion field
despite a read-only catalog showing no worker databases or active sessions; the existing
receipt-verified cleanup helper reconciled all four exact receipts to `cleanup_completed: true`.
Evidence is `evidence/2026-10-12-cross-db-purge-failure-retry-P5H7.md`.

This closes the focused P11a cross-database child-purge failure/retry behavior only. It does not
close every CONTACT-4/5 route or legacy-proof inventory, D-11's complete committed-transaction
matrix, P10b Group account semantics, P12b Avatar cutover/write barrier, remaining P12a semantic
inventory, host Alloy runtime verification or privacy-retention policy.

### 16.24 Resume update — P3d delivery-adapter retirement boundary (2026-10-12)

Following Sections 5.3 and 14.2, the remaining executable P3d edge was checked through the public
Email and Telephone delivery adapters. The current runtime inventory contains no writer for the
retired identifier-owned HOTP fields or APP/COM source proof contexts. `OtpTelephoneAdapter` rejects
retired `sign_up_otp_counter` and `contact_otp_counter` keywords before SMS transport;
`OtpEmailNotifierAdapter` rejects those keywords before invoking the notifier. Tests now assert both
rejection paths and the absence of a transport/notifier side effect.

The focused adapter collection passed `19 runs, 73 assertions, 0 failures, 0 errors, 0 skips`.
Targeted RuboCop passed for both adapters and the modified parallel-test cleanup helper. The cleanup
helper now records an already-empty run-owned worker catalog as complete only after it confirms that
no expected worker session remains; it does not issue a second destructive drop.

The required post-change Gate 2 passed against the same run-owned manifest with Rails
`15154 runs, 128329 assertions, 0 failures, 0 errors, 0 skips` in 332.481 seconds and Vitest
`99 files, 1140 tests` in 13.21 seconds. All four latest worker receipts were reconciled to
`cleanup_completed: true`, and read-only catalog checks found zero worker databases and zero active
sessions. Evidence is in [`J8R4`](evidence/2026-10-12-p3d-adapter-retirement-gate-J8R4.md).

This closes only the tested adapter rejection edge and cleanup evidence. It does not close the
complete CONTACT-4/5 route, source/fixture/constraint inventory, full D-11 isolation matrix or the
entire P3d schema-retirement acceptance; the realm plan remains unchecked for those gaps.

### 16.25 Resume update — P12a legacy public-ID candidates classified and held (2026-10-12)

The fresh run-owned `identifiers:inventory` report inspected 20 connections and 892 tables. Of the
52 unbounded `public_id` columns, the current `CAPACITY_TABLES` slice and explicit target migrations
cover 50. The two remaining names are `app_zenith.legacy_replaced_clients.public_id` and
`org_zenith.legacy_operator_department_accounts.public_id`.

Read-only source and schema review found no current application model/runtime consumer for either
legacy owner table, but retained foreign-key boundaries remain: `user_client_*` tables point at the
former app client table, while the legacy org account is still referenced by the schema's
`staff_operators` table. The current org membership model uses the concrete
`operator_workspace_account_memberships` table instead. Both legacy owner tables and their legacy
child tables were empty in the run-owned catalog; that fact does not establish shared-data or
retention safety.

No capacity check, narrowing, rename or drop was added. Both candidates remain outside ID-4f until
their consumer and retention meaning has a bounded decision and recovery plan. This is a P12a
inventory disposition, not a completion claim. Evidence is in
[`M6T2`](evidence/2026-10-12-identifier-legacy-candidates-M6T2.md).

### 16.26 Resume update — P3d current route and proof-source inventory (2026-10-12)

Following Section 14.2 after the latest Gate 2, the current executable source and all named
Email/Telephone issuer, delivery, verification, finalizer, reentry and sign-up operation families
were re-inventoried before selecting another feature slice. The `app/`, `lib/` and `config/`
inventory contains no writer, reader or lifecycle method for the retired identifier-owned HOTP
fields or APP/COM source proof contexts. Remaining names are bounded exceptions: ceremony contract
forbidden-claim lists, parameter-filtering/legacy translation metadata, or public adapter inputs
that reject retired counters before invoking transport. Current `otp_expires_at` runtime uses are
ceremony-owned fields.

The public route/consumer collection passed
`682 runs, 10952 assertions, 0 failures, 0 errors, 0 skips` with four workers against the run-owned
PostgreSQL manifest. This narrows the P3d gap to the explicit CONTACT-4/5 HTTP-family matrix and
cross-database fault campaign; it does not claim that those remaining cases are complete, and it
does not weaken the requirement for ceremony binding, purpose isolation, single-use consumption or
transport receipt evidence. The source and test inventory is in
[`K4L8`](evidence/2026-10-12-p3d-route-inventory-K4L8.md). No application or schema change was made
by this inventory step.

### 16.27 Resume update — P3d public authentication route matrix (2026-10-12)

Following Sections 5.3 and 14.2, the next focused P3d check exercised the public Email/Telephone
sign-up OTP controllers, Email sign-in entry controllers, App/Com/Org sign-in controllers,
App/Com/Org passkey entry controllers, the Org Entra callback guards, App and Org social session
paths, Email sign-in isolation, sign-up completion, Email verification, delayed OTP transport and
withdrawal reentry. This extends the preceding operation/adapter inventory without changing
application or schema code.

The focused collection passed `223 runs, 2525 assertions, 0 failures, 0 errors, 0 skips` in 16.154
seconds with four workers. A read-only PostgreSQL follow-up reported zero run-owned worker databases
and zero active sessions. Evidence is in
[`H2N6`](evidence/2026-10-12-p3d-public-route-matrix-H2N6.md).

This is current public route evidence, not completion of every CONTACT-4/5 condition. Provider-
specific callback cells, every applicable MFA/capacity/checkpoint route and the remaining
cross-database transport fault campaign still require an explicit applicability map and evidence
before P3d can close. No full gate was repeated because this slice changed only evidence and this
progress record after the current full Rails/Vitest result; any subsequent behavior or schema edit
must re-establish Gate 2 before another feature slice.

### 16.28 Resume update — P10a Grant authority recheck (2026-10-12)

The next independently ready child after the P3d route check was P10a. Following the dependency
graph, this recheck stayed within concrete Grant and permission behavior and did not attempt the
held P10b Group account decision or the P12b cutover. The collection covered Enterprise Persona and
Bureau Agent Grant issuance, ownership-generation binding, non-owner/member refusal, revocation,
permission resolution, Group membership authorization, transfer reservation cardinality/replay and
the app/org public registry-admission guards.

The focused collection passed `81 runs, 355 assertions, 0 failures, 0 errors, 0 skips` in 5.616
seconds with four workers. A read-only PostgreSQL follow-up reported zero run-owned worker databases
and zero active sessions. Evidence is in
[`R3V7`](evidence/2026-10-12-avatar-p10a-grant-recheck-R3V7.md).

This recheck supports the independently executable P10a subconditions in the current dirty worktree.
It does not close the full O1→O2→O1 transfer consequence, P10b Group account semantics, writer
quiescence or the P12b marker. Registry tests remain implementation evidence until the explicit
cutover boundary is verified; no new admission or schema change was made by this slice.

### 16.29 Resume update — P3d Source/Ticket fault and retry check (2026-10-12)

The next executable P3d gap was the two-database fault boundary. The Email sign-up source-audit
integration was run for APP and COM with injected Ticket failures after Source commit and identical
HTTP retries. The Step-Up settings integration was run for App, Com and Org to verify that a binding
failure retains the original proof and that an identical retry is the receipt/recovery path.

The focused collection passed `28 runs, 1236 assertions, 0 failures, 0 errors, 0 skips` in 6.367
seconds with four workers. A read-only PostgreSQL follow-up reported zero run-owned worker databases
and zero active sessions. Evidence is in
[`H5W2`](evidence/2026-10-12-p3d-source-ticket-fault-H5W2.md).

This closes the exercised Email Source/Ticket and Step-Up retry subconditions in the current dirty
worktree. It does not claim a distributed transaction or all provider/credential-family paths; the
existing Telephone sign-up fault journey and any remaining CONTACT-4/5 applicability cells must
still be reconciled before P3d is marked complete. No application or schema change was made by this
verification slice.

### 16.30 Resume update — P3d remaining Email integration edges (2026-10-12)

The remaining named Email integration edges in the current P3d inventory were executed through
`delivered_otp_autocomplete_test`, `email_delivery_test` and
`email_sign_in_enumeration_parity_test`. These checks complement the public route and Source/Ticket
fault collections without changing application or schema code.

The focused collection passed `10 runs, 215 assertions, 0 failures, 0 errors, 0 skips` in 3.740
seconds with four workers. A read-only PostgreSQL follow-up reported zero run-owned worker databases
and zero active sessions. Evidence is in
[`J6Q4`](evidence/2026-10-12-p3d-integration-edges-J6Q4.md).

The named Email integration edge set is now current evidence for this dirty worktree. P3d remains
open for any applicable provider/credential cells not represented by these tests, the full
purpose/realm and concurrency matrix, and any remaining source/fixture/constraint retirement
inventory. No full Gate 2 was repeated because this slice changed only evidence and checklist
references after the current full Rails/Vitest result; a subsequent behavior or schema edit must
re-establish Gate 2.

### 16.31 Resume update — P3d Mermaid policy-axis reconciliation (2026-10-12)

The documentation inventory still contained six per-record OTP Mermaid axes that described the
retired Source-HOTP `store_otp`/`clear_otp` lifecycle and referenced the removed `otp_lockable`
concern. The current source was rechecked before editing: runtime `app/`, `lib/` and `config/`
contain no identifier-owned HOTP proof writer, reader or lifecycle method. The six diagrams now
describe the independent `EmailOtpPolicy`/`TelephoneOtpPolicy` failure and lock predicates, explicit
Telephone issuance time, preserved failure state and separate ceremony-owned proof. The
state-axis/value-coverage sources and transition-inventory disposition now point to the existing
policy/transaction/operation boundaries and label retained Source-HOTP rows as historical.

`git diff --check` and `scripts/check-repository-knowledge` both passed. Evidence is in
[`N7C4`](evidence/2026-10-12-p3d-mermaid-policy-reconciliation-N7C4.md). This is a documentation
reconciliation only; it does not close the remaining P3d source/fixture/constraint inventory or the
complete CONTACT-4/5 matrix, and it does not require a new full Gate 2.

### 16.32 Resume update — P3a independent policy disposition (2026-10-12)

The realm implementation plan's independent Email/Telephone policy item was rechecked through the
six concrete Client/Visitor/Operator models. The current focused test covers zero/one/MAX−1/MAX/
MAX+1 failure boundaries, issuance/resend retention, expiry/cancellation retention, explicit
successful-consumption reset, Telephone issuance timestamps, retired identifier-proof absence and
the absence of the superseded shared stateful policy.

The run passed `33 runs, 458 assertions, 0 failures, 0 errors, 0 skips` in 2.706 seconds with four
workers; the run-owned catalog and active-session counts were both zero afterward. Evidence is in
[`G5L2`](evidence/2026-10-12-p3a-independent-policy-G5L2.md). The corresponding plan item is checked
with that revision-scoped evidence. The ceremony-purpose/realm/concurrency matrix and remaining P3d
schema/fixture/constraint inventory remain separate open criteria.

### 16.33 Resume update — Group transition and contact retirement recheck (2026-10-12)

Following Section 14.2, two independently executable checks were run against the same run-owned
PostgreSQL fleet. The bounded Group transition collection passed
`8 runs, 36 assertions, 0 failures, 0 errors, 0 skips`. It covers direct-SQL protection of concrete
Group history, legacy/concrete source selection around the cutover marker, dry-run/apply/replay
behavior, matching-chain readiness, ownerless selection refusal, bounded selection and gap
classification. It does not decide whether `account_surface`/`account_public_id` is identical to
ownership, establish writer quiescence or perform the P12b marker/cutover. Evidence is in
[`G4H6`](evidence/2026-10-12-avatar-group-transition-G4H6.md).

The six-model Client/Visitor/Operator Email/Telephone collection passed
`126 runs, 405 assertions, 0 failures, 0 errors, 0 skips`, covering current normalization, live
status predicates, digest lookup, deletion/reuse and the available independent-connection
race/rollback cases. CONTACT-6 remains open for any missing realm/status/concurrency partitions.
Evidence is in [`T6N4`](evidence/2026-10-12-p3e-live-uniqueness-T6N4.md).

The P3d catalog recheck found zero retired identifier-owned proof columns in all six identifier
tables, all corresponding retirement versions in their owning disposable databases, and zero
constraint, non-internal trigger or public function definitions referencing those retired names. The
schema portion of CONTACT-5 is current for this rehearsal; historical migration definitions,
intentional forbidden-key/redaction lists, stale test names and adapter rejection fixtures remain
traceability material. The full P3d transport/source/fixture/constraint and
purpose/realm/concurrency matrix remains open. Evidence is in
[`U4K6`](evidence/2026-10-12-p3d-schema-retirement-U4K6.md). The six model-test schema comments were
also corrected to remove retired columns and show the explicit Telephone issuance timestamp; no
runtime behavior or migration history was changed.

These checks changed only documentation/evidence and test comments after the current full Gate 2;
they do not require a new full Gate 2. Any subsequent application, test behavior or schema edit must
re-establish Gate 2 before another feature slice.

### 16.34 Resume update — P3d ceremony delivery matrix (2026-10-12)

The next focused P3d check exercised the existing Email/Telephone ceremony model, operation,
integration and delivery boundaries: expiry/deadline, purpose and binding checks, proof-shape and
terminal database protections, registration issuer/verifier/resend paths, delivery guards, HTTP
Telephone signup delivery and stale source-proof retry behavior. The selected collection passed
`418 runs, 6843 assertions, 0 failures, 0 errors, 0 skips` in 8.318 seconds with four workers on the
run-owned fleet. Evidence is in [`B7Q5`](evidence/2026-10-12-p3d-ceremony-matrix-B7Q5.md).

This narrows the executable CONTACT-4/5 gap. It does not close every provider/credential cell, every
realm/purpose concurrency case, the complete source/fixture/constraint inventory or the
cross-database transport fault campaign. No application or schema source changed in this slice, so
the already current full Gate 2 remains the latest shared-worktree gate; any later behavior or
schema edit must re-establish it before further feature work.

### 16.35 Resume update — P11a dead-history and retention matrix recheck (2026-10-12)

After rereading Sections 5.3, 16 and 14.2, the next independently executable P11a check was the
current seven-file dead-identifier history and retention collection. It exercised the six concrete
history contracts, identity-scoped fingerprint verification, ordinary destroy/purge boundaries,
retention behavior, visibility invariants and the available independent-connection concurrent purge
cases. The run passed `96 runs, 776 assertions, 0 failures, 0 errors, 0 skips` in 6.710 seconds with
four workers against the run-owned PostgreSQL fleet. Evidence is in
[`V3M7`](evidence/2026-10-12-p11a-history-matrix-V3M7.md).

This is current focused evidence for the P11a history boundary. It does not authorize real-data
purge and does not close every cross-database fault, whole-owner/legal-retention or complete
six-model create/purge partition. CONTACT-7/8/9 and the realm implementation plan therefore remain
open where those conditions are still explicit. No application or schema source changed in this
slice; the latest full Rails/Vitest Gate 2 remains current. Any later behavior or schema edit must
re-establish Gate 2 before another feature slice.

### 16.36 Resume update — P11a integrated history and retention matrix (2026-10-12)

The next P11a/P3e recheck combined the current six-model dead-history and purge collection with OTP
failure retention, realm/channel HMAC rotation and maintenance isolation, and realm encryption
rotation. It passed `110 runs, 1066 assertions, 0 failures, 0 errors, 0 skips` in 5.977 seconds with
four workers against the run-owned PostgreSQL fleet. Evidence is in
[`X7Q4`](evidence/2026-10-12-p11a-integrated-matrix-X7Q4.md).

This is current focused evidence for the executable history, cryptographic and retention paths. It
does not authorize real-data purge or close every CONTACT-4/5 route, the complete source/fixture
inventory, cross-database transport campaign, whole-owner/legal-retention partition or the full D-11
committed-transaction matrix. No application or schema source changed in this slice; the latest full
Rails/Vitest Gate 2 remains current. Any later behavior or schema edit must re-establish Gate 2
before another feature slice.

### 16.37 Resume update — P3d provider, MFA, checkpoint and session-limit matrix (2026-10-12)

The next P3d public-boundary check exercised the existing App/Com/Org MFA and checkpoint
controllers, session-limit paths, social ceremony and callback guards, OIDC callbacks and entrances,
and Org Entra resolver/preflight/token guards. The focused collection passed
`210 runs, 1831 assertions, 0 failures, 0 errors, 0 skips` in 22.031 seconds with four workers
against the run-owned PostgreSQL fleet. A read-only Rails catalog follow-up reported zero worker
databases and zero active worker sessions. Evidence is in
[`Y5R8`](evidence/2026-10-12-p3d-provider-mfa-matrix-Y5R8.md).

This is current evidence for the selected provider/MFA/checkpoint/session-limit cells. It does not
claim every provider or credential family applies to every surface, close the remaining P3d
source/fixture/constraint and cross-database transport inventory, or verify live external providers
or production infrastructure. No application or schema source changed in this slice; the latest full
Rails/Vitest Gate 2 remains current. Any later behavior or schema edit must re-establish Gate 2
before another feature slice.

### 16.38 Resume update — P10a transfer and generation-bound Grant matrix (2026-10-12)

Following the dependency graph, the next P10a check remained independent of the held P10b Group
account decision and P12b cutover. The selected collection exercised concrete ownership periods,
transfer validation, registry cardinality and replay, independent-connection concurrency, cutover
barrier guards, app/org transfer controllers, concrete Grant issuance/resolution and Avatar
authorization constraints. It passed `130 runs, 600 assertions, 0 failures, 0 errors, 0 skips` in
6.113 seconds with four workers against the run-owned PostgreSQL fleet. A read-only Rails catalog
follow-up reported zero worker databases and zero active worker sessions. Evidence is in
[`Z4M6`](evidence/2026-10-12-avatar-p10a-transfer-grant-matrix-Z4M6.md).

This is current focused P10a evidence. It does not establish P10b Group account semantics, writer
quiescence, operational backfill, final P12b cutover or the complete O1-to-O2-to-O1 and client-
transition matrix. No application or schema source changed in this slice; the latest full
Rails/Vitest Gate 2 remains current. Any later behavior or schema edit must re-establish Gate 2
before another feature slice.

### 16.39 Resume update — P10a historical Grant non-reactivation (2026-10-12)

Following Sections 5.3, 16 and 14.2, the next ready P10a subcondition was the explicit O1 → O2 → O1
Grant rule. A public-operation regression first failed because a stale in-memory ownership-period
object was treated as current after its database row had been closed. The minimal fix makes
`AvatarAccessGrantResolver` re-read the current period from the database before resolving a Grant.
The same test then passed through the concrete registry, proved that the historical O1 Grant was
ineffective for the closed O1 period and the new O1 period, and proved that a newly authorized Grant
was required.

The focused collection passed `33 runs, 172 assertions, 0 failures, 0 errors, 0 skips` in 3.148
seconds. Evidence is in [`G5N2`](evidence/2026-10-12-avatar-p10a-generation-reuse-G5N2.md). Because
this changed runtime behavior and a test, Gate 2 was re-established afterward: Rails passed
`15155 runs, 128324 assertions, 0 failures, 0 errors, 0 skips` in 351.294 seconds and Vitest passed
`99 files, 1140 tests` in 13.77 seconds. The run-owned catalog follow-up reported zero worker
databases and zero active worker sessions.

This closes the stale-period Grant non-reactivation subcondition only. It does not close the full O1
→ O2 → O1/client-transition or failure-injection matrix, P10b Group account semantics, writer
quiescence, operational backfill, the P12b marker/cutover, D-11's complete committed-transaction
matrix, remaining P3d transport/source inventory, held P12a public-ID candidates, host Alloy runtime
verification or the unresolved privacy-retention policy. No production/shared data was changed, and
no local commit or remote synchronization was performed.

### 16.40 Resume update — P3d OTP and authentication concurrency matrix (2026-10-12)

After the behavior Gate 2, the next independent P3d subcondition was the real concurrent single-use
and authentication-state boundary. The selected collection exercised independent connections for
Email/Telephone ceremony consumption, Auth Email consumption, authentication session and revocation
state, TOTP-window consumption, Telephone sign-up issuance and registration OTP verification. It
passed `118 runs, 1653 assertions, 0 failures, 0 errors, 0 skips` in 5.909 seconds with four
workers. Evidence is in [`P6R2`](evidence/2026-10-12-p3d-otp-concurrency-matrix-P6R2.md). A
read-only catalog follow-up reported zero run-owned worker databases and zero active worker
sessions.

This narrows the concurrency evidence for the exercised P3d cells. It does not close every
purpose/realm/provider applicability partition, the remaining source/fixture/constraint retirement
inventory, or the cross-database transport fault campaign. No application or schema source changed
in this slice, so the latest full Rails/Vitest Gate remains current; a subsequent behavior or schema
edit must re-establish Gate 2.

### 16.41 Resume update — P3d retired proof reference inventory (2026-10-12)

The remaining P3d source/fixture question was classified without changing runtime or schema code. A
repository-wide search for the retired identifier-owned proof/context names enumerated 15 `app`, 0
`lib`, 5 `config`, 61 `test` and 41 `db` paths. The current application paths are ceremony-owned
`otp_expires_at` reads, explicit rejection/forbidden-key/filter names, or the bounded ORG legacy
reference inventory; no identifier-owned proof writer, reader or lifecycle helper was found. The
current disposable catalog result in `U4K6` still reports no retired identifier columns or matching
live non-internal constraint, trigger or public function. Evidence is in
[`R7M4`](evidence/2026-10-12-p3d-proof-reference-inventory-R7M4.md).

This classifies the current reference set and narrows CONTACT-5. Historical migrations, rejection
fixtures, forbidden-key lists and locale labels remain deliberate traceability material; the
classification does not authorize removing them, certify every transport consumer or close the
cross-database fault campaign. No application or schema source changed in this slice, so the latest
full Rails/Vitest Gate remains current.

### 16.42 Resume update — current Gate 2 and static verification (2026-10-12)

Following Sections 5.3, 16 and 14.2, the run-owned twenty-database manifest was prepared before
resuming the next check. A first command without the required `PARALLEL_WORKERS` and pending
migrations was refused before tests; the corrected `db:test:prepare` completed successfully. The
focused restart sample passed `35 runs, 188 assertions, 0 failures, 0 errors, 0 skips`.

The current full Rails gate then passed
`15155 runs, 128326 assertions, 0 failures, 0 errors, 0 skips` in 334.240 seconds with four workers.
`bun run test` passed `99 files` and `1140 tests` in 13.09 seconds. The four newest worker receipts
report `cleanup_completed: true`, and the manifest still contains twenty run-owned databases. The
detailed command record is [`H8K4`](evidence/2026-10-12-resume-gate-H8K4.md).

Gate 4 static checks also passed for `bun run check`, `bin/rubocop`,
`bundle exec erb_lint --lint-all`, Brakeman, repository knowledge and a local test Rails boot.
`bin/bundler-audit` found no vulnerabilities. `bun audit` remains a separate dependency finding for
the existing moderate `postcss-selector-parser@6.0.10` advisory; no upgrade was authorized or made.
This current gate does not close D-11's complete committed-transaction matrix, P10b/P12b
Group/cutover decisions, held legacy identifier candidates, host Alloy runtime remount or
privacy-retention policy.

### 16.43 Resume update — test-preparation scope aligned locally (2026-10-12)

After rereading Sections 5.3, 16 and 14.2, the first independent environment repair in this
resumption was the test-preparation manifest. The local `config/ci.rb` command now names all six
non-replica test databases that the current Rails configuration owns: `test_primary_db`,
`test_app_ticket_db`, `test_com_ticket_db`, `test_org_ticket_db`, `test_app_zenith_db` and
`test_chronicle_db`. The guarded run-owned `db:test:prepare` completed successfully before the
focused and full suites recorded in [H8K4](evidence/2026-10-12-resume-gate-H8K4.md).

The aligned configuration contract passed with
`15 runs, 60 assertions, 0 failures, 0 errors, 0 skips`. The post-change full Gate 2 then passed
with Rails `15155 runs, 128346 assertions, 0 failures, 0 errors, 0 skips` in 330.574606 seconds and
Vitest `99 files, 1140 tests` in 12.94 seconds.

The initial gate process left one run-owned worker receipt incomplete at the tool wait boundary. The
receipt's exact 20 database names and owner were rechecked read-only; the existing receipt-verified
cleanup helper removed only those 20 worker-3 databases, set its completion field, and a final
catalog query found zero worker databases for workers 0–3.

`ruby -c config/ci.rb` and `git diff --check` passed. GitHub's `.github/workflows/ci.yml` is mounted
read-only in this container and still has the previous four-name literal; it was not bypassed or
edited. A host-side workflow edit to the same six-name set remains required before that external job
is aligned. No CI job was run, and no CI result is claimed. The exact local disposition is recorded
in [`R6M4`](evidence/2026-10-12-test-preparation-scope-R6M4.md).

### 16.44 Resume audit after the Section 5.3/16/14.2 restart check (2026-10-12)

The restart procedure was applied again after rereading the Section 5.3 addition, all of Section 16
and Section 14.2. The worktree remains on branch `feature` at
`ccceabd05d2e3a8f923ce398046f99d026a5b78e` with 226 changed paths; no reset, clean, stash, worktree,
push or shared-database operation was performed.

The local test-preparation repair is now part of the current source: `config/ci.rb` names all six
non-replica test databases and its existing configuration contract is synchronized. The focused
contract passed `15 runs, 60 assertions, 0 failures, 0 errors, 0 skips`. The current full local
verification passed Rails with `15155 runs, 128346 assertions, 0 failures, 0 errors, 0 skips` and
Vitest with `99 files, 1140 tests`; the run-owned worker catalog was empty after the verified
cleanup helper completed. These results are current execution evidence, not acceptance completion.

The implementation/source reconciliation found no additional independent production-code slice that
can be changed safely in this shared tree without either guessing a domain decision or activating an
operational cutover. The six contact schemas no longer contain identifier-owned HOTP/context
columns; remaining matching source is ceremony-owned proof, explicit legacy-payload
rejection/filtering, historical migration definitions or bounded inventory traceability. The
concrete Group ownership source selector/backfill and Avatar cutover guard already exist, but the
marker still requires an explicit Group inventory and verified writer quiescence. The two remaining
unbounded historical identifier candidates remain held because retained foreign keys and ownership
semantics have not been authorized for destructive narrowing. The full DB immutability map likewise
cannot be completed by inventing a new trigger authority.

Accordingly, this restart records a truthful implementation hold rather than adding speculative
code. The next executable mutations require their existing boundaries: host recreation for the
read-only Alloy/workflow mounts, an explicit operational Avatar/Group inventory and writer-control
cutover for P12b, reviewed treatment of the retained legacy identifier tables for P12a, and the
environment/owner decision needed for the remaining D-11 and privacy-retention checks. No CI or
Podman result is claimed, and no acceptance test is being marked complete by this entry. Detailed
commands and results are in [`R6M4`](evidence/2026-10-12-test-preparation-scope-R6M4.md); the
working tree and all unrelated changes remain preserved.

### 16.45 Resume update — current identifier catalog corrected (2026-10-12)

The current run-owned `identifiers:inventory` was rerun after the restart audit, scanning 20 writer
connections and 892 tables. It reports zero missing and zero composite primary keys. The only
non-bigint primary keys are the Rails-owned `ar_internal_metadata` and `schema_migrations` tables.
The old observation that `avatar_ownership_cutovers` lacked a primary key is no longer current:
`20261012130000_promote_avatar_ownership_cutover_key.rb` is present and the current structure dump
contains its bigint primary-key constraint. No Hash, invalid or unready index was reported.

The two reviewed unbounded legacy `public_id` tables remain the only capacity candidates outside the
explicit P12a inventory. Their retained foreign keys and historical ownership/retention meaning
still prevent a safe narrowing or removal without a separate reviewed decision. Current Group
consumers and the owning specification also settle the D-2 meaning question: `account_surface` /
`account_public_id` remain selected-account context and are not the concrete organization owner.
This correction removes the stale marker-key and domain-meaning holds; it does not close data
reconciliation, permanent-ID immutability or shared/production transition work. The catalog report
and command are recorded in [`7P3M`](evidence/2026-10-12-current-identifier-catalog-7P3M.md).

The current marker/barrier regression was also rerun against the same manifest and passed
`5 runs, 74 assertions, 0 failures, 0 errors, 0 skips`. This verifies the current local
migration/model boundary only; it does not establish the operational writer-quiescence or
shared-data cutover.

### 16.46 Resume update — Avatar draft provenance is already recorded (2026-10-12)

The six preserved files under `specs/avatar-organization-ownership/migration-drafts/` were checked
against the current ownership specification. Its `Historical draft disposition` table already
records, for each exact path, the successor migration or abandonment reason and the current
run-owned migration-history observation. The drafts remain outside `db/avatars_migrate/` discovery
and none is reapplied or deleted. This removes the stale documentation-only hold from 16.5; it does
not authorize the separate operational P12b cutover or any historical-data deletion.

### 16.47 Resume update — legacy identifier and development Avatar catalog check (2026-10-12)

The next read-only resume check inspected the two remaining unbounded legacy identifier candidates
and the current development Avatar catalog. `legacy_replaced_clients.public_id` and
`legacy_operator_department_accounts.public_id` both have zero rows in the development databases,
but each table retains a unique B-tree index and several foreign-key/dependent-reference paths. The
empty development result therefore does not authorize a capacity narrowing, rename or removal for
retained data. The exact catalog facts and commands are in
[`H3K8`](evidence/2026-10-12-resume-legacy-catalog-H3K8.md).

The development Avatar database contains the existing Avatar, Group, legacy-period and cutover
tables with zero rows, but it does not yet contain `avatar_group_concrete_ownership_periods`. A
model-count probe failed closed on that absent relation; a follow-up `to_regclass`/`count(*)` probe
was read-only. No development/shared migration was run and no cutover marker was created. The
concrete Group backfill and P12b writer-barrier operation remain prepared-only until a run-owned
disposable rehearsal or an explicitly approved operational environment supplies the missing table,
complete inventory and writer-quiescence evidence. This is an environment and operational boundary,
not permission to add a fallback or to weaken the cutover guard.

### 16.48 Resume update — HMAC role lifecycle boundary (2026-10-12)

The HMAC role lifecycle was rechecked before any migration edit. The three maintenance migrations
are already applied in the local development databases. Their forward path correctly validates
restricted attributes, membership and foreign database dependencies before reusing an existing role,
and the current catalog contains the expected twelve restricted roles. The exact role attributes,
dependency scope and applied-version facts are in
[`J4N8`](evidence/2026-10-12-hmac-role-lifecycle-J4N8.md).

The applied migration `down` methods still contain unconditional `DROP ROLE` statements. Because
Section 5.3/16 forbids editing applied history and forbids deleting an unproven shared role, no
rollback or role deletion was attempted. This leaves only the historical rollback path blocked;
normal forward migration and run-owned isolated cleanup remain separate. A future repair must be
forward-only or otherwise explicitly establish rollback ownership before any role deletion is
possible. This finding does not authorize a role fallback, a shared-cluster change, or a migration
reset. The existing database workflow now records this historical rollback hazard and keeps the
run-owned receipt-verified rebuild as the only current role-deletion path.

### 16.49 Resume update — focused Minitest after local writer preparation (2026-10-12)

The first public sample test was intentionally attempted before further implementation. With the
container's inherited four-database `POSTGRESQL_TEST_PREPARE_DATABASES` value, Rails stopped before
loading the test file and reported 43 pending migrations in the other configured writer databases.
This was classified as a preparation failure, not a test result. The guarded task was then run with
the twenty non-replica writer databases derived from the current Rails test configuration; it
completed successfully without reset, drop, CI, Podman or shared-database operations. The exact
scope and command are recorded in [`P7L4`](evidence/2026-10-12-resume-minitest-sample-P7L4.md).

The focused public HMAC maintenance boundary then passed with
`4 runs, 108 assertions, 0 failures, 0 errors, 0 skips`. This confirms that the local test databases
can be prepared and a representative service contract can run when the complete writer scope is
supplied explicitly. It does not certify the full suite or acceptance completion. The inherited
four-database container variable still needs the approved host/container configuration to be
corrected or recreated before plain `bundle exec rails test` can be treated as self-preparing for
future migrations. After the local twenty writer databases were prepared, the unqualified sample
command also passed with `4 runs, 108 assertions, 0 failures, 0 errors, 0 skips`; that result relies
on the current DBs already being migrated. The local `config/ci.rb` source was also aligned to
enumerate all twenty non-replica writers, and its focused static contract passed with
`15 runs, 66 assertions, 0 failures, 0 errors, 0 skips`; no CI job was invoked.

### 16.50 Resume update — Gate 2 after writer-scope alignment (2026-10-12)

Because the test-preparation source changed, Gate 2 was rerun before considering another
implementation slice. The existing run-owned twenty-database manifest was used with four Rails
workers. Rails passed with `15155 runs, 128338 assertions, 0 failures, 0 errors, 0 skips` in
334.271947 seconds, and `bun run test` passed `99` files and `1140` tests in 12.86 seconds. The
focused configuration contract remained green at
`15 runs, 66 assertions, 0 failures, 0 errors, 0 skips`. The commands and dirty-worktree conditions
are recorded in [`U8Q2`](evidence/2026-10-12-resume-gate-after-scope-U8Q2.md).

This closes the local test-preparation regression for the current writer scope. It does not turn the
stale inherited four-database container variable into a self-preparing environment, and it does not
close P12b operational cutover, legacy identifier retention review, D-11 committed- transaction
coverage, host Alloy remount, privacy retention, or the historical HMAC-role rollback hazard. This
current twenty-writer result supersedes the six-database source wording in Sections 16.43 and 16.44;
those sections remain historical records of the earlier repair state.

### 16.51 Resume update — preparation scope now fails closed (2026-10-12)

The next safe slice after the Section 5.3/16/14.2 restart check closed the remaining local
preparation loophole. `DatabaseSafety.verify_catalog!` now publishes the effective non-replica
writer set separately from the full test configuration set, and `prepare_database_names!` rejects an
environment scope that omits any verified writer. Replica configurations remain excluded from the
migration target by their actual Rails configuration rather than by requiring replica names in the
migration variable.

The TDD Red case showed that the former implementation accepted the single-name subset
`test_primary_db`. The Green focused collection passed
`28 runs, 137 assertions, 0 failures, 0 errors, 0 skips`. Re-running the old four-name environment
caused `db:test:prepare` to fail before the migration loop and list the missing writers, so it
cannot accumulate pending migrations while appearing prepared.

After the implementation, the required current Gate 2 was re-established against the run-owned
twenty-database manifest with four workers: Rails passed
`15155 runs, 128349 assertions, 0 failures, 0 errors, 0 skips` in 346.959799 seconds, and Vitest
passed `99` files / `1140` tests in 12.98 seconds. RuboCop, Ruby syntax checks, `git diff --check`
and the repository knowledge checker also passed. Detailed commands and the dirty-worktree scope are
recorded in [`M7Q2`](evidence/2026-10-12-test-preparation-fail-fast-M7Q2.md).

A read-only catalog check after Rails reported zero run-owned worker databases and zero active
worker sessions; the twenty run-owned parent databases were preserved.

This closes the local source-level test-preparation scope gap only. The inherited host/container
environment variable still requires its authorized host-side correction or recreation; no CI or
Podman result is claimed. P12b operational cutover, held legacy identifier semantics, D-11's
complete committed-transaction matrix, host Alloy runtime verification, privacy retention and the
historical HMAC-role rollback hazard remain open. No application acceptance test is marked complete
by this entry.

### 16.52 Resume update — current static Gate 4 checks (2026-10-12)

After the preparation-scope slice and its Gate 2, the repository-wide static checks were rerun
against the same dirty worktree. `bin/rubocop` inspected 5,381 files with no offenses,
`bundle exec erb_lint --lint-all` linted 4,391 files with no errors, `bin/brakeman` reported zero
errors and zero security warnings, and `bin/bundler-audit` reported no vulnerabilities. The commands
and exact scope are included in [`M7Q2`](evidence/2026-10-12-test-preparation-fail-fast-M7Q2.md).

These checks strengthen current code quality evidence but do not close the remaining operational
cutover, privacy-retention, host-runtime, isolated committed-transaction, legacy identifier or
historical rollback boundaries. They also do not convert focused or static evidence into an
independent acceptance decision.

### 16.53 Resume update — ActionMailer span scrubber defense-in-depth (2026-10-12)

After rereading Sections 5.3, 16 and 14.2, the next safe P1 observability slice was a concrete
secondary-control gap. The ActionMailer instrumentation already uses the installed 0.8.1 formal
allowlist transform and `email_address: :omit`; however, the in-process `ObservabilitySpanScrubber`
did not classify an accidentally emitted `email.subject` or `args` span attribute as sensitive. The
Red test reproduced that leak shape, and the smallest Green change now removes every `email.*`
attribute except the explicitly permitted `email.x_mailer`, plus `args` at any span-key depth. The
Rails ActionMailer logger policy, delivery semantics, Noticed/interceptor behavior and Alloy
secondary processor were not changed.

The focused collection passed `13 runs, 50 assertions, 0 failures, 0 errors, 0 skips`; the exact
Red/Green and source diff are recorded in
[`M2H7`](evidence/2026-10-12-observability-span-scrubber-M2H7.md). The shared-worktree Gate 2 was
then re-established with Rails `15156 runs, 128351 assertions, 0 failures, 0 errors, 0 skips` in
335.967952 seconds and Vitest `99 files, 1140 tests` in 12.96 seconds. RuboCop, ERB lint, Brakeman,
bundler-audit, repository knowledge and `git diff --check` also passed.

This closes only the in-process ActionMailer span-scrubber regression boundary. It does not claim
the host-managed Alloy read-only mount or processor runtime was exercised, and it does not close
P10b/P12b operational cutover, D-11 committed-transaction isolation, held identifier semantics,
privacy-retention decisions or historical HMAC-role rollback. No CI, Podman, production or shared
destructive operation was used, and no acceptance condition is marked complete by this entry.

### 16.54 Resume recheck after the required 14.2 procedure (2026-10-12)

The resume order was applied again: Section 5.3 including its appended decision, all of Section 16,
and then Section 14.2. The current tree remains on `feature` at
`ccceabd05d2e3a8f923ce398046f99d026a5b78e` with the pre-existing dirty work preserved. The exact
status split at capture was 240 status paths, with 0 staged, 129 unstaged tracked and 111 untracked
paths. No reset, clean, stash, worktree, push, CI, Podman, production or shared destructive
operation was used.

The last implementation slice was rechecked through its public focused tests against the complete
run-owned disposable writer scope: `13 runs, 50 assertions, 0 failures, 0 errors, 0 skips`. A
read-only post-run catalog check reported zero run-owned worker databases and zero active worker
sessions. The first cleanup probe without `PARALLEL_WORKERS` failed closed during application
initialization and made no database change; rerunning it with the manifest's four-worker scope
passed. The existing P10b Group inventory/backfill preparation tests were also rerun with
`5 runs, 22 assertions, 0 failures, 0 errors, 0 skips`; they do not establish a cutover marker. The
exact commands and scope are in [`Q8V4`](evidence/2026-10-12-resume-check-Q8V4.md).

`git diff --check`, the changed Ruby syntax check and the repository knowledge checker passed. The
latest full Gate 2 remains the current result in
[`M2H7`](evidence/2026-10-12-observability-span-scrubber-M2H7.md): Rails
`15156 runs, 128351 assertions, 0 failures, 0 errors, 0 skips` and Vitest `99 files, 1140 tests`,
with the recorded static checks green.

This recheck does not convert evidence into acceptance. No further reversible production-code slice
was selected because the remaining work requires an existing boundary: P10b/P12b Group semantics and
operational cutover, the two retained legacy identifier tables, the complete D-11
committed-transaction/isolation matrix, host Alloy remount/runtime verification, privacy-retention
policy, or the historical HMAC-role rollback path. The acceptance-test work excluded by the user
remains unclaimed.

### 16.55 Resume update — explicit safe ActionMailer attribute guard (2026-10-12)

The in-process scrubber slice received one additional regression guard for the existing OTel
allowlist: `email.x_mailer` remains observable while all other `email.*` attributes and `args`
remain redacted. The focused collection then passed
`14 runs, 51 assertions, 0 failures, 0 errors, 0 skips`.

Because a test file changed, Gate 2 was rerun against the same complete run-owned writer manifest.
Rails passed with `15157 runs, 128352 assertions, 0 failures, 0 errors, 0 skips` in 337.407710
seconds, and Vitest passed with `99` files and `1140` tests in 12.87 seconds. No new regression was
observed. No CI, Podman, production or shared destructive operation was used. The current command
record is in [`Q8V4`](evidence/2026-10-12-resume-check-Q8V4.md). During the Rails run an external
local `[CHECKPOINT] .` commit advanced HEAD from `ccceabd05d2e3a8f923ce398046f99d026a5b78e` to
`0823fde7ee93e5ca54a05a4b4102382db3c683f2`; it was preserved and not rewritten by this work.

This remains a local implementation/regression result. It does not close host Alloy runtime
verification, P10b/P12b cutover, D-11 isolation, held legacy identifier semantics, privacy-retention
policy or the user-excluded independent acceptance work.

### 16.56 Resume update — first focused check after the required restart reading (2026-10-12)

After rereading the Section 5.3 addition, all of Section 16 and Section 14.2 in that order, the
first focused public-boundary check was rerun before selecting another implementation slice. Using
the existing run-owned twenty-writer manifest with four Rails workers, the observability scrubber,
OTel initializer, Group inventory/backfill operation and Group transition inventory query collection
passed `19 runs, 73 assertions, 0 failures, 0 errors, 0 skips`. A read-only PostgreSQL probe after
the run found zero run-owned worker databases and zero active worker sessions. The exact command,
HEAD and limits are recorded in [`A6M2`](evidence/2026-10-12-restart-focused-minitest-A6M2.md).

This is current implementation evidence only. It does not mark an acceptance condition complete or
authorize a new production-code slice. The remaining mutations still require the existing boundaries
for P10b/P12b Group semantics and writer-controlled cutover, the retained legacy identifier tables,
D-11 committed-transaction isolation, host Alloy recreation/runtime verification, privacy-retention
policy, or the historical HMAC-role rollback path. No CI, Podman, production, shared destructive
operation, or independent acceptance investigation was performed.

### 16.57 Resume update — current identifier catalog after the focused check (2026-10-12)

The read-only `identifiers:inventory` task was rerun with the required four-worker manifest guard
after the focused check. It scanned 20 configured writer connections and 892 tables. Each connection
reported zero missing or composite primary keys, zero Hash indexes, zero invalid indexes and zero
unready indexes. The only two non-bigint primary keys reported per connection are the Rails-owned
`schema_migrations` and `ar_internal_metadata` tables; this catalog result does not replace semantic
owner/consumer classification. The exact command and the ignored report path are in
[`C3N8`](evidence/2026-10-12-restart-identifier-inventory-C3N8.md).

The first attempt without `PARALLEL_WORKERS` failed closed during application initialization with
`ConfigurationError`; it made no database change. The corrected run passed. This confirms the
current inventory guard and does not close the retained legacy identifier review, permanent-ID
immutability mapping, operational Avatar cutover, or any independent acceptance condition.

### 16.58 Resume update — current schema dump matches the run-owned databases (2026-10-12)

The read-only `db:verify_no_schema_drift` gate was rerun with the same twenty-writer manifest and
required four-worker guard. It passed with `No schema drift detected in 20 schema dump file(s).` The
earlier dirty-dump result belonged to the preceding uncommitted migration state and remains a
historical record; it is superseded for the current checked-out commit by the run in
[`D4K9`](evidence/2026-10-12-schema-drift-current-D4K9.md).

This closes the current disposable schema-dump comparison only. It does not authorize shared or
production migration, physical deletion, writer-quiescence cutover, or any of the remaining
operational/policy holds.

### 16.59 Resume update — stale generic OTP guidance marked historical (2026-10-12)

The two duplicate generic security-design documents contained old identifier-owned HOTP examples
without a current-contract notice. They now explicitly direct readers to the accepted
realm-separated ceremony-verifier ADR and mark those examples as historical guidance. This is a
documentation-only alignment; it does not alter the Email/Telephone implementation or introduce a
new policy. The pre-commit documentation check and scope are recorded in
[`R1P6`](evidence/2026-10-12-otp-guidance-doc-sync-R1P6.md).

### 16.60 Resume update — retired OTP email fallback removed (2026-10-12)

After the required Section 5.3, Section 16 and Section 14.2 reading, the next implementation slice
removed the retired direct `OtpEmailAdapter` and `OtpEmailNotifierRollout` path. The production
`OtpAdapter.for` boundary now selects the concrete Noticed adapter for Email in each of the APP, COM
and ORG surfaces without a feature flag or silent fallback. The existing ActionMailer, Noticed,
interceptor, delivery-job and surface ownership contracts remain in place; this change does not
redesign mail delivery or OTP generation. The former rollout and direct-adapter tests were removed
or rewritten as final-path characterization and boundary tests, and the static architecture baseline
was regenerated through its repository task after the deleted files caused one initial baseline
failure.

The first focused TDD check changed the adapter expectations before production code and failed with
four assertions because the old adapter was still returned. The smallest production change then made
the three Email selections explicit and the focused adapter test passed with
`10 runs, 12 assertions, 0 failures, 0 errors, 0 skips`. The broader adapter/security collection
passed with `41 runs, 367 assertions, 0 failures, 0 errors, 0 skips`; the affected
controller/integration collection passed with
`123 runs, 2,963 assertions, 0 failures, 0 errors, 0 skips`.

The first full Rails Gate 2 run found one static architecture-baseline failure listing the two
deleted files. After `bin/rails architecture:baseline`, its contract test passed with
`3 runs, 2,742 assertions, 0 failures, 0 errors, 0 skips`. The rerun of the complete owned
disposable writer scope with four workers passed with
`15,134 runs, 128,192 assertions, 0 failures, 0 errors, 0 skips` in 329.978810 seconds. The
corresponding `bun run test` passed `99` files and `1,140` tests in 12.93 seconds. A read-only
PostgreSQL catalog check found the twenty run-owned parent databases and zero active worker
sessions. Static checks also passed: RuboCop inspected 5,377 files with no offenses, Brakeman
reported zero warnings/errors, bundler-audit reported no vulnerabilities, `bun run check` succeeded,
the repository knowledge check passed, and `git diff --check` passed.

This is current implementation evidence only, not an independent acceptance decision. The user
excluded acceptance-test work remains unclaimed. P10b/P12b Group semantics and operational cutover,
D-11's complete committed-transaction isolation matrix, host Alloy remount/runtime verification, the
two retained legacy identifier tables, privacy-retention policy, and the historical HMAC-role
rollback hazard remain open. No CI, Podman, production, shared destructive operation or remote
synchronization was used.

### 16.61 Resume update — explicit dead-history destruction boundary (2026-10-12)

After reading the Section 5.3 appended decision, all of Section 16 and Section 14.2 in the required
order, the next implementation slice addressed the remaining local dead-history destruction
boundary. The Red tests first required named lifecycle operations and rejected an unmarked persisted
identifier destroy. The Green change added `purge_with_dead_history!` and
`destroy_without_dead_history!` to the independent Email and Telephone history concerns, routed the
two channel purgers through the irreversible operation, and routed ordinary ORG identifier removal
through the explicit no-history operation. Owner-dependent whole-Identity erasure remains its
separate contract and does not archive a new row while it removes existing owner histories. No
schema or migration was added.

The focused history/concurrency tests passed
`29 runs, 141 assertions, 0 failures, 0 errors, 0 skips`; the broader six-model history, retention,
controller and social-unlink collection passed
`181 runs, 918 assertions, 0 failures, 0 errors, 0 skips`. After a named OIDC clock-leeway test was
rerun successfully following an unrelated intermediate failure, the complete run-owned Rails Gate 2
passed `15141 runs, 128212 assertions, 0 failures, 0 errors, 0 skips`, and Vitest passed
`99 files, 1140 tests`. Targeted RuboCop, Brakeman, Ruby syntax, `git diff --check` and repository
knowledge checks passed. Exact commands, dirty-worktree scope and limits are recorded in
[`R7K3`](evidence/2026-10-12-dead-history-destroy-boundary-R7K3.md).

This closes only the local explicit destruction boundary. It does not mark the physical-purge
acceptance condition complete, authorize real-data purge, or resolve the remaining P3d route and
consumer inventory, P10b/P12b Group and writer-controlled cutover, held legacy identifier tables,
D-11 committed-transaction isolation, host Alloy recreation/runtime verification, privacy-retention
policy or historical HMAC-role rollback hazard. No independent acceptance investigation was done.

### 16.62 Resume update — remaining owned opaque issuers and collision boundary (P2, 2026-10-12)

Following Sections 5.3 and 14.2, the next ready P2 slice was the source-confirmed owned opaque
identifier path that still bypassed the shared NanoID issuer. `LogoutTransaction` had been
generating 22-character URL-safe values directly, and the three realm-specific `EnforcementCase`
models were generating 15-byte URL-safe values in their shared concern. These are internal
transaction/policy identities, not provider or protocol secrets. The initial format assertions
failed before the production edits. The Green change routes both paths through `PublicId.generate`;
the logout issuer also retries only a collision reported by its named `public_id` unique index, with
the finite `PublicId::MAX_COLLISION_RETRIES` budget and a fresh transaction for each attempt. Other
validation or unique failures propagate. Both model boundaries now reject post-creation public-ID
changes through ordinary updates; no new trigger or raw SQL authority was added.

The final focused collection passed `40 runs, 135 assertions, 0 failures, 0 errors, 0 skips`. The
current run-owned twenty-database Gate 2 then passed Rails with
`15146 runs, 128235 assertions, 0 failures, 0 errors, 0 skips` and Vitest with
`99 files, 1140 tests`. RuboCop, Brakeman, bundler-audit, `bun run check`, syntax, repository
knowledge and `git diff --check` also passed. Full and focused commands, the dirty worktree revision
and limits are recorded in [`H4J2`](evidence/2026-10-12-public-id-issuers-H4J2.md).

This closes only the two identified issuer/model boundaries. It does not claim database-level
immutability for every owned identifier, complete P2/P6 inventory acceptance, the unchecked
ceremony-purpose and physical-purge matrices, D-11 committed-transaction isolation, P10b/P12b
operational cutover, retained legacy identifier semantics, host Alloy recreation/runtime
verification, privacy-retention policy or the user-excluded independent acceptance investigation.

### 16.63 Resume update — ORG normal sign-in transaction issuer (P2, 2026-10-12)

After the required Section 5.3, Section 16 and Section 14.2 reading order, the next ready P2 slice
classified the `OrgNormalSignInTransaction` session `public_id` as a self-controlled opaque
transaction identity. It is placed into the signed ORG Entra-to-passkey binding and is not an
external provider value, protocol secret, nonce, CSRF token, PKCE value or persistent database
primary key. The existing session storage, binding validation and Entra authority boundary remain
unchanged; only new issuance was standardized.

The Red assertion observed the previous 32-character hexadecimal issuer. The smallest Green change
now calls `PublicId.generate`, producing the repository's NanoID-21 format for new transactions.
Existing session rows and already-issued bindings remain readable. The focused public-boundary
collection passed `19 runs, 117 assertions, 0 failures, 0 errors, 0 skips`.

Before selecting another implementation slice, the run-owned twenty-database Rails Gate 2 passed
`15146 runs, 128226 assertions, 0 failures, 0 errors, 0 skips`; the corresponding Vitest Gate 2
passed `99` files and `1140` tests. The two changed Ruby files passed targeted RuboCop after a
format-only correction. No migration, raw SQL, provider-secret change, CI, Podman, production or
shared destructive operation was used. The exact commands and dirty-worktree limits are recorded in
`evidence/2026-10-12-org-normal-sign-in-public-id-J7K4.md`.

This is current implementation evidence only. It does not close the complete ceremony-ID and purpose
matrix, database-level immutability inventory, D-11 committed-transaction isolation, P10b/P12b
operational cutover, retained legacy identifier semantics, host Alloy runtime verification,
privacy-retention policy or the user-excluded independent acceptance investigation.

### 16.64 Resume update — shared sign-in sequence issuer (P2, 2026-10-12)

The next ready P2 slice classified the `SignInSequenceCarrier` session `id` as a self-controlled,
opaque workflow identity. It is stored inside the surface-scoped Rails session payload and is not a
provider value, protocol secret, CSRF token, PKCE value, database primary key or external API
identifier. The Red assertion observed the former UUID issuer through the public `start!` boundary.
The smallest Green change now uses `PublicId.generate` for newly started sequences while retaining
the existing session shape, surface partitioning, terminal-state behavior and compatibility read of
older serialized payloads. No database, migration, raw SQL, provider-secret or authentication
authority boundary changed.

The focused sequence and adjacent checkpoint collection passed
`29 runs, 68 assertions, 0 failures, 0 errors, 0 skips`. After that local Green, the run-owned Rails
Gate 2 passed `15146 runs, 128238 assertions, 0 failures, 0 errors, 0 skips`, and Vitest passed
`99 files, 1140 tests`. Targeted RuboCop and `git diff --check` also passed. The exact Red/Green
commands, current HEAD, dirty-worktree scope and verification limits are recorded in
[`K8L2`](evidence/2026-10-12-sign-in-sequence-issuer-K8L2.md).

This closes only the shared session-sequence issuer boundary. It does not close the complete
ceremony transaction/grant/result purpose matrix, database-level immutability inventory, D-11
committed-transaction isolation, P10b/P12b operational cutover, retained legacy identifier
semantics, host Alloy recreation/runtime verification, privacy-retention policy or the user-excluded
independent acceptance investigation. No CI, Podman, production, shared destructive operation or
remote synchronization was used.

### 16.65 Resume update — pending-MFA session issuer (P2, 2026-10-12)

The next ready P2 slice classified the `set_pending_mfa!` session `public_id` as a self-controlled,
opaque pending-MFA workflow identity. It is held in the Rails session and is not a provider value,
protocol secret, CSRF token, PKCE value, database primary key or public API identifier. The Red
assertion reached this behavior through the APP challenge HTTP boundary and observed the previous
32-character hexadecimal issuer. The smallest Green change now uses `PublicId.generate` for newly
created pending-MFA payloads while retaining the existing actor, surface, expiry, primary-method and
authentication-boundary fields. No database, migration, raw SQL or session-issuance authority
boundary changed.

The focused APP challenge/TOTP/passkey collection passed
`39 runs, 665 assertions, 0 failures, 0 errors, 0 skips`. The shared-authentication change then
passed the run-owned Rails Gate 2 with
`15146 runs, 128224 assertions, 0 failures, 0 errors, 0 skips`, and Vitest passed
`99 files, 1140 tests`. Targeted RuboCop and `git diff --check` passed. The exact Red/Green
commands, current HEAD, dirty-worktree scope and verification limits are recorded in
[`M3P7`](evidence/2026-10-12-pending-mfa-session-issuer-M3P7.md).

This closes only the pending-MFA session issuer boundary. It does not close the complete ceremony
transaction/grant/result purpose matrix, database-level immutability inventory, D-11
committed-transaction isolation, P10b/P12b operational cutover, retained legacy identifier
semantics, host Alloy recreation/runtime verification, privacy-retention policy or the user-excluded
independent acceptance investigation. No CI, Podman, production, shared destructive operation or
remote synchronization was used.

### 16.66 Resume update — SocialAuth link-intent flow issuer (P2, 2026-10-12)

The next source-confirmed P2 slice classified `SocialAuth`'s `social_auth_flow_id` as a
self-controlled, opaque link-intent correlation identity stored in the Rails session. It is not the
OAuth `state`, provider value, nonce, PKCE verifier, CSRF token, protocol secret, database primary
key or public API identifier. The Red assertion decoded the session cookie through the public social
link integration boundary and observed the previous 32-character hexadecimal issuer. The smallest
Green change now uses `PublicId.generate` for newly created link intents while preserving the
existing session key, TTL, provider binding, callback-state validation, link authorization and
clear-on-completion behavior. The OAuth callback `state` and Apple nonce remain on their existing
security-specific issuers.

The focused SocialAuth link/unlink collection passed
`29 runs, 138 assertions, 0 failures, 0 errors, 0 skips`. Targeted RuboCop inspected the changed
concern and integration tests with no offenses. The run-owned Rails Gate 2 then passed
`15146 runs, 128226 assertions, 0 failures, 0 errors, 0 skips`, and Vitest passed `99` files and
`1140` tests. Exact commands, the tested HEAD, dirty-worktree scope and verification limits are
recorded in [`S6N4`](evidence/2026-10-12-social-auth-flow-issuer-S6N4.md).

This closes only the SocialAuth link-intent issuer boundary. It does not close the complete
OAuth/OIDC, provider-callback, ceremony transaction/grant/result or protocol-secret inventory,
database-level immutability inventory, D-11 committed-transaction isolation, P10b/P12b operational
cutover, retained legacy identifier semantics, host Alloy recreation/runtime verification,
privacy-retention policy or the user-excluded independent acceptance investigation. No CI, Podman,
production, shared destructive operation or remote synchronization was used.

### 16.67 Resume update — identity ceremony candidate references (P2, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next ready P2
slice traced the concrete consumers of the remaining identity ceremony candidate `ref` values. TOTP
enrollment, secret-credential and APP/COM/ORG passkey candidate references are self-controlled,
non-secret opaque values with unique B-tree indexes and no external format authority. Their new
issuers now use `PublicId.generate` (NanoID-21). A shared creation boundary retains normal model
validation, allows only a `ref`-only uniqueness collision to reach the database constraint, and
retries only the named `ref` index within the finite `PublicId::MAX_COLLISION_RETRIES` budget. Other
validation and uniqueness errors are not regenerated. Existing rows and all purpose-specific
secrets, transaction IDs, WebAuthn values and protocol references remain unchanged.

The source review found that `IdentitySocialCeremonyCandidate.ref` is different: APP social-link
completion renders it into a browser form, and the receiver deliberately accepts only the existing
UUID-v4 `AuthAdmissionBinding::REFERENCE_PATTERN`. It remains on that capability contract; the
shared UUID boundary was not widened and no fallback was added. The first attempted NanoID change
was rejected by the public integration tests with HTTP 400, then reverted before the Green run.

The initial candidate-format tests were Red on the former UUID issuers. After the scoped production
change and the named-collision test, the candidate/refusal collection passed
`51 runs, 533 assertions, 0 failures, 0 errors, 0 skips`; the affected SocialAuth app/completion
collection passed `40 runs, 328 assertions, 0 failures, 0 errors, 0 skips`. The run-owned Rails Gate
2 passed `15147 runs, 128249 assertions, 0 failures, 0 errors, 0 skips` with four workers, and
Vitest passed `99 files` and `1140 tests`. Targeted RuboCop and `git diff --check` passed. Exact
commands, the tested HEAD, dirty-worktree scope and verification limits are recorded in
[`T5Q8`](evidence/2026-10-12-identity-candidate-ref-issuer-T5Q8.md).

This closes only the three self-controlled candidate-ref issuer boundaries and their collision
handling. It does not close the full ceremony-purpose matrix, the SocialAuth protocol/capability
exception inventory, database-level immutability for every identifier, D-11 committed-transaction
isolation, P10b/P12b operational cutover, retained legacy identifier semantics, host Alloy
recreation/runtime verification, privacy-retention policy or the user-excluded independent
acceptance investigation. No migration, CI, Podman, production, shared destructive operation or
remote synchronization was used.

### 16.68 Resume update — credential-registration transaction references (P2, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next
source-confirmed P2 slice covered only the six concrete Email/Telephone credential-registration
transaction issuers. These `transaction_id` values are self-controlled, non-secret ceremony
identities bound into the surface/channel session value and delivery path. They are distinct from
OTP `generation`, grant and result identities, provider/protocol values and database primary keys.
The generic ceremony transaction defaults for other purposes remain untouched pending their own
purpose and consumer classification.

The Red tests observed UUID transaction references and rejected NanoID references at the session and
delivery-binding boundaries. The smallest Green change now supplies `PublicId.generate` (NanoID-21)
explicitly for new credential-registration Email and Telephone transactions. Existing UUID-v4
references remain accepted for reads and bindings; OTP generation remains UUID-v4. A transaction-ID
collision is retried only when the concrete table reports its named, single-column unique B-tree
index. Each retry runs inside a database savepoint with a fresh reference and the finite shared
collision budget; unrelated validation or uniqueness errors propagate. No migration, raw SQL,
provider-secret, session authority or cross-surface fallback changed. Missing generic
`transaction_id` attribute labels exposed by the collision boundary were added to the existing
locale fallback maps without changing user-facing workflow semantics.

The initial correctly configured Red collection reported
`33 runs, 488 assertions, 8 failures, 3 errors, 0 skips`. After the implementation and savepoint
collision tests, the focused collection passed
`35 runs, 729 assertions, 0 failures, 0 errors, 0 skips`; the broader credential-registration
collection passed `531 runs, 8643 assertions, 0 failures, 0 errors, 0 skips`. The run-owned
twenty-database Rails Gate 2 then passed
`15150 runs, 128278 assertions, 0 failures, 0 errors, 0 skips` with four workers, and Vitest passed
`99 files` and `1140 tests`. Targeted RuboCop passed for all eleven changed Ruby files. Exact
commands, the tested HEAD, dirty-worktree scope and verification limits are recorded in
[`C7P4`](evidence/2026-10-12-credential-registration-transaction-issuer-C7P4.md).

This closes only the credential-registration transaction-reference issuer and compatibility slice.
It does not close the complete ceremony-purpose matrix, database-level immutability for every
identifier, D-11 committed-transaction isolation, P10b/P12b operational cutover, retained legacy
identifier semantics, host Alloy recreation/runtime verification, privacy-retention policy or the
user-excluded independent acceptance investigation. No CI, Podman, production, shared destructive
operation or remote synchronization was used.

### 16.69 Resume update — APP TOTP enrollment child transaction reference (P2, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next
source-confirmed P2 slice classified only the APP TOTP enrollment child transaction's
`transaction_id`. It is a self-controlled, non-secret ceremony identity carried through the APP TOTP
grant/result and replay store. It is distinct from the step-up parent transaction, grant JTI, OTP
secret/proof, candidate reference, result JTI and database primary key. Other TOTP transaction,
grant, result and protocol values remain on their existing contracts.

The Red test reached the public enrollment issuer and observed the former UUID child reference. The
smallest Green change supplies `PublicId.generate` (NanoID-21) explicitly for new child rows while
leaving the generic TOTP transaction factory UUID-compatible for unclassified callers. The issuer
accepts existing values and preserves the signed grant/result shape. A child transaction reference
collision is retried only for the named single-column `transaction_id` unique B-tree index, inside a
database savepoint with a fresh value and the finite shared collision budget; unrelated validation
or uniqueness failures propagate. No parent step-up, grant JTI, OTP, candidate, result or
cross-surface authority changed.

The correctly configured Red collection reported
`3 runs, 25 assertions, 1 failure, 0 errors, 0 skips`. After implementation and the real
unique-index collision test, the focused issuer collection passed
`4 runs, 32 assertions, 0 failures, 0 errors, 0 skips`; the `.rb` TOTP regression collection passed
`173 runs, 1380 assertions, 0 failures, 0 errors, 0 skips`. The run-owned twenty-database Rails Gate
2 passed `15151 runs, 128275 assertions, 0 failures, 0 errors, 0 skips` with four workers, and
Vitest passed `99 files` and `1140 tests`. Targeted RuboCop passed for the three changed Ruby
implementation/test files. The first attempted broad command included a fixture YAML and was
discarded before test execution; the recorded TOTP collection uses only `.rb` files. Exact commands,
the tested HEAD, dirty-worktree scope and verification limits are recorded in
[`D4R6`](evidence/2026-10-12-totp-enrollment-transaction-issuer-D4R6.md).

This closes only the APP TOTP enrollment child transaction-reference issuer and collision slice. It
does not close the full ceremony-purpose matrix, other transaction/grant/result issuers,
database-level immutability for every identifier, D-11 committed-transaction isolation, P10b/P12b
operational cutover, retained legacy identifier semantics, host Alloy recreation/runtime
verification, privacy-retention policy or the user-excluded independent acceptance investigation. No
CI, Podman, production, shared destructive operation or remote synchronization was used.

### 16.70 Resume update — EnforcementCase public-ID collision boundary (P2, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next ready P2
slice covered only the three realm-local `EnforcementCase.public_id` issuers. These values are
self-controlled, non-secret policy identities; they are separate from principal references,
enforcement state, protocol values and database primary keys. Existing values remain unchanged.

The first Red run reproduced the former behavior: an internally generated ID that collided at the
model validation boundary raised `ActiveRecord::RecordInvalid` instead of entering a bounded
collision path. The smallest Green change keeps `PublicId.generate` as the sole issuer, assigns
through both normal validation and validation-disabled creation, and retries only the exact named
single-column `public_id` unique B-tree collision. Each retry uses a fresh value inside a savepoint
and the finite `PublicId::MAX_COLLISION_RETRIES` budget. The preflight existence check is only an
optimization; the database unique index remains the final authority. Caller-supplied IDs, unrelated
uniqueness errors and exhausted retries propagate explicitly. The existing post-creation
immutability validation remains in force for all three realms.

The focused EnforcementCase public-ID contract passed
`5 runs, 16 assertions, 0 failures, 0 errors, 0 skips`; the related model, ordering and trigger
collection passed `42 runs, 133 assertions, 0 failures, 0 errors, 0 skips`. Targeted RuboCop passed
for the changed concern and test. The run-owned twenty-database Rails Gate 2 passed
`15155 runs, 128289 assertions, 0 failures, 0 errors, 0 skips` with four workers, and Vitest passed
`99 files` and `1140 tests`. No migration, raw SQL, trigger, provider/protocol value, cross-realm
lookup, CI, Podman, production operation, shared destructive operation or remote synchronization was
used. The implementation and test are still uncommitted in the shared worktree; the
document/evidence commit is intentionally separate.

This closes only the EnforcementCase public-ID issuer collision and immutability slice. It does not
close the complete ceremony-purpose matrix, all-table database immutability, D-11 committed-
transaction isolation, P10b/P12b operational cutover, retained legacy identifier semantics,
host-Alloy recreation/runtime verification, privacy-retention policy or the user-excluded
independent acceptance investigation.

### 16.71 Resume update — realm preference public-ID creation boundary (P2/P12a, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next independent
slice covered the owned management identities in `ClientPreference`, `VisitorPreference` and
`OperatorPreference`. These `public_id` values are realm-local, self-controlled, non-secret
preference identities; they are distinct from email/telephone identifiers, provider credential
values, user/visitor/operator identity and database primary keys. Existing values and the existing
P12a capacity migrations remain unchanged.

The Red test reproduced a validation-time duplicate when the shared generator returned an existing
preference ID. The smallest Green change makes the three models use the existing `PublicId` concern
and adds its generated-value preflight refresh before validation. The concern already supplies the
database savepoint retry for a collision on the exact named single-column `public_id` unique B-tree
index, bounded by `PublicId::MAX_COLLISION_RETRIES`; the database remains the final authority.
Caller-supplied values and unrelated uniqueness failures are not regenerated. Normal creation,
validation-disabled creation and ordinary post-creation model updates are covered; existing values
are not rewritten. This is model-level identity protection and does not claim direct-SQL/database
immutability for every owned identifier.

The focused preference collision and shared Concern contract passed
`9 runs, 30 assertions, 0 failures, 0 errors, 0 skips`; the related APP/COM/ORG preference and
capacity suites passed `90 runs, 260 assertions, 0 failures, 0 errors, 0 skips`. Targeted RuboCop
passed for the four Ruby models, shared Concern and new test. The run-owned twenty-database Rails
Gate 2 passed `15159 runs, 128308 assertions, 0 failures, 0 errors, 0 skips` with four workers, and
Vitest passed `99 files` and `1140 tests`. No migration, raw SQL, trigger, provider/protocol value,
cross-realm lookup, CI, Podman, production operation, shared destructive operation or remote
synchronization was used.

This closes only the realm preference model-level generation, collision and ordinary-update
boundary. It does not close direct-SQL immutability, the complete identifier inventory, D-11
committed- transaction isolation, P10b/P12b operational cutover, retained legacy identifier
semantics, host-Alloy recreation/runtime verification, privacy-retention policy or the user-excluded
independent acceptance investigation.

### 16.72 Resume update — APP TOTP credential public-ID creation boundary (P2, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next independent
slice covered only `ClientTotpCredential.public_id`. This is an APP-owned, self-controlled,
non-secret management identity. It is distinct from the encrypted TOTP secret, OTP counters,
one-time proof material, provider/authenticator values and the database primary key.

The Red test reproduced the former behavior: the model-specific initialization callback minted an ID
before the shared `PublicId` concern could record its generated value, so a deterministic unique
index collision surfaced as validation failure without retry. The smallest Green change removes that
duplicate initialization issuer and lets the existing concern generate at the validation/create
boundary. The concern refreshes a generated duplicate before validation and retries a concurrent
collision only for the named single-column `public_id` unique B-tree index, inside a savepoint and
within the finite `PublicId::MAX_COLLISION_RETRIES` budget. Caller-supplied values and unrelated
uniqueness failures are not regenerated; ordinary persisted updates remain immutable. The TOTP
secret, counters, proof and enrollment authority are unchanged.

The focused APP TOTP credential and shared `PublicId` collection passed
`27 runs, 54 assertions, 0 failures, 0 errors, 0 skips`; targeted RuboCop passed for the model and
new test. The run-owned twenty-database Rails Gate 2 passed
`15163 runs, 128328 assertions, 0 failures, 0 errors, 0 skips` with four workers, and Vitest passed
`99 files` and `1140 tests`. No migration, raw SQL, trigger, provider/protocol value, cross-realm
lookup, CI, Podman, production operation, shared destructive operation or remote synchronization was
used. The exact Red/Green commands, tested HEAD, dirty-worktree scope and verification limits are
recorded in [`H7N3`](evidence/2026-10-12-client-totp-public-id-boundary-H7N3.md).

This closes only the APP TOTP credential model-level generation, collision and ordinary-update
boundary. It does not close direct-SQL immutability, the complete identifier inventory, D-11
committed-transaction isolation, P10b/P12b operational cutover, retained legacy identifier
semantics, host-Alloy recreation/runtime verification, privacy-retention policy or the user-excluded
independent acceptance investigation.

### 16.73 Resume update — sign-up Email/Telephone transaction references (P2, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next independent
slice covered only the APP and COM Email/Telephone sign-up transaction issuers and their delivery
binding readers. These `transaction_id` values are self-controlled, non-secret ceremony identities;
they remain distinct from OTP `generation`, grant/result identities, actor/session bindings and
database primary keys. The generic transaction-purpose inventory remains open outside this slice.

The Red run added public issuer assertions and reproduced the previous UUID transaction references:
`30 runs, 386 assertions, 4 failures, 0 errors, 0 skips`. The smallest Green change now supplies
`PublicId.generate` (NanoID-21) for newly issued APP/COM sign-up Email and Telephone transactions.
The delivery binding accepts NanoID-21 or an existing lower-case UUID-v4 transaction reference; the
OTP `generation` reference remains UUID-v4. A generated transaction collision is retried only for
the concrete table's named, single-column `transaction_id` unique B-tree index, using a fresh
reference inside a savepoint and the finite `PublicId::MAX_COLLISION_RETRIES` budget.
Caller-supplied references and unrelated validation or uniqueness failures propagate. No
cross-purpose fallback, surface inference, migration, protocol-secret change or session-authority
change was introduced.

The focused issuer collection passed `34 runs, 502 assertions, 0 failures, 0 errors, 0 skips`; the
binding-value collection passed `6 runs, 272 assertions, 0 failures, 0 errors, 0 skips`; the broader
sign-up delivery/transport collection passed
`114 runs, 2316 assertions, 0 failures, 0 errors, 0 skips`. Targeted RuboCop passed for the eight
changed Ruby files. The run-owned twenty-database Rails Gate 2 passed
`15167 runs, 128354 assertions, 0 failures, 0 errors, 0 skips` with four workers, and Vitest passed
`99 files` and `1140 tests`. Exact commands, tested HEAD, dirty-worktree scope and verification
limits are recorded in [`R4J8`](evidence/2026-10-12-signup-transaction-references-R4J8.md).

This closes only the APP/COM sign-up transaction-reference generation, bounded legacy reader,
delivery-binding and collision slice. It does not close the complete ceremony-purpose matrix,
unclassified transaction/grant/result issuers, database-level immutability for every identifier,
D-11 committed-transaction isolation, P10b/P12b operational cutover, retained legacy identifier
semantics, host-Alloy recreation/runtime verification, privacy-retention policy or the user-excluded
independent acceptance investigation. No CI, Podman, production, shared destructive operation or
remote synchronization was used.

### 16.74 Resume update — sign-up Email/Telephone grant references (P2, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next independent
slice extended only the APP/COM Email/Telephone sign-up issuer boundary to its separate `grant_jti`.
This value is a self-controlled, non-secret grant identity and remains distinct from
`transaction_id`, OTP `generation`, `result_jti`, actor/session references and provider/protocol
values. Other ceremony grant issuers remain unclassified outside this slice.

The Red run added NanoID-21 and generated-grant-collision assertions and reproduced the former UUID
behavior plus the missing retry path: `38 runs, 510 assertions, 8 failures, 0 errors, 0 skips`. The
smallest Green change now generates `grant_jti` with `PublicId.generate` alongside the transaction
reference. It retries only the exact named single-column `grant_jti` or `transaction_id` unique
B-tree collision inside a savepoint and the finite `PublicId::MAX_COLLISION_RETRIES` budget;
caller-supplied values and unrelated validation/uniqueness failures propagate. Existing UUID-v4
grant values remain valid opaque claims. The four locale fallback maps now include the missing
`grant_jti` attribute label so collision validation reports an error rather than failing while
looking up its label; this does not alter the workflow contract.

The first Green attempt exposed that missing locale label as four errors
(`38 runs, 506 assertions, 0 failures, 4 errors, 0 skips`). After the label and style corrections,
the focused issuer collection passed `38 runs, 522 assertions, 0 failures, 0 errors, 0 skips`; the
broader sign-up delivery/transport collection passed
`118 runs, 2336 assertions, 0 failures, 0 errors, 0 skips`. Targeted RuboCop passed for the four
changed Ruby implementation/test files. The run-owned twenty-database Rails Gate 2 passed
`15171 runs, 128372 assertions, 0 failures, 0 errors, 0 skips` with four workers, and Vitest passed
`99 files` and `1140 tests`. Exact commands, tested HEAD, dirty-worktree scope, the intermediate
locale error and verification limits are recorded in
[`P6T9`](evidence/2026-10-12-signup-grant-references-P6T9.md).

This closes only the APP/COM sign-up grant-reference generation and exact collision boundary. It
does not close other grant issuers, result identities, the complete ceremony-purpose matrix,
database-level immutability for every identifier, D-11 committed-transaction isolation, P10b/P12b
operational cutover, retained legacy identifier semantics, host-Alloy recreation/runtime
verification, privacy-retention policy or the user-excluded independent acceptance investigation. No
CI, Podman, production, shared destructive operation or remote synchronization was used.

### 16.75 Resume update — credential-registration Email/Telephone grant references (P2, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next independent
P2 slice covered only the APP, COM and ORG Email/Telephone credential-registration `grant_jti`
issuers. This is a self-controlled, non-secret grant identity distinct from the transaction
reference, OTP generation, result identities, actor/session references and provider/protocol values.
Existing UUID-v4 grant values remain opaque and readable; no other ceremony grant or result issuer
was inferred from this slice.

The Red run reached the public Email and Telephone registration issuers and reproduced the former
UUID grant values plus the missing generated-grant collision path:
`20 runs, 191 assertions, 7 failures, 0 errors, 0 skips`. The smallest Green change now generates
`grant_jti` with `PublicId.generate` alongside each new transaction reference. It retries only an
exact named single-column `grant_jti` or `transaction_id` unique B-tree collision inside a database
savepoint and the finite `PublicId::MAX_COLLISION_RETRIES` budget; caller-supplied values and
unrelated validation or uniqueness failures propagate. Transaction, grant, generation and
proof/session purpose bindings remain separate.

The focused issuer collection passed `20 runs, 248 assertions, 0 failures, 0 errors, 0 skips`. The
broader issuer/binding collection passed `37 runs, 745 assertions, 0 failures, 0 errors, 0 skips`.
Targeted RuboCop passed for the four changed Ruby implementation/test files. Gate 2 then ran the
run-owned twenty-database Rails suite with four workers and passed
`15173 runs, 128384 assertions, 0 failures, 0 errors, 0 skips`; Vitest passed `99 files` and
`1140 tests`. The Rails run emitted existing Flipper/OmniAuth diagnostic output but no test
failures. Exact commands, tested HEAD, dirty-worktree scope and limits are recorded in
[`T3K7`](evidence/2026-10-12-credential-registration-grant-references-T3K7.md).

This closes only the credential-registration Email/Telephone grant-reference generation and exact
collision boundary. It does not close the complete ceremony-purpose matrix, other grant/result
issuers, database-level immutability for every identifier, D-11 committed-transaction isolation,
P10b/P12b operational cutover, retained legacy identifier semantics, host-Alloy recreation/runtime
verification, privacy-retention policy or the user-excluded independent acceptance investigation. No
CI, Podman, production, shared destructive operation or remote synchronization was used.

### 16.76 Resume update — Email recovery and withdrawal reentry references (P2, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next independent
P2 slice covered Email reentry OTP issuance for APP, COM and ORG recovery and APP/COM withdrawal.
ORG withdrawal remains an explicit unsupported operation. The new transaction and grant references
are self-controlled, non-secret ceremony identities; browser/session references and OTP generation
remain separate UUID-bound contracts.

The Red run first reproduced the former UUID transaction/grant values in the public issuer:
`7 runs, 52 assertions, 5 failures, 0 errors, 0 skips`. After adding explicit transaction- and
grant-collision cases, the Red run reported `9 runs, 58 assertions, 7 failures, 0 errors, 0 skips`.
The smallest Green change now supplies `PublicId.generate` for both new references and retries only
an exact named single-column `transaction_id` or `grant_jti` unique B-tree collision inside a
savepoint and the finite `PublicId::MAX_COLLISION_RETRIES` budget. The delivery binding was changed
to accept NanoID-21 or existing UUID-v4 transaction references while continuing to require UUID OTP
generation; operation, surface and no-fallback boundaries remain unchanged.

The final issuer/binding collection passed `11 runs, 187 assertions, 0 failures, 0 errors, 0 skips`;
the broader reentry delivery/verification collection passed
`22 runs, 313 assertions, 0 failures, 0 errors, 0 skips`. Targeted RuboCop passed for the four
changed Ruby implementation/test files after one correctable empty-line offense. Gate 2 then ran the
run-owned twenty-database Rails suite with four workers and passed
`15175 runs, 128413 assertions, 0 failures, 0 errors, 0 skips`; Vitest passed `99 files` and
`1140 tests`. Exact commands, tested HEAD, dirty-worktree scope and limits are recorded in
[`Q4M8`](evidence/2026-10-12-email-reentry-references-Q4M8.md).

This closes only the Email reentry transaction/grant reference and reader boundary. It does not
close the complete ceremony-purpose matrix, other grant/result issuers, database-level immutability
for every identifier, D-11 committed-transaction isolation, P10b/P12b operational cutover, retained
legacy identifier semantics, host-Alloy recreation/runtime verification, privacy-retention policy or
the user-excluded independent acceptance investigation. No CI, Podman, production, shared
destructive operation or remote synchronization was used.

### 16.77 Resume update — Secret Credential ceremony transaction and grant references (P2, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next independent
P2 slice covered only the APP, COM and ORG Secret Credential ceremony transaction creation boundary.
The concrete `transaction_id` and `grant_jti` values are self-controlled, non-secret ceremony
identities; `result_jti`, candidate references, secret material and actor/session references remain
separate contracts. Other result and ceremony issuers remain outside this slice.

The Red run added public replay-store/model assertions and reproduced the former UUID generation
plus missing collision recovery: `7 runs, 16 assertions, 5 failures, 0 errors, 0 skips`. The
smallest Green change now makes `SecretCredentialCeremonyTransactionable.create_transaction!`
generate a separate `PublicId.generate` value for each missing reference. It retries only an exact
named single-column `transaction_id` or `grant_jti` unique B-tree collision inside a savepoint and
the finite `PublicId::MAX_COLLISION_RETRIES` budget. Explicit inputs, unrelated validation or
uniqueness failures and exhausted retries remain explicit failures; no result identity, secret,
surface or purpose fallback was added.

The focused replay-store collection passed `7 runs, 27 assertions, 0 failures, 0 errors, 0 skips`.
The related Secret Credential contract, result-issuer, final-committer, consumer and purger
collection passed `50 runs, 313 assertions, 0 failures, 0 errors, 0 skips`. Targeted RuboCop passed
for the concern and replay-store test. Gate 2 then ran the run-owned twenty-database Rails suite
with four workers and passed `15180 runs, 128432 assertions, 0 failures, 0 errors, 0 skips`; Vitest
passed `99 files` and `1140 tests`. Exact commands, tested HEAD, dirty-worktree scope and limits are
recorded in [`S7L2`](evidence/2026-10-12-secret-credential-references-S7L2.md).

This closes only generated Secret Credential ceremony transaction/grant references and their exact
collision boundary. It does not close Secret Credential `result_jti`, the permanent credential
identity, other unclassified ceremony issuers, database-level immutability for every identifier,
D-11 committed-transaction isolation, P10b/P12b operational cutover, retained legacy identifier
semantics, host-Alloy recreation/runtime verification, privacy-retention policy or the user-excluded
independent acceptance investigation. No CI, Podman, production, shared destructive operation or
remote synchronization was used.

### 16.78 Resume update — Social ceremony transaction and grant references (P2, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next independent
P2 slice covered only the APP Social ceremony transaction creation boundary used by
`IdentitySocialCeremonyGrantIssuer`. The internally generated `transaction_id` and `grant_jti` are
self-controlled, non-secret ceremony identities; provider subject values, OAuth/OIDC state,
candidate capability references and result identities remain separate contracts.

The Red run strengthened the public transaction concern assertions and added transaction- and
grant-collision cases, reproducing the former UUID generation and missing retry path:
`5 runs, 18 assertions, 3 failures, 0 errors, 0 skips`. The smallest Green change now makes
`SocialCeremonyTransactionable.create_transaction!` generate separate `PublicId.generate` values for
missing references. It retries only an exact named single-column `transaction_id` or `grant_jti`
unique B-tree collision inside a savepoint and the finite `PublicId::MAX_COLLISION_RETRIES` budget.
Explicit values, provider subject/candidate values, unrelated validation or uniqueness failures and
exhausted retries remain explicit; no OAuth/provider or cross-purpose fallback was added.

The focused Social transaction collection passed
`5 runs, 37 assertions, 0 failures, 0 errors, 0 skips`. The related Social contract, result-issuer,
consumer and integration collection passed `69 runs, 400 assertions, 0 failures, 0 errors, 0 skips`.
Targeted RuboCop passed for the concern and test. Gate 2 then ran the run-owned twenty-database
Rails suite with four workers and passed
`15182 runs, 128433 assertions, 0 failures, 0 errors, 0 skips`; Vitest passed `99 files` and
`1140 tests`. Exact commands, tested HEAD, dirty-worktree scope and limits are recorded in
[`H5N6`](evidence/2026-10-12-social-ceremony-references-H5N6.md).

This closes only generated Social ceremony transaction/grant references and their exact collision
boundary. It does not close Social `result_jti`, provider subject values, candidate capability
references, permanent external-identity identifiers, other unclassified ceremony issuers,
database-level immutability for every identifier, D-11 committed-transaction isolation, P10b/P12b
operational cutover, retained legacy identifier semantics, host-Alloy recreation/runtime
verification, privacy-retention policy or the user-excluded independent acceptance investigation. No
CI, Podman, production, shared destructive operation or remote synchronization was used.

### 16.79 Resume update — Step-up ceremony transaction and grant references (P2, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next independent
P2 slice covered the APP, COM and ORG Step-up ceremony transaction creation boundary. The internally
generated `transaction_id` and `grant_jti` are separate self-controlled, non-secret ceremony
identities. Step-up purpose, surface, actor/session binding, audience, allowed methods, expiry and
assurance guards remain authoritative; `result_jti`, signed result claims, credential/session
references and OTP or authenticator values remain separate contracts.

The Red run reached the public APP Step-up transaction boundary and reproduced the former UUID
generation plus missing generated-collision recovery:
`6 runs, 33 assertions, 3 failures, 0 errors, 0 skips`. The smallest Green change now makes
`StepUpCeremonyTransactionable.create_transaction!` generate separate `PublicId.generate` values for
missing transaction and grant references. It retries only an exact named single-column
`transaction_id` or `grant_jti` unique B-tree collision inside a savepoint and the finite
`PublicId::MAX_COLLISION_RETRIES` budget. Explicit inputs, unrelated validation or uniqueness
failures and exhausted retries remain explicit; no result, proof, session-issuance, surface or
purpose fallback was added.

The focused Step-up transaction collection passed
`6 runs, 41 assertions, 0 failures, 0 errors, 0 skips`. The related Step-up contract, replay-store,
model-transition, admission, verification, purge and integration collection passed
`204 runs, 1758 assertions, 0 failures, 0 errors, 0 skips`. Targeted RuboCop passed for the concern
and transaction test. Gate 2 then ran the run-owned twenty-database Rails suite with four workers
and passed `15184 runs, 128457 assertions, 0 failures, 0 errors, 0 skips`; Vitest passed `99 files`
and `1140 tests`. Exact commands, tested HEAD, dirty-worktree scope and verification limits are
recorded in [`J7P3`](evidence/2026-10-12-step-up-ceremony-references-J7P3.md).

This closes only generated Step-up ceremony transaction/grant references and their exact collision
boundary. It does not close Step-up `result_jti`, proof or authenticator identities, other
unclassified ceremony issuers, database-level immutability for every identifier, D-11 committed-
transaction isolation, P10b/P12b operational cutover, retained legacy identifier semantics,
host-Alloy recreation/runtime verification, privacy-retention policy or the user-excluded
independent acceptance investigation. No CI, Podman, production, shared destructive operation or
remote synchronization was used.

### 16.80 Resume update — OIDC authorization transaction references (P2, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next independent
P2 slice covered the three concrete APP, COM and ORG OIDC authorization transaction writers and
their coordinator consumers. `transaction_id` is an internally generated, non-secret durable
transaction identity. OIDC `state`, `nonce`, PKCE challenge, login challenge, client/provider values
and protocol identifiers remain separate contracts.

The Red run reached the public model/coordinator boundary and reproduced the former UUID generation
plus missing collision recovery: `13 runs, 189 assertions, 2 failures, 0 errors, 0 skips`. The
smallest Green change now makes `OidcAuthorizationTransactionable.create_transaction!` generate a
NanoID-21 `transaction_id` with `PublicId.generate`. It retries only an exact named single-column
`transaction_id` unique B-tree collision inside a savepoint and the finite
`PublicId::MAX_COLLISION_RETRIES` budget. Login-challenge uniqueness, caller/request validation,
other uniqueness failures and exhausted retries remain explicit; no state, nonce, PKCE, provider,
surface or protocol fallback was added.

The focused OIDC model collection passed `13 runs, 191 assertions, 0 failures, 0 errors, 0 skips`.
The related coordinator, admission-binding, token-exchange, purge and OIDC integration collection
passed `185 runs, 1610 assertions, 0 failures, 0 errors, 0 skips`. Targeted RuboCop passed for the
concern and test after one parameter-alignment correction. Gate 2 then ran the run-owned
twenty-database Rails suite with four workers and passed
`15185 runs, 128451 assertions, 0 failures, 0 errors, 0 skips`; Vitest passed `99 files` and
`1140 tests`. Exact commands, tested HEAD, dirty-worktree scope and verification limits are recorded
in [`K2R4`](evidence/2026-10-12-oidc-authorization-transaction-references-K2R4.md).

This closes only generated OIDC authorization transaction references and their exact collision
boundary. It does not close OIDC `state`, `nonce`, PKCE, login-challenge, provider/client or
protocol identifiers, other unclassified ceremony issuers, database-level immutability for every
identifier, D-11 committed-transaction isolation, P10b/P12b operational cutover, retained legacy
identifier semantics, host-Alloy recreation/runtime verification, privacy-retention policy or the
user-excluded independent acceptance investigation. No CI, Podman, production, shared destructive
operation or remote synchronization was used.

### 16.81 Resume update — Passkey ceremony transaction references (P2, 2026-10-12)

Following the required Section 5.3, Section 16 and Section 14.2 reading order, the next independent
P2 slice covered the concrete APP, COM and ORG Passkey ceremony transaction factory and its replay,
result, final-commit, purge, registration and authorization consumers. `transaction_id` and
`grant_jti` are self-controlled, non-secret ceremony identities. Relying-party identifiers and
origins, credential-candidate references, WebAuthn challenge/client-data/result values, credential
identities and other protocol/session values remain separate contracts; the existing
challenge/protocol writer remains the HTTP authority.

The Red run reached the public Passkey transaction boundary and reproduced the former UUID
generation plus missing generated-collision recovery:
`9 runs, 228 assertions, 3 failures, 0 errors, 0 skips`. The smallest Green change now makes
`PasskeyCeremonyTransactionable.create_transaction!` generate separate NanoID-21 `transaction_id`
and `grant_jti` values. It retries only an exact named single-column `transaction_id` or `grant_jti`
unique B-tree collision inside a savepoint and the finite `PublicId::MAX_COLLISION_RETRIES` budget.
Explicit inputs, unrelated validation or uniqueness failures and exhausted retries remain explicit;
no surface, purpose, WebAuthn or protocol fallback was added.

The focused Passkey transaction collection passed
`9 runs, 233 assertions, 0 failures, 0 errors, 0 skips`. The related Passkey replay-store, contract,
result-issuer, final-committer, purger, registration-committer, authorization and numeric-date
collection passed `65 runs, 644 assertions, 0 failures, 0 errors, 0 skips`. Targeted RuboCop passed
for the concern and test. Gate 2 then ran the run-owned twenty-database Rails suite with four
workers and passed `15188 runs, 128470 assertions, 0 failures, 0 errors, 0 skips`; Vitest passed
`99 files` and `1140 tests`. Exact commands, tested HEAD, dirty-worktree scope and verification
limits are recorded in [`M3P5`](evidence/2026-10-12-passkey-ceremony-references-M3P5.md).

This closes only generated Passkey ceremony transaction/grant references and their exact collision
boundary. It does not close WebAuthn credential IDs or challenge/protocol values, Passkey result
identities, other unclassified ceremony issuers, database-level immutability for every identifier,
D-11 committed-transaction isolation, P10b/P12b operational cutover, retained legacy identifier
semantics, host-Alloy recreation/runtime verification, privacy-retention policy or the user-excluded
independent acceptance investigation. No CI, Podman, production, shared destructive operation or
remote synchronization was used.
