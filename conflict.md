# Conflict ledger

This file is the single conflict ledger for the integrated hardening work. It does not replace
accepted ADRs, implementation plans, or evidence.

Current naming note (2026-09-25): historical references to the Rails `Side`/`Wide` surface mean the
current `Warp` internal namespace. Protocol and persisted identifiers retain their existing names.

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

- Status: CLOSED_FOR_ISOLATED_TEST_VERIFICATION
- Severity: P1
- Requirement: Phase 0 verification and every test-gated implementation slice
- Evidence: The prescribed preflight completed successfully on 2026-09-22 with the explicit
  `.env.devcontainer.example` selection. `primary` PostgreSQL and `valkey-kvs` resolved from the
  Compose-backed test network; no secret values were printed. The current focused authentication,
  OIDC, RP Session, OTP, authority, enforcement, queue, dashboard, and observability groups passed
  with 487 runs / 2,879 assertions / 0 failures / 0 errors / 3 skips. The current full Rails suite
  also passed with 11,503 runs / 73,303 assertions / 0 failures / 0 errors / 5 skips.
- Conflict: The earlier missing-service and incomplete-schema observations were environment state at
  the time of the historical records, not a current test-boundary failure. They remain preserved in
  the dated evidence and do not describe the current Compose-backed execution context.
- Impact: The isolated test boundary is usable for the verified local Rails and Valkey paths. This
  does not establish production/development worker topology, external provider delivery, Cloudflare
  routing, or any architecture decision tracked by another conflict.
- Current-cycle action: Use the explicit Compose-backed test environment for subsequent focused
  verification. Keep secrets out of output and do not substitute shared or loopback production-like
  datastores.
- Safe to defer because: production worker/runtime and external-service checks are explicitly out of
  scope for this local closure and remain tracked by CF-005, CF-007, CF-009, CF-010, and CF-011 as
  applicable.
- Next-cycle action: Re-open this conflict only if the prescribed preflight or an affected local
  test path fails after a code/configuration change. Do not treat a production-topology gap as a
  failure of the isolated test boundary.
- Acceptance test: the bundled preflight, the affected `bin/rails test` commands, and isolated DB
  checks boot without falling back to a non-test datastore. This acceptance test passed in the
  current environment.
- Related evidence: `evidence/2026-09-22-auth-otp-authority-revalidation-R5S6.md` and the current
  full-suite result; historical unavailable-service results remain in their original evidence files.

## CF-003 — Existing Persona/Organization authority graph is not the adopted graph

> **Current disposition:** The original decision-gated wording in this section is historical. The
> approved six-family owner mapping and the current pre-deployment disposition are maintained in
> `plans/backlog/2026-09-17-integrated-hardening-plan.md`. The isolated pre-deployment acceptance
> set now covers the reviewed mapping/conflict rules, lifecycle state, atomic and idempotent
> backfill, family gate, immutable point of no return, and post-cutover owner-specific consumers.
> Production inventory, real cutover, and operational forward-recovery rehearsal remain deployment
> gates; they do not reopen this repository-side status.

- Status: CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED
- Current-cycle closure evidence: `evidence/2026-09-23-cf003-cf007-predeployment-acceptance-F7G8.md`
  records the Compose-backed authority acceptance (`97 runs / 690 assertions / 0 failures / 0
  errors / 0 skips`) and the subsequent full Rails suite. The detailed action, deferral, and
  acceptance bullets below preserve the earlier evidence trail and are not the current status.
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
  surface-local canonical writer boundary, and the six lifecycle tables are authored, but the
  live database, old-data owner mapping, lifecycle backfill, runtime rollback/concurrency proof,
  and authorization cutover are not proven.
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
  as the adopted authority model or add a dual fallback. The selector bootstrap may call the
  creators for newly created graphs, but creator operations are not exposed as new direct routes;
  existing-data consumer cutover remains gated by isolated DB, rollback/concurrency, lifecycle, and
  owner-mapping evidence. The six authored ownership models now reject independent Active Record destruction so an
  application path cannot create an ownerless interval; this guard does not replace the future
  locked transfer/lifecycle operations or prove direct-SQL behavior. A read-only
  `AuthorityOwnerMigrationInventory` and `authority:owner_inventory` task now enumerate all six
  concrete resources, classify legacy binding/membership candidates, emit only public identifiers,
  and fail on a partially applied authority schema. An earlier Compose-backed isolated task run
  reported an applied schema but zero resource rows; that historical result proves command/schema
  handling only and does not resolve owner mapping. The current process could not reach the required
  PostgreSQL service, as recorded in the latest lifecycle evidence.
  `AuthorityOwnerPredeploymentBackfillOperation` now combines one reviewed owner mapping and one
  reviewed lifecycle state in a single surface-local transaction, with idempotent replay and
  rollback on lifecycle conflict. It remains a pre-cutover migration unit; it does not switch
  authorization consumers or establish post-cutover rollback.
  Owner-specific quota policy reads and all six concrete creator quota checks now use the same
  explicit lifecycle relation. Inactive resources do not consume a slot, while an ownership row
  without a lifecycle row blocks creation. This closes a local quota bypass but does not replace
  delegated selector/switcher access or constitute a family-wide consumer cutover.
  The owner-specific `AccountPolicy` is now staged on the account-family marker: before cutover it
  preserves the legacy identity contract; after cutover it requires the configured explicit owner,
  eligible principal, and active resource lifecycle. `OrganizationPolicy` and the selector/switcher
  delegated-access graph remain unchanged by design. This names one owner-specific consumer but
  does not close the family-wide consumer, forward-recovery, or isolated runtime proof gates.
  `AuthorityOwnerFamilyBackfillOperation` now validates and applies a complete reviewed mapping for
  one resource family atomically, rejects duplicate resource entries, and rolls back earlier rows
  when a later row is rejected. Replaying the same complete family mapping is idempotent. This
  remains a pre-cutover unit and does not provide a consumer switch. The separate
  `AuthorityOwnerFamilyCutoverOperation` records the immutable family marker only after the guard
  passes; post-marker backfill and legacy rollback are rejected. The selector bootstrap has a
  public regression test for the post-marker fail-closed boundary: an ineligible new principal
  cannot enter the legacy-only resource path after the account-family marker exists. The cutover
  guard treats explicitly inactive, discarded, deleted, and retained resources as historical
  non-authority-required rows; it still blocks active, unknown-lifecycle, or ineligible-owner rows.
- Safe to defer because: the foundation does not switch authorization sources or backfill a second
  owner. Static model loading, syntax, lint, and the canonical pool inheritance are authored;
  runtime migration, rollback, quota races, current-data mapping, and this lifecycle slice's
  database-backed acceptance remain unverified in the current process. Historical focused creator,
  schema-contract, vocabulary, and app creation-race results do not substitute for that proof.
- Next-cycle action: Run the owner inventory against reviewed representative isolated data, review
  ambiguous rows, then prove one-writer migration rollback/concurrency before any lifecycle-gated
  policy or cutover one surface at a time. Do not infer a mapping from the current zero-row report.
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

> **Current disposition:** This entry preserves the original retention/lifecycle conflict evidence.
> It is not permission to reinterpret principal retention columns as resource lifecycle state. The
> isolated pre-deployment lifecycle/backfill and family-cutover acceptance is now satisfied under
> the approved six-family contract. Production row inventory, real cutover, and operational
> forward-recovery rehearsal remain deployment gates.

- Status: CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED
- Current-cycle closure evidence: `evidence/2026-09-23-cf003-cf007-predeployment-acceptance-F7G8.md`
  records the isolated lifecycle/backfill and cutover acceptance included in the authority suite.
  Production inventory, live cutover, and operational forward-recovery rehearsal remain deployment
  gates. The detailed action, deferral, and acceptance bullets below preserve the earlier evidence
  trail and are not the current status.
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
- Current-cycle action: Keep principal retention columns separate from the six concrete resource
  lifecycle tables. Use the explicit lifecycle backfill operation for reviewed existing rows, then
  inventory exact current operations, holds, anonymizer fields, operator deletion paths, and the
  boundary between the existing principal recovery flow and the not-yet-enabled resource lifecycle.
- Safe to defer because: the new resource lifecycle tables and creator-row contract do not enable
  retention, scrub, transfer, or authorization cutover. The current process could not run the
  database-backed lifecycle checks.
- Next-cycle action: Define explicit current-state workflow fields/relations, lock order, scrub
  inventory, and isolated migration/runbook gates; then prove the lifecycle transition and
  retention boundary without reusing principal retention timestamps.
- Acceptance test: boundary tests at one hour, seven days, thirty-one days, hold races, stale jobs,
  rollback, and terminal non-recovery pass on isolated data.
- Related evidence: existing retention ADRs and the lifecycle inventory to be added during Phase 6.

## CF-005 — Solid Queue runtime execution is not yet proven

- Status: CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED
- Severity: P1
- Requirement: explicit queue/worker/recurring configuration
- Evidence: The original configuration used anchors, merge keys, and `queues: "*"`; the original
  recurring file omitted explicit class queue/priority/args and differed by environment. The current
  `config/queue.yml` and `config/recurring.yml` are explicit, the concrete/gem inventory is recorded
  in `docs/operations/solid-queue-runtime.md`, and the contract test parses the mapping. The
  test-scoped `RAILS_ENV=test ... bundle exec bin/jobs check` passed with disposable local
  variables. The current Compose-backed development recheck with explicit `TRUSTED_PROXIES`
  also reports `Solid Queue configuration is valid.` A bounded test Solid Queue supervisor now
  picked up and completed one existing application job with recurring scheduling disabled. The
  existing Solid Queue enqueue/status and recurring-schedule behavior tests also pass with 9 runs
  / 31 assertions / 0 failures / 0 errors / 0 skips. A current production `bin/jobs check`
  attempt stopped during Rails boot because the required `BASE_SERVICE_URL` was not supplied;
  no fallback value was invented and no worker/provider was started. Production boot/topology
  therefore remains unverified.
- Current status note: The historical conflict body above records the earlier missing runtime
  proof. The local Compose-backed scheduler/dispatcher/worker acceptance described in
  `evidence/2026-09-23-cf005-queue-runtime-P6Q7.md` supersedes that status for pre-deployment.
  Production topology, heartbeat, monitoring, and operational rollback remain deployment gates.
- Conflict: Static mapping can prove configuration coverage but cannot prove that a deployed worker
  reads this file, the queue DB schema is current, or dispatcher/scheduler/worker state transitions
  execute.
- Impact: lost processing, queue starvation, retry failure, or accidental production load
  concentration.
- Current-cycle action: Replaced the wildcard/anchor configuration, aligned development and
  production recurring sets, added exact workers and queue-pool documentation, isolated retention
  work, added a per-job ledger, verified the test-scoped and current development Solid Queue
  configuration commands, and verified one bounded test worker pickup. No production worker or
  queue DB was touched.
- Safe to defer because: queue configuration is statically explicit and no external runtime claim is
  being made; enabling or deploying the changed topology without the runtime check is not safe to
  claim.
- Next-cycle action: Supply the required development/production boot variables without using shared
  data stores, provide the approved production host configuration without exposing credentials,
  rerun the production check, and run the isolated immediate/delayed/recurring/retry worker
  integration suite against disposable test services.
- Acceptance test: every effective queue has a worker, every recurring class/command is valid, no
  wildcard/anchor/duplicate key remains, and delayed/retry/recurring jobs execute in an isolated
  queue DB.
- Related evidence: `evidence/2026-09-22-solid-queue-worker-pickup-Q1R2.md`; production topology,
  recurring scheduler, retry/recovery, and provider delivery remain unverified.

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
  lifecycle, create, or RBAC behavior changed. The current Compose-backed focused dashboard tests
  verify the repository-side navigation contract.
- Safe to defer because: current Avatar show/edit routes exist and no new authority is granted by
  deferral.
- Next-cycle action: Re-audit after the excluded Avatar work completes; remove or retain the
  navigation-only change based on that review, without expanding Avatar scope.
- Acceptance test: show exposes an existing authorized edit link without adding new permissions or
  changing Avatar state transitions.
- Related evidence: dashboard inventory and Avatar controller source.

## CF-007 — Regional RP registration conflicts with the accepted seven-client ADR

> **Current disposition:** The decision conflict is resolved by the approved 2026-09-23 amendment
> in the Frozen Plan: twelve independent regional Core/Side clients plus global `edit-org`. The
> seven-client registry remains compatibility state during expand-and-contract migration. This
> section is retained as the historical conflict record; its current repository gaps are the
> missing independent Side US host source and independent regional audience source.

- Status: OPEN — CONTRACT CONTRADICTION (pre-deployment; logical matrix approved, required SSOT input remains absent)
- Severity: P0
- Requirement: Auth/RP regional registration and session uniqueness
- Evidence: `adr/base-auth-ceremony-and-seven-rp-boundary.md:31-39` fixes seven first-party clients
  named `core-app`, `core-com`, `core-org`, `side-app`, `side-com`, `side-org`, and `edit-org`; the
  current auth consolidation plan repeats that exact set at
  `plans/backlog/integrated-auth-boundary-surface-consolidation-plan.md:20-28`. The adopted
  hardening prompt separately requires JP and US to be distinct registered app RPs and says
  `core-app-jp`/`core-app-us` are illustrative names.
- Remaining contract contradiction: The approved matrix fixes the logical client identities and
  isolation invariant, but the current repository still lacks a canonical Side US host source and
  independently bound regional audience values. No existing conflicting values were found; the
  required SSOT inputs are absent. This is not a request to invent another client or a guessed
  audience. The active registry remains the seven-client compatibility registry, and no caller or
  RP-session migration may guess the missing values or derive them from a request Host header.
- Impact: Cross-region RP-session issuance, redirect/client confusion, stale-session migration, and
  incorrect revoke scope.
- Current-cycle action: Record the approved 13-cell logical matrix, derive only the Core, existing
  Side JP, and global Edit URI bindings available from canonical repository sources, define independent logical key
  namespaces and RP-session bindings, and fail closed for missing Side hosts or audiences. Keep the
  active seven-client registry and `core-next-rp` compatibility path unchanged until the complete
  regional contract exists.
- Safe to defer because: no current-cycle slice changes RP acceptance or authorization, and leaving
  the existing registry untouched does not silently broaden access.
- Next-cycle action: Approve or provide an authoritative regional audience source and an independent
  Side US host source (while retaining the existing canonical Side JP source), then implement the
  expand-and-contract registry/caller migration and its local
  cross-acceptance tests. Real Base registration, credentials, deployed callers, and retirement
  remain deployment acceptance gates.
- Acceptance test: Pre-deployment tests prove the exact approved matrix, URI and namespace
  isolation, missing-source fail-closed behavior, and JP/US cross-acceptance rejection without
  activating an incomplete registry. The later deployment gate proves actual registrations and
  caller retirement.
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
  proof, restartable backfill design, stale-job tests, and a disposable isolated validation or
  rollback rehearsal before any destructive or terminal behavior change. This is an execution
  safety gate for a separately approved transformation, not a requirement to add a
  `RetentionPurgeJob` dry-run/preview API or a dry-run-specific schema.
- Acceptance test: exact target inventory is persisted, hold races block destructive work,
  duplicate/partial jobs resume safely, terminal rows cannot authenticate, and no production
  datastore is touched during migration validation.
- Related evidence: Phase 0 inventory in `plans/backlog/2026-09-17-integrated-hardening-plan.md` and
  the existing retention/lifecycle ADRs.

## CF-009 — Request-body limit contract has separate origin and edge boundaries

- Status: CLOSED_FOR_RAILS_JSON_ORIGIN_BOUNDARY
- Severity: P1
- Requirement: #845; request-size enforcement before parsing
- Evidence: `lib/request_body_size_limit.rb:10-89` defines a 1 MiB JSON/`+json` limit and reads no
  more than one byte beyond the boundary. `config/application.rb:140` inserts it immediately after
  `ActionDispatch::RequestId`, before routes and Rails parameter parsing. It rejects invalid or
  negative declared lengths, missing-length/chunked oversized bodies, and unsupported compressed
  JSON with Problem Details responses. Endpoint-specific CSP and Apple readers retain their own
  narrower limits.
- Conflict: The historical gap concerned the absence of an origin-side pre-parser JSON limit. The
  current Rails contract now defines that boundary. Cloudflare, proxy, and server-ingress limits
  remain external and are not proven by this repository; multipart/upload and compressed-body
  policies remain intentionally separate.
- Impact: The Rails JSON resource-exhaustion boundary is protected. Claiming complete ingress
  protection, or applying the 1 MiB JSON value to uploads or compressed input, would be incorrect.
- Current-cycle action: Preserve the middleware and its explicit media-type scope. No external
  configuration, upload contract, or compression decoder was added.
- Safe to defer because: the remaining edge and non-JSON contracts do not prevent the verified Rails
  JSON boundary from operating and require separate operational or product decisions.
- Next-cycle action: Verify edge/origin alignment through an approved non-invasive operational check
  and define any multipart/streaming/compressed limits separately before broadening this boundary.
- Acceptance test: the middleware and Core boundary tests cover exact-limit success, oversized
  declared and chunked bodies, malformed/negative lengths, unsupported compression, and rejection
  before downstream parsing. This acceptance test passed with 25 runs / 110 assertions.
- Related evidence: `evidence/2026-09-22-request-body-limit-revalidation-B3C4.md` and the historical
  `evidence/2026-09-17-auth-body-limit-blockers.md`.

## CF-010 — Auth/Base issuance handoff contract remains unresolved

- Status: CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED
- Severity: P0
- Requirement: #846; Base as the sole physical IdP/AS authority
- Evidence: the current Auth application controllers still include the shared session/authentication
  stack (`app/controllers/auth/app/application_controller.rb:13-32`, with equivalent includes in
  `app/controllers/auth/com/application_controller.rb:12-28` and
  `app/controllers/auth/org/application_controller.rb:12-28`). The non-OIDC sequence still calls
  `log_in` while promoting a session-limit cycle or issuing a selector session at
  `app/controllers/concerns/authentication_sequence_gate.rb:511-580`. The OIDC primary-authentication
  branch now records Auth-local evidence without calling `log_in` at
  `app/controllers/concerns/authentication_base.rb:2441-2450,2498-2525`; the result handoff then
  registers a Base authorization result through
  `app/controllers/concerns/auth_oidc_result_handoff.rb:20-45` and
  `app/services/base_auth_admission_coordinator.rb:136-148`, while Auth admission continuity is
  handled by `app/controllers/concerns/auth_ceremony_admission.rb:38-77`. The legacy shared client
  registrations remain in the static registry and dependent tests/docs, but no current Auth
  application-controller `sign-rp` definition was found.
- Conflict: The adopted architecture says Auth is a ceremony surface and Base is the sole physical
  IdP/AS issuer, but legacy shared RP registrations remain in the static registry while Auth-side
  non-OIDC/session-limit paths can still issue browser sessions before any Base-owned handoff. The
  repository does not yet establish the accepted
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
- Current status note: The conflict description above is historical. The approved closure amendment
  and focused/full-suite evidence in the Frozen Plan supersede it for the repository-side
  pre-deployment contract. Immediate invalidation of existing access JWTs, live RP registration,
  and production/external runtime acceptance remain explicitly outside that closure.

## CF-011 — Processor-erasure adapters are not implemented

- Status: CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED
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
  not add provider integrations or a generic notification framework. The notification state now
  calculates its existing 15-minute retry timestamp from the supplied decision time, so retry
  scheduling does not silently use a second clock. Its public transition methods also re-check
  terminal state under a row lock, so `NOTIFIED` and `SKIPPED` rows cannot be overwritten by a
  later failure or notification update.
- Safe to defer because: No external processor delivery is claimed after this containment, and the
  affected workflow remains visibly incomplete rather than silently successful.
- Next-cycle action: Define each processor's trusted endpoint/adapter, payload minimization,
  authentication, provider-acceptance/receipt semantics, bounded retry/backoff, duplicate handling,
  permanent-failure state, and recovery sweep before enabling one key at a time.
- Acceptance test: A concrete processor receives only the authorized erasure request, its provider
  result is persisted separately from delivery completion, retries are bounded and idempotent, and
  an unavailable integration cannot produce `NOTIFIED`.
- Related evidence: `evidence/2026-09-18-processor-notification-success-boundary.md`,
  `evidence/2026-09-22-processor-notification-retry-clock-A1B2.md`,
  `evidence/2026-09-22-processor-notification-terminal-guard-C3D4.md`, and
  `docs/security/withdrawal-privacy-erasure.md`.
- Current status note: The no-adapter/false-success conflict above is historical. The provider-neutral
  adapter, authenticated receipt, retry, permanent-failure, and recovery contract was later
  implemented and accepted in the isolated Compose environment. Provider authentication, real
  credentials, provider-specific receipt protocol, and provider E2E remain deployment/provider
  gates.

## CF-012 — Solid Queue setup checks conflict with the repository test rule

- Status: CLOSED_FOR_RULE_RECONCILIATION
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
- Current-cycle action: The setup-only test is absent, behavior-level job tests remain, and the
  installed validator has been run again against the isolated test environment. The exact mapping
  audit and validator result remain in evidence.
- Safe to close this conflict because: the repository-rule disagreement is resolved without
  weakening queue behavior coverage. Worker/database runtime remains independently tracked by
  CF-005.
- Next-cycle action: Re-run `bin/jobs check` for development and production with their required
  isolated boot variables, then run the real disposable worker/scheduler path. Do not restore a
  setup-only Minitest unless the repository rule is explicitly amended.
- Acceptance test: The installed validator passes in each supported environment, the static audit
  finds no wildcard/alias/duplicate-key omission, and the isolated worker executes immediate,
  delayed, recurring, and retry paths.
- Related evidence: `evidence/2026-09-17-phase-0-and-safe-slices.md`,
  `docs/operations/solid-queue-runtime.md`, and
  `evidence/2026-09-22-solid-queue-rule-status-E5F6.md`.

## CF-013 — JWT anomaly runtime codes are not covered by the occurrence catalog

- Status: CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED
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
- Conflict: The runtime resource-type vocabulary and failure-code vocabulary did not match the
  persisted reference catalog. The additive current-catalog transition and schema-load seed path
  now resolve the supported runtime pairs without rewriting historical rows. Unknown codes remain
  observable through the existing bounded catalog-miss path rather than being fabricated into
  occurrence rows.
- Impact: #606 cannot claim complete authentication anomaly persistence or complete operational
  coverage. This is an observability and audit-loss risk; it does not itself grant authorization.
- Current-cycle action: Additive reference data, standard-seed replay, migration-path replay, and
  schema-load replay were verified on disposable/test occurrence databases. The fixed status IDs,
  78 current catalog rows, idempotence, legacy-row retention, and sanitized anomaly boundaries all
  pass. No non-test occurrence database was changed.
- Safe to defer because: The catalog reconstruction boundary is complete. Notification provider
  delivery/receipt/retry/permanent-failure remains a separate contract and is not closed here.
- Next-cycle action: None for catalog reconstruction. Keep provider-delivery work separate and do not
  treat this closure as proof of external delivery.
- Acceptance test: Every supported runtime context/reason pair resolves to an active occurrence,
  unknown codes have an observable non-success path rather than silent loss, historical rows are not
  rewritten, and anomaly events retain no raw JWT or secret values. This acceptance test passed in
  the current disposable/test verification.
- Related evidence: `evidence/2026-09-21-occurrence-catalog-seed-reconstruction-P8Q9.md` and the
  current plan's occurrence resolution section.
