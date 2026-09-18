# Conflict ledger

This file is the single conflict ledger for the integrated hardening work. It does not replace
accepted ADRs, implementation plans, or evidence.

## CF-001 — Pre-existing plan-file deletions

- Status: OPEN_NON_BLOCKING
- Severity: P2
- Requirement: execution discipline; repository plan and conflict handling
- Evidence: branch `feature` at `3ff5241c4b876c2c828e772c0fd289c8aae5f850`;
  `git status --porcelain=v2` shows a pre-existing deletion of `misc.md` and `refactor.md`.
- Conflict: Earlier instructions name `misc.md` and `refactor.md`, while the current repository
  knowledge tree directs implementation plans to `plans/` and the adopted prompt names root
  `conflict.md` as the conflict ledger.
- Impact: Restoring either deleted file would overwrite another actor's work and create competing
  planning ledgers.
- Current-cycle action: Preserve both deletions; use
  `plans/backlog/2026-09-17-integrated-hardening-plan.md` and this root `conflict.md`.
- Safe to defer because: no runtime or security behavior depends on either deleted file.
- Next-cycle action: The owner of the pre-existing deletion should decide whether those files are
  intentionally retired.
- Acceptance test: `git status` still identifies the deletions as pre-existing and the canonical
  plan/ledger are linked from the final handoff.
- Related evidence: Phase 0 working-tree inspection; no secrets or raw logs retained.

## CF-002 — Isolated Rails test boundary is incomplete

- Status: BLOCKS_SLICE
- Severity: P1
- Requirement: Phase 0 verification and every test-gated implementation slice
- Evidence: `bundle check` succeeds and Bundler loads `pg` 1.6.3. A direct
  `scripts/test-environment-check` invocation uses the system Ruby and fails with
  `LoadError: cannot load such file -- pg`; `bundle exec scripts/test-environment-check` fails
  because `VALKEY_TEST_HOST` and `VALKEY_TEST_PORT` are unset; the bundled affected `bin/rails test`
  boot fails before test execution for the same missing test Valkey configuration. Attempts with the
  repository's explicit loopback Valkey URL shape booted Rails and reached the configured PostgreSQL
  host, but the focused authority test failed before assertions because the test surface schema
  lacks the `organizations` relation (`PG::UndefinedTable`). The configured `valkey` service did not
  respond to readiness checks. The test-scoped `RAILS_ENV=test ... bundle exec bin/jobs check` did
  pass with disposable local variable values, but
  `RAILS_ENV=development ... bundle exec bin/jobs check` with the required local boot variables
  reaches recurring-task loading but cannot resolve the configured PostgreSQL host `primary`; the
  production equivalent stops at missing `TRUSTED_PROXIES`. Current focused Rails tests likewise
  stop before assertions because PostgreSQL is not listening at `127.0.0.1:5432`, so those checks
  remain unverified.
- Conflict: The repository requires isolated Rails/Minitest verification, but the hostname-based
  test Valkey service is not responsive, the primary test database remains incomplete for the full
  fixture set, and the available surface databases require explicit loopback test variables. This
  prevents treating the focused surface runs as a full-suite or deployment-topology proof.
- Impact: Rails tests, route/runtime checks, database connection proofs, and Solid Queue integration
  checks are currently unverified.
- Current-cycle action: Preserve the historical isolated-service results as historical evidence and
  use only explicitly isolated services for any new regression slice. The current session has no
  usable PostgreSQL/Valkey listener, so no new database-backed result is promoted to a full-suite,
  worker-runtime, or production-readiness claim.
- Safe to defer because: no application behavior is enabled by this environment failure, and no
  datastore fallback is safe.
- Next-cycle action: Provision or restore the repository's explicit isolated PostgreSQL/Valkey test
  topology, apply only the approved test schema preparation, provide the required
  development/production boot variables without using shared data stores, then rerun the narrow
  baseline through `scripts/test-isolated` and the environment-specific Solid Queue checks.
- Acceptance test: the bundled preflight, the affected `bin/rails test` commands, and isolated DB
  checks boot without falling back to a non-test datastore.
- Related evidence: `evidence/2026-09-17-phase-0-and-safe-slices.md` records the exact command
  outcomes without secrets or raw logs.

## CF-003 — Existing Persona/Organization authority graph is not the adopted graph

- Status: BLOCKS_SLICE
- Severity: P0
- Requirement: adopted Persona/Organization vocabulary, ownership, and RBAC migration
- Evidence: commit `c34b1ee40` introduced `app/models/client_persona.rb`,
  `app/models/operator_organization.rb`, and the `app/models/concerns/persona.rb` /
  `organization.rb` interfaces. The current worktree authors the surface-local authority schema in
  `db/app_zenith_migrate/20260917120000_create_app_authority_relations.rb`,
  `db/com_zenith_migrate/20260917120001_create_com_authority_relations.rb`, and
  `db/org_zenith_migrate/20260917120002_create_org_authority_relations.rb`; those migrations have
  not run in this session. The existing `persona_assignments`, `individual_assignments`,
  `agent_assignments`, and membership rows still use RP binding or concrete-resource relationships.
- Conflict: The adopted contract requires real Persona/Organization interfaces and
  Client/Visitor/Operator authority rows. The semantic principal/RP bases now inherit one
  surface-local canonical writer boundary, but the live database, old-data owner mapping, lifecycle
  gates, runtime rollback/concurrency proof, and authorization cutover are not proven.
- Impact: A partial rename or parallel authority table would permit ambiguous authorization,
  duplicate ownership, or cross-surface confusion.
- Current-cycle action: Complete the mechanical vocabulary/reference migration without aliases,
  author the explicit surface-local schema and six creation contracts, and give each surface one
  canonical writer pool while retaining distinct semantic RP/principal interfaces. The authority
  lock acquisition now passes only its unique principal key so repeated or concurrent
  `create_or_find_by!` recovery cannot be made impossible by changing timestamp attributes or a Ruby
  uniqueness validation. The creators also lock and re-read the concrete principal before checking
  the fixed surface `ACTIVE` status, `login_allowed?`, and `access_enabled?`. Keep old
  assignment/membership authorization active only as the current implementation; do not present it
  as the adopted authority model or add a dual fallback. Do not execute the migrations or wire the
  creators into user-facing routes until isolated DB, rollback/concurrency, and owner-mapping gates
  pass. The six authored ownership models now reject independent Active Record destruction so an
  application path cannot create an ownerless interval; this guard does not replace the future
  locked transfer/lifecycle operations or prove direct-SQL behavior. A read-only
  `AuthorityOwnerMigrationInventory` and `authority:owner_inventory` task now enumerate all six
  concrete resources, classify legacy binding/membership candidates, emit only public identifiers,
  and fail on a partially applied authority schema; the live report remains unrun because the
  isolated PostgreSQL/Valkey test boundary is unavailable.
- Safe to defer because: the foundation does not switch authorization sources or backfill a second
  owner. Static model loading, syntax, lint, and the canonical pool inheritance are authored;
  runtime migration, rollback, quota races, and current-data mapping remain unverified. Focused
  creator, schema-contract, vocabulary, and app creation-race tests now pass against the available
  isolated test services; this does not substitute for migration/cutover proof.
- Next-cycle action: Run the three surface migrations on isolated databases, prove one-writer
  rollback/concurrency, run the owner inventory against each isolated surface, review ambiguous
  rows, then implement lifecycle-gated policy and cutover one surface at a time.
- Acceptance test: one validated app slice proves concrete FKs, owner uniqueness, role gates,
  connection rollback, quota serialization, and no old authority fallback before com/org expansion.
- Related evidence: `docs/architecture/persona-organization-authority.md`,
  `plans/backlog/2026-09-17-integrated-hardening-plan.md`,
  `evidence/2026-09-17-phase-1-vocabulary.md`, commits `c34b1ee40`, `3c8086cd8`, `a94eaccab`,
  `bc8367aed`, `10c28f908`, `89f9b1aa3`, and `763a2153f`, and current model/migration sources;
  `evidence/2026-09-17-authority-lock-reuse.md` records the lock-reuse correction;
  `evidence/2026-09-17-authority-eligibility.md` records the administrative-lock regression check;
  `evidence/2026-09-17-authority-ownership-retention.md` records the ownership-row guard and its
  blocked runtime test; the current inventory result is recorded in the dated evidence for this
  phase.

## CF-004 — Existing lifecycle/retention clocks differ from the adopted cycle

- Status: BLOCKS_SLICE
- Severity: P0
- Requirement: irreversible lifecycle, coordinated closure, scrub, and retention
- Evidence: `Client`, `Visitor`, and `Operator` use `deactivated_at`, `discarded_at`, `purged_at`,
  `withdrawal_started_at`, and `terminated_at`; existing comments and `RetentionPurgeJob` use the
  retention columns for deletion/anonymization, while the adopted contract gives the
  1-hour/7-day/31-day meaning to a distinct closure cycle.
- Conflict: Reinterpreting existing columns or enabling new irreversible transitions without an
  inventory would change security and data-retention semantics. The current Client/Visitor sign
  withdrawal flow explicitly permits recovery after logical discard; that is a separate principal
  contract and cannot be silently applied to, or treated as the adopted lifecycle for, Persona or
  Organization resources.
- Impact: Incorrect reactivation, premature deletion, stale-job restoration, or false termination
  completion.
- Current-cycle action: No lifecycle column reinterpretation or destructive migration; inventory
  exact current operations, holds, anonymizer fields, operator deletion paths, and the boundary
  between the existing principal recovery flow and the not-yet-enabled resource lifecycle.
- Safe to defer because: no new lifecycle behavior is enabled by the independent observability
  slice.
- Next-cycle action: Define explicit current-state workflow fields/relations, lock order, scrub
  inventory, and isolated migration/runbook gates.
- Acceptance test: boundary tests at one hour, seven days, thirty-one days, hold races, stale jobs,
  rollback, and terminal non-recovery pass on isolated data.
- Related evidence: existing retention ADRs and the lifecycle inventory to be added during Phase 6.

## CF-005 — Solid Queue runtime execution is not yet proven

- Status: BLOCKS_SLICE
- Severity: P1
- Requirement: explicit queue/worker/recurring configuration
- Evidence: The original configuration used anchors, merge keys, and `queues: "*"`; the original
  recurring file omitted explicit class queue/priority/args and differed by environment. The current
  `config/queue.yml` and `config/recurring.yml` are explicit, the concrete/gem inventory is recorded
  in `docs/operations/solid-queue-runtime.md`, and the contract test parses the mapping. The
  test-scoped `RAILS_ENV=test ... bundle exec bin/jobs check` passed with disposable local
  variables. A development check with explicit loopback cache/rate-limit/auth-state URLs and
  `TRUSTED_PROXIES` stopped while resolving PostgreSQL host `primary`; production stopped before
  boot because `TRUSTED_PROXIES` was absent. No isolated worker was run.
- Conflict: Static mapping can prove configuration coverage but cannot prove that a deployed worker
  reads this file, the queue DB schema is current, or dispatcher/scheduler/worker state transitions
  execute.
- Impact: lost processing, queue starvation, retry failure, or accidental production load
  concentration.
- Current-cycle action: Replaced the wildcard/anchor configuration, aligned development and
  production recurring sets, added exact workers and queue-pool documentation, isolated retention
  work, added a per-job ledger, and verified the test-scoped Solid Queue configuration command. No
  production worker or queue DB was touched.
- Safe to defer because: queue configuration is statically explicit and no external runtime claim is
  being made; enabling or deploying the changed topology without the runtime check is not safe to
  claim.
- Next-cycle action: Supply the required development/production boot variables without using shared
  data stores, rerun both environment checks, and run the isolated immediate/delayed/recurring/retry
  worker integration suite against disposable test services.
- Acceptance test: every effective queue has a worker, every recurring class/command is valid, no
  wildcard/anchor/duplicate key remains, and delayed/retry/recurring jobs execute in an isolated
  queue DB.
- Related evidence: queue audit evidence after the inventory is executed.

## CF-006 — Avatar navigation request overlaps an explicit Avatar exclusion

- Status: ACCEPTED_LIMITATION
- Severity: P2
- Requirement: dashboard Avatar show-to-edit reachability versus Persona prompt explicit exclusions
- Evidence: `app/controllers/base/org/avatars_controller.rb` has `show` and `edit`;
  `app/controllers/base/org/roots_controller.rb` links only to `base_org_avatar_path`; the adopted
  prompt excludes Avatar functionality/RBAC/lifecycle changes.
- Conflict: Adding a new Avatar UI control may be a navigation-only fix, but broadening it while the
  Persona slice is explicitly excluding Avatar is unsafe scope expansion.
- Impact: possible UI drift or accidental Avatar authorization/lifecycle coupling; no impact on
  current independent navigation/observability work.
- Current-cycle action: Added only an existing-route navigation prop from org Avatar show to edit.
  The controller's existing `show?` and `update?` authorization remains in place; no Avatar state,
  lifecycle, create, or RBAC behavior changed. Runtime props verification remains blocked by CF-002.
- Safe to defer because: current Avatar show/edit routes exist and no new authority is granted by
  deferral.
- Next-cycle action: Re-audit after the excluded Avatar work completes; remove or retain the
  navigation-only change based on that review, without expanding Avatar scope.
- Acceptance test: show exposes an existing authorized edit link without adding new permissions or
  changing Avatar state transitions.
- Related evidence: dashboard inventory and Avatar controller source.

## CF-007 — Regional RP registration conflicts with the accepted seven-client ADR

- Status: BLOCKS_SLICE
- Severity: P0
- Requirement: Auth/RP regional registration and session uniqueness
- Evidence: `adr/base-auth-ceremony-and-seven-rp-boundary.md:31-39` fixes seven first-party clients
  named `core-app`, `core-com`, `core-org`, `side-app`, `side-com`, `side-org`, and `edit-org`; the
  current auth consolidation plan repeats that exact set at
  `plans/backlog/integrated-auth-boundary-surface-consolidation-plan.md:20-28`. The adopted
  hardening prompt separately requires JP and US to be distinct registered app RPs and says
  `core-app-jp`/`core-app-us` are illustrative names.
- Conflict: The client count, identity, configuration keys, redirect registrations, logout
  destinations, and migration/retirement order cannot be chosen from the repository alone. Treating
  the two statements as equivalent could merge regional sessions or bypass old-client retirement.
- Impact: Cross-region RP-session issuance, redirect/client confusion, stale-session migration, and
  incorrect revoke scope.
- Current-cycle action: Do not change OIDC client registries, RP names, redirects, keys, or session
  schema. Keep the conflict visible while independent navigation, observability, and queue slices
  proceed.
- Safe to defer because: no current-cycle slice changes RP acceptance or authorization, and leaving
  the existing registry untouched does not silently broaden access.
- Next-cycle action: Produce a region/client matrix with exact IDs, audiences, redirect URIs, logout
  destinations, existing-session migration state, and external RP/Edge acceptance before
  implementation.
- Acceptance test: JP and US issue only to their registered client IDs, exact redirect/client
  binding is enforced before code consumption, old clients have a safe retirement window, and
  same-parent same-RP uniqueness is proven concurrently.
- Related evidence: current accepted ADR, auth consolidation plan, and the regional-RP requirement
  ledger.

## CF-008 — Adopted scrub inventory is broader than the current anonymizer and Operator path

- Status: BLOCKS_SLICE
- Severity: P0
- Requirement: lifecycle, asynchronous scrubbing, retained terminal rows, and encryption cutover
- Evidence: `app/operations/withdrawal_personal_data_anonymizer.rb:12-83` handles Client/Visitor
  contacts, credentials, and common social identities; `app/jobs/retention_purge_job.rb:121-150`
  marks Client/Visitor rows terminated after that operation and has a separate Operator physical
  purge path at `:89-119`. The adopted contract requires an explicit per-model/per-attribute
  inventory, retained terminal Identity rows, no unapproved resource-row purge, and completion only
  after all required scrub steps.
- Conflict: The current code does not establish that all required live attributes, Operator records,
  related databases, credentials, holds, or backup boundaries satisfy the adopted terminal contract.
  Reinterpreting existing `discarded_at`/`purged_at` clocks or expanding the anonymizer without a
  data-shape review could erase data or leave credentials active.
- Impact: stale authentication, incomplete erasure, legal-hold bypass, irreversible data loss, or
  false `TERMINATED` reporting.
- Current-cycle action: No lifecycle column reinterpretation, encryption migration, physical purge,
  Operator deletion change, or new scrub job was enabled. The Phase 0 plan records the observed
  inventory and blocks the affected slice.
- Safe to defer because: unrelated safe slices do not rely on lifecycle completion or destructive
  cleanup, and the current request-time access gates remain unchanged.
- Next-cycle action: Complete the surface-local schema/attribute/hold inventory, connection rollback
  proof, restartable backfill design, stale-job tests, and isolated dry-run before any destructive
  or terminal behavior change.
- Acceptance test: exact target inventory is persisted, hold races block destructive work,
  duplicate/partial jobs resume safely, terminal rows cannot authenticate, and no production
  datastore is touched during migration validation.
- Related evidence: Phase 0 inventory in `plans/backlog/2026-09-17-integrated-hardening-plan.md` and
  the existing retention/lifecycle ADRs.

## CF-009 — Request-body limit contract is not established

- Status: BLOCKS_SLICE
- Severity: P1
- Requirement: #845; request-size enforcement before parsing
- Evidence: The current checkout has endpoint-specific bounded readers in
  `app/controllers/concerns/csp_violation_report.rb:51-58` and
  `app/controllers/auth/app/apple/notifications_controller.rb:28-57`. The repository-wide
  application configuration at `config/application.rb:90-207` does not install a pre-parser
  request-size limit. The Apple audit plan requires a strict notification limit at
  `plans/analysis/apple-google-external-authentication-architecture-audit.md:1070-1083`, while
  `docs/security/security-headers.md:41-48` documents limits only for the CSP report endpoint.
- Conflict: The adopted requirement needs an effective limit before the first unbounded read, but
  the repository does not define one maximum that is valid for JSON, form, multipart, upload, and
  streaming contracts. Cloudflare or another edge may enforce an external limit, but that is not
  evidence of an origin-side limit and is not inspectable from this checkout. Adding a guessed
  global limit could reject valid uploads or protocol payloads; adding a post-parse limit would not
  address the resource-exhaustion risk.
- Impact: An incorrect change could either leave a reachable unbounded request path or break valid
  authentication, notification, or upload traffic while giving a false sense of protection.
- Current-cycle action: Keep the existing endpoint-specific bounds and do not add a guessed global
  middleware limit. Record the missing contract rather than changing parsing order or upload
  semantics without an approved size matrix.
- Safe to defer because: No current slice proves a specific missing origin-side limit that can be
  fixed without changing an external or public payload contract, and no safe numeric bound can be
  derived from the repository alone.
- Next-cycle action: Inventory every public body-reading path and the edge/origin chain, approve a
  per-endpoint size/media/streaming matrix, then enforce it before parsing with controlled
  oversized, chunked, compressed, and valid-upload tests.
- Acceptance test: The approved paths reject oversized input before body parsing, handle missing or
  inconsistent lengths safely, preserve valid uploads, and document the edge/origin responsibility.
- Related evidence: `evidence/2026-09-17-auth-body-limit-blockers.md`; no external edge
  configuration was modified or treated as verified.

## CF-010 — Auth/Base issuance handoff contract remains unresolved

- Status: BLOCKS_SLICE
- Severity: P0
- Requirement: #846; Base as the sole physical IdP/AS authority
- Evidence: Auth controllers still define the `sign-rp` client at
  `app/controllers/auth/app/application_controller.rb:114-152`, with equivalent definitions in
  `app/controllers/auth/com/application_controller.rb:188-223` and
  `app/controllers/auth/org/application_controller.rb:112-151`. The authentication sequence calls
  `log_in` and creates the current session at
  `app/controllers/concerns/authentication_sequence_gate.rb:513-545` and `:550-624`, then calls
  `BaseAuthAdmissionCoordinator.register_result_and_issue_resume!` at `:609-618`. The coordinator
  registers the result through `app/services/base_auth_admission_coordinator.rb:136-148`, and the
  Auth admission flow consumes the resulting handoff in
  `app/controllers/concerns/auth_ceremony_admission.rb:38-77`.
- Conflict: The adopted architecture says Auth is a ceremony surface and Base is the sole physical
  IdP/AS issuer, but the current code still has Auth-owned RP identity and Auth-side browser-session
  issuance before the Base result/resume handoff. The repository does not yet establish the accepted
  browser binding, one-time result consumption, issuer/realm, AAL/AMR, session-limit, and failure
  semantics needed to remove or relocate that issuance safely.
- Impact: A partial move could create duplicate parent sessions, bypass session limits, break
  ceremony continuity, or make a stale handoff issue authority in the wrong surface.
- Current-cycle action: Do not remove Auth session issuance or broadly relocate the handoff. Keep
  the independent realm, OTP, replay, and revocation hardening changes scoped to their verified
  contracts; they do not claim to complete the issuer migration.
- Safe to defer because: The current safe slices do not require changing the physical issuer, and a
  partial cutover would be less safe than the existing explicit handoff until the missing contract
  is accepted and tested.
- Next-cycle action: Define a surface-by-surface Auth/Base handoff matrix, including browser
  binding, one-shot result/admission consumption, issuer/realm/AAL/AMR propagation, session limits,
  stale result rejection, and rollback behavior; then migrate one flow with an isolated integration
  proof before removing the old issuance path.
- Acceptance test: Auth mints no Base/RP authority, Base is the sole issuer, every handoff is bound
  to the intended ceremony and surface and consumed once, and session-limit/expiry/replay behavior
  remains intact under failure and duplicate requests.
- Related evidence: `evidence/2026-09-17-auth-body-limit-blockers.md`,
  `adr/base-auth-ceremony-and-seven-rp-boundary.md`,
  `plans/backlog/integrated-auth-boundary-surface-consolidation-plan.md`, and the current Auth/Base
  controller, coordinator, and admission sources.

## CF-011 — Processor-erasure adapters are not implemented

- Status: BLOCKS_SLICE
- Severity: P1
- Requirement: #554 notification delivery semantics; privacy-erasure processor notification recovery
- Evidence: `app/jobs/processor_erasure_notification_job.rb` has no provider/processor call site;
  the repository search for the declared `email_delivery`, `sms_delivery`, `push_delivery`,
  `analytics`, `object_storage`, `search_index`, and `log_pipeline` keys found only the state rows,
  job, and tests. The job previously marked those keys `NOTIFIED` without a dispatch result.
- Conflict: The workflow needs to distinguish notification request, provider acceptance, delivery
  outcome, retry, and permanent failure, but no concrete processor adapter or receipt contract is
  available in this repository. Treating the queue execution itself as delivery success would be a
  false erasure guarantee.
- Impact: Downstream processors could remain uninformed while the privacy workflow records success;
  retries, manual intervention, and completion reporting would be unreliable.
- Current-cycle action: Empty the job's success allowlist and record an explicit unavailable/manual-
  follow-up failure instead. Keep `NOTIFIED` reserved for a future concrete dispatch contract; do
  not add provider integrations or a generic notification framework.
- Safe to defer because: No external processor delivery is claimed after this containment, and the
  affected workflow remains visibly incomplete rather than silently successful.
- Next-cycle action: Define each processor's trusted endpoint/adapter, payload minimization,
  authentication, provider-acceptance/receipt semantics, bounded retry/backoff, duplicate handling,
  permanent-failure state, and recovery sweep before enabling one key at a time.
- Acceptance test: A concrete processor receives only the authorized erasure request, its provider
  result is persisted separately from delivery completion, retries are bounded and idempotent, and
  an unavailable integration cannot produce `NOTIFIED`.
- Related evidence: `evidence/2026-09-18-processor-notification-success-boundary.md` and
  `docs/security/withdrawal-privacy-erasure.md`.

## CF-012 — Solid Queue setup checks conflict with the repository test rule

- Status: OPEN_NON_BLOCKING
- Severity: P2
- Requirement: Solid Queue configuration verification; repository environment-test rule
- Evidence: `adr/no-test-suite-for-environment-construction.md` and
  `.agents/harnesses/rules/project/no-environment-tests.mdc` prohibit Minitest/Vitest cases whose
  subject is environment or tooling construction. The earlier
  `test/config/solid_queue_configuration_contract_test.rb` parsed `config/queue.yml` and
  `config/recurring.yml` as setup assertions rather than application behavior.
- Conflict: The integrated queue requirement asks for configuration tests, while the repository's
  accepted rule requires running the installed validator and recording observed results instead of
  adding permanent setup coverage.
- Impact: Keeping the setup test would violate repository rules; removing it means YAML mapping
  regressions are detected by review, the static audit, and operational validation rather than every
  Minitest run.
- Current-cycle action: Remove the setup test, retain behavior-level job tests, run `bin/jobs check`
  with isolated variables where possible, and keep the exact mapping audit and result in evidence.
- Safe to defer because: the current queue mapping is explicit and the test-scoped `bin/jobs check`
  already passed; worker/database runtime remains independently blocked by CF-005.
- Next-cycle action: Re-run `bin/jobs check` for development and production with their required
  isolated boot variables, then run the real disposable worker/scheduler path. Do not restore a
  setup-only Minitest unless the repository rule is explicitly amended.
- Acceptance test: The installed validator passes in each supported environment, the static audit
  finds no wildcard/alias/duplicate-key omission, and the isolated worker executes immediate,
  delayed, recurring, and retry paths.
- Related evidence: `evidence/2026-09-17-phase-0-and-safe-slices.md` and
  `docs/operations/solid-queue-runtime.md`.

## CF-013 — JWT anomaly runtime codes are not covered by the occurrence catalog

- Status: BLOCKS_SLICE
- Severity: P1
- Requirement: #606; authentication and JWT anomaly observability
- Evidence: `app/services/jit_security_jwt_anomaly_reporter.rb:7-18,47-67` emits `AUTH_CLIENT`,
  `AUTH_OPERATOR`, and `AUTH_VISITOR` contexts and maps missing claims to reason codes.
  `app/subscribers/jwt_anomaly_subscriber.rb:21-24,27-39` returns when its exact `body` lookup is
  absent and persists matching events only after the lookup.
  `db/occurrences_migrate/20260311150200_insert_jwt_occurrence_reference_data.rb:11-17` seeds
  `AUTH_USER` and `AUTH_STAFF` instead, and
  `app/values/security_jwt_auth_access_token_codec.rb:121-128,287-294` emits `CLAIM_INVALID` and
  `DECODE_FAILED`, which were not in the original seeded reason set. The additive transition is
  authored in `db/occurrences_migrate/20260918150000_insert_current_jwt_anomaly_reference_data.rb`.
- Conflict: The runtime resource-type vocabulary and failure-code vocabulary do not match the
  persisted reference catalog. Before this slice, the subscriber silently skipped unknown codes; it
  now emits `jwt.anomaly.catalog_miss`, but those authentication anomalies still do not become
  `JwtAnomalyEvent` rows. The missing-`nbf` mapping was compatible with the existing `MISSING_NBF`
  reason and is fixed in the current safe slice, but the context and non-missing-claim code mismatch
  requires an explicit persisted reference-data transition.
- Impact: #606 cannot claim complete authentication anomaly persistence or complete operational
  coverage. This is an observability and audit-loss risk; it does not itself grant authorization.
- Current-cycle action: Add regression coverage, map the existing missing-`nbf` claim to
  `MISSING_NBF`, connect the reporter to the existing Active Support notification boundary, and make
  a catalog miss observable without creating a fabricated occurrence row. Malformed external values
  are reduced to an `INVALID` marker and length. Commit `172686b23` adds 78 current runtime catalog
  rows in a forward-only, idempotent migration. It preserves the legacy rows and event references,
  refuses to rewrite an existing same-body row with a non-active status, and has not been executed
  because the isolated occurrence database is unavailable.
- Safe to defer because: The additive migration is not enabled or executed in this workspace, and
  the affected anomaly paths remain visible in bounded structured logs without fabricated rows. It
  is not safe to defer the disposable-database migration and persistence verification while claiming
  the #606 audit slice is complete.
- Next-cycle action: Run the authored transition in a disposable occurrence database and verify
  rerun safety, legacy-row identity preservation, active status, unique public IDs, and event
  persistence for every supported runtime context/reason pair. Do not execute it against populated
  non-test data until the migration runbook gate is satisfied.
- Acceptance test: Every supported runtime context/reason pair resolves to an active occurrence,
  unknown codes have an observable non-success path rather than silent loss, historical rows are not
  rewritten, and anomaly events retain no raw JWT or secret values. The acceptance test is not yet
  runtime-proven because PostgreSQL is unavailable.
- Related evidence: `evidence/2026-09-18-jwt-anomaly-catalog-audit.md`.
