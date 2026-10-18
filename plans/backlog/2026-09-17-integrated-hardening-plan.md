# Integrated hardening and reachability implementation plan

> **Retention vocabulary amendment (2026-09-21):** The unreleased schema reconstruction renamed
> Retainable columns to `discard_at` and `purge_eligible_at`. Historical inventory rows below may
> retain their original wording; current implementation and active documentation use the semantic
> names. The reconstruction and test-only database verification are recorded in
> `evidence/2026-09-21-phase-09-reconstruction-X4Y5.md`.

## Status

PRE_DEPLOYMENT_SCOPE_REOPENED. Phase 0 is complete as an initial inventory. The observability correction,
dashboard reachability, URL policy, OIDC delivery failure classification, explicit Solid Queue
configuration, Phase 1 vocabulary migration, the Phase 2 authority schema foundation, static
RP-session realm/revocation hardening, enforcement appeal recovery, sign-up guardrail enforcement,
OTP resend serialization, and one-time OTP consumption are implemented as local slices. Historical
focused Rails runs for the authority vocabulary/schema and creator/concurrency contracts are
recorded. The occurrence migration/seed paths and a bounded test Solid Queue worker pickup are
historical evidence, not current-process acceptance evidence. A subsequent local Compose-backed
recheck completed the CF-011 migration, structure-load, focused, and full Rails acceptance checks;
the later local Compose-backed CF-005 runtime recheck also verified scheduler enqueue, dispatcher/
worker execution, expected database mutation, and controlled failure handling. Production worker topology,
production recurring scheduler execution, migration rollback proofs,
and provider delivery remain unverified. `CF-002` is closed for the isolated local test boundary;
production worker/runtime and external-service checks remain separate conflicts. The adopted
Persona/Organization redesign is not enabled until its source-owner inventory, connection proof,
lifecycle gates, and migration gates are complete. The Rails-side JSON body-size boundary for #845
is now verified; external edge limits, compressed-input policy, and non-JSON upload limits remain
separate operational contracts. The Base/Auth issuance handoff for #846/CF-010 is now implemented
under the closure amendment below; external RP registration/key deployment and live runtime
acceptance remain separate. The neutral browser RP entry now also refuses a second flow when the
same RP's valid access credential is present, while preserving cross-surface cookie isolation.

Status precedence: dated sections explicitly labeled historical record the state at the time of
that verification. The current status and latest dated resolution above take precedence over
earlier handoff wording; historical blocker entries are not reopened by their preserved text.

### Approved CF-003/CF-004 and CF-007 decision amendment (2026-09-23)

The human decisions recorded in the current blocker-input document are approved and supersede the
earlier decision-request wording below. They authorize pre-deployment repository work; they do not
authorize production data access, external registration, key generation, deployed-caller changes,
or live cutover.

For `CF-003/CF-004`, the six surface-local explicit ownership relations are the sole owner
authority after a resource-family cutover:

| Surface | Principal | Resource families |
| --- | --- | --- |
| `app` | `Client` | `Client -> Persona`, `Client -> Enterprise` |
| `com` | `Visitor` | `Visitor -> Individual`, `Visitor -> Company` |
| `org` | `Operator` | `Operator -> Agent`, `Operator -> Bureau` |

Memberships, assignments, administrator relations, identity bindings, legacy owner fields, and
legacy `Organization` hierarchy data are migration evidence only. `Organization` is not `Bureau`.
Zero, ambiguous, inactive-only, contradictory, cross-surface, membership-only, administrator-only,
and legacy-only candidates are never resolved by a tie-breaker; they remain rejected or
manual-review/ownerless according to the approved disposition. Principal/resource lifecycle
eligibility is separate from the retained ownership fact. A resource-family cutover requires zero
unresolved authority-required active rows. Before that point rollback is permitted; after any
consumer reads the new relation, normal rollback to legacy authority is forbidden and recovery is
forward-only.

For `CF-007`, the approved target is regional expansion with one independent Core and Side RP for
each `app`, `com`, and `org` JP/US cell, plus global `edit-org`:

`core-app-jp`, `core-app-us`, `core-com-jp`, `core-com-us`, `core-org-jp`, `core-org-us`,
`side-app-jp`, `side-app-us`, `side-com-jp`, `side-com-us`, `side-org-jp`, `side-org-us`, and
`edit-org`.

Each cell requires independent client binding, audience semantics, exact redirect/logout/backchannel
bindings, private-key-JWT namespace, and RP Session binding. The current seven-client registry and
`core-next-rp` compatibility path remain during expand-and-contract migration. Regional URIs and
audiences must come from an existing canonical repository source; no missing value may be guessed
or derived from an arbitrary Host header. Real Base registration, credential fingerprints, deployed
caller confirmation, and retirement are later deployment gates.

The approved decisions change the blocker state from decision-gated to implementation-gated. The
current repository slice may be implemented and tested, but a blocker is not closed until its
pre-deployment acceptance evidence proves the full contract. A missing canonical host or audience
source is not permission to invent a value; when no repository SSOT exists, it is recorded as a
contract contradiction and the activation path remains fail-closed.

### Pre-deployment consumer and regional-input review (2026-09-23)

The repository review identified the current owner-specific consumers without changing delegated
access semantics. `AccountPolicy` is staged on each account-family cutover marker. The two quota
policies and the six concrete creator operations use the configured surface-local ownership and
lifecycle relation for owner-specific quota decisions. `OrganizationPolicy`,
`BaseSelectorAuthority`, and `BaseSwitcherAuthority` remain membership/act-as contracts and are
not owner consumers; replacing them with owner-only reads would be an unapproved authorization
change. The persisted family marker, immutable marker model, post-marker backfill rejection, and
post-cutover AccountPolicy test provide the forward-only boundary; no ownership-transfer acceptance
route is enabled because its recipient authentication, step-up, lifecycle, quota, and locked
transaction contract is explicitly deferred in the authority ADR.

The approved regional matrix and independent logical key namespaces are present in
`AuthBoundaryAuthorityMap` and `RegionalRpClientMatrix`. Exact Core JP/US, existing Side JP, and
global Edit URI bindings are derived only from repository sources. The repository has no
independent Side US canonical host source and no regional audience SSOT for the new IDs, so the
active seven-client registry remains unchanged and the regional activation path fails closed.
Those missing inputs are not filled from a request Host header or a guessed client-id audience.

This review changes neither acceptance scope nor external deployment gates. The current process
could not run the DB-backed acceptance because `primary` and `valkey-kvs` were not resolvable;
the exact command and full error are recorded in the current evidence record.

### Approved-decision implementation slice (2026-09-23)

The repository now has a read-only inventory view of explicit ownership rows and a
`AuthorityOwnerDirectBindingBackfillOperation` for one unambiguous direct identity binding. The
operation is surface-local, lock-protected, idempotent, and conflict-rejecting; membership,
administrator, legacy-organization, inactive, and ambiguous cases are not promoted. The approved
13-cell RP target is recorded in `AuthBoundaryAuthorityMap` as a migration contract while the
active seven-client registry remains unchanged.

The operation requires an explicitly reviewed surface-local `owner_public_id` for every backfill
mutation, including a resource with an otherwise unambiguous legacy identity binding. It never
derives that owner from identity binding, membership, administrator, assignment, or legacy
Organization data, and rejects a principal from another surface. A read-only
`AuthorityOwnerCutoverGuard` checks the family inventory and refuses readiness when the resource
model has no explicit lifecycle contract; absence of lifecycle columns is not interpreted as
active. It also requires an explicit `lifecycle_active?` result before a family can be ready and
distinguishes inactive authoritative resources from inactive principals. Membership inventory
classifies multiple candidates as ambiguous and never promotes membership-only evidence.
`AuthorityOwnerPredeploymentBackfillOperation` composes the reviewed owner and lifecycle inputs in
one surface-local transaction. If either input is rejected, an already-created half of that pair is
rolled back; repeating the same reviewed input is idempotent. This is a migration/backfill safety
unit only. It does not infer candidates or switch an authorization consumer. The new
`AuthorityOwnerFamilyCutoverOperation` acquires the same family resource-table lock, rechecks the
guard, and creates one immutable surface-local singleton marker; after that point all reviewed
backfill paths reject and bootstrap refuses to create an authority-incomplete resource. The marker
is the persisted point of no return; recovery after it is forward-only.
The read-only `authority:cutover_guard` task now evaluates all six approved families through the
same guard and writes only a public-identifier readiness report. It performs no backfill, consumer
switch, or cutover mutation.
The read-only `auth:regional_rp_contract` task evaluates all 13 approved client IDs against the
same canonical URI and registry binding checks. Missing hosts, missing audiences, and invalid
registrations are reported as incomplete; the task never activates a client or generates a key.
`RegionalRpClientMatrix` derives exact Core JP/US callback, logout, and backchannel URIs from
`RegionalRootUrlRegistry`, derives the already-established global `edit-org` host from
`PUBLIC_EDIT_STAFF_URL`, provides independent logical key namespaces and RP-session bindings,
and refuses missing Side host sources instead of inventing them.

The selector bootstrap uses the six concrete creator operations only when a newly created resource
has an eligible active principal. Such a resource receives its explicit ownership and `active`
lifecycle row in the same surface-local transaction; the existing assignment/membership rows
remain separate relationship data. Withdrawal, inactive, or access-restricted legacy bootstrap
flows retain their legacy graph construction because that graph is still required before family
cutover. Existing legacy resources are not inferred or repaired by bootstrap and remain subject to
the reviewed inventory/backfill and family cutover gates. After the family marker exists, a new
ineligible resource is rejected instead of entering the legacy-only path; an eligible new resource
continues through the concrete owner/lifecycle creator. The marker is immutable and establishes the
point of no return for that family.

The bootstrap now acquires the existing surface-local authority lock for the complete graph
transaction before checking or creating the RP account, identity, resource, collective, membership,
and (for app) avatar graph. This closes the identified concurrent-bootstrap window in which two
callers could each pass the initial membership check and leave an extra collective. The lock is a
serialization mechanism only; it is not an owner or access grant.

Owner-specific quota policies now apply the approved lifecycle boundary without changing delegated
selector/switcher access: they count only explicitly `active` owned resources, reject an ineligible
principal, and fail closed when any resource in the evaluated scope has no lifecycle row. This is
an owner-policy slice, not a family-wide authorization cutover; legacy candidate graphs remain
separate until a named consumer and family cutover contract are accepted.

The owner-specific quota consumer now reads through `AuthorityOwnerResourceScopeQuery`, which
accepts only the configured surface-local principal/resource family and has no legacy fallback. This
names and centralizes the quota source of truth without changing selector/switcher delegated access.
The owner-specific `AccountPolicy` is now staged on the same family marker: before cutover it
preserves the existing legacy behavior, while after cutover it requires the explicit ownership
relation, eligible principal, and active resource lifecycle and does not consult the legacy identity
binding. `OrganizationPolicy` remains a delegated membership contract, and the selector/switcher
candidate graph is intentionally unchanged. This names one owner-specific consumer but does not by
itself satisfy the separate family-wide authorization consumer cutover gate.

All six concrete resource creator operations now call the corresponding owner-scoped quota policy
inside the existing surface-local principal lock and transaction. They no longer count ownership
rows directly, so inactive lifecycle resources do not consume a slot and an ownership row without
an explicit lifecycle row blocks creation. The creator still writes its resource, active lifecycle,
and ownership rows atomically. This closes the quota-policy/creator-path discrepancy; it does not
switch selector/switcher access or constitute the family-wide authorization cutover.

#### Adversarial boundary review: owner authority versus act-as context (2026-09-23)

The approved owner mapping does not authorize a blanket replacement of the selector/switcher
candidate graph. `BaseSelectorAuthority` and `BaseSwitcherAuthority` resolve act-as context through
the existing surface-local identity, assignment, membership, and avatar contracts; those relations
can represent legitimate delegated or member access and are not owner authority. Replacing that
path with an owner-only query would be an unapproved access-contract change. The ownership tables
remain the sole source for owner-specific decisions, including the quota policies and the reviewed
backfill/cutover gate. Any future consumer switch must name an owner-specific authorization
consumer and pass its own access/delegation review before it changes selector behavior.

The inventory and cutover guard also distinguish an ownership fact from current authority
eligibility. An ownership row with an inactive or access-blocked principal remains retained data
but is unresolved for family cutover; row presence alone cannot satisfy the cutover gate.

### Pre-deployment continuation: fail-closed boundaries (2026-09-23)

The owner backfill now treats a non-global `public_id` collision across concrete principal
surfaces as `manual_review` rather than selecting the principal in the requested surface. Principal
classification distinguishes inactive status from a suspended/access-blocked principal; neither is
an eligible authority candidate, and neither causes transfer or revival. The approved six mapping
table is fixed by an explicit inventory regression contract. Legacy identity bindings remain
candidate evidence only: every backfill mutation requires an explicitly reviewed surface-local
owner, so an identity binding cannot promote itself into owner authority.

The regional RP matrix separates URI derivation from a complete OIDC registration. `uri_binding_for`
may derive approved Core JP/US and global Edit URI bindings from canonical repository sources, while
`binding_for` fails with `MissingCanonicalAudience` until an authoritative regional audience source
exists. No audience, Side host, registry entry, caller mapping, or credential was guessed or
activated. A complete registered binding also now requires the registry account to use
`private_key_jwt`, in addition to the exact resource type, redirect/logout/backchannel URIs,
audience isolation, namespace, and RP-session client binding. This preserves the approved
fail-closed contract while the matrix contradiction remains open.

The current acceptance gaps are explicit: the six resource families now have concrete,
surface-local lifecycle tables, explicit lifecycle-state backfill, and creator-path insertion of an
`active` row, but complete reviewed backfill and family-level consumer cutover are still absent.
The existing canonical Side JP host can be derived, but no independent Side US host source or
regional audience semantics exists in the repository. These are not production-evidence
requirements, but they are repository implementation/contract prerequisites and therefore keep
`CF-007` open. `CF-003/CF-004` remains open for the separate family-level authorization consumer
switch and forward-recovery proof. Detailed evidence is recorded in
`evidence/2026-09-23-cf003-cf007-continuation-T6U7.md`, the later Side JP source check in
`evidence/2026-09-23-cf007-side-jp-source-Q2S3.md`, and the current lifecycle implementation
evidence.

The pre-deployment backfill unit is now atomic per resource: an explicitly reviewed owner and
explicit lifecycle state are committed together or neither is committed. The unit is idempotent
for the same reviewed pair and rejects lifecycle conflicts without leaving a newly created owner
row behind. This advances the isolated backfill contract but does not close `CF-003/CF-004`, because
the complete reviewed mapping, family-level consumer switch, and post-cutover forward-recovery
proof are still not implemented.

The approved six-family owner mapping is now also the Ruby-level SSOT for the account and
organization quota consumers. `AuthorityOwnerMigrationInventory::RESOURCE_KIND_BY_CATEGORY`
resolves the app/com/org account and organization resource kinds, and both quota policies derive
their ownership and lifecycle relations from the corresponding inventory configuration. This
removes a second policy-local mapping without changing the delegated selector/switcher graph.
This is a consumer consistency slice, not the family-level cutover or point-of-no-return marker.
Evidence: `evidence/2026-09-23-owner-mapping-ssot-M2N3.md`.

This slice still does not close either blocker. Complete reviewed backfill and family-level
consumer cutover, post-cutover forward-recovery proof, exact regional audience mapping, active
regional registry entries, caller/RP-session migration, and `core-next-rp` retirement procedure
remain implementation work. Evidence for this slice is recorded in the next dated pre-deployment
evidence record.

### Current-process pre-deployment acceptance recheck (2026-09-23)

The required Compose-backed test preflight was rerun with the explicit
`.env.devcontainer.example` environment. The test credential key was present, all required
PostgreSQL/Valkey variables were present without printing their values, `primary` and
`valkey-kvs` resolved, PostgreSQL 17.7 was reachable, and Valkey 7.2.4 returned PONG for the
rate-limit and auth-state logical databases. The disposable local test databases and stale
parallel worker clones were rebuilt only as test infrastructure; no production or shared data was
changed.

The complete CF-003/CF-004 authority acceptance set passed with `97 runs / 690 assertions / 0
failures / 0 errors / 0 skips`. It covers the six approved mappings, lifecycle and conflict
dispositions, idempotent and atomic backfill, unique-owner enforcement, family-level cutover,
immutable point-of-no-return behavior, post-marker backfill rejection, and post-cutover explicit
ownership reads. The full Rails suite then passed with `11,672 runs / 74,218 assertions / 0
failures / 0 errors / 8 skips`. Targeted syntax, RuboCop, and `git diff --check` also passed.

The earlier current-process wording that called the isolated acceptance unverified is superseded
by this recheck. `CF-003/CF-004` is now `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`. The
immutable marker and post-marker rejection are the repository proof of forward-only recovery: the
old authority cannot be restored through the normal backfill path. Production row inventory,
actual cutover, and operational recovery rehearsal remain later deployment gates.

`CF-007` remains `OPEN — CONTRACT CONTRADICTION`: its approved 13-cell matrix and isolation
tests are present, but the repository still has no canonical Side US host source or regional
audience SSOT. No value was guessed, activated, or derived from a Host header.

Evidence: `evidence/2026-09-23-cf003-cf007-predeployment-acceptance-F7G8.md`.

`AuthorityOwnerFamilyBackfillOperation` now provides the repository-side pre-cutover unit: one
complete reviewed mapping for one resource family is validated for explicit owner/lifecycle fields
and duplicate resource entries, then applied in one surface-local transaction. A rejected or
conflicting row rolls back earlier rows from that reviewed batch; an identical complete batch is
idempotent. `AuthorityOwnerFamilyCutoverOperation` separately rechecks the family guard while
holding the same resource-table lock and records one immutable surface-local singleton marker.
After that marker, all reviewed backfill paths reject and bootstrap cannot create a new
authority-incomplete resource. The remaining family-level authorization consumer switch and its
forward-recovery proof remain open.

The historical Compose-backed runs remain evidence of what passed in that earlier environment. A
non-escalated 2026-09-23 process initially could not resolve the required `primary` and `valkey-kvs`
service names; that environment observation was superseded by the later Compose-backed runs recorded
in the dated CF-011 and CF-005 closure evidence. Production worker/runtime evidence remains a later
deployment gate.

### Current pre-deployment scope correction (2026-09-23)

The repository is not deployed to production. Production runtime, production data, deployed
callers, Base deployment registry state, credential fingerprints, and provider end-to-end delivery
are therefore not prerequisites for closing the current repository cycle. They remain mandatory
later gates under `PRE-DEPLOYMENT / DEPLOYMENT ACCEPTANCE GATE`; they are not deleted or weakened.

The current cycle uses only approved design, repository behavior, and isolated development/test
evidence. No local queue run, expected registry manifest, or fake adapter may be reported as
production/provider evidence. The current blocker vocabulary is:

- `OPEN — DECISION REQUIRED`: an approved design input is missing.
- `OPEN — CONTRACT CONTRADICTION`: the approved design requires a binding input, but the repository
  has no authoritative SSOT from which that input can be derived; no guessed value may be introduced.
- `OPEN — IMPLEMENTATION REQUIRED`: repository behavior is incomplete.
- `OPEN — EVIDENCE REQUIRED`: repository behavior exists but the required local proof is missing.
- `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`: repository/design/isolated-environment
  acceptance is complete; later deployment/provider gates remain open.

Current dispositions:

| Blocker | Pre-deployment disposition |
| --- | --- |
| `CF-003/CF-004` | `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`: the six approved surface-local mappings, lifecycle/conflict dispositions, atomic/idempotent backfill, unique-owner enforcement, family-level gate, immutable point of no return, post-marker backfill rejection, and post-cutover explicit ownership consumers are covered by the isolated PostgreSQL acceptance set. Ownership-transfer acceptance remains intentionally disabled rather than guessed; production inventory/cutover and operational forward-recovery rehearsal remain deployment gates. |
| `CF-005` | `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`: configuration validation, recurring scheduler enqueue, dispatcher/worker pickup, expected database mutation, and controlled failure evidence are complete in the isolated local environment. Production runtime remains a later deployment gate. |
| `CF-007` | `OPEN — CONTRACT CONTRADICTION`: the 13-cell regional matrix and isolation policy are approved, and the repository now exposes one expected registry contract for all 13 cells. The exact Side US host source and regional audience SSOT are still absent, so the active registry/caller/bridge migration must not guess those values or derive them from Host headers. |
| `CF-008` | `BLOCKS_SLICE`: the adopted scrub contract still lacks an approved per-model/per-attribute inventory and an isolated, reversible validation for the distinct Client/Visitor anonymization and Operator purge paths. No destructive scrub, lifecycle reinterpretation, encryption backfill, or new dry-run/preview API is required or enabled by this status. |
| `CF-011` | `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`: provider-neutral state, receipt, idempotency, retry/permanent-failure, recovery, and DB-backed regression evidence passed in the isolated Compose environment. Provider authentication and provider E2E remain deployment/provider gates. |

The approved-decision continuation and its current verification are recorded in
`evidence/2026-09-23-cf003-cf007-approved-continuation-Z8V9.md`.

### Retention bounded-input hardening (2026-09-23)

An adversarial review found that the existing retention job had an explicit default batch size but
did not constrain a direct caller-supplied `batch_size`. `RetentionPurgeJob` now rejects values
outside the inclusive `1..500` range, including fractional, zero, negative, missing, and oversized
values, before the kill-switch branch or destructive work. Integral strings remain accepted for
Active Job argument compatibility. This strengthens the existing bounded-batch contract and adds
no dry-run, preview, simulation, audit-only, or schema interface. CF-008 remains blocked because
the broader scrub/lifecycle data contract is still not approved; this change does not reinterpret
the Operator purge path or claim complete erasure. Evidence:
`evidence/2026-09-23-retention-batch-boundary-Q5R6.md`.

### Lifecycle cutover gate correction (2026-09-23)

The adversarial review found that the family cutover guard treated every non-active resource as an
unresolved owner-authority row. That was stricter than the approved lifecycle contract. An
explicitly `inactive`, `discarded`, `deleted`, or `retained` resource does not require an active
owner authority for family cutover; its historical relation may be retained and its normal
authorization remains unavailable. The guard now excludes those explicit non-authority-required
resource states from its unresolved set while continuing to block an active resource, a missing or
unknown lifecycle state, an ineligible authoritative owner, or any resource without the required
explicit lifecycle proof. This does not change selector/switcher act-as behavior or create an
automatic owner. The new regression covers inactive and discarded resource states through the
public cutover guard. Rails execution remains unverified in the current process because the
required `primary` and `valkey-kvs` service names were not resolvable.

For `CF-003/CF-004`, pre-deployment acceptance will use isolated migration/backfill fixtures,
idempotency, unique-owner enforcement, conflict rejection, and rollback/forward-recovery tests;
production row inventory and cutover remain later gates. For `CF-005`, acceptance requires
configuration validation, recurring enqueue, dispatcher pickup, worker execution, expected database
mutation, and controlled failure with bounded retry/recovery in an isolated queue. For `CF-007`,
acceptance requires an approved logical JP/US/global matrix and repository cross-acceptance
rejection tests, not external registration. For `CF-011`, `NOTIFIED` is reachable only after an
authenticated receipt bound to the notification, processor, and idempotency key; provider-specific
authentication and E2E remain later gates. The latest pre-deployment recheck is recorded in
`evidence/2026-09-23-cf011-parallel-seed-recheck-M7N8.md`.

The approved CF-003/CF-004 and CF-007 decisions, their implementation boundary, and their minimum
acceptance evidence are recorded in
`plans/backlog/2026-09-23-critical-blocker-decision-inputs.md`. Its earlier choice tables are
historical decision-input records; the approved amendment above is the current authority.

The approved-decision continuation adds two repository-side guards without activating external
state. The migration inventory now records administrator grant public identifiers and classifies an
administrator-only organization as manual review; administrator relations remain evidence only and
never become owner authority. `RegionalRpClientMatrix.expected_registry_contract` is the single
expected Base-registry shape for the approved 13 cells: it records the approved actor, region,
logical key namespace, RP-session client binding, and canonical host/audience source without storing
or inventing a host value, audience value, or credential. The compatibility registry and
`core-next-rp` remain unchanged. These changes do not close either blocker: CF-003/CF-004 still
needs isolated PostgreSQL acceptance, while CF-007 still needs an authoritative Side US host source
and regional audience SSOT before registry activation.

### Test boot dependency reclassification (2026-09-23)

The current source and a Compose-backed preflight were rechecked against the resumed blocker
contract. `config/environments/test.rb` uses an in-process `MemoryStore` for the application
cache, but deliberately constructs a Valkey-backed rate-limit store and loads the Auth-state
store. `test/test_helper.rb` also cleans those two namespaces through the configured KVS service.
`config/database.yml` requires the configured test PostgreSQL host for the `primary` connection.

When the required variables and service network are absent, the repository preflight stops before
application checks. With the explicit `.env.devcontainer.example` selected inside the local
Compose network, PostgreSQL and Valkey both resolve and the preflight reports PostgreSQL 17.7 and
Valkey 7.2.4 with successful PINGs for test logical DBs 4 and 6. This classifies the outside-network
failure as `ENVIRONMENT_UNAVAILABLE`, not `CONFIGURATION_BUG`; no repository fallback, hostname
rewrite, or silent Valkey degradation is warranted. Evidence:
`evidence/2026-09-23-boot-dependency-classification-Q3R4.md`.

This does not reopen CF-005 or CF-011. Their current pre-deployment acceptance evidence remains
authoritative, and the production/provider checks remain later deployment gates.

### CF-011 pre-deployment closure recheck (2026-09-23)

The DB-backed CF-011 regression set was rerun after correcting the visitor fixed-reference seed
allowlist and making parallel test-database clone freshness include `db/seeds.rb`. Focused tests
passed with `77 runs / 367 assertions / 0 failures / 0 errors / 0 skips`; the full parallel Rails
suite then passed with `11,579 runs / 73,647 assertions / 0 failures / 0 errors / 8 skips`. The
previous seven missing-reference errors did not recur. Syntax, targeted RuboCop, and
`git diff --check` also passed. No skip or mock was added and no external/provider service was
contacted.

`CF-011` is therefore `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`. This does not close provider
authentication, provider-specific receipts, production worker topology, or production/provider
end-to-end delivery; those remain in the later deployment/provider acceptance gate.

### CF-005 pre-deployment acceptance closure (2026-09-23)

The isolated local Compose environment passed the required PostgreSQL/Valkey preflight and
`bin/jobs check` for development and test. The development Solid Queue adapter was used for the
runtime probe because the test environment intentionally uses the Rails test adapter. A temporary
one-second recurring definition drove `SecurityConsumedJtiPurgeJob` through the actual scheduler,
dispatcher, and retention worker. Five recurring executions and five completed queue jobs were
observed, and an expired application row was removed by the job. A separate invalid `batch_size: 0`
execution produced a recorded `ArgumentError` failed execution without a false successful mutation.
The repository's existing bounded retry/recovery contract tests remain part of the evidence set.

The normal repository recurring schedules were restored after the probe. No production worker,
production queue database, heartbeat/monitoring, operational rollback, or provider was contacted.
Those checks remain mandatory under the later `PRE-DEPLOYMENT / DEPLOYMENT ACCEPTANCE GATE`.

Evidence: `evidence/2026-09-23-cf005-queue-runtime-P6Q7.md`.

### CF-011 migration rollback correction (2026-09-23)

An adversarial review found that the client and visitor processor-delivery validation migrations
used a helper CHECK constraint name in `down` that was not created by `up`. Both migrations now use
the same explicit helper-constraint constant in both directions. The focused rollback-contract
regression passed with `2 runs / 2 assertions / 0 failures / 0 errors / 0 skips`, and the full
RuboCop, Brakeman, syntax, and diff checks passed. This is a repository-side correction; actual
PostgreSQL `down`/`up` execution remains unverified until the configured Compose PostgreSQL service
is reachable. It is not represented as production migration-rollback evidence.

Evidence: `evidence/2026-09-23-processor-migration-rollback-fix-T2U3.md`.

### CF-011 retry-policy boundary correction (2026-09-23)

An adversarial review found that `ProcessorErasureRetryPolicy#retry_at` rejected non-positive
attempt numbers while `#exhausted?` accepted them. Both operations now share the same positive
attempt-number normalization. The inclusive exhaustion boundary and maximum-policy boundaries are
covered by a pure value-object regression (`3 runs / 11 assertions / 0 failures / 0 errors / 0
skips`). This does not alter persisted attempt limits or provider behavior; PostgreSQL-backed
verification remains subject to the reachable Compose test environment.

Evidence: `evidence/2026-09-23-processor-retry-boundary-fix-V4W5.md`.

### CF-011 receipt value-boundary coverage (2026-09-23)

The provider-neutral receipt and dispatch value objects now have pure public-contract coverage for
missing/empty bindings, zero generation, invalid digest format, success without a verified receipt,
and failure without an error code. Valid integer/string normalization remains covered only for
permitted values. The focused value set passed with `3 runs / 14 assertions / 0 failures / 0
errors / 0 skips`; this does not replace PostgreSQL-backed receipt application or concurrency
verification.

Evidence: `evidence/2026-09-23-processor-receipt-value-boundary-W6X7.md`.

### CF-011 dispatch-outcome null boundary correction (2026-09-23)

An adversarial value-boundary review found that a nil or numeric adapter outcome raised
`NoMethodError` while the public dispatch-result contract requires explicit rejection of unsupported
outcomes. The constructor now normalizes only values that expose `to_sym` and rejects nil, numeric,
and other unsupported outcomes with `ArgumentError`; successful receipt and failure classification
semantics are unchanged. The RED/green value test passed with `3 runs / 16 assertions / 0 failures /
0 errors / 0 skips`, and targeted RuboCop plus `git diff --check` passed. Evidence:
`evidence/2026-09-23-processor-dispatch-null-boundary-Y8Z9.md`.

### CF-011 processor error-message secret boundary (2026-09-23)

An adversarial review found that an adapter failure message could otherwise reach notification and
attempt error metadata without the existing sensitive-text sanitizer. The normal dispatch-result
path now applies `ChronicleRecordPolicy.sanitize_text` before persistence. A RED test reproduced a
raw token-shaped message in `4 runs / 18 assertions / 1 failure`; the corrected boundary passed with
`4 runs / 19 assertions / 0 failures / 0 errors / 0 skips`. Targeted RuboCop and `git diff --check`
also passed. Evidence: `evidence/2026-09-23-processor-error-message-sanitization-Z0A1.md`.

### CF-011 processor error-code and constructor boundary (2026-09-23)

An additional adversarial review found that the dispatch-result value object accepted arbitrary
failure error-code strings and that direct public construction could bypass the normal factory's
message sanitization. Failure codes are now restricted to the existing safe categorical form
(`a-z`, followed by up to 63 lowercase letters, digits, dots, underscores, or hyphens), and the
constructor sanitizes error messages for every construction path. This rejects token-shaped values
as error codes without changing the provider-neutral outcome taxonomy. The value-boundary suite now
passes with `5 runs / 23 assertions / 0 failures / 0 errors / 0 skips`; full RuboCop, Brakeman, and
`git diff --check` also pass. PostgreSQL/Valkey-backed acceptance remains subject to the reachable
Compose environment and is not claimed by this value-only check.

Evidence: `evidence/2026-09-23-processor-error-code-boundary-B2C3.md`.

### CF-011 notification-state metadata bypass closure (2026-09-23)

The adversarial review then followed the public notification-state methods rather than only the
dispatch value object. `mark_retryable_failure!` and `mark_permanent_failure!` could previously
persist caller-supplied error metadata directly, bypassing the value-object boundary. Both public
transitions and the locked failure recorder now use the same safe error-code normalization and
sensitive-message sanitization before updating attempt or notification rows. Regression tests cover
unsafe-code rejection for both retryable and permanent transitions without a state change, and
sanitization at the direct state-transition boundary. They are added but remain unexecuted because the current process cannot resolve the
required PostgreSQL service; this is an evidence gap, not a reason to weaken the test or database
contract. Pure value tests, full RuboCop, Brakeman, syntax, and diff checks pass.

Evidence: `evidence/2026-09-23-processor-state-metadata-boundary-C3D4.md`.

### CF-011 request-idempotency correction (2026-09-23)

An adversarial review found that generating a new idempotency digest for every retry would allow an
ambiguous processor response to be retried as a distinct external request. The pre-deployment
implementation now stores one digest-only request identity per delivery generation and reuses it for
all retry attempts in that generation. Authorized manual recovery advances the generation and creates
a new identity. Attempt number remains unique and monotonic; its lookup index is non-unique because
the same generation-scoped request identity is intentionally reused. Receipt validation remains bound
to notification, processor, generation, and that identity. Evidence:
`evidence/2026-09-23-cf011-idempotency-recheck-R4S5.md`.

The former resumption table below is historical for its production/provider prerequisites. The
current scope above takes precedence and the later deployment/provider gate must be read as the
activation requirement, not as a current blocker.

#### PRE-DEPLOYMENT / DEPLOYMENT ACCEPTANCE GATE

The following evidence remains mandatory before actual activation:

| Gate | Later evidence |
| --- | --- |
| `CF-003/CF-004` | Production row inventory, reviewed disposition, real cutover, post-cutover single-source proof, and rollback/forward-recovery rehearsal. |
| `CF-005` | Production worker, dispatcher, scheduler, queue database, DB connections, heartbeat/monitoring, recurring execution, and operational rollback proof. |
| `CF-007` | Real Base registry records, credential/key fingerprints, deployed caller mapping, and `core-next-rp` migration/retirement against the actual deployment. |
| `CF-011` | Provider authentication, provider credentials, authenticated receipt protocol, retry/exhaustion/permanent-failure behavior, manual recovery, and provider E2E evidence. |

No item in this gate may be satisfied by local configuration, a fake adapter, or an expected
registry manifest alone.

### Historical readiness re-audit (2026-09-22; superseded by the provider-neutral contract)

The local Compose-backed verification boundary remains healthy. The CF-010/CF-011 focused set
passed with `161 runs / 711 assertions / 0 failures / 0 errors / 6 skips`, and the complete Rails
suite passed with `11536 runs / 73426 assertions / 0 failures / 0 errors / 8 skips`. `RAILS_ENV=test
bin/jobs check` passed with the repository's explicit `.env.devcontainer.example`, confirming the
local Solid Queue configuration. These checks do not prove production worker topology or provider
delivery.

The current read-only owner inventory was rerun against the disposable test topology. It reported
`authority_schema_state=applied`, `resources_scanned=0`, and an empty classification set. This is
evidence that the test database contains no owner data to classify; it is not evidence for an
owner mapping or permission to backfill production data. CF-003/CF-004 therefore remain blocked on
authoritative source data and an approved migration/cutover contract.

CF-011 remains open because the repository still has no concrete processor adapter, authenticated
receipt contract, bounded retry-exhaustion policy, or approved permanent-failure state. The
success allowlist remains empty, and unsupported processor notifications remain explicit failures.
CF-007 remains open because regional RP IDs, exact URI matrices, credentials, deployed-caller
migration, and Base-side registrations are not established by repository evidence. No external
service was contacted and no security boundary was weakened to make these gates appear complete.
Evidence: `evidence/2026-09-22-cf010-cf011-revalidation-A7B8.md`,
`evidence/2026-09-22-solid-queue-local-recheck-C1D2.md`, and
`evidence/2026-09-22-authority-owner-inventory-recheck-J4K5.md`.

### Historical resumed readiness audit (2026-09-23; superseded by the provider-neutral contract)

The resumed local audit loaded the explicit Compose-backed test environment and passed the
repository preflight. The read-only owner inventory reported `authority_schema_state=applied`,
`resources_scanned=0`, and no classifications. The corrected focused boundary set passed with
`140 runs / 602 assertions / 0 failures / 0 errors / 6 skips`. No external service or shared data
was contacted or changed. Evidence: `evidence/2026-09-23-resumed-readiness-audit-V2W3.md`.

This revalidation does not change the remaining decisions. CF-003/CF-004 still require
authoritative owner data and an approved migration/cutover contract; CF-007 still requires the
regional RP registration and credential matrix plus deployed-caller/Base registration evidence;
CF-011 still requires an approved processor adapter, receipt, retry-exhaustion, and
permanent-failure contract; and CF-005 still lacks production worker/scheduler proof. No safe
local implementation can close those boundaries without inventing an authority, destructive data
operation, external registration, or provider contract.

### Owner-inventory regression and full-suite revalidation (2026-09-23)

The public `AuthorityOwnerMigrationInventory` contract now has regression coverage for direct app,
com, and org resources with inactive identity bindings, missing principals, multiple active
memberships, and the prohibition on exposing database-local identifiers. The focused inventory
test passed with `6 runs / 85 assertions / 0 failures / 0 errors / 0 skips`; the related authority
schema/model set passed with `50 runs / 448 assertions / 0 failures / 0 errors / 0 skips`.

The full Rails suite was then rerun using the explicit Compose-backed test environment and passed
with `11539 runs / 73460 assertions / 0 failures / 0 errors / 8 skips`. This is repository-side
verification only. The isolated inventory still reports `authority_schema_state=applied` and
`resources_scanned=0`; it does not authorize owner mapping, backfill, migration, or cutover.
No external service, shared database, production credential, or provider was contacted or changed.
Evidence: `evidence/2026-09-23-owner-inventory-contract-X4Y5.md`.

The inventory regression was then extended with active identity bindings whose principals are
inactive on app, com, and org. All remain `inactive_principal`, `manual_review`, and
non-authoritative candidates. The focused inventory test passed with `7 runs / 97 assertions`,
the related authority/schema/model set with `51 runs / 460 assertions`, and the subsequent full
Rails suite with `11540 runs / 73472 assertions / 0 failures / 0 errors / 8 skips`. This adds
classification coverage only; it does not authorize an owner mapping or cutover.

### Unblocked-slice re-audit (2026-09-23)

The current Rails controllers, models, services, jobs, routes, library code, and security tests
were re-audited for unfinished local implementation that could be completed without inventing a
contract. `OutageService` and `TokenEmergencyService` remain explicit placeholders with no
production call site or approved state, authorization, and audit contract; they remain
`NEXT_CYCLE / CONTRACT_UNDEFINED`. The Base/Side `/web/v0` preference FIXME markers still denote
an unapproved compatibility migration, and the GUID/actor-observability comments do not identify
a current security defect. No implementation was inferred from those markers.

The regional RP, processor-delivery, owner-cutover, and production-worker gates remain critical
because they require external registration state, an approved provider contract, authoritative
source data, or production topology evidence. The local queue configuration check, targeted
RuboCop, and `git diff --check` passed. Full Rails, frontend, and static quality results remain
recorded in the dated evidence files. This re-audit therefore found no additional safe local
implementation slice; it does not close any of the critical gates. Evidence:
`evidence/2026-09-23-unblocked-slice-reaudit-C3D4.md`.

The follow-up marker scan confirmed that `OutageService` and `TokenEmergencyService` remain
contract-undefined placeholders with no production call site, while the base OTP/notice adapters
and external-notification ports remain the explicit CF-011 delivery boundary. No fallback,
provider, outage state machine, or emergency-token authority was invented to remove the markers.
This preserves fail-closed behavior and records the unresolved contract rather than treating a
placeholder as an implementation defect that can be safely filled in locally.

### Historical resumption contract for the four critical gates (2026-09-23; superseded by the approved pre-deployment scope)

The following table records the earlier blocked-state inputs and is retained for audit history. It
is superseded by the approved decisions recorded in the 2026-09-23 amendments above. It MUST NOT
be read as requiring production, deployed-caller, provider, or external-registration evidence
before repository-side pre-deployment implementation can proceed. Those facts remain later
deployment/provider gates.

| Gate | Required input before implementation | Minimum acceptance evidence |
| --- | --- | --- |
| `CF-003/CF-004` owner mapping and cutover | An approved source-to-owner mapping for app, com, and org; lifecycle/conflict rules; authoritative source data access; migration, backfill, cutover, and rollback procedure | A read-only inventory against the approved authoritative data with every candidate classified; an approved disposition for inactive, ambiguous, legacy, and unowned rows; isolated migration proof before any destructive or production operation; post-cutover proof that exactly one approved relation is authoritative for each owned resource, dual ownership/source disagreement is rejected or explicitly ownerless, and all consumers use that same source of truth |
| `CF-005` production queue runtime | The production worker, dispatcher, scheduler, queue, database, and environment topology owned by operations | A non-destructive operational check showing the intended worker and scheduler topology, queue pickup, recurrence, failure/retry behavior, and rollback/runbook path, including one production-equivalent end-to-end job execution; local `bin/jobs check` alone is insufficient |
| `CF-007` regional RP identity | Historical requirement: an approved JP/US client-ID and host matrix, global-RP exceptions, independent key/credential mapping, Base registry entries, deployed caller inventory, and `core-next-rp` migration/retirement order | Historical requirement: repository contract tests plus controlled evidence that corresponding Base and deployed registrations agree; the approved 13-cell matrix now authorizes repository-side contract work, while external registration and deployed-caller evidence remain deployment gates |
| `CF-011` processor delivery | An approved processor adapter and authentication contract; request idempotency; authenticated receipt; transient/permanent failure taxonomy; bounded retry/exhaustion policy; explicit terminal permanent-failure state; audit and manual-recovery contract | Contract tests using an approved fake/adapter, including receipt forgery, duplicate delivery, retry exhaustion, permanent failure, and recovery; each state transition must be observable and terminal states immutable; production/provider verification only under separately authorized operational access |

At the time of this historical record, those inputs were absent. The current approved scope is
defined by the amendments above: owner migration remains fail-closed, queue checks do not claim
production execution, the registry does not invent regional values, and unsupported processor
notifications do not become `NOTIFIED`; repository-side work may proceed where the approved
pre-deployment contract and isolated evidence are sufficient.

The 2026-09-23 closure audit applied this table without implementing any of the four blocked
changes. The focused owner/RP/processor set passed with `151 runs / 981 assertions / 0 failures /
0 errors / 0 skips`, and the full Rails suite passed with `11540 runs / 73472 assertions / 0
failures / 0 errors / 8 skips`. These results verify repository-side regression health only; they
do not satisfy the data, deployment, regional-registration, or processor-contract evidence above.
All four gates therefore remain open. Evidence:
`evidence/2026-09-23-critical-gate-closure-audit-H7J8.md`.

As a cleanup within the same authentication-boundary review, the generic authorization-code store
test was canonicalized from retired `core-app-rp`/`/sign/in/callback` examples to the current
`core-app`/`/sign/callback` contract. This changed no production code or store behavior; the
focused Valkey store test passed with `8 runs / 34 assertions / 0 failures / 0 errors / 0 skips`.
The separately retained `core-next-rp` bridge references were not changed. Evidence:
`evidence/2026-09-23-authorization-code-fixture-canonicalization-D4E5.md`.

The same audit then canonicalized two additional RP-session/result test fixtures from retired
`core-app-rp`/`side-app-rp` examples to the current local client IDs and added an explicit
historical-reading rule to superseded authority documentation. The related focused set passed with
`15 runs / 71 assertions / 0 failures / 0 errors / 0 skips`, followed by the unchanged full Rails
suite with `11540 runs / 73472 assertions / 0 failures / 0 errors / 8 skips`. This remains a
test/documentation cleanup only; regional registration, external keys, and the `core-next-rp`
bridge migration remain `CF-007`. Evidence:
`evidence/2026-09-23-retired-rp-reference-cleanup-E5F6.md`.

The same adversarial document review found vendor-facing identity package documents, the OIDC
discovery/downstream-token security references, and the partially superseded Base lobby ADR that
could still be read as current Acme/Sign authority or shared-RP instructions. They now carry
explicit historical/supersession warnings pointing to the Base/Auth ADR and current sign-in
sequence. Historical tables were retained; no route, registry, issuer, key, or authority behavior
changed. Evidence:
`evidence/2026-09-23-vendor-identity-doc-supersession-F6G7.md`.

### Final adversarial security scan (2026-09-22)

The final implementation-direction review re-traced the app/com discoverable Passkey options
boundary, the intentional Org/MFA/Emergency actor-bound Passkey paths, TOTP terminal revocation,
first-party neutral OIDC intent, and reviewed credential-related diagnostic logging. The focused
public-boundary set passed with `149 runs / 813 assertions / 0 failures / 0 errors / 0 skips`.
App/com options disclose no stored credential descriptors and create actor-unbound challenges;
actor-bound descriptor results remain only in the ceremonies that require a known actor. TOTP
`REVOKED` remains terminal and the failure counter is bounded. No new Critical or High finding
was identified. This scan does not close external RP deployment, production worker topology,
provider delivery, or unresolved owner-mapping gates. Evidence:
`evidence/2026-09-22-final-adversarial-security-scan-P1Q2.md`.

### CF-010 closure amendment (2026-09-22)

`CF-010` is closed for the approved Base/Auth OIDC finalization contract. Auth remains ceremony-only;
the three surface-local Base authorization-transaction tables are the durable lifecycle authority.
They persist only result digest/generation/expiry and finalization references, never raw result or
authorization-code values. Auth-to-Base result transport is short-lived Valkey state and is read
only after server-side transaction validation; a valid result may be retried while its transport
TTL remains. The result generation is rechecked under the locked PostgreSQL transaction row before
the finalization block runs, so an older result cannot win after a newer result was issued.
PostgreSQL row locking makes Base Browser Session finalization idempotent and creates at most one
root Browser Session for the transaction.

Authorization-code aliases carry the transaction reference and exact OIDC binding. In the same
surface ticket-database transaction that creates or resolves the RP Session, Base atomically claims
`authorization_grant_redeemed_at`; a second alias or callback therefore cannot create or replace a
second RP Session. Valkey authorization-code consumption and family-link cleanup occur after the
durable database transaction and are transport cleanup rather than the grant authority. A Valkey
cleanup failure is not reported as distributed atomicity and does not return credentials from a
failed database transaction.

The closure does not claim immediate invalidation of already-issued Access JWTs, distributed ACID
across PostgreSQL and Valkey, live external RP registration/key deployment, or production/external
Tunnel verification. Those remain separately bounded operational or deployment checks.

The obsolete, unreferenced `BaseAuthAdmissionCoordinator.consume_result!` one-shot compatibility
method was removed after a repository-wide production call-site audit. The current OIDC result
POST uses `read_result!`; PostgreSQL transaction generation/finalization remains the durable
authority. The separate ceremony transaction `consume_result!` methods are unrelated and remain
unchanged. Focused verification passed with `162 runs / 774 assertions / 0 failures / 0 errors / 6
skips`; the unchanged full Rails suite passed with `11536 runs / 73426 assertions / 0 failures / 0
errors / 8 skips`. Evidence:
`evidence/2026-09-22-oidc-result-one-shot-retirement-U7V8.md`.

The remaining active security-document references to the retired Sign/Acme signed one-shot result
vocabulary were labeled as historical and linked to the current Base/Auth contract. This was a
documentation-only clarification; it did not introduce a signed-result API, alter CSRF behavior,
or change the Auth ceremony/session boundary. The same evidence records the affected documents.

The current checkout was then revalidated with the CF-010 focused set (`162 runs / 774 assertions /
0 failures / 0 errors / 6 skips`) followed by the full Rails suite (`11536 runs / 73429 assertions /
0 failures / 0 errors / 8 skips`). Evidence:
`evidence/2026-09-22-oidc-result-doc-boundary-recheck-W8X9.md`.

The unimplemented `OutageService` and `TokenEmergencyService` placeholders were also audited. No
production call site or approved state/authorization/audit contract exists, so neither was guessed
into existence or deleted. They are recorded as `NEXT_CYCLE / CONTRACT_UNDEFINED` in
`evidence/2026-09-22-placeholder-service-contract-audit-Y1Z2.md`.

### Auth ceremony and full-suite runtime revalidation (2026-09-22)

The previously environment-blocked Auth ceremony admission rotation tests now run against the
Compose-backed services. The public rotation, rollback, terminal-transition, and independent
connection concurrency contracts pass with `36 runs / 219 assertions / 0 failures / 0 errors / 0
skips`. The related first-party OIDC registry and local-keyset tests also pass together with one
worker (`13 runs / 220 assertions / 0 failures / 0 errors / 0 skips`).

One parallel full-suite run first exposed a single, non-reproduced `CORE_APP` private-key assertion
failure in the registry test. The failing file passed alone, the related registry/local-keyset
group passed with one worker, and a second unchanged full-suite run passed with `11536 runs /
73426 assertions / 0 failures / 0 errors / 8 skips`. The first failure is retained as an
unresolved parallel-test shared-state suspicion rather than hidden or treated as a production
failure; no tests were weakened or skipped. Evidence:
`evidence/2026-09-22-auth-ceremony-rotation-runtime-revalidation-S3T4.md` and
`evidence/2026-09-22-auth-ceremony-full-suite-revalidation-T4U5.md`.

### Latest final-suite and content-RP revalidation (2026-09-22)

After the local content-RP test cleanup, the Compose-backed checkout completed the final Rails
suite with `11529 runs, 73419 assertions, 0 failures, 0 errors, 8 skips`. The focused OIDC registry,
token-exchange, assertion, and surface-lookup set passed with `154 runs, 816 assertions`; the
read-only content route/API and registry set passed with `55 runs, 591 assertions`; and the final
test-only cleanup set passed with `107 runs, 476 assertions`. Targeted RuboCop and `git diff --check`
also passed. Evidence: `evidence/2026-09-22-content-rp-final-revalidation-H8J9.md`.

The static registry does not contain `docs_*`, `news_*`, or `help_*` OIDC clients, while the
read-only content routes and APIs remain available. The `side-rails-rp`, `sign-rp`, and
`base-rails-rp` shared browser registrations were retired from the local registry after a
surface-specific call-path and test audit. The local registry negative tests, face-specific realm
tests, callback, logout, token-exchange, and browser-flow tests now pass. `core-next-rp` remains a
local compatibility registration because the live `CoreRpBridge` still references it. External RP
registration/key retirement, deployed callers outside this repository, and the core-next bridge
data migration remain separate gates; this local slice does not claim those external gates closed.

The side-shared-client retirement slice then passed its focused contract set with `67 runs, 430
assertions, 0 failures, 0 errors, 0 skips`, targeted RuboCop and `git diff --check`, and a complete
Rails suite with `11530 runs, 73418 assertions, 0 failures, 0 errors, 8 skips`. A later full-suite
recheck exposed a false-positive assertion in the cross-realm OIDC logout redirect test: a short
state value happened to occur in a random CSP nonce. The test was narrowed to the public Inertia
props contract, the focused file passed with `7 runs, 37 assertions`, and the subsequent full
suite passed with `11530 runs, 73419 assertions, 0 failures, 0 errors, 8 skips`. The current local
Rails suite is therefore green; the earlier failure remains historical evidence of the test
observation defect. Evidence: `evidence/2026-09-22-side-shared-client-retirement-K1L2.md`,
`evidence/2026-09-22-full-suite-regression-recheck-E6F7.md`, and
`evidence/2026-09-22-final-local-quality-gates-G7H8.md`.

The initial local retirement attempt was rolled back after registry RED exposed broad legacy OIDC
test and flow-helper dependencies. A subsequent TDD slice completed the required surface-specific
mapping rather than using a blind substitution. The final local registry no longer returns
`sign-rp`, `base-rails-rp`, or `side-rails-rp`; `core-next-rp` remains only as the explicitly
retained bridge compatibility client. Evidence:
`evidence/2026-09-22-shared-client-retirement-audit-P3Q4.md` and
`evidence/2026-09-22-shared-client-retirement-final-Q5R6.md`.

The read-only test-database bridge inventory found zero `core-next-rp` rows in the three Core bridge
tables. This is not production evidence and does not authorize removing the legacy normalization
path or performing a backfill; the migration gate remains open.

### OOB OTP lifetime revalidation (2026-09-22)

The shared `CommonOtpPolicy::MAX_OOB_TTL` now makes the finite ten-minute upper bound explicit while
preserving the semantic distinction between authentication OTPs and signup contact-confirmation
OTPs. The public ceremony tests cover successful verification immediately before the ten-minute
boundary and rejection at the boundary. No workflow-ticket lifetime was shortened merely to satisfy
the OTP secret lifetime, and no dry-run, preview, or simulation path was added.

The focused ceremony/delivery set passed with `15 runs / 77 assertions / 0 failures / 0 errors / 0
skips`; the broader app/com signup OTP controller set passed with `47 runs / 298 assertions / 0
failures / 0 errors / 0 skips`; and the complete Rails suite passed with `11536 runs / 73426
assertions / 0 failures / 0 errors / 8 skips`. RuboCop, Ruby syntax checks, and `git diff --check`
also passed. The eight suite skips were pre-existing. Evidence:
`evidence/2026-09-22-oob-otp-lifetime-revalidation-M7N8.md` and
`plans/backlog/out-of-band-otp-lifetime.md`.

This closes only the repository-owned OOB OTP lifetime contract. The accepted email transport
deviation, external delivery/provider receipt, and any separate notification retry/permanent-failure
contract remain independent boundaries.

### Backend transport and CSRF contract revalidation (2026-09-22)

The application-side backend transport guards remain present: production PostgreSQL configuration
requires `verify-full`, and production Valkey responsibility URLs require `rediss://`. The focused
Valkey/settings/environment/database configuration set passed with `28 runs / 174 assertions / 0
failures / 0 errors / 0 skips`. Provider values and live TLS handshakes remain deployment checks;
no external endpoint was contacted. Evidence:
`evidence/2026-09-22-backend-transport-tls-revalidation-N8P9.md`.

The historical public-controller CSRF plan named controller classes that are absent from the current
tree. It is now marked `STALE_REQUIREMENT`; the active replacement is the surface-controller and
repository-wide Rails 8.2 strategy inventory. Base/Auth public boundary, explicit strategy, and
approved exception tests passed with `20 runs / 38 assertions / 0 failures / 0 errors / 0 skips`.
No Rails CSRF protection was weakened, and no production route/controller was added. Evidence:
`evidence/2026-09-22-csrf-public-boundary-revalidation-Q1R2.md`.

### F8 discoverable Passkey client cleanup (2026-09-22)

The app/com direct Passkey contract is implemented as an anonymous discoverable ceremony: options
do not select an account or return real credential descriptors, and verification resolves the
surface-local credential by assertion credential ID before applying the existing public-key, UV,
RP/origin, sign-count, credential-state, owner-state, verified-PII, rate-limit, Turnstile, and
session checks. App/com registration requires discoverable credentials; org normal, Emergency, MFA,
and Step-Up remain actor-known ceremonies.

The current app/com pages use the React panels and do not submit identifiers. A repository-wide
reference audit found an unreferenced legacy Stimulus controller and its tests that still required
and submitted an identifier. Those obsolete files were removed rather than retained as a
compatibility path. The actor-bound descriptor helper remains only for actor-known ceremonies that
require it. Evidence: `evidence/2026-09-22-passkey-legacy-client-retirement-D8E9.md`.

The post-cleanup cross-surface review found that the shared React panel ignored the server-provided
field for org Emergency. That actor-known flow therefore rendered no identifier field and submitted
an empty identifier even though the Rails contract required one. A public UI test reproduced the
failure; the panel now renders and submits the provided field for actor lookup ceremonies while
leaving the app/com null-identifier path unchanged. The related frontend contract set passed with
121 tests, the org Emergency Rails controller set passed with 10 runs / 53 assertions, and the
frontend full suite passed with 84 files / 1,036 tests. Evidence:
`evidence/2026-09-22-passkey-legacy-client-retirement-D8E9.md`.

The affected Rails WebAuthn regression set passed with 70 runs / 328 assertions, and the frontend
Passkey/sign-in set passed with 4 files / 121 tests after the correction. Frontend typecheck, lint,
format check, and the complete frontend suite passed. No external credential registration or
database reset was performed.

### First-party screen-hint neutrality revalidation (2026-09-22)

The three current first-party Base browser RPs (`core-app`, `core-com`, and `core-org`) were
retested through the public OAuth authorization endpoint with both `screen_hint=signup` and
`screen_hint=signin`. Each request remains a neutral `authentication` transaction and admission;
Auth's internal sign-in/sign-up ceremony routes remain available as separate capabilities. The
deprecated `core-next-rp` compatibility client retains its explicitly bounded legacy behavior until
its bridge migration gate is complete; this is not a first-party RP contract. The focused set passed
with `42 runs / 243 assertions / 0 failures / 0 errors / 0 skips`, and the subsequent full Rails
suite passed with `11531 runs / 73411 assertions / 0 failures / 0 errors / 8 skips`. Evidence:
`evidence/2026-09-22-first-party-screen-hint-neutrality-V1W2.md`.

The shared first-party RP initiator was then tightened by removing its unused `screen_hint`
keyword and query emission. This prevents a future Core/Side/Edit caller from restoring the
retired RP-level sign-in/sign-up choice through the common browser-flow helper. The TDD RED run
observed the obsolete query parameter; the focused SSO/browser-flow set then passed with
`35 runs / 434 assertions / 0 failures / 0 errors / 0 skips`, followed by a full suite of
`11531 runs / 73409 assertions / 0 failures / 0 errors / 8 skips`. Auth internal ceremony routes
and the explicitly retained `core-next-rp` compatibility branch were not changed. Evidence:
`evidence/2026-09-22-screen-hint-emission-removal-X3Y4.md`.

### Historical OIDC document boundary revalidation (2026-09-22)

The local application and registry search found no remaining production Ruby/configuration call
site for `sign-rp`, `base-rails-rp`, or `side-rails-rp`. A small set of superseded ADRs and
architecture/security references still contained historical client statements without an equally
visible current-contract warning. Supersession notes now point those readers to
`adr/base-auth-ceremony-and-seven-rp-boundary.md` and explicitly prevent treating the historical
client list as a registration instruction. No route, registry, migration, external registration,
or key changed in this slice. Evidence:
`evidence/2026-09-22-oidc-historical-doc-boundary-M1N2.md`.

### Retention acceptance scope clarification (2026-09-21)

For FREQ-0064, retention deletion/anonymization safety is the existing explicit allowlist,
batch/scope, writer-clock, hold, enforcement, and kill-switch contract. `dry-run`, `preview`, and
`simulation` are not required capabilities for `RetentionPurgeJob`, and no interface, command,
service, audit event, or schema may be added solely for that purpose. Other plan references to a
read-only source-owner inventory (historically labelled a dry run), an isolated data-transformation
dry run, or an optional unsubscribe preview belong to those separate domains and do not add a
RetentionPurgeJob requirement.

Here, `bounded` means that each database selection/deletion operation is an explicit finite
`in_batches(of: batch_size)` scope. The public batch argument is validated to the inclusive `1..500`
range before any destructive work begins. A run may process successive eligible batches until its
current allowlisted scope is exhausted; this is not a requirement for a new total-row cap, preview
count, or simulation interface. The recurring retention entry supplies `batch_size: 500`, and
direct callers must use the existing explicit batch argument rather than an unbounded set-based
delete.

The contract does not infer archive eligibility. Data that must remain available under a separate,
approved archive or legal-retention policy is outside this Retainable purge contract until that
policy is represented by an explicit model-specific eligibility rule or hold. The current
`RETAINABLE_MODELS` allowlist contains no model with archive-specific columns or state; a future
archive-semantic model must not be added to the allowlist without that separate approval.

The remaining dry-run/preview wording in this plan is classified as follows:

| Reference | Classification | Contractual effect |
| --- | --- | --- |
| Former `Current source-to-owner dry-run inventory` label and its required report | Investigation/decision gate for the future Persona/Organization owner mapping; it is read-only inventory work, not retention execution. | It does not require or imply a `RetentionPurgeJob` preview API. |
| Isolated data-transformation dry run before encryption/backfill or other migration work | Safety gate for a separately approved data transformation. | It applies only when that transformation is approved; it does not add a retention purge interface. |
| Promotional unsubscribe preview | Optional, scoped to a separate bearer-capability UX and explicitly deferrable. | It is not a retention requirement and must not be implemented merely because the word `preview` appears here. |
| Historical `audit and dry-run` phase wording | Corrected for retention to `audit and retention-safety verification`; historical source-owner and transformation references retain their separate meanings above. | No new retention feature is implied. |

### Request-body limit status clarification (2026-09-22)

`CF-009` is closed for the Rails-owned JSON origin boundary. The existing
`RequestBodySizeLimit` Rack middleware is inserted before application routing and parameter
parsing, applies only to JSON and structured `+json` media types, rejects bodies above the
explicit 1 MiB limit, bounds reads when `Content-Length` is absent or unusable, rejects malformed
or negative declared lengths, and rejects compressed JSON without an approved bounded-decompression
contract. Its focused middleware and Core API tests, including exact-size, chunked oversize,
malformed-length, and unsupported-encoding cases, are recorded in
`evidence/2026-09-22-request-body-limit-revalidation-B3C4.md`.

No additional global limit, upload limit, compressed-input implementation, or external edge
configuration is required by this local closure. Cloudflare/proxy/server-ingress limits and
non-JSON upload contracts remain separate operational decisions and must not be represented as
verified merely because the Rails middleware is present.

### Current execution revalidation (2026-09-21; latest verification 2026-09-22)

The historical environment-blocker notes below remain historical records and are not the current
test status. In the earlier Compose-backed execution context, `primary` and `valkey-kvs` resolved,
the repository test preflight succeeded with the explicitly selected `.env.devcontainer.example`,
and the Rails suite was executable. The latest complete Rails result including the current
RP-entry cookie guard (2026-09-22) is `11,507 runs, 73,317 assertions, 0 failures, 0 errors, 5
skips`; the skips were pre-existing and no test was weakened or added solely to obtain that result.
The RP-entry result is recorded in `evidence/2026-09-22-rp-entry-authenticated-cookie-guard-Q7R8.md`;
the retry-window slice and its initial environment retry are recorded in
`evidence/2026-09-22-processor-notification-retry-window-H4J5.md`. A prior current-checkout runtime record is in
`evidence/2026-09-22-runtime-revalidation-J7K8.md`. Focused retention, authentication, OIDC/RP-session, WebAuthn,
TOTP, Core BFF, schema/retention, and historical blocked-slice groups also passed in that
Compose-backed revalidation environment. The occurrence migration and schema-load/seed
reconstruction proofs are recorded in
the dated occurrence evidence below. JavaScript tests/checks, repository-wide RuboCop, Zeitwerk,
Solid Queue configuration, the bounded test worker pickup, `git diff --check`, and Brakeman pass as
recorded in the dated evidence files. The worker smoke does not establish production topology or
external delivery.

Coverage remains below the repository's existing threshold and is intentionally not a release gate
for this revalidation, per the current task instruction; the threshold, exclusions, assertions, and
skips were not changed. Live Cloudflare/Tunnel, provider receipt/delivery/retry/permanent-failure,
external RP registrations and keys, and destructive/production data operations remain unverified or
blocked where the corresponding contract is not repository-owned. Those boundaries must not be
reported as complete merely because repository-side tests pass.

A later focused auth-state test attempt from a non-Compose process on 2026-09-22 stopped during
Rails schema maintenance because `primary` and `valkey-kvs` were not resolvable; no assertion ran,
and no fallback host or datastore was used. This does not supersede the Compose-backed passing
evidence above. The auth-state store, handoff, and token-exchange runtime checks must be repeated
from the core service before accepting a new database-backed change.

#### Earlier repository quality-gate revalidation (2026-09-22)

After the CF-010 cross-store finalization slice, an earlier Compose-backed checkout completed the
full Rails suite with `11529 runs, 73449 assertions, 0 failures, 0 errors, 8 skips`. The focused
authority schema/owner-inventory/security boundary set completed with `10 runs, 276 assertions,
0 failures, 0 errors, 0 skips`. JavaScript tests passed with 85 files and 1065 tests; the
repository JavaScript check passed. Brakeman reported 0 errors and 0 security warnings, and
repository-wide RuboCop inspected 4755 files with no offenses. Evidence:
`evidence/2026-09-22-integrated-hardening-quality-gates-M7N8.md`.

The later final local revalidation supersedes that run and also passed the Rails suite, Zeitwerk,
Brakeman, targeted RuboCop, and `git diff --check`; its exact current results are recorded in
`evidence/2026-09-22-final-local-quality-gates-G7H8.md`.

These repository-side results do not close the explicitly separate regional external RP
registration, authority owner cutover/backfill, production worker topology, provider receipt/
delivery/retry/permanent-failure, or live external-network gates.

#### Latest full-suite recheck (2026-09-22)

The first recheck exposed a false-positive test assertion: the cross-realm OIDC logout test searched
the complete HTML for the short value `xyz`, which can occur by chance in a random CSP nonce. The
test now checks the rendered Inertia props JSON instead. No production logout behavior changed.
The corrected Base com OIDC logout file passed with `7 runs, 37 assertions, 0 failures, 0 errors,
0 skips`, and the subsequent Compose-backed full Rails suite passed with `11530 runs, 73419
assertions, 0 failures, 0 errors, 8 skips`. Evidence:
`evidence/2026-09-22-full-suite-regression-recheck-E6F7.md`.

#### RP Session and refresh revalidation (2026-09-22)

The previously unverified repository-side RP Session/revocation slice was rerun against the
Compose-backed test services. The focused collection passed with `81 runs, 367 assertions,
0 failures, 0 errors, 0 skips`. It covers RP-session and parent-scope revocation, parent-first
locking, stateless Access JWT behavior, refresh rotation/reuse, realm/surface lookup, and
concurrent refresh attempts. This strengthens local evidence only; it does not close regional
external RP registration, production topology, authority-owner cutover/backfill, provider
delivery, or live external-network acceptance. Evidence:
`evidence/2026-09-22-rp-session-revocation-revalidation-D5E6.md`.

#### Historical follow-up: occurrence catalog reconstruction gap (2026-09-21)

- The isolated `test_occurrence_db` has migration marker `20260918150000`, but a direct read found
  zero `AUTH_CLIENT_*`, `AUTH_OPERATOR_*`, and `AUTH_VISITOR_*` reference rows. The subscriber
  tests remain green because they create representative catalog rows in their own test transactions;
  that does not prove a fresh schema-load/seed path has the required catalog.
- `db/seeds.rb` does not currently seed the JWT anomaly catalog. Calling the existing migration
  inserter from a runner while `OccurrenceRecord` is connected still made the migration inspect the
  primary connection and failed with `JWT anomaly reference tables must exist`; no connection
  override or monkey patch was added. A dedicated, approved occurrence-seed ownership decision is
  required before changing the seed path.
- `CF-013` was open for clean occurrence reconstruction and required catalog data at the time of
  this record. This historical evidence remains unchanged; the later resolution is recorded below.
  Evidence: `evidence/2026-09-21-occurrence-catalog-reconstruction-gap-V7W8.md`.

#### Resolution: occurrence catalog reconstruction (2026-09-21)

- The current JWT anomaly reference writer now accepts an explicit occurrence-database writer
  connection. It remains idempotent, preserves historical rows, fails closed for a partial schema,
  and keeps the fixed status IDs and current `AUTH_CLIENT`/`AUTH_OPERATOR`/`AUTH_VISITOR` catalog
  on the occurrence database. `db/seeds.rb` invokes that writer only when the occurrence tables
  exist, so an empty pre-migration bootstrap is still distinguishable from a partial schema.
- A clean migration-path verification created a uniquely named disposable test database, applied
  every `db/occurrences_migrate` migration, and observed five status rows and 78 current catalog
  rows. A separate schema-load-path verification loaded `occurrence_structure.sql`, observed zero
  business rows before seed, replayed the standard occurrence seed writer, and observed the same
  five status rows and 78 current catalog rows. Re-running the seed left the current catalog at 78.
- The existing test database retained its historical rows by design: after standard `db:seed` it
  contained 78 current catalog rows and 198 total JWT occurrence rows. No obsolete legacy rows were
  deleted or rewritten, and no production, development, shared, or external database was touched.
- Focused occurrence/catalog coverage passed with 34 runs / 205 assertions. The post-change full
  Rails suite passed with 11,500 runs / 73,294 assertions / 0 failures / 0 errors / 5 skips.
  `CF-013` is therefore closed for the occurrence catalog reconstruction and persistence boundary;
  notification delivery/receipt/retry/permanent-failure remains a separate contract and is not
  closed by this result. Evidence:
  `evidence/2026-09-21-occurrence-catalog-seed-reconstruction-P8Q9.md`.

## Historical handoff (2026-09-18; superseded by the current execution revalidation above)

The current branch is `feature`. The latest current-session handoff commit is `22afe6b4c`
(`Document credential redaction follow-up`), preceded by `033c5d88c` (named credential diagnostic
redaction), `df797f166` (current conflict evidence), `9c0c2db8f` (handoff status), `90f908a72`
(earlier handoff), `9fe0d5015` (redaction evidence), `63478758d`
(`Redact token-shaped observability messages`), `eff36467e` (Solid Queue environment evidence),
`a0b4cc140` (JWT reporter evidence), and `a8a0ef9f5` (JWT reporter failure-log sanitization). The
earlier JWT anomaly subscriber boundary is committed as `7314bc332`, after `57797f607`, `c9f5743ea`,
`172686b23`, `6930e7303`, `79324edf6`, and `842900c7e`; the explicit push queue, authority
inventory, and surface writer/lock slices remain recorded below. The latest verified local slices
after the initial baseline are the canonical surface writer-pool boundary (`3c8086cd8`), explicit
surface transactions (`a94eaccab`), deterministic authority-lock reuse (`bc8367aed` and
`89f9b1aa3`), principal-row locking during creation (`10c28f908`), administrative-lock eligibility
enforcement (`763a2153f`), trusted OIDC endpoint realms (`e72d4e18c`), and the ownership-row
deletion guard (`54d694eb9`), followed by fixed `ACTIVE` principal eligibility (`6e05e5100`). The
current working tree contains pre-existing README/Gemfile.lock/deleted-plan, browser-block
notification, and setup-file changes outside the task slice.

Historical focused creator, schema-contract, vocabulary, independent-connection app creation-race,
and surface RP lock-order runs are recorded as passing against their isolated services. In the
current session, the owner-inventory contract test, push enqueue test, JWT anomaly subscriber test,
and redactor Rails test were attempted with explicit test endpoints but stopped before assertions
because PostgreSQL was not listening. The owner report, push enqueue assertion, subscriber
persistence, and migration assertions therefore remain runtime-unverified. The JWT code and additive
catalog transition are committed, but CF-013 still blocks claiming complete authentication anomaly
persistence until the migration and runtime persistence are verified on a disposable occurrence
database. The next safe action is to restore disposable isolated databases and worker services, then
run the inventory, surface migration/rollback, catalog, and worker proofs. Until those checks pass,
the new authority migrations and creators remain unexposed and the old assignment/membership path
remains the current runtime path.

## Baseline

- Branch: `feature`
- Starting HEAD: `3ff5241c4b876c2c828e772c0fd289c8aae5f850`
- Upstream: `origin/feature`
- Working tree at inspection: pre-existing modification to `README.md`, and pre-existing deletions
  of `misc.md` and `refactor.md`; no staged or untracked changes.
- Rails: `8.2.0.alpha`; Ruby: `4.0.6`.
- Relevant gems: Solid Queue `1.7.0`, OpenTelemetry API `1.11.0`, SDK `1.13.0`, instrumentation
  `0.96.0`, Lograge `0.15.0`, Action Policy `0.7.7`, Noticed `3.0.0`, Shrine `3.9.0`.
- The bundled PostgreSQL adapter is available (`pg 1.6.3`). The test environment accepts the
  required isolated Valkey URL shape, but the Rails test suite cannot connect to the configured
  PostgreSQL host `primary`; no isolated PostgreSQL/Valkey services are available in this session.
  The non-Bundler preflight script also cannot load `pg` when invoked with the system Ruby. No
  database reset, migration, worker, or external delivery was attempted.

## Phase 1 — Vocabulary and interface boundaries

Commit `c34b1ee40` completed the mechanical naming slice without an alias constant or a behavior
switch:

- `Persona` is now the common Ruby interface concern. The app concrete model is `ClientPersona`,
  explicitly mapped to the existing `personas` table. `Individual` and `Agent` remain their
  surface-local concrete implementations.
- `Organization` is now the common Ruby interface concern. `Enterprise`, `Company`, and `Bureau`
  retain their existing tables and public-ID behavior. The legacy org-principal model is
  `OperatorOrganization`, explicitly mapped to `organizations` and kept separate from the new
  authority graph.
- RP binding associations and surface-local assignment/membership associations now name their
  concrete classes explicitly where Rails inference would resolve the former concrete constants.
  Existing persisted column names, route vocabulary, assignment keys, and protocol membership names
  were preserved.
- The old `Account` and `Collective` concern constants and the old concrete `Persona` and
  `Organization` class constants were removed. No `Persona = ClientPersona` or
  `Organization = OperatorOrganization` compatibility alias was introduced.
- `zeitwerk:check`, Ruby syntax checks, and RuboCop passed. The authority vocabulary regression test
  now passes when run with the available isolated test services; the full suite still depends on the
  repository's complete test-database provisioning.

This phase does not claim that the existing RP assignment/membership graph is an ownership or RBAC
implementation. The semantic RP/principal bases now inherit one canonical writer boundary per
surface, so authority operations can use one physical pool without collapsing domain interfaces. The
next safe slice is app-only surface-local ownership/grant persistence and policy contracts, preceded
by an isolated database rollback/concurrency proof.

## Phase 2A — Surface-local authority schema and creation foundation

The current branch contains the explicit 33 authority tables plus one surface-local principal lock
table per surface, with concrete model classes and associations. The table shape is documented in
`docs/architecture/persona-organization-authority.md` and contains no shared/polymorphic authority
store. The six explicit creators enforce concrete actor/owner identity, fixed `ACTIVE` principal
status, active principal access gates, active RP binding, and the adopted 10 Persona / 2
Organization ownership limits. They create the resource and owner row in one canonical surface
writer transaction after acquiring the surface-local lock row and re-reading the locked principal;
they do not create implicit grants. The lock acquisition passes only the unique principal key to
`create_or_find_by!` and obtains the row lock afterward, so its retry cannot be defeated by
timestamp attributes or a Ruby uniqueness validation.

All six ownership models now reject an independent Active Record `destroy`; an ownership transfer
must update the existing row and advance its revision. This is an application-layer guard only: the
future transfer/lifecycle operations, migration constraints, and runtime database proof still need
to establish the complete invariant, and raw SQL deletion is not represented as supported behavior.

This is a foundation slice, not an authorization cutover. Existing assignment/membership paths
remain the current runtime behavior until a verified owner inventory, lifecycle state contract,
connection rollback proof, and policy integration are complete. The migrations are intentionally
schema-only and have not been run in this session. Focused creator and app race tests pass; broader
migration, rollback, and cutover proof remains blocked by CF-002/CF-003.

## Phase 0 evidence-backed inventories

These inventories separate facts observed in the current checkout from target decisions that are not
yet safe to enable. Counts that require a live database are intentionally marked `UNRUN` rather than
inferred from model files or historical reports.

### Rename and reference matrix

| Current symbol / concern                                         | Current persistence and meaning                                                                                                                                                                                                                                                                                                                                                   | Adopted target                                                                                                        | Safe current-cycle action                                                                                                     |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `Account` concern                                                | `app/models/concerns/account.rb` is included by concrete `Persona`, `Individual`, and `Agent`; it exposes membership/collective helpers.                                                                                                                                                                                                                                          | Common `Persona` interface concern.                                                                                   | Do not rename while the concrete `Persona` constant still owns `personas`; prepare a reference matrix first.                  |
| `Collective` concern                                             | `app/models/concerns/collective.rb` is included by `Enterprise`, `Company`, and `Bureau`; it validates `name`/`title`.                                                                                                                                                                                                                                                            | Common `Organization` interface concern.                                                                              | Do not rename while the concrete `Organization` model and unrelated hierarchy code remain active.                             |
| `Persona`                                                        | `app/models/persona.rb` is a concrete `AppRpRecord`; table `personas`; required unique `client_identity_id`; assignments, memberships, and Avatar binding.                                                                                                                                                                                                                        | `ClientPersona`, same physical table, explicit table/class mappings.                                                  | No alias constant or class rename in this cycle.                                                                              |
| `Individual`                                                     | `app/models/individual.rb` is a concrete `ComRpRecord`; table `individuals`; required unique `visitor_identity_id`; assignments/memberships.                                                                                                                                                                                                                                      | Keep `Individual` as the com Persona implementation.                                                                  | No behavior change.                                                                                                           |
| `Agent`                                                          | `app/models/agent.rb` is a concrete `OrgRpRecord`; table `agents`; required unique `operator_identity_id`; assignments/memberships.                                                                                                                                                                                                                                               | Keep `Agent` as the org Persona implementation.                                                                       | No behavior change.                                                                                                           |
| `Enterprise` / `Company` / `Bureau`                              | Concrete resource models with tables `enterprises`, `companies`, and `bureaus`; each includes `Collective`, has units, and has memberships.                                                                                                                                                                                                                                       | Keep concrete names as app/com/org Organization implementations.                                                      | No new ownership tables until source-owner mapping is complete.                                                               |
| `Organization`                                                   | `app/models/organization.rb` is a concrete `OrgPrincipalRecord` over legacy `organizations`; its schema comments use the historical `org_principal` migration name, while `config/database.yml` maps both `db/org_principals_migrate` and `db/org_zenith_migrate` into the current `org_zenith` connection. It has optional `operator_id`, hierarchy links, and workspace status. | `OperatorOrganization` mapping for the legacy resource; `Organization` must become the interface.                     | Treat it as a separate legacy resource within the org surface; do not replace the constant or migrate the table mechanically. |
| `ClientIdentity` / `VisitorIdentity` / `OperatorIdentity`        | RP/IdP binding records with issuer/subject/audience and one current resource association (`persona`, `individual`, or `agent`).                                                                                                                                                                                                                                                   | Remain RP/IdP bindings, not RBAC principals.                                                                          | Do not use them as new authority-table grantees.                                                                              |
| `PersonaAssignment` / `IndividualAssignment` / `AgentAssignment` | Surface-local assignment rows currently grant an RP Identity access to a concrete resource; active pair uniqueness is DB-enforced.                                                                                                                                                                                                                                                | Existing assignment protocols require deliberate retirement after new Client/Visitor/Operator authority is validated. | No dual authority path or automatic conversion.                                                                               |
| `PersonaMembership` / `IndividualMembership` / `AgentMembership` | Surface-local resource memberships connect the concrete Persona implementation to an Enterprise/Company/Bureau and unit; they are not proven ownership rows.                                                                                                                                                                                                                      | Organization relationships remain separate from fixed ownership/RBAC relations.                                       | Do not infer owner or create grants from membership.                                                                          |

The physical table names for the six adopted resource implementations are therefore preserved for
the planned cutover: `personas`, `enterprises`, `individuals`, `companies`, `agents`, and `bureaus`.
The legacy `organizations` table remains a separate org-principal resource until its consumers and
mapping are approved. `Persona = ClientPersona` and `Organization = OperatorOrganization` aliases
are explicitly prohibited because they would hide the collision instead of migrating references.

### Current source-to-owner inventory (separate read-only decision gate)

| Surface / resource        | Current owner-like source                                                                                                 | What the source actually proves                                                                                                             | Migration status                                         |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| app `Persona`             | `personas.client_identity_id`, unique and non-null; `ClientIdentity` has one `persona`.                                   | One RP binding is linked to one concrete resource; it does not prove that the linked `Client` is the adopted owner principal.               | `BLOCKED`; isolated inventory completed with zero rows; authoritative source data remains absent. |
| app `Enterprise`          | No owner column. `PersonaMembership` links Personas to an Enterprise and unit; `primary` applies to a Persona membership. | Membership/primary state is not a single owner relation.                                                                                    | `BLOCKED`; isolated inventory completed with zero rows; never auto-promote a membership or first row. |
| com `Individual`          | `individuals.visitor_identity_id`, unique and non-null; `VisitorIdentity` has one `individual`.                           | One RP binding is linked to one concrete resource; it does not prove an adopted `Visitor` owner row.                                        | `BLOCKED`; isolated inventory completed with zero rows; authoritative source data remains absent. |
| com `Company`             | No owner column. `IndividualMembership` links Individuals to a Company and unit.                                          | Membership/primary state is not a single owner relation.                                                                                    | `BLOCKED`; isolated inventory completed with zero rows; no owner guess. |
| org `Agent`               | `agents.operator_identity_id`, unique and non-null; `OperatorIdentity` has one `agent`.                                   | One RP binding is linked to one concrete resource; it does not prove an adopted `Operator` owner row.                                       | `BLOCKED`; isolated inventory completed with zero rows; authoritative source data remains absent. |
| org `Bureau`              | No owner column. `AgentMembership` links Agents to a Bureau and unit.                                                     | Membership/primary state is not a single owner relation.                                                                                    | `BLOCKED`; isolated inventory completed with zero rows; no owner guess. |
| legacy org `Organization` | Nullable `organizations.operator_id` plus legacy hierarchy and `user_organizations`.                                      | A legacy operator reference may exist, but its principal/table/approval semantics are not equivalent to the adopted Operator ownership row. | `BLOCKED`; isolated inventory completed with zero rows; consumer and authoritative data inventory remain required. |

The separate read-only source-owner inventory run must report counts and opaque identifiers for
missing owners, multiple candidates, disabled principals, cross-surface mismatches, duplicate
public IDs, and inconsistent assignments. This is an investigation gate for the unapproved
Persona/Organization authority cutover, not a RetentionPurgeJob mode or API. The latest isolated
run completed with an applied schema but zero resource rows, so it cannot supply an owner mapping.
There is no safe basis to select the first assignment, promote an administrator, or silently skip
an ambiguous row.

The classification contract is now covered by a disposable-data regression across all three
direct surfaces: inactive identity bindings and missing principals are classified without exposing
database-local identifiers. This strengthens the read-only tool only; the current real inventory
still has zero rows, so owner mapping and authority cutover remain blocked. Evidence:
`evidence/2026-09-23-owner-inventory-contract-X4Y5.md`.
The same regression also verifies across app/com/org that multiple or active organization
memberships remain `membership_not_ownership` candidates requiring `manual_review`; no membership
is promoted to an owner.

### Connection and transaction inventory

| Boundary                            | Current abstract base / database                                                                                                                               | Observed relationship                                                                                            | Transaction conclusion                                                                                           |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| app resource and RP binding         | `AppRpRecord` → shared `AppZenithRecord` writer pool → `app_zenith` / replica                                                                                  | `ClientPersona`, `Enterprise`, `ClientIdentity`, assignments, and memberships use app-specific semantic classes. | Source-level pool sharing is explicit; runtime rollback proof is still required.                                 |
| app principal                       | `AppPrincipalRecord` → shared `AppZenithRecord` writer pool → `app_zenith` / replica                                                                           | `Client` uses the principal hierarchy while resources use RP hierarchy.                                          | Semantic bases remain separate, but authority transactions have one canonical writer pool; DB proof is unrun.    |
| com resource and RP binding         | `ComRpRecord` → shared `ComZenithRecord` writer pool → `com_zenith` / replica                                                                                  | `Individual`, `Company`, `VisitorIdentity`, assignments, and memberships use com-local semantic classes.         | Source-level pool sharing is explicit; runtime rollback proof is still required.                                 |
| com principal                       | `ComPrincipalRecord` → shared `ComZenithRecord` writer pool → `com_zenith` / replica                                                                           | `Visitor` remains a separate principal hierarchy.                                                                | Semantic bases remain separate; DB proof is unrun.                                                               |
| org resource and RP binding         | `OrgRpRecord` → shared `OrgZenithRecord` writer pool → `org_zenith` / replica                                                                                  | `Agent`, `Bureau`, `OperatorIdentity`, assignments, and memberships use org-local semantic classes.              | Source-level pool sharing is explicit; runtime rollback proof is still required.                                 |
| org principal / legacy organization | `OrgPrincipalRecord` → shared `OrgZenithRecord` writer pool → `org_zenith` / replica; both legacy and org-zenith migration paths use that configured database. | The legacy hierarchy is a distinct domain/resource contract, not a distinct database authority.                  | Keep it separate by model/table semantics; require one-writer rollback proof and no cross-surface FKs.           |
| Chronicle and signals               | `ChronicleRecord`, `AppSignalRecord`, `ComSignalRecord`, `OrgSignalRecord`                                                                                     | History and notifications use separate database connections.                                                     | Source mutation and history/notification writes are not one ACID transaction; preserve the documented crash gap. |
| Solid Queue                         | `config/database.yml` queue connection / dedicated queue DB                                                                                                    | Worker state is infrastructure state, not surface authority state.                                               | Enqueue-after-commit is delivery, not business-state proof; runtime integration remains unrun.                   |

Before any accepted transfer, quota, closure, or grant mutation, an isolated PostgreSQL test must
prove the actual connection identity, rollback across every participating surface-local row, and a
deterministic lock order. Base class names and identical database names are insufficient evidence.

### Encryption and scrub inventory

| Data                                                     | Current state                                                                                                                                                                                             | Adopted target / required verification                                                                                                    | Current decision                                                                         |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `Persona.moniker`, `Individual.moniker`, `Agent.moniker` | String columns; model declarations do not currently call `encrypts`.                                                                                                                                      | Non-deterministic Active Record Encryption, bounded plaintext validation, no name search/order dependency, restartable backfill.          | `BLOCKED` until key-scoped isolated migration design and dependency search are complete. |
| `Enterprise.name`, `Company.name`, `Bureau.name`         | Non-null string columns with empty-string defaults in the existing model-layer migrations.                                                                                                                | Non-deterministic Active Record Encryption with ciphertext-capable text storage and validated cutover.                                    | `BLOCKED`; no schema or key change made.                                                 |
| Legacy `Organization.name`                               | Org-principal legacy string; not one of the adopted six encrypted fields.                                                                                                                                 | Do not encrypt merely because the old class is named Organization; inventory separately.                                                  | Deferred with legacy owner mapping.                                                      |
| Existing contact/credential fields                       | Email/telephone/birthdate/credential models already use encryption or status/revocation protocols; `WithdrawalPersonalDataAnonymizer` currently handles Client/Visitor contact and credential paths only. | Extend only after per-model keep/replace/revoke/delete inventory; do not claim complete erasure or alter Operator deletion in this slice. | `BLOCKED`; current anonymizer is not the adopted complete scrub contract.                |
| Jobs/logs/audit                                          | Existing filtering/encrypted payload boundaries exist, but touched serializers and exception/job surfaces require synthetic-secret capture tests.                                                         | No plaintext names, secrets, tokens, cookies, or snapshots in logs, jobs, Chronicle, or evidence.                                         | No new data exposure introduced; capture suite remains unrun.                            |
| Retention clocks                                         | `discarded_at`, `purged_at`, `withdrawal_started_at`, `deactivated_at`, `withdrawn_at`, and `terminated_at` are used by existing concerns/jobs with different meanings.                                   | A distinct closure cycle must own the 1-hour/7-day/31-day decisions; `purged_at` must not be repurposed.                                  | `BLOCKED`; no lifecycle reinterpretation or destructive execution.                       |

This inventory is a Phase 0 design record, not a declaration that encryption/backfill/scrubbing has
been implemented. Any data transformation requires a separate restartable task, isolated dry run,
approval gate, and explicit rollback limitations.

### Lock and transaction design gate

The proposed order for a future app vertical slice is: surface-local principal lock → concrete
resource lock → ownership/grant/request rows in stable key order → quota re-read → domain mutation →
source commit → Chronicle write/recovery path. The com and org slices must use their own concrete
classes and connections; the order must be proven independently. This is a design gate only. No
generic lock manager, authority table, cross-surface transaction, or retry loop was added.

### Phase 7 source-owner inventory sub-slice (2026-09-18)

- Purpose: establish a read-only, surface-local inventory before any authority backfill or runtime
  cutover. The inventory must distinguish an RP binding or membership from an adopted owner and must
  never select a resource owner automatically.
- Current state: `ClientPersona`, `Individual`, and `Agent` have legacy RP-identity bindings;
  `Enterprise`, `Company`, and `Bureau` have membership relationships but no proven single owner.
  The new authority migrations are authored but have not been enabled for cutover. The isolated
  test inventory reports an applied schema with zero resource rows; an explicit development
  inventory reports four local rows classified as two `inactive_principal` and two
  `membership_not_ownership`. Neither result is authoritative production ownership data.
- Target state: `AuthorityOwnerMigrationInventory` covers all six concrete resource kinds and all
  three surfaces, reports the explicit authority-schema state, emits only public/opaque identifiers,
  classifies inactive or missing binding candidates, and marks every legacy source as
  `source_is_authoritative_owner: false`. The Rake task writes a report only; it has no apply mode.
- Dependencies: the existing concrete models and their surface-local connections; the authored
  authority table names; an explicitly isolated database for the eventual report run. No migration,
  owner backfill, lifecycle transition, or authorization cutover depends on this task's presence.
- Files/components: `app/queries/authority_owner_migration_inventory.rb`,
  `lib/tasks/authority_owner_inventory.rake`, and
  `test/queries/authority_owner_migration_inventory_test.rb`.
- Security: no guessed owner, membership-to-owner promotion, cross-surface lookup, arbitrary
  constantization, internal numeric ID output, or data mutation. A partial authority schema raises
  instead of being treated as ready. The report contains no names or credentials.
- Performance: resources and memberships are read in bounded batches with preloaded associations and
  one principal lookup per batch; the query does not issue one principal/membership query per
  resource. The eventual due-work and migration locks remain separate design gates.
- Tests: the focused inventory contract passes with `7 runs / 97 assertions / 0 failures / 0
  errors / 0 skips`; the related authority/schema/model regression set passes with `51 runs / 460
  assertions / 0 failures / 0 errors / 0 skips`; scoped RuboCop and `git diff --check` pass. The
  read-only Rake inventory runs against the isolated test topology and reports an applied schema
  with zero resource rows. No development or production datastore fallback was used.
- Documentation: this section records the implementation boundary; CF-003 remains blocked until
  authoritative source data and ambiguous rows are reviewed. Evidence records the runtime
  inventory and disposable-data classification coverage:
  `evidence/2026-09-23-owner-inventory-contract-X4Y5.md`.
- Completion criteria: static implementation checks pass, the isolated report produces counts and
  opaque identifiers for every surface/resource kind, an approved mapping resolves all ambiguous
  rows, and only then may a separate migration/cutover slice be designed. This sub-slice does not
  satisfy the owner-mapping or authorization-cutover gate by itself.

## Requirement ledger

| Requirement group                        | Repository evidence                                                                                                                                                                                                                                                                                                       | Current decision                                                                                                                                                                                                                                                                                   | Planned position                                                                                                                                         |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Dashboard reachability                   | Base root pages are the signed-in dashboards. They linked to identity, accounts/organizations, selector/switcher, and machine protocol endpoints. `BasePreferenceIndexPage` omitted calendar, clock, and currency. The identity hubs already expose surface-local human-facing children.                                  | GO for the missing intentional links and Preference hub links; remove machine protocol links and keep child pages under their hubs. Exclude mutation-only, callback, ceremony, and bearer-capability URLs.                                                                                         | Phase 2 implementation is complete; the selected repository runtime reachability subset and full Rails suite pass. Live deployment and external sign-out reachability remain unverified. |
| Identity hub                             | `base/app`, `base/com`, and `base/org` identity controllers already have surface-local sections and routes.                                                                                                                                                                                                               | GO for only verified omissions; no dashboard deep-link dump.                                                                                                                                                                                                                                       | Phase 2 audit and tests.                                                                                                                                 |
| Avatar                                   | Org Avatar has `show`, `edit`, `update`, and `destroy`; the current show props do not yet prove a show-to-edit link. The adopted Persona prompt explicitly excludes Avatar design/RBAC/lifecycle work.                                                                                                                    | Do not expand Avatar behavior in the Persona slice. Any navigation-only change must remain isolated and be re-evaluated against that exclusion.                                                                                                                                                    | Conflict CF-006; no enabling change until scoped.                                                                                                        |
| Promotional unsubscribe                  | Tokenized unsubscribe capability is a real bearer capability. No dashboard token embedding is permitted.                                                                                                                                                                                                                  | No real token in HTML. A preview is optional and must be a development/test-only read-only mechanism; otherwise defer.                                                                                                                                                                             | Phase 2 security review; likely deferred unless an existing preview is found.                                                                            |
| Offline page                             | Rails PWA offline routes exist on Base/Side/Auth/Palm surfaces and are GET-only framework routes.                                                                                                                                                                                                                         | Base app/com/org offline links are safe if exact helpers exist; never link the service worker as a human page.                                                                                                                                                                                     | Phase 2.                                                                                                                                                 |
| Solid Queue                              | The original `config/queue.yml` used YAML anchors and `queues: "*"`; recurring entries omitted explicit queue/priority/args and development/production sets differed. Concrete jobs and gem defaults have now been inventoried.                                                                                           | Exact environment mappings, workers, dispatcher/scheduler values, recurring entries, and retention isolation are implemented. `bin/jobs check` and a bounded test worker pickup pass; production worker topology, recurring scheduler execution, and provider delivery remain unverified.       | Phase 3 implementation is complete for repository configuration and test pickup; production runtime verification remains separate.                         |
| OTel correlation                         | `ActorSupport#set_current_observability` and Core Browser API installed `request.request_id` as `trace_id`; Lograge emitted only `request_id` and `host`.                                                                                                                                                                 | A small resolver now reads only a valid OTel SpanContext, Actor and Lograge use it, and request ID remains separate. OTel remains disabled in test and opt-in in development. The configured Lograge callable and Actor/invariant tests pass; deployed lifecycle remains outside this environment. | Phase 1 implementation complete; deployed/runtime collector verification remains unverified.                                                             |
| URL reserved characters                  | The current prompt allocates `@` only to Core Avatar handles and reserves `~`, `$` in URLs, `#`, `?`, `/`, `\\`, and `!`.                                                                                                                                                                                                 | Document and test the policy without introducing routes or changing Avatar. Search current routes/identifiers for conflicts first.                                                                                                                                                                 | Phase 4 documentation/static contract slice.                                                                                                             |
| RP/session hardening                     | Current repository uses surface-local principals, tokens, RP records, Valkey ceremony state, and multiple auth boundaries. The adopted contract requires parent-session/RP uniqueness, explicit realm/client binding, PostgreSQL revocation authority, and no request-time RP lookup.                                     | Security-critical; no guessed migration or compatibility fallback. Build an evidence-backed session/RP matrix and add regression tests before any schema change.                                                                                                                                   | Phase 5; blocked until connection/contract inventory is complete.                                                                                        |
| OTP/signup/enforcement/body limits       | Existing ceremony, enforcement, request parsing, and rate-limit code is distributed across controllers, concerns, values, and jobs.                                                                                                                                                                                       | #841 guardrail bypass is fixed for contact-verified email/telephone tickets; the state machine and policies require the guardrail before checkpoint. Social callback completion remains its existing separate path. Other OTP/body-limit claims require path-specific evidence.                    | Phase 5, separate vertical slices; guardrail sub-slice implemented.                                                                                      |
| Expired signup cleanup                   | `SignUpTermination` and `SignUpArtifactCleanup` already provide the domain boundary; no expiry sweep was wired at the historical reference.                                                                                                                                                                               | `SignUpExpiryJob` now re-discovers expired app/com flows on `retention`, delegates terminalization and cleanup, and is explicitly scheduled in development/production. Request-time expiry remains authoritative. A stale-row interleaving proof now confirms that a completed flow cannot be terminalized from an older instance; bounded worker pickup, production worker topology, and exact live completion/expiry concurrency remain unverified. | Phase 3 implementation is verified for the repository-side stale-row contract; production runtime and full worker race verification remain separate.                                    |
| Chronicle/audit/retention                | Chronicle and fallback writers exist across DB boundaries; retention uses explicit model lists and cross-database cleanup.                                                                                                                                                                                                | Preserve accepted non-atomic audit gap; no new transactional outbox. Retention purge disposition is `ACCEPTED_AS_EXISTING_IMPLEMENTATION`: the existing retention safety contract is explicit, allowlisted, batch/scope-bounded, writer-clock based, hold-aware, enforcement-aware, and stoppable by the kill switch. It does not infer archive eligibility; models with separate archive/legal-retention semantics remain outside the allowlist until an approved model-specific rule or hold exists. No dry-run or preview is required. | Phase 5/6 audit and retention-safety verification slices; Retention blocker for the dry-run interpretation is CLOSED. Notification delivery/receipt/retry/permanent-failure remains an independent contract. |
| Persona/Organization vocabulary          | Current concrete `Persona`, `Individual`, and `Agent` include `Account` and reference RP Identity records. Current `Organization` is a separate org-principal hierarchy model; `Enterprise`, `Company`, and `Bureau` include `Collective`. Existing assignment/membership tables use identity and resource-specific keys. | The adopted rename/interface contract is a major migration, not a mechanical rename. It is blocked for enabling until the complete rename/reference matrix, source-owner mapping, schema proposal, and serialization/cutover plan are reviewed.                                                    | Phase 7, after independent safe slices.                                                                                                                  |
| Authority tables/RBAC/ownership/transfer | The Phase 2A source now explicitly authors 33 concrete authority tables plus three surface-local principal lock tables. Existing assignment/membership graph is not equivalent and remains the runtime path.                                                                                                              | The schema foundation and unexposed creation contracts are GO for static verification; ownership rows also reject independent Active Record deletion. Authorization cutover, transfer acceptance, lifecycle gates, and owner backfill remain blocked.                                              | Phase 2A foundation now; policy/cutover in Phase 7/8.                                                                                                    |
| Lifecycle/scrub/encryption               | Existing principal models use `deactivated_at`, `discarded_at`, `purged_at`, `terminated_at`, and withdrawal concerns; current anonymizer inventory is narrower than the adopted scrub contract and Operator deletion requires review.                                                                                    | Do not reinterpret existing clocks or run destructive deletion. First inventory exact attributes, holds, jobs, and backup limits; then implement reversible decision state and idempotent scrub jobs.                                                                                              | Phase 6/7; destructive execution remains blocked.                                                                                                        |

## Implementation units

### Phase 1 — OTel/request correlation semantics

- Purpose: keep Rails request correlation separate from W3C/OpenTelemetry trace correlation.
- Current state: Rails standard request ID behavior is present; two application paths substituted
  `request.request_id` for `trace_id`; Lograge lacks trace/span fields; consent currently changes
  technical correlation semantics.
- Target state: `request_id` comes from Rails request handling, while `trace_id` and `span_id` come
  only from a valid current OTel `SpanContext`. Missing/invalid OTel context yields absent values.
- Dependencies: installed OTel API; no SDK enablement change.
- Likely files: `app/controllers/concerns/actor_support.rb`,
  `app/controllers/concerns/core_browser_api_boundary.rb`, a small `app/resolvers`/`app/values`
  value boundary, `config/initializers/lograge.rb`, focused Minitest files, and the two existing
  observability documents.
- Security: no request ID authentication meaning, no token/PII logging, no global/thread state, no
  analytics-consent coupling, and no request-ID middleware replacement.
- Performance: one current-span read per relevant lifecycle/log event; no DB/cache/network work.
- Tests: valid and invalid SpanContext, consent on/off, missing OTel, request-ID independence,
  Lograge field presence/absence, and request-to-request non-leakage.
- Documentation: amend the existing Alloy routing ADR and observability boundary.
- Completion: all known substitution patterns are gone, static/standalone checks pass, and
  OTel-disabled behavior remains nil/absent without SDK startup. The current Compose-backed Rails
  request/runtime tests pass; deployed collector lifecycle remains unverified.

### Phase 2 — Base dashboard and domain-hub reachability

- Purpose: make implemented human-facing pages inspectable through intentional navigation.
- Current state: Base roots act as dashboards; Preference index is missing three existing screens;
  identity hubs are already richer than the dashboard and should remain the child hub.
- Target state: app/com/org Base dashboard roots link only to required high-level hubs and safe
  offline pages; Preference links to existing calendar/clock/currency screens; Identity remains the
  sole child hub for its verified self-service pages.
- Dependencies: exact current route helpers and Inertia props; no new routes or model changes.
- Likely files: three Base root controllers, `BasePreferenceIndexPage`, existing identity/avatar
  tests, and dashboard/preference test files. No Avatar lifecycle/RBAC redesign.
- Security: preserve surface controller boundaries, authorization, CSRF, context query parameters,
  and do not expose tokenized unsubscribe URLs or mutation endpoints.
- Performance: static props only; no additional model payloads or queries.
- Tests: controller/integration/Inertia props for all three surfaces, exclusion assertions, context
  preservation, and safe offline GETs.
- Documentation: update the existing navigation principle document/ADR if one exists; otherwise add
  the smallest repository-language-compliant reference.
- Completion: no route dump, no machine endpoint links, no duplicate child links on the dashboard,
  and all selected human pages are reachable through the intended hierarchy. The current
  Compose-backed repository runtime reachability tests pass; live deployment reachability remains
  unverified.

### Phase 3 — Solid Queue audit and explicit configuration

- Purpose: ensure every effective queue is consumed and every recurring task is explicit and valid.
- Current state: wildcard workers and YAML merges hide the effective mapping; jobs and gem jobs are
  not yet reconciled with recurring entries and worker capacity.
- Target state: development/test/production support is explicit, exact-match, queue-by-queue, and
  has documented worker/dispatcher/scheduler startup and retry behavior.
- Dependencies: complete enqueue/gem inventory, installed Solid Queue config semantics, DB/pool
  assessment, and no external production assumptions.
- Likely files: `config/queue.yml`, `config/recurring.yml`, environment/worker launch definitions,
  job queue declarations, operations docs, and evidence. Environment construction is verified by
  running the installed command and recording the result, not by adding a Minitest setup case.
- Security: no plaintext secrets in job arguments/logs; no auth/expiry decision waits for workers;
  no unbounded retries; no queue DB treated as business-state authority.
- Performance: isolate delivery/latency-sensitive work from retention/maintenance; evaluate
  process/thread totals against queue and business DB pools.
- Verification: parse the configuration during the static audit without anchors/wildcards/duplicate
  keys, resolve every concrete enqueue queue, validate class/args/schedule, run `bin/jobs check`,
  and run an isolated Solid Queue integration path where the environment permits it. Do not add a
  Minitest whose subject is Solid Queue environment construction.
- Documentation: per-job ledger, startup/recovery procedures, retention and reconciliation policy.
- Completion: exact queue-to-worker coverage is demonstrated statically; any externally deployed
  process and actual worker pickup remain explicitly unverified.

### Phase 4 — URL identifier policy and residual navigation review

- Purpose: prevent future URL syntax collisions and preserve surface-specific identifier meaning.
- Current state: route and identifier allocation must be searched against the current tree; Avatar
  is excluded from redesign.
- Target state: an English canonical policy documents the allocation and a current-tree route/
  identifier audit protects the reserved characters without adding a namespace.
- Dependencies: route/handle inventory.
- Likely files: existing URL/identifier docs or a single canonical reference, route/identifier
  invariant test if an existing test boundary is appropriate.
- Security/performance: reject parser-confusable identifiers before normalization; no new lookups or
  broad route matching.
- Tests: current-tree route and identifier search is recorded; no handle implementation in this
  Rails surface currently assigns a new reserved prefix.
- Completion: no implicit release of a reserved character.

### Phase 5 — Authentication/session/OTP/enforcement hardening

- Purpose: enforce the accepted Identity → Base Browser Session → RP Session contract and related
  OTP/realm/revocation/body-limit invariants.
- Current state: multiple auth boundaries, token records, Valkey ceremony state, and existing
  integrations require path-by-path tracing; current code is not evidence of the adopted contract.
- Target state: one explicit authority for issuance and scope, PostgreSQL-backed RP lifecycle
  checks, correct realm/client binding before side effects, bounded OTP/retry behavior, and
  effective body limits before parsing.
- Dependencies: complete current session/token/RP matrix, installed schema/connection facts, and
  explicit Before/After shape proposals for any persisted/API change.
- Likely files: auth/base controllers, token/RP operations/models, OTP values/operations,
  middleware, jobs, migrations only after approval, and security regression tests.
- Security: no cross-surface authorization, replay bypass, stale callback action, Redis revocation
  authority, or immediate-JWT-revocation overclaim.
- Performance: no per-request RP DB lookup or unbounded retries; measure lock/query changes.
- Tests: concurrent issuance/revoke/refresh, replay, realm mismatch before consumption, OTP races,
  request-size boundaries, and scheduler-stopped expiry decisions.
- Documentation: current session authority/realm/revocation ADR amendments and evidence.
- Completion: only verified sub-slices enabled; unresolved external RP acceptance remains explicit.

#### Implemented sub-slice: RP realm binding and non-overlapping RP sessions (2026-09-17)

- `Base::App::Oauth::*`, `Base::Com::Oauth::*`, and `Base::Org::Oauth::*` now bind the expected
  resource type from the controller class. Authorization-code realm mismatch is rejected before
  Valkey consumption; a missing or unknown endpoint realm is rejected before client authentication
  and code consumption; refresh mismatch is rejected before rotation; revocation rejects an
  authenticated client registered for another surface. Direct coordinator callers must provide the
  same fixed, allowlisted realm explicitly; the service does not infer it from payload or client ID.
- Same parent Browser Session plus same RP client cannot create a second unretired RP Session. The
  parent row is locked before child lookup, a loser is rejected, and an existing session's
  credentials are not overwritten.
- `oidc_access_token_max_expires_at` is authored as a nullable, surface-local migration column and
  updated monotonically before token response. A revoked row with unknown history remains occupied;
  known history retires at maximum `exp` plus the configured 30-second verifier leeway.
- Static syntax, lint, diff, and Zeitwerk checks pass. Database-backed realm, lock, migration,
  refresh/revoke race, and token issuance tests are blocked before assertions by the unavailable
  isolated PostgreSQL service (`primary` cannot resolve). The migrations were not executed.
- The seven-client versus JP/US regional RP-registration conflict remains `CF-007`; this slice does
  not change IDs, redirects, keys, external RP settings, or legacy-session migration.
- OIDC connection revocation is no longer cleared for every code exchange. The code's `issued_at`
  must be later than the stored connection `revoked_at`; old codes are rejected before consume and
  the writer-side recorder repeats the check under a row lock.
- Back-channel logout keeps exact registry matching and redirect refusal, and now requires HTTPS at
  the outbound connection boundary in production. The existing loopback HTTP convention remains
  available only outside production. The focused regression is recorded in
  `evidence/2026-09-18-oidc-backchannel-https-boundary.md`.
- `RpSession#mark_logout_status!` now uses the same parent-before-child writer lock as issuance,
  refresh rotation, expiry recording, and revoke. Its focused Rails test remains blocked by the
  isolated PostgreSQL/Valkey services; see `evidence/2026-09-18-rp-session-logout-state-lock.md`.

#### Implemented sub-slices: RP revocation, logout, and replay boundaries (2026-09-17)

- OIDC RP-session revoke and verified back-channel logout now delegate to the surface-local
  `RpSessionRevoker` for Nanoid RP Session SIDs. The child-only operation locks the Base Browser
  Session before the targeted RP Session on the writing connection, preserving sibling/parent
  isolation and the lock order used by exchange and refresh. Legacy UUID parent SIDs remain on the
  existing parent logout primitive. Back-channel logout records a successful child revoke after
  client-bound lookup, including when the refresh window has expired.
- OIDC token revocation no longer directly updates the RP-session row, and replay-linked cleanup is
  performed on the fixed realm's writer connection. The RP `sid`, client, and `jti` checks remain
  prerequisites; no Redis/Valkey revocation authority was introduced.
- Static syntax, lint, and diff checks pass. Focused Rails tests and SQL lock-order assertions are
  blocked before assertions by CF-002 (`primary` PostgreSQL cannot resolve). See
  `evidence/2026-09-17-rp-revoke-lock-order.md` and `evidence/2026-09-17-replay-writer-scope.md`.

#### Implemented sub-slice: Enforcement appeal decision and recovery boundary (2026-09-17)

- `EnforcementAppeal#submit!` and `resolve!` now commit appeal state before Chronicle delivery or
  Case-ending/release side effects. Approved resolution locks and rechecks the still-active Case
  before committing; a stale approved request is rejected without changing the appeal.
- `EnforcementReconciliationJob` now distinguishes active apply convergence from ended-Case
  convergence and rediscovers submitted, approved, and rejected appeals from their surface-local
  rows. Approved appeals retry Case ending/release before the `appeal_approved` event. Chronicle
  existence is checked on the writer under the Case lock, but the documented cross-database crash
  gap and lack of distributed exactly-once delivery remain.
- Regression tests cover committed rejected/approved decisions when the later audit or release
  operation fails, and ensure ended Cases do not enter the active apply convergence scope. Focused
  Rails execution is blocked before assertions by CF-002; syntax, RuboCop, and diff checks remain
  the available verification.

#### Implemented sub-slice: Sign-up OTP resend lock boundary (2026-09-17)

- `SignOtpCeremony#issue!` retains its fast cooldown check but repeats it after locking the bound
  contact row. A concurrent resend therefore cannot replace the stored OTP or reach the delivery
  adapter after another request has established the cooldown.
- A focused regression test proves the second check occurs inside the lock and that a locked
  cooldown does not store or deliver a new code. The available focused OTP/signup Rails set passes;
  the complete test topology and external delivery remain covered by CF-002.
- The existing app/com surface and OTP retention/delivery contracts are unchanged. No threshold,
  duration, or external provider behavior was changed.

#### Implemented sub-slice: OTP one-time consumption boundary (2026-09-17)

- Existing record-backed email and telephone callers now use
  `CommonOtp#verify_otp_code_and_consume`, which verifies, consumes a successful code, or increments
  a failed-attempt counter while holding the same record lock. The app sign-in paths use the
  optional pre-consumption eligibility check so an ineligible account does not consume a valid OTP.
- Registration, sign-in, enforcement-recovery, and withdrawal-reentry callers no longer perform a
  separate unlocked `verify_otp_code` followed by `clear_otp`; this closes the concurrent double-
  acceptance window without changing OTP policy values or delivery behavior.
- A focused test covers single-use consumption, failed-attempt serialization, and an eligibility
  rejection. The available OTP/signup regression set passes; an independent PostgreSQL concurrency
  and rollback proof remains required by CF-002.

#### Blocked slices: request-body limits and Auth/Base issuance (2026-09-17)

- The current tree has bounded readers for CSP reports and Apple notifications, but no repository-
  wide pre-parser limit and no approved per-endpoint size/media/streaming matrix. Cloudflare or an
  upstream edge is not inspectable evidence of origin enforcement. A guessed global limit could
  break valid uploads or protocol payloads, while a post-parse check would not address the stated
  risk. The affected work remains `CF-009` and is not enabled.
- The Auth OIDC-started branch now records only ceremony authentication evidence; it does not call
  `log_in`, rotate the Auth Rails session, or create a root Browser Session. Base remains the owner
  of Browser Session creation during the result/resume handoff. The complete Base-only issuer
  contract still lacked the fully verified browser binding, result generation, issuer/realm, AAL/AMR,
  session-limit, stale-result, and rollback semantics needed for a safe end-to-end relocation at
  the time of this historical review. The later CF-010 closure amendment supplies those
  boundaries; the earlier source-level blocker remains historical evidence and is not the current
  status.

#### Follow-up: Auth-side root-session authority regression (2026-09-21)

- The public OIDC browser-flow regression now asserts that the ClientToken count is unchanged
  immediately after the Auth-to-Base result handoff. The same flow verifies that Base creates the
  Browser Session only while resuming the authenticated authorization transaction.
- Focused verification passed with 13 runs / 119 assertions. The full Rails suite passed with
  11,500 runs / 73,296 assertions / 0 failures / 0 errors / 5 skips. RuboCop and `git diff --check`
  passed for the changed test. At that time this closed only the Auth-side root-session creation
  proof; the later CF-010 closure amendment supersedes the open-status wording for the approved
  Base/Auth finalization contract.
- Evidence: `evidence/2026-09-21-auth-base-root-session-regression-Y3Z4.md`.

#### Follow-up: real PostgreSQL authorization-transaction race proof (2026-09-21)

- The authorization-transaction concurrency regression now opts out of transactional fixtures,
  commits its setup rows, synchronizes both workers at a barrier, and checks out independent
  PostgreSQL connections from the Com ticket pool. The former future-based test could pass without
  proving that two real transactions contend on the same row lock.
- Focused verification passed with 8 runs / 44 assertions. The full Rails suite passed with 11,500
  runs / 73,296 assertions / 0 failures / 0 errors / 5 skips. The changed test has no RuboCop
  offenses. At that time this strengthened the transaction-state regression proof without closing
  the then-unresolved Base commit/code-issuance and cross-store failure semantics; those semantics
  are addressed by the later CF-010 closure amendment.
- Evidence: `evidence/2026-09-21-oidc-transaction-concurrency-test-R4S5.md`.

### Phase 6 — Lifecycle, Solid Queue scrub, audit, and retention safety

- Purpose: implement only the adopted lifecycle/scrub/hold/Chronicle behavior that is supported by
  current surface-local data and operational boundaries.
- Current state: withdrawal/retention/anonymizer/Chronicle paths exist but use different clocks,
  cross-DB behavior, and attribute inventories.
- Target state: persisted lifecycle decisions are synchronously security-effective; scrub work is
  idempotent, bounded, rediscoverable from current state, hold-aware, and never marks completion
  early.
- Dependencies: lifecycle and attribute inventory, connection participation proof, queue Phase 3,
  legal/retention policy status, and no destructive production operation.
- Likely files: lifecycle concerns/operations, surface-local jobs, retention/hold queries, Chronicle
  writers/fallbacks, encryption configuration/backfill tasks, tests, runbook/docs.
- Security: no reactivation after discard, no stale job restoring data, no hold bypass, no plaintext
  PII in logs/jobs/audit, and no false delivery/audit success.
- Performance: bounded batches, indexed due-work scans, no full-table generic purge, measured locks.
- Tests: commit/enqueue failure, rollback, stale cycle, hold race, partial retry, masked captures,
  cross-connection rollback, and no worker means no access extension.
- Completion: terminal state and cleanup semantics are proven in isolated test data; production
  erasure/backfill remains a separate approved runbook step.

#### Revalidation: approved reason-note encryption (2026-09-23)

The seven explicitly approved free-text encryption targets are already implemented with standard
non-deterministic Active Record Encryption: the three principal administrative lock notes,
`AccountAccessEvent.reason_note`, and the app/com/org enforcement-case `reason_note` fields. The
focused persistence test reads through Active Record and the raw writing-database column, passing
with `1 run / 28 assertions / 0 failures / 0 errors / 0 skips`; targeted RuboCop is clean. No
migration, key change, deterministic search contract, or backfill is required for this target.
Evidence: `evidence/2026-09-23-reason-note-encryption-recheck-A1B2.md`.

This `ALREADY_SATISFIED` result does not close the separate Persona/Organization name-encryption,
broader lifecycle scrub, or destructive retention gates, which still require an approved data
shape and operational contract.

### Phase 7 — Persona/Organization vocabulary and authority migration

- Purpose: migrate the existing concrete model graph to the adopted independent surface-local
  Persona/Organization interfaces and explicit Client/Visitor/Operator authority.
- Current state: concrete names and concerns overlap the adopted vocabulary, current resource rows
  reference RP Identity records, and assignments/memberships encode existing authority assumptions.
- Target state: interfaces are real concerns/contracts, concrete table mappings are explicit,
  authority tables are surface-local, one ownership row is enforced, roles are independent, and old
  authority paths are retired only after validated cutover.
- Dependencies: complete rename/reference matrix, read-only source-owner inventory, schema shape approval,
  connection/lock proof, authorization matrix, encrypted-name cutover, and migration approvals.
- Likely files: model/concern/association/policy/operation paths, surface-local migrations/models,
  selectors/jobs/GlobalID registries, fixtures/tests, docs and deployment runbook.
- Security: no alias constants, shared/poly tables, ownerless intervals, guessed owners, dual
  authority, or cross-surface principal confusion.
- Performance: indexed concrete FKs/reverse grants, no per-row authorization N+1, stable lock order.
- Tests: all minimum acceptance tests in the adopted prompt, starting with one app vertical slice
  then independent com/org slices.
- Documentation: data dictionary, RBAC/action matrix, migration/cutover/rollback stages.
- Completion: no partially enabled authority model; ambiguous existing data blocks cutover.

#### Ownership-row retention sub-slice (commit `54d694eb9`)

- Purpose: prevent an application transfer or lifecycle path from deleting the only ownership row
  and creating an ownerless interval.
- Current state: the six authored ownership models have concrete resource/principal foreign keys and
  unique resource constraints, but independent Active Record destruction was not explicitly
  rejected.
- Target state: transfer updates the existing ownership row under the future locked operation;
  direct model destruction is rejected, while terminal owner references remain available as inert
  retained data where the lifecycle contract requires them.
- Dependencies: the authored surface-local schema, the one-writer connection boundary, and future
  transfer/lifecycle operations. This does not enable the new authority graph or infer owners from
  existing assignments/memberships.
- Files/components: the six ownership models, `authority_schema_contract_test.rb`, and the authority
  architecture document.
- Security: a stale or unauthorized operation must not gain an ownerless transition by deleting the
  row; the guard does not authorize transfers and does not protect direct SQL outside the
  application contract.
- Performance: no query or index change; the callback is local to a destruction attempt.
- Tests: the focused model contract is authored; execution is blocked by CF-002. Transfer,
  lifecycle, rollback, and direct-database behavior remain unverified.
- The six transfer-request migrations now omit an empty-string `public_id` default. `PublicId`
  generates the required identifier at the model boundary, so a missing application value cannot be
  silently represented as a fake empty identifier. The static authority schema contract passes;
  migration execution and transfer runtime behavior remain blocked by CF-002/CF-003.
- `Acme::AccountQuotaPolicy` and `Acme::OrganizationQuotaPolicy` derive their counts from the
  surface-local ownership relation, intersect optional resource scopes with that set, count only
  explicit `active` lifecycle rows, and fail closed for an ineligible principal or missing lifecycle
  row. Unsupported concrete principals still fail closed. This does not switch selector/switcher
  act-as context or complete the family-wide consumer cutover.
- Documentation: the authority table contract and
  `evidence/2026-09-17-authority-ownership-retention.md` record the implemented boundary and its
  limits.
- Completion: static syntax/lint/diff checks pass and the change is locally committed; runtime
  database proof remains a prerequisite before exposing transfer or lifecycle routes.

#### Authority documentation consolidation (2026-09-18)

- The current database-placement guide now names the adopted concrete mappings, legacy
  `OperatorOrganization` boundary, surface-local `*_zenith` authority, and phase-gated cutover.
- The earlier proposed Acme Account / Organization ADR is now a concise superseded record pointing
  to the accepted naming ADR and the current authority implementation reference. No route, schema,
  or authorization behavior changed in this documentation-only slice.
- The current dictionary and Avatar/SNS references now separate the excluded legacy Avatar boundary
  from the authority foundation; no Avatar code or schema was changed.
- Evidence: `evidence/2026-09-18-authority-documentation-consolidation.md` and
  `evidence/2026-09-18-persona-avatar-documentation-boundary.md`.

### Phase 8 — Integrated verification and handoff

- Purpose: reconcile implementation, evidence, docs, conflicts, and deployment readiness.
- Current state: the bundled PostgreSQL adapter is available (`pg 1.6.3`). The Compose-backed
  PostgreSQL/Valkey services and complete primary test topology are available for local Rails
  verification when `.env.devcontainer.example` is selected explicitly. The non-Bundler preflight
  script still cannot load `pg` when invoked with the system Ruby; this is an invocation/tooling
  boundary, not the status of the Bundler-backed Rails suite. Production worker topology,
  external services, and live network acceptance remain separate.
- Target state: current-session tests, queue checks, frontend checks, static/security checks,
  coverage, and isolated integration verification are recorded separately as
  pass/fail/blocked/unverified.
- Dependencies: completed safe slices and restored test dependencies/isolated services.
- Likely files: dated flat evidence, conflict ledger, canonical docs/indexes, plan handoff.
- Security/performance: final adversarial review of trust boundaries, secrets, races,
  query/lock/batch measurements; no claims beyond executed evidence.
- Tests: repository commands appropriate to touched boundaries; no new permanent worker or test-only
  app behavior.
- Documentation: English only in repository prose; Japanese only in the conversational report.
- Completion: local commits contain only isolated task changes; no GitHub or external writes made.

## Current safe-slice state

1. Observability tests and resolver are present; static source scans, syntax checks, RuboCop, and a
   standalone valid/invalid SpanContext check pass. The focused resolver/Lograge/Actor/invariant
   suite passes with 40 runs / 110 assertions; deployed collector and full request lifecycle remain
   unverified.
2. Dashboard roots now expose only high-level human hubs and safe offline pages; Preference exposes
   Calendar/Clock/Currency; app Identity exposes its existing Sessions page; org Avatar has a
   navigation-only show-to-edit action. Machine protocol links were removed. The selected
   reachability subset passes with 110 runs / 2,957 assertions. The previously unavailable
   Valkey-backed sign-out notice path was revalidated in the Compose-backed test environment with
   the three Base surface sign-out controllers: 22 runs / 116 assertions / 0 failures / 0 errors /
   0 skips. The signed-in Menu/Primary section ordering and context propagation revalidation is
   recorded in `evidence/2026-09-22-dashboard-menu-links-revalidation-B8C9.md`; the sign-out notice
   revalidation is recorded in `evidence/2026-09-22-dashboard-signout-notice-revalidation-C4D5.md`.
3. Queue and recurring configuration is explicit, queue workers are exact, recurring task arguments
   are explicit, five ceremony purgers are isolated to `retention`, and `SignUpExpiryJob` is wired.
   OIDC delivery now distinguishes success, retryable failure, and permanent failure. Static config
   checks, `bin/jobs check`, and a bounded test worker pickup pass; production worker topology,
   recurring scheduler execution, and provider delivery remain unverified.
4. URL identifier policy is documented and linked from the documentation index; no route namespace
   was added.
5. Persona/Organization schema foundation is authored but not enabled. Do not execute migrations,
   backfill owners, enable grant/transfer routes, change lifecycle clocks, encrypt existing names,
   or perform destructive work until the blocked matrices and isolated database gates are complete.
6. RP Session browser-scope revocation now follows the parent-first, deterministic child-lock order
   used by token exchange. Child-scope revocation, OIDC token revocation, and back-channel logout
   use the same operation; the focused public-operation lock-order regressions pass. Independent
   PostgreSQL concurrency, rollback, worker execution, and external logout behavior remain
   unverified.
7. `CF-009` is closed for the Rails-side JSON body-size middleware and pre-parser boundary for
   #845. External edge and non-JSON contracts remain separate and unverified. `CF-010` is closed
   for the approved Base/Auth cross-store finalization contract; external RP registration/key
   deployment, issuer cutover, and live runtime acceptance remain separate gates and are not
   implied by that closure.
8. The JWT anomaly occurrence catalog now reproduces through both the full occurrence migration
   path and the schema-load plus standard-seed path. The current catalog has 78 rows and five fixed
   status rows in both clean paths; rerunning the seed is stable and historical rows are retained.
   `CF-013` is closed for catalog reconstruction and persistence. Notification delivery/receipt/
   retry/permanent-failure remains independent and is not closed by this slice.
9. The previously environment-blocked authentication, RP Session, OTP, authority, enforcement,
   queue, dashboard, and observability focused suites now run against the Compose-backed test
   services: 487 runs / 2,879 assertions /
   0 failures / 0 errors / 3 skips. This reopens local verification for those contracts without
   changing the external RP, provider, production-worker, Auth/Base issuer, or authority-cutover
   boundaries. Evidence: `evidence/2026-09-22-auth-otp-authority-revalidation-R5S6.md`.
10. The read-only `authority:owner_inventory` task now runs under Rails deprecation-as-error after
    replacing a deprecated connection accessor with `lease_connection`. Its isolated test run
    reports an applied schema but zero resource rows, so owner mapping and cutover remain blocked;
    it is not treated as evidence of a completed migration. Evidence:
    `evidence/2026-09-22-authority-owner-inventory-revalidation-T7U8.md`.
    A current Compose-backed invocation on this checkout also completed with
    `authority_schema_state: applied`, `resources_scanned: 0`, and no classifications. The
    isolated test database still has no authority-bearing resource rows, so this remains command
    and schema-state evidence only; it does not open owner mapping or cutover. Evidence:
    `evidence/2026-09-22-authority-owner-inventory-current-O1P2.md`.
11. Welcome authorization and Auth pre-authentication checks were revalidated against the current
    controllers and public behavior. Base app/com/org Welcome flows authorize the pending sign-in
    cycle through the shared sequence gate; Auth checks enforce sequence integrity and are not
    ordinary authenticated-resource authorization points. The focused three-surface/app-check
    suite passes with 15 runs / 171 assertions / 0 failures / 0 errors / 0 skips. No duplicate
    Action Policy hook was added. Evidence:
    `evidence/2026-09-22-welcome-preauth-authorization-revalidation-U9V0.md`.
12. OIDC connection reactivation and RP revocation were revalidated against the current
    surface-local implementations. Stale authorization codes cannot clear a newer connection
    revocation, and RP revoke remains limited to the authenticated RP Session with parent-first
    locking. The focused operation/controller suite passes with 23 runs / 72 assertions / 0
    failures / 0 errors / 0 skips. External RP registration and the unresolved Auth/Base authority
    handoff remain separate gates. Evidence:
    `evidence/2026-09-22-oidc-revoke-connection-revalidation-V2W3.md`.
13. A stale-row sign-up expiry interleaving was verified with a committed flow and an independent
   PostgreSQL connection: legitimate completion remains authoritative and the later expiry
   operation rejects the stale terminal transition. This strengthens the repository-side #840
   proof but does not establish production scheduler topology or exact live worker/request
   concurrency. Evidence: `evidence/2026-09-22-signup-expiry-stale-row-D4E5.md`.
14. The setup-only Solid Queue configuration test remains absent in accordance with the repository
    no-environment-tests rule. The installed test-environment validator was rerun and reported
    `Solid Queue configuration is valid.` Existing enqueue/status and recurring-schedule behavior
    tests also pass with 9 runs / 31 assertions. The same validator now also passes for the local
    development environment with explicit `TRUSTED_PROXIES`; production worker topology,
    scheduler execution, and provider delivery remain CF-005/CF-011 concerns. A production check
    was attempted but stopped before validation because `BASE_SERVICE_URL` was not supplied; no
    fallback host was invented. Evidence:
    `evidence/2026-09-22-solid-queue-rule-status-E5F6.md`.
15. Auth ceremony admission rotation now uses the public `rotate_and_admit!` operation so
    predecessor revocation and replacement admission share one writing-database transaction. The
    existing predecessor digest records the replacement lineage and prevents a second replacement
    from the same persisted predecessor after the first commits; a uniqueness failure rolls back
    the predecessor revocation. The Compose-backed focused model and independent-connection
    concurrency tests now pass with 36 runs / 219 assertions / 0 failures / 0 errors / 0 skips.
    This closes only the Auth-local admission-rotation sub-boundary. The later CF-010 closure
    amendment supplies the approved Base/Auth finalization contract; external RP registration,
    key deployment, live acceptance, and first-admission coordination without a persisted
    predecessor remain separate gates.
    Evidence: `evidence/2026-09-22-auth-ceremony-atomic-rotation-C6D7.md` and
    `evidence/2026-09-22-auth-ceremony-rotation-runtime-revalidation-S3T4.md`.
16. Historical validation-order check: the Base Auth-result POST validated the stored OIDC
    authorization request before consuming the then-current one-shot Valkey result. The current
    implementation supersedes that transport detail with a re-readable, generation-bound result
    and PostgreSQL finalization; this entry remains historical evidence.
    Evidence: `evidence/2026-09-22-result-validation-before-consume-S1T2.md`.
17. Historical readiness check: the result endpoint checked that the authorization transaction was
    unexpired and authenticated before consuming the then-current one-shot result, using the
    transaction class's writer-database clock. The current implementation retains the DB-clock
    check and supersedes consumption with generation-bound result validation and idempotent
    finalization. Evidence:
    `evidence/2026-09-22-result-readiness-before-consume-T3U4.md`.
18. Auth admission now evaluates Base authorization-transaction expiry using the matching writer
    database clock for both login-challenge and transaction expiry. A public app admission
    regression covers a DB-clock-expired transaction that is still future relative to the
    application clock and verifies that no Auth ceremony state is created. This closes only the
    local clock-consistency case; the current CF-010 closure adds the cross-store issuance,
    recovery, and concurrent handoff semantics. Evidence:
    `evidence/2026-09-22-auth-admission-db-clock-U5V6.md`.
19. A read-only Step-Up boundary audit reviewed the app Avatar Group and Group Avatar Membership
    writes. They retain Client authentication, selected-account scoping, and object policy checks,
    but the current architecture explicitly treats Group v1 as an Avatar container rather than a
    posting, legal, organization, authentication, or RBAC actor. Whether membership grants
    representative authority is still an explicit unresolved design question. No new Step-Up gate
    was added because choosing a scope/AAL for an unresolved authority meaning would invent a
    product/security contract. This remains `NEXT_CYCLE / CONTRACT_UNDEFINED` for the separate
    Persona/Avatar authority decision; it is not evidence that existing credential, recovery,
    session-revocation, withdrawal, social-linking, or enforcement gates were removed.
    Evidence: `evidence/2026-09-22-step-up-group-boundary-audit-V6W7.md`.
20. The OIDC endpoint/realm boundary was revalidated through the public exchange, refresh,
    revocation, and first-party browser authorization contracts. Controller-supplied
    `expected_resource_type` is required before code consumption or token issuance; refresh and
    revoke remain scoped to the expected surface-local client/session. First-party browser RPs stay
    neutral for both sign-in and sign-up screen hints. The remaining legacy intent branch belongs
    only to the retained `core-next-rp` bridge compatibility registration. Its external callers,
    registrations, keys, and migration state are not proven locally, so removing it would be an
    unapproved external-contract change. This local boundary is verified; the external migration
    remains `CF-007`. Focused verification passed with 160 runs / 828 assertions / 0 failures / 0
    errors / 0 skips, followed by the full Rails suite with 11,536 runs / 73,429 assertions / 0
    failures / 0 errors / 8 skips. Evidence:
    `evidence/2026-09-22-oidc-endpoint-realm-revalidation-C8D9.md`.
21. The defined #884 sensitive-write Step-Up contracts were revalidated on the current Compose-backed
    test services. Credential management, contact changes, MFA reset, social unlink, withdrawal,
    revoke-all, and Emergency-context refusal passed with 76 runs / 290 assertions / 0 failures / 0
    errors / 0 skips. App Group and Group Avatar Membership remain outside a newly invented scope
    because their assurance classification is still an explicit authority decision. Evidence:
    `evidence/2026-09-22-step-up-runtime-revalidation-D9E0.md`.
22. The Base app/com/org Dashboard Menu/Primary contract was rerun against the current Compose-backed
    checkout. The focused public Inertia-props set passed with 19 runs / 267 assertions / 0 failures /
    0 errors / 0 skips, and the full Rails suite passed with 11,536 runs / 73,426 assertions / 0
    failures / 0 errors / 8 skips. No Dashboard implementation change was needed; the existing
    route-helper props and shared section renderer satisfy the accepted presentation-only contract.
    Evidence: `evidence/2026-09-22-dashboard-menu-links-runtime-H1I2.md`.
23. The current checkout's formal preflight, full Rails suite, full Vitest suite, RuboCop, and
    JavaScript/OpenAPI quality checks were rerun without displaying secrets or contacting external
    services. Coverage was intentionally omitted; no coverage threshold or test assertion was
    weakened. Evidence: `evidence/2026-09-22-final-quality-gates-J3K4.md`.
24. The read-only `authority:owner_inventory` task was rerun against the isolated test topology.
    It reports `authority_schema_state: applied`, `resources_scanned: 0`, and no classifications.
    This confirms the task and schema-state boundary, but leaves CF-003/CF-004 blocked because an
    empty inventory cannot authorize owner mapping, backfill, lifecycle, or destructive cutover.
    Evidence: `evidence/2026-09-22-authority-owner-inventory-recheck-J4K5.md`.
25. The `core-next-rp` compatibility boundary was rechecked through the production bridge models,
    static registry, and public registry/bridge tests (`47 runs / 358 assertions / 0 failures / 0
    errors / 0 skips`). The bridge still has live local references, so retiring the client requires
    external registration/key and data-migration reconciliation; no client ID or credential sharing
    was invented. Evidence: `evidence/2026-09-22-core-next-rp-bridge-recheck-K5L6.md`.
26. Rails 8.2 CSRF strategy declarations were revalidated through the public security invariants:
    `header_or_legacy_token` and `with: :exception` remain explicit on the application boundary,
    while the two reviewed non-browser exceptions remain narrowly allowlisted. The focused set
    passed with 9 runs / 20 assertions / 0 failures / 0 errors / 0 skips. Evidence:
    `evidence/2026-09-22-csrf-strategy-runtime-L7M8.md`.

#### Follow-up: authority and queue contract runtime recheck (2026-09-21)

- The previously environment-blocked owner-inventory, authority-schema/vocabulary, creator-race,
  and Solid Queue integration contracts now run against the Compose-backed isolated services.
  Focused verification passed with 19 runs / 279 assertions / 0 failures / 0 errors / 0 skips.
- This confirms the current local contracts and real creator concurrency only. It does not enable
  the authored authority migrations, infer owners, perform backfill, start a worker, or prove
  production queue operation. The owner mapping and cutover gates remain closed until their
  explicit data and operational reviews are complete.
- Evidence: `evidence/2026-09-21-authority-queue-runtime-recheck-N5P6.md`.

#### Follow-up: nested surface connection owners

The first focused enforcement run exposed that several existing helpers selected the first abstract
Active Record ancestor rather than the class that established the surface connection. This caused
`connected_to` to reject an `App/Com/OrgPrincipalRecord` or RP base even though its concrete model
was backed by `App/Com/OrgZenithRecord`. Preference adoption/synchronization, OIDC RP identity
provisioning, banner reads, and restricted-session cleanup now use Rails'
`connection_class_for_self`. The focused enforcement set passes with 53 runs / 182 assertions, and
the related connection-owner contract and consumers pass with 22 runs / 66 assertions. This fixes
the local connection-owner selection defect; it does not prove cross-database atomicity, migration
safety, full-suite health, or production topology.

## Handoff rule

The next safe action is to continue static review of the remaining authentication/session
boundaries and rerun narrow Rails suites before extending policy or lifecycle behavior. The JWT
anomaly subscriber makes missing catalog rows observable without fabricating reference data, and
the current-runtime catalog transition is now verified through both migration and schema-load/seed
paths; CF-013 is closed for that boundary. The next blocked action is executing the authority
migrations, backfilling owners, enabling grant/transfer routes, destructive scrub, or production
queue changes without the shape, connection, migration, and isolated-test gates.

#### Follow-up: JWT anomaly catalog boundary (2026-09-18)

- `JitSecurityJwtAnomalyReporter` now maps a missing `nbf` claim to the existing `MISSING_NBF`
  catalog reason and publishes the existing `jwt.anomaly.detected` Active Support notification. The
  new initializer registers `JwtAnomalySubscriber` for that exact event. The subscriber validates
  the internal code format and emits a bounded `jwt.anomaly.catalog_miss` structured event when a
  runtime code has no reference row; malformed values are represented only by `INVALID` and byte
  length. It never fabricates a `JwtOccurrence` row and does not persist unknown codes as anomaly
  events.
- Static source review confirmed a larger existing mismatch: runtime auth contexts are
  `AUTH_CLIENT`/`AUTH_OPERATOR`/`AUTH_VISITOR`, while the original reference migration seeds
  `AUTH_USER`/`AUTH_STAFF`; the access-token codec also emits `CLAIM_INVALID`/`DECODE_FAILED`, which
  were absent from the original reason set. This is recorded as CF-013. An additive reference-data
  migration is now authored but has not been executed because the isolated occurrence database is
  unavailable; legacy rows remain untouched by design.
- Ruby syntax, scoped RuboCop, `git diff --check`, isolated subscriber behavior, and isolated Active
  Support notification smoke passed. The JWT reporter and subscriber Rails tests were attempted with
  explicit loopback test service variables but stopped during schema boot because PostgreSQL at
  `127.0.0.1:5432` was unavailable; no fallback datastore was used. Evidence:
  `evidence/2026-09-18-jwt-anomaly-catalog-audit.md`.
- Commits: `cbfdc356f` (mapping/subscriber containment) and `842900c7e` (notification wiring, tests,
  and handoff records).

#### Follow-up: JWT anomaly payload field boundary (2026-09-18)

- `JitSecurityJwtAnomalyReporter` now passes error messages through the existing
  `ChronicleRecordPolicy` sanitizer before logging or publishing them. `JwtAnomalySubscriber`
  applies the same boundary before persistence and truncation, so raw JWT-shaped values are not
  retained.
- Reporter extras and subscriber metadata use explicit default-deny allowlists. They are currently
  empty because no production call site declares a safe additional field; arbitrary notification
  payload keys are no longer copied to the JSON metadata column. This is a code-only containment
  slice and does not change occurrence reference data, schema, or retention policy.
- Regression tests cover raw JWT-shaped errors and unallowlisted metadata/extras. Syntax, scoped
  RuboCop, and DB-free sanitizer smokes pass. Rails persistence tests remain blocked by the
  unavailable isolated PostgreSQL listener, as recorded in the JWT evidence file.
- Commit: `79324edf6` (`Bound JWT anomaly metadata and error capture`).

#### Follow-up: JWT diagnostic cardinality boundary (2026-09-18)

- Untrusted JWT diagnostic strings are now limited to 255 characters and audience arrays to eight
  values before structured logging and notification publication. Each string passes through the
  existing Chronicle sanitizer, so raw token-shaped values are not copied into the diagnostic
  payload.
- This is a code-only observability hardening slice. It does not alter JWT verification, accepted
  claims, reference-data rows, persistence schema, retention, or authentication outcomes.
- Regression coverage, syntax, scoped RuboCop, and a DB-free bounds smoke pass. The focused Rails
  test remains blocked at schema boot by unavailable isolated PostgreSQL. Commit: `6930e7303`
  (`Bound JWT anomaly diagnostic payloads`).

#### Follow-up: OIDC revocation coverage double (2026-09-18)

- The full-suite attempt exposed a stale coverage-test token double: production `RpSession#revoke!`
  accepts `status:` and `now:` keywords, while the double accepted no arguments. The double now
  follows that existing public contract and records the arguments; no production revoke behavior
  changed.
- The focused coverage test passed with 8 runs / 26 assertions, and the combined OIDC/RP-session
  revocation set passed with 25 runs / 101 assertions. Syntax and RuboCop passed for the changed
  test.
- The full suite remains incomplete because the process terminated after reaching the unavailable
  test Valkey path; CF-002 remains open and no full-suite claim is made.

#### Follow-up: OIDC exchange helper and environment boundary (2026-09-18)

- The OIDC exchange regression suite exposed one test-only call that omitted the required
  `client_id`, `redirect_uri`, `code_challenge`, and `code_challenge_method` keywords when planting
  a pre-revocation authorization code. The call now supplies the same registered client and PKCE
  values used by the test setup; production exchange code was not changed.
- Syntax and RuboCop passed. The corrected case reached its Valkey write and stopped only at the
  unavailable Valkey connection. The broader exchange/realm/refresh/controller command ran 147 tests
  / 234 assertions and ended with 8 failures / 86 errors, predominantly at unavailable Valkey
  stores. This is not reported as a passing suite.
- The explicit environment check also stopped because PostgreSQL host `primary` could not be
  resolved. `CF-002` remains open; no fallback datastore or external service was used.

#### Follow-up: RP-session issuance boundary after revoke (2026-09-18)

- `RpSession#record_access_token_expiry!` now acquires the parent Browser Session before the RP
  Session, rechecks `active?`, and raises an explicit issuance rejection when revocation or parent
  termination has won the boundary. The OIDC coordinator maps that condition to `invalid_grant`
  without returning an Access JWT. The maximum Access JWT `exp` remains monotonic and is persisted
  before token encoding/response.
- This closes the refresh-rotation-commit to access-token-response race without restoring a rotated
  refresh token or introducing a cache-based revocation authority. It does not provide immediate
  invalidation of an already returned Access JWT; the documented natural-expiry window remains.

#### Follow-up: RP-session refresh lock order (2026-09-18)

- `RpSession#issue_refresh_token!`, `#rotate_refresh_token!`, and `#revoke!` now use the same parent
  Browser Session → RP Session lock order. Initial refresh issuance also rechecks `active?` under
  both locks, so a revoke that wins before issuance prevents a refresh digest from being written.
- This closes the direct model-method path that could write an initial refresh credential after an
  RP Session had been revoked. It does not make already returned Access JWTs immediately invalid;
  the existing natural-expiry and verifier-leeway window remains the contract.
- Syntax and RuboCop passed. The focused RP-session Rails command was attempted with explicit
  loopback test Valkey/PostgreSQL variables and stopped during schema boot because PostgreSQL at
  `127.0.0.1:5432` is unavailable. Database-backed lock-order and rejection assertions remain
  unverified under CF-002.

#### Follow-up: processor-erasure notification success boundary (2026-09-18)

- `ProcessorErasureNotificationJob` no longer treats named processor keys as delivered merely
  because a notification row exists. The repository has no concrete email, SMS, push, analytics,
  storage, search, or log-pipeline processor adapter for this workflow, so its success allowlist is
  empty and current rows enter the explicit unavailable/manual-follow-up failure state.
- `NOTIFIED` remains reserved for a future concrete dispatch contract that can distinguish request
  acceptance, provider receipt, delivery outcome, retry, and permanent failure. No provider or new
  generic notification framework was added.
- Syntax and RuboCop passed. The job regression test was not able to boot its Rails schema because
  PostgreSQL at `127.0.0.1:5432` is unavailable; no external processor was contacted.

#### Follow-up: processor-notification retry decision clock (2026-09-22)

- `ProcessorErasureNotificationState#mark_failed!` now derives `next_retry_at` from its supplied
  decision time instead of reacquiring `Time.current`. The existing 15-minute retry policy and
  explicit unavailable-processor failure boundary are unchanged; no processor adapter or delivery
  contract was introduced.
- TDD RED reproduced the mismatch with a fixed historical decision time. The focused model, job,
  and existing processor-notification coverage then passed with 35 runs / 312 assertions / 0
  failures / 0 errors / 0 skips. Targeted RuboCop, Ruby syntax, and `git diff --check` passed.
- The subsequent full Rails suite passed with 11,501 runs / 73,297 assertions / 0 failures / 0
  errors / 5 skips. The skips and expected provider/OmniAuth test diagnostics were not changed by
  this slice.
- This fixes retry timestamp consistency only. Processor receipt, delivery, retry exhaustion, and
  permanent-failure semantics remain the independent CF-011 contract and are not closed.
- Evidence: `evidence/2026-09-22-processor-notification-retry-clock-A1B2.md`.

#### Follow-up: processor-notification terminal-state guard (2026-09-22)

- Adversarial review found that the public `mark_failed!` and `mark_notified!` methods could
  overwrite a persisted `NOTIFIED` or `SKIPPED` row because the job-level `terminal?` check was
  not repeated inside the state update.
- The methods now lock and re-read the row, then leave terminal rows unchanged. Non-terminal
  `PENDING`/`FAILED` retry behavior is unchanged.
- This closes only terminal-state overwrite. It does not close CF-011's separate processor
  adapter, provider receipt, bounded retry/exhaustion, or permanent-failure contract.
- Evidence: `evidence/2026-09-22-processor-notification-terminal-guard-C3D4.md`.

#### Follow-up: processor-notification retry-window guard (2026-09-22)

- A stale duplicate `ProcessorErasureNotificationJob` invocation now returns before recording a
  request or changing failure metadata when the persisted `next_retry_at` is still in the future,
  using the notification model's database clock. This is a local retry-window guard only; the
  pre-dispatch check is advisory for jobs that become due concurrently and does not claim exactly-
  once request emission. It does not add a provider adapter, receipt ledger, retry-exhaustion
  policy, or permanent-failure state.
- The public job regression test and the changed job pass syntax, targeted RuboCop, and
  `git diff --check`. The focused job/model set passes with 38 runs / 321 assertions and the full
  Rails suite passes with 11,505 runs / 73,310 assertions / 0 failures / 0 errors / 5 skips. The
  initial restricted-shell boot failure and the successful Compose-service re-run are both recorded
  in `evidence/2026-09-22-processor-notification-retry-window-H4J5.md`.

#### Revalidation: retention, notification, and RP route contracts (2026-09-22)

- The focused retention, notification-state, and Core route contract set passed with 59 runs / 374
  assertions / 0 failures / 0 errors / 0 skips against the Compose-backed test services. This
  revalidation covers the existing retention allowlist, bounded batches, writer-clock eligibility,
  hold and enforcement protection, kill switch, notification retry-window and terminal-state
  guards, and the canonical RP callback route.
- `git diff --check`, changed-file syntax, and targeted RuboCop passed. The latest complete Rails
  result including the retry-window implementation remains 11,505 runs / 73,310 assertions / 0
  failures / 0 errors / 5 skips, recorded in the retry-window evidence.
- Retention remains `ACCEPTED_AS_EXISTING_IMPLEMENTATION`; dry-run, preview, and simulation APIs
  are not required and were not added. Provider delivery/receipt/retry-exhaustion/permanent-failure
  remains `CF-011`, and the Auth/Base authority and external RP/deployment gates remain open.
- Evidence: `evidence/2026-09-22-retention-notification-route-revalidation-N6P7.md` and the final
  plan re-review in `evidence/2026-09-22-retention-frozen-plan-rereview-R9S0.md`.

#### CF-011 contract revalidation (2026-09-22)

The processor-notification boundary was rechecked against the current models, job, tests, and
security documentation. The repository still has no concrete processor adapter, authenticated
receipt contract, bounded retry-exhaustion policy, or approved permanent-failure status. The
success allowlist therefore remains empty; a requested notification is recorded as
`processor_unavailable` rather than falsely marked `NOTIFIED`. The focused retention,
notification-state, and Core route set passed with `31 runs, 287 assertions, 0 failures, 0 errors,
0 skips`. No adapter, receipt ledger, retry limit, or status was invented without an approved
contract. Evidence: `evidence/2026-09-22-processor-notification-contract-revalidation-L3M4.md`.

The 2026-09-23 local contract recheck reconfirmed the same boundary with the focused processor
job/state tests (`8 runs, 23 assertions, 0 failures, 0 errors, 0 skips`). Existing coverage is
sufficient for the currently defined fail-closed behavior: unsupported processors do not become
`NOTIFIED`, terminal states are protected, and the retry window is enforced. The required forged
receipt, duplicate-delivery, retry-exhaustion, permanent-failure, and manual-recovery tests remain
undefined until their contracts are approved. Evidence:
`evidence/2026-09-23-cf011-local-contract-recheck-J9K0.md`.

#### Follow-up: RP-authenticated neutral-entry refusal (2026-09-22)

- Adversarial review found that `POST /sign` rejected only the legacy/root Browser Session
  predicate. A browser carrying a valid same-RP `oidc_rp_access` credential could therefore start a
  second OIDC flow, contrary to the server-side already-authenticated RP contract.
- `OidcRpSignEntry` now reuses the existing host, client, audience, issuer, and resource-type
  validation in `OidcRpBrowserCredentialContract` before allowing a new POST flow. It does not
  inspect refresh credentials, create an RP-session lookup, accept another surface's cookie, or
  alter Rails CSRF protection. Invalid, expired, or cross-surface credentials remain eligible for
  their normal failure/new-flow behavior rather than being treated as authentication.
- TDD RED reproduced the valid same-RP cookie path as a 302 authorization redirect instead of the
  required plain 409 refusal. The focused neutral-entry contract then passed with 10 runs / 173
  assertions. The broader RP callback, cookie-isolation, browser-flow, access-token, and API
  boundary set passed with 73 runs / 546 assertions. The local Base/Auth finalization portion is
  covered by the later CF-010 closure amendment; external RP registrations and deployment/runtime
  acceptance remain open under `CF-007` and the operational gates.
- Evidence: `evidence/2026-09-22-rp-entry-authenticated-cookie-guard-Q7R8.md`.

#### Follow-up: authority migration index contract (2026-09-18)

- The three not-yet-enabled authority migrations now opt every `t.references` declaration out of
  Rails' automatic single-column index. Required unique, composite, partial, and reverse-principal
  indexes remain explicitly declared, avoiding redundant indexes beside leftmost unique/composite
  indexes without changing authority rows or foreign keys.
- A schema contract test checks the explicit `index: false` choice for all 75 authority references.
  The standalone source-count check, Ruby syntax, targeted RuboCop, and `git diff --check` passed.
- The isolated Rails contract test could not boot because PostgreSQL and Valkey are unavailable; the
  migrations were not applied and runtime index/rollback behavior remains unverified under CF-002.

#### Follow-up: separate Persona and organization-context readiness (2026-09-18)

- `Actor::SelectedContext` now exposes `persona_selected?` for Persona-only flows and
  `organization_context_selected?` for the existing Persona + Organization + Unit contract.
  `selected?` delegates to the complete organization-context predicate, so full-access controllers
  retain their existing gate and no Unit/Position implementation was introduced.
- Existing persisted field names (`selected_account_public_id`, `selected_collective_public_id`, and
  `selected_collective_unit_public_id`) remain unchanged pending an explicit reader/writer
  migration. Selection remains context rather than authorization proof; downstream authority checks
  are still required.
- The focused selected-context model test passed with 6 runs / 22 assertions. The related
  full-access and dashboard regression set passed with 37 runs / 113 assertions. The first test boot
  without the required `VALKEY_TEST_HOST`/`VALKEY_TEST_PORT` was rejected by the repository's
  explicit test configuration; no fallback service was used.

#### Follow-up: malformed OTP input boundary (2026-09-18)

- The shared OTP and sign-up ceremony verifiers now reject short, oversized, non-numeric, and nil
  input before comparison/HOTP verification. This prevents malformed external input from becoming a
  comparison exception or a successful consume; OTP length, expiry, attempt, cooldown, and delivery
  policy values remain unchanged.
- Standalone valid/malformed OTP smoke, Ruby syntax, and RuboCop passed. The corresponding Rails
  tests were added but could not boot past the unavailable isolated PostgreSQL hostname `primary`
  after explicit test Valkey variables were supplied. Runtime DB concurrency proof remains under
  CF-002.

#### Follow-up: resend reservation and permanent SMS payload reporting (2026-09-18)

- `SignInOtpResender` now creates or finds the HMAC-keyed occurrence through its unique index and
  locks the occurrence while evaluating and persisting the resend reservation. The reservation is
  committed before provider I/O, so concurrent requests cannot both pass the cooldown and a failed
  provider call cannot be used to obtain an immediate second attempt. The external provider is not
  called while the occurrence row is locked; a later retry remains subject to the same policy.
- `Outbound::SmsDeliveryJob` still refuses plaintext and mixed legacy payloads, but malformed
  permanent payloads now use Rails/Active Job error reporting before discard. This keeps the
  no-plaintext boundary while making the delivery gap observable.
- Syntax and RuboCop passed for the changed production and test files. The focused Rails tests were
  attempted with explicit loopback test Valkey and PostgreSQL variables and stopped during schema
  boot because PostgreSQL at `127.0.0.1:5432` is unavailable; no non-test datastore fallback was
  used. A standalone Active Job discard-report smoke passed. The database-backed reservation and
  error-reporter regression tests remain unverified under CF-002.

#### Follow-up: shared OTP generation lock (2026-09-18)

- The common `generate_otp_for` helper now generates and persists the HOTP secret, counter, and
  expiry inside the target record's `with_lock` boundary. This covers the existing registration,
  sign-in, recovery, and re-entry callers without moving provider delivery into the transaction.
- The regression harness verifies that the stored credential produces the returned six-digit code
  and that generation enters the record lock. The Rails test was attempted with explicit loopback
  test Valkey/PostgreSQL variables and stopped during schema boot because PostgreSQL at
  `127.0.0.1:5432` is unavailable. A standalone HOTP generation/lock smoke passed; independent
  PostgreSQL concurrency proof remains under CF-002.

#### Follow-up: OTP email verification-token queue boundary (2026-09-18)

- The Action Mailer and Noticed OTP producers now encrypt the optional email verification token
  before creating `ActionMailer::MailDeliveryJob` or `Noticed::EventJob` arguments. The token uses a
  purpose-separated `OutboundSensitivePayload` value and is decrypted only by the surface mailer
  while rendering the message. New producers therefore do not place the bearer token in the queue
  database or serialized job arguments.
- The mailers retain a read-only compatibility branch for already queued legacy arguments that
  contain `verification_token`; it is not used by the current adapter or notifier producers and is
  not a new producer contract.
- Static inspection, syntax, RuboCop, and standalone encryption round-trip verification passed. The
  focused Rails test set was attempted with explicit loopback test Valkey/PostgreSQL variables and
  stopped during schema boot because PostgreSQL at `127.0.0.1:5432` is unavailable. Queue-worker
  execution remains unverified under CF-002.

#### Follow-up: logout state serialization and production transport boundary (2026-09-18)

- RP logout status updates now use the same Browser Session -> RP Session lock order as issuance,
  refresh, and revoke. This closes the direct model update path that could otherwise race a new
  issuance without adding a cache-based revocation authority.
- OIDC back-channel logout now requires HTTPS in production before the outbound transport is built.
  Non-production local test conventions remain explicit and do not weaken the production boundary.
- The focused database-backed tests were attempted with explicit loopback PostgreSQL and Valkey
  endpoints, but those services were not listening in this environment. Syntax, scoped RuboCop, and
  the transport regression source checks passed; the lock behavior remains unverified until isolated
  services are available.

#### Follow-up: authority documentation and setup-validation reconciliation (2026-09-18)

- Authority, Avatar, SNS, and dictionary documentation now describe the adopted concrete
  `ClientPersona`/`OperatorOrganization` mappings and keep Avatar behavior/RBAC outside this
  program. No Avatar code, schema, or authorization behavior was changed.
- The setup-only Solid Queue Minitest was removed to comply with the repository rule that
  environment construction is verified by running the installed validator rather than by adding a
  test case. Behavior-level job tests remain in scope, and
  `RAILS_ENV=test bundle exec bin/jobs check` passed with disposable loopback variables.
  Development/production worker execution remains blocked by absent local PostgreSQL/Valkey services
  (CF-005).

#### Follow-up: read-only authority owner inventory (2026-09-18)

- `AuthorityOwnerMigrationInventory` now provides an explicit, read-only inventory for all six
  concrete Persona/Organization resources across the three independent surfaces. It reports only
  opaque public identifiers, classifies legacy RP bindings and active memberships without treating
  them as ownership, and refuses to treat a partially applied authority schema as ready.
- The `authority:owner_inventory` task writes a JSON report under `tmp/authority` by default and has
  no apply or backfill mode. Resource and membership reads are bounded and preloaded to avoid a
  per-resource principal/membership query pattern.
- Syntax, scoped RuboCop, and diff checks passed. The Rails contract test was attempted with
  explicit test-only loopback PostgreSQL/Valkey settings, but PostgreSQL was not listening at
  `127.0.0.1:5432`; the report itself therefore remains unverified. This does not change CF-003 or
  enable migrations, owner backfill, lifecycle, or authorization cutover.
- Evidence: `evidence/2026-09-18-authority-owner-inventory-4K7M.md`.

#### Final handoff state (updated 2026-09-18)

- The latest implementation slice is `7314bc332` on branch `feature`; the JWT anomaly payload and
  diagnostic boundaries are recorded in `57797f607` and `7314bc332`, following the catalog and
  persistence slices. The task began at `3ff5241c4b876c2c828e772c0fd289c8aae5f850`. Pre-existing
  staged, unstaged, and untracked changes remain outside the task commits.
- The safe local slices are committed through the OTel correlation, dashboard reachability, queue
  configuration, explicit push queue pinning, realm/refresh/revoke/OTP hardening, authority
  foundation, read-only owner inventory, JWT anomaly catalog containment, documentation boundaries,
  and production OIDC transport checks. No authority cutover, destructive migration/backfill,
  Auth/Base issuer migration, body-limit deployment, lifecycle scrub enablement, occurrence-catalog
  migration, or external RP configuration was executed.
- Full database-backed and real-worker verification is not complete because isolated PostgreSQL and
  Valkey services are unavailable. `CF-002`, `CF-003`, `CF-004`, `CF-005`, `CF-007`, `CF-008`,
  `CF-009`, `CF-010`, `CF-011`, and `CF-013` remain the relevant blocked or limited slices; `CF-012`
  records the repository-rule resolution for setup validation.
- The exact next safe action is to provision disposable isolated PostgreSQL, Valkey, and
  queue-worker services without touching non-test data, rerun the focused lock/order, authority,
  OTP, queue, scrub, and JWT anomaly tests, and update the evidence before enabling any blocked
  slice. Execute the authored CF-013 occurrence-catalog transition only on a disposable occurrence
  database, then claim #606 complete only after persistence and rerun-safety checks pass.

#### Follow-up: current JWT anomaly catalog transition (2026-09-18)

- The runtime/catalog mismatch has an additive implementation in commit `172686b23`:
  `db/occurrences_migrate/20260918150000_insert_current_jwt_anomaly_reference_data.rb` covers the
  current `AUTH_CLIENT`, `AUTH_OPERATOR`, and `AUTH_VISITOR` contexts and the runtime
  `CLAIM_INVALID`/`DECODE_FAILED` reasons without deleting or renaming historical rows.
- The migration is intentionally forward-only because anomaly events can retain foreign-key
  references to catalog rows. It reuses the existing active status and reference retention
  convention, checks conflicting same-body rows rather than silently rewriting them, fails loudly
  when prerequisite occurrence tables are absent, and is idempotent for already-active rows. A
  representative persistence regression is in `test/subscribers/jwt_anomaly_subscriber_test.rb`.
- Static syntax, RuboCop, diff, and Zeitwerk checks passed. The Rails persistence test and actual
  occurrence migration remain unverified because no isolated PostgreSQL listener is available. The
  migration and #606 slice remain blocked from deployment until a disposable occurrence DB verifies
  clean apply, rerun, legacy-row preservation, and current event persistence.

#### Follow-up: subscriber persistence boundary (2026-09-18)

- Commit `c9f5743ea` sanitizes every diagnostic string copied from the JWT anomaly notification
  payload into `JwtAnomalyEvent`, including request host, key id, algorithm, type, issuer, jti, and
  error class. This closes the persistence-side boundary when an internal notification is
  constructed outside the reporter; it does not alter JWT verification or catalog semantics.
- A regression test covers a synthetic JWT-shaped value in each field. Syntax, scoped RuboCop, and
  the pre-commit hook passed, but the Rails assertion remains blocked by unavailable isolated
  PostgreSQL. The migration and subscriber runtime proof remain part of CF-013's blocked acceptance
  gate.

#### Follow-up: malformed payload and failure-log boundaries (2026-09-18)

- Commit `57797f607` rejects non-Hash notification payloads without catalog lookup or event
  persistence and records only a bounded payload class. Nil payloads retain the existing no-op
  behavior. This prevents malformed internal notifications from becoming subscriber exceptions or
  fabricated anomaly rows.
- Commit `7314bc332` sanitizes `ActiveRecord` persistence failure messages with the existing
  `ChronicleRecordPolicy` before structured logging. A DB-free red/green smoke reproduced and then
  closed the raw JWT-shaped exception-message leak. Neither change alters JWT verification,
  authentication outcomes, catalog state, or authorization behavior.
- The Rails regression remains unverified because PostgreSQL is unavailable at the isolated test
  endpoint. The evidence is recorded in `evidence/2026-09-18-jwt-anomaly-catalog-audit.md`.

#### Follow-up: reporter failure-log sanitization (2026-09-18)

- Commit `a8a0ef9f5` bounds and sanitizes the JWT anomaly reporter's own failure message before it
  reaches the structured log. This closes the adjacent failure path left after subscriber failure
  logging was hardened; it does not change JWT verification, authentication outcomes, catalog state,
  or authorization behavior.
- The regression was added after a DB-free red reproduction and passed in the DB-free green smoke;
  syntax, scoped RuboCop, and the commit hook passed. The focused Rails test remains blocked before
  assertions by unavailable isolated PostgreSQL. Evidence:
  `evidence/2026-09-18-jwt-anomaly-catalog-audit.md`.
- CF-013 remains `BLOCKS_SLICE`: the occurrence migration, event persistence, and full Rails
  regression still require a disposable occurrence database and must be verified together.

#### Follow-up: free-form observability token redaction (2026-09-18)

- Commit `63478758d` extends the existing `ObservabilityRedactor` to remove token-shaped JWT and
  Bearer values from free-form strings, including exception messages normalized by `JitLogEvent`.
  Request/trace correlation semantics and authentication behavior are unchanged.
- The redactor regression, a DB-free `JitLogEvent` smoke, syntax, scoped RuboCop, Zeitwerk loading,
  and the pre-commit hook passed. The Rails redactor test was attempted with explicit loopback
  PostgreSQL/Valkey endpoints and remains blocked before assertions by unavailable PostgreSQL.
  Evidence: `evidence/2026-09-18-final-hardening-static-review.md`.

#### Follow-up: Solid Queue environment recheck (2026-09-18)

- Commit `eff36467e` records the current supported-environment check results. The isolated test
  configuration validator passed; development stopped while resolving the configured PostgreSQL host
  `primary`, and production stopped before boot because `TRUSTED_PROXIES` was absent.
- Dispatcher/scheduler startup, real worker execution, recurring enqueue, retry, and recovery stay
  unverified under `CF-005` and are not represented as deployment-ready.

#### Follow-up: named credential diagnostic redaction (2026-09-18)

- Commit `033c5d88c` extends the existing observability redactor from JWT/Bearer strings to explicit
  `token=...` and `access_token: ...` forms in free-form diagnostic messages. Authentication and
  credential semantics are unchanged.
- A DB-free red/green smoke, syntax, scoped RuboCop, and the commit hook passed. The Rails test
  boundary remains unverified under `CF-002`; no database or external service was used.

#### Follow-up: current authority terminology audit (2026-09-18)

- The current-tree review found stale concrete-model references in
  `docs/architecture/principal-zenith-membership-organization-placement.md`: it still described the
  former concrete `Persona`/`Organization` models, the retired `Account` concern, and the old
  `org_principal` placement for the legacy organization row.
- The document now names `ClientPersona` and `OperatorOrganization`, records the existing
  `organizations` table mapping under `org_zenith`, distinguishes the common `Persona` and
  `Organization` interfaces from concrete models, and removes claims that `Member` or
  `OperatorWorkspaceAccount` include the retired `Account` concern. RP-account projection names
  remain where they are an unrelated protocol projection, as allowed by the adopted vocabulary.
- This was documentation-only. No migration, authority table, route, policy, or Avatar behavior
  changed. `git diff --check` passed; runtime documentation/link checks were not run because the
  current Rails test environment still lacks an isolated PostgreSQL/Valkey service.

#### Follow-up: transaction-bound grant rollback after token issuance failure (2026-09-22)

- A public token-exchange regression now covers the failure boundary after a transaction-bound
  authorization grant has been claimed. If RP token encoding fails, the exchange returns a server
  error without a token response; no RP Session is persisted, the durable grant claim is rolled
  back, and the authorization-code transport remains issued for a safe retry. This preserves the
  distinction between a real authorization-code replay and a failed database-backed token issuance
  attempt.
- The regression uses the existing transaction-bound OIDC path and introduces no new authority,
  cache, session lookup, or retry mechanism. No production code or schema changed in this slice.
- Focused verification passed with 123 runs / 571 assertions. The full Rails suite passed with
  11,532 runs / 73,415 assertions / 0 failures / 0 errors / 8 skips. Ruby syntax, scoped RuboCop,
  and `git diff --check` also passed. Evidence:
  `evidence/2026-09-22-oidc-grant-rollback-T6U7.md`.

#### Revalidation: app-only TOTP lifecycle and attempt binding (2026-09-22)

- The current TOTP implementation was revalidated through the public consumer, controller, model,
  concurrency, enrollment, and route-contract interfaces. The focused set passed with 91 runs / 747
  assertions / 0 failures / 0 errors / 0 skips. It confirms app-only routing, actor-scoped credential
  selection, per-credential failure accounting, terminal `REVOKED` at 100 failures, replay rejection,
  independent-connection concurrency behavior, and the two-slot ACTIVE/INACTIVE enrollment rule.
- The `last_otp_at` schema concern was corrected in a separate reversible migration. New and existing
  never-used credentials now store `NULL`; the model no longer requires a fabricated event timestamp,
  settings continue to render an unused credential safely, and accepted codes still write a finite
  timestamp used by replay prevention. The migration was applied only to the disposable test
  `app_zenith` database during verification, and the standard `app_zenith_structure.sql` dump was
  updated without carrying unrelated live-database constraint differences into the repository.
- RED verification before the correction was 29 runs / 68 assertions / 3 failures. After the
  correction, the focused model/consumer set passed with 29 runs / 70 assertions, and the broader
  TOTP set passed with 91 runs / 747 assertions. The post-change full suite passed with 11,533 runs /
  73,416 assertions / 0 failures / 0 errors / 8 skips, and the subsequent structure-load/reset
  verification passed with 11,533 runs / 73,419 assertions / 0 failures / 0 errors / 8 skips.
  Syntax, scoped and repository-wide RuboCop, Brakeman (0 errors / 0 security warnings), and diff
  checks passed. The migration was also rolled back and reapplied on the disposable test database
  successfully. Evidence:
  `evidence/2026-09-22-totp-last-otp-nullability-Z6A7.md`.

#### Historical CF-011 pre-deployment implementation continuation (2026-09-23; superseded by closure below)

The approved provider-neutral contract is now represented in the repository. App and com
notifications have concrete attempt ledgers, monotonic delivery generations, digest-only
idempotency identities, verified-receipt binding, bounded retry policy, immutable
`PERMANENT_FAILURE`, and an authorized manual-recovery operation. `NOTIFIED` cannot be reached from
enqueue or an unverified processor response. A due retry is re-enqueued through the retention queue,
and a recurring bounded sweep recovers rows whose retry enqueue was interrupted. The adapter registry
remains empty by default, so no provider or external credential was invented.

The focused acceptance suite remains unverified because the current process cannot resolve the
required Compose service `primary`; the exact preflight and Rails boot error are recorded in
`evidence/2026-09-23-pre-deployment-scope-reopen-B5C6.md`. Syntax, `git diff --check`, and scoped
RuboCop passed. CF-011 remains `OPEN — EVIDENCE REQUIRED` until isolated PostgreSQL migration,
constraint, concurrency, and focused Minitest evidence is collected. Provider authentication,
provider receipt protocol, and provider E2E remain deployment/provider gates.

The subsequent adversarial pass corrected two local contract edges before acceptance: a retryable
adapter result that exhausts the finite policy no longer enqueues a retry with a nil deadline, and
the attempt ledger's child foreign keys use `ON DELETE CASCADE` because attempts have no independent
retention window while `RetentionPurgeJob` uses set-based deletion. The DB-backed regression tests
for both edges remain unverified until the isolated PostgreSQL service is available.

The next adversarial pass corrected three further local edges. Retry selection now defaults to the
owning writer database clock; receipt application rechecks terminal notification state under the row
lock; and migration rollback restores status foreign keys in the correct order while refusing to
restore the retired unique idempotency index after valid retry duplicates exist. These corrections
preserve fail-closed behavior without inventing provider semantics. Syntax, scoped RuboCop, and
`git diff --check` passed; PostgreSQL migration and runtime evidence remain unverified.

The resumed blocker audit also rechecked the Rails test boot dependency. Test cache is intentionally an
in-process MemoryStore, but test rate-limit and auth-state use the configured KVS service, so removing the
`VALKEY_KVS_HOST` dependency would be a test-isolation and security-contract regression rather than a
configuration fix. The required environment variables load successfully, while the current process still
cannot resolve `primary` or `valkey-kvs`; the exact preflight remains `PG::ConnectionBad` before application
checks. A new independent-connection CF-011 regression test now covers at-most-one attempt claim and
concurrent verified-receipt idempotency. It is syntax-valid and RuboCop-clean but remains unrun until the
isolated PostgreSQL/Valkey services are available. At that historical point CF-005 and CF-011 were
evidence-gated, while CF-003/CF-004 and CF-007 were decision-gated. The later approved-decision and
closure sections supersede those dispositions.

The retry-sweep contract test also now fixes due-only selection and the configured batch boundary at the
public Active Job interface. This is repository-level evidence only; it does not substitute for dispatcher,
worker, scheduler, or database-backed queue execution evidence.

The current-process CF-011 recheck on 2026-09-23 found no additional implementation defect. Syntax,
scoped RuboCop, Brakeman, diff checks, and the DB-free value-contract smoke passed. The required preflight
still fails before Rails boot because `primary` and `valkey-kvs` do not resolve in this process. Therefore
the focused Minitest, migration, PostgreSQL locking/constraint, and queue-runtime acceptance evidence
remain uncollected; CF-011 stays `OPEN — EVIDENCE REQUIRED` and is not promoted to pre-deployment CLOSED.

The paragraphs in this historical continuation describe an earlier non-Compose verification
boundary. They are retained as evidence of what was not executable in that process and do not
override the later isolated Compose acceptance and the current status table at the top of this
plan.

#### CF-011 pre-deployment acceptance closure (2026-09-23)

The previous paragraph is a historical record of the non-escalated process and no longer describes
the latest verification state. With the process attached to the local Podman Compose network, the
required PostgreSQL and Valkey preflight succeeded. Clean isolated app_zenith and com_zenith test
databases accepted the delivery-contract migrations, including the strong_migrations-safe deferred
constraint validation and concurrent index replacement. The generated app/com SQL structure dumps
were loaded through the standard Rails reset tasks and the combined schema/contract tests passed.

The CF-011 focused suite passed with `30 runs / 118 assertions / 0 failures / 0 errors / 0 skips`.
The schema, architecture, and placement contract set passed with `17 runs / 3118 assertions / 0
failures / 0 errors / 0 skips`; after structure load the combined set passed with `47 runs / 3236
assertions / 0 failures / 0 errors / 0 skips`. The full Rails suite then passed with `11560 runs /
73578 assertions / 0 failures / 0 errors / 8 skips`. Repository-wide RuboCop, Brakeman, and diff
checks passed. Evidence: `evidence/2026-09-23-cf011-idempotency-recheck-R4S5.md`.

`CF-011` is therefore `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`. This closure covers only the
provider-neutral repository and isolated-environment contract. Provider authentication, real
credentials, provider-specific receipt protocol, and provider E2E remain in the later deployment /
provider acceptance gate. At the time of this CF-011 verification, `CF-005` remained independently
open; the later local queue-runtime evidence below supersedes that status.

This paragraph is retained as historical evidence for the earlier isolated run and is superseded
for current status by the later CF-011 state-metadata, retry-boundary, and current-process
revalidation entries below. It must not be read as the present blocker disposition; the status
table at the top of this plan remains authoritative.

#### CF-005 pre-deployment acceptance closure (2026-09-23)

The local Compose-backed development queue was verified through the actual default fork-mode Solid
Queue supervisor. `bin/jobs check` passed for development and test. A temporary recurring definition
drove `SecurityConsumedJtiPurgeJob` through scheduler registration, recurring execution recording,
dispatcher/worker pickup, and five completed queue jobs; an expired application replay row was
removed by the job. An intentionally invalid `SignUpExpiryJob` boundary produced a recorded
`ArgumentError` failed execution and no false successful mutation. Existing bounded retry/recovery
contract tests passed in the focused queue/OIDC/processor suite with `23 runs / 59 assertions / 0
failures / 0 errors / 0 skips`.

The repository's normal recurring schedules were restored after the probe. No production worker,
production queue database, heartbeat/monitoring, operational rollback, or external provider was
contacted. Those checks remain later deployment/provider gates.

`CF-005` is therefore `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`. Evidence:
`evidence/2026-09-23-cf005-queue-runtime-P6Q7.md`.

#### Frontend Passkey revalidation (2026-09-23)

The changed Passkey frontend surface was revalidated independently of the Rails/PostgreSQL
environment. The initial attempt incorrectly passed the Jest-only `--runInBand` option to Vitest and
failed before test discovery; the corrected command passed all frontend tests. Formatting, lint, and
TypeScript checks, the production Vite build, local dead-code analysis, OpenAPI lint, and the
aggregate `bun run check` also passed. This evidence covers repository-side frontend behavior only
and does not replace
Rails/WebAuthn integration or live authenticator verification.

Evidence: `evidence/2026-09-23-frontend-quality-revalidation-D5E6.md`.

#### Historical Rails loader and CF-011 verification boundary (2026-09-23; superseded by isolated acceptance)

The non-Compose process initially stopped before Rails loading because the repository environment
file's `RUBY_DEBUG_OPEN=false` is interpreted as a truthy untyped option by the vendored `debug`
gem, which attempted to bind a UNIX debugger socket. This was not bypassed by changing repository
configuration. A process-local `RUBY_DEBUG_ENABLE=0` override allowed `bundle exec bin/rails
zeitwerk:check` to complete with `All is good!`.

The same process-local override does not provide database services. The required test preflight and
the focused `ProcessorErasureNotificationState` test still fail before assertions because `primary`
cannot be resolved (`PG::ConnectionBad: could not translate host name "primary" to address:
Temporary failure in name resolution`); `getent hosts primary` and `getent hosts valkey-kvs` return
no records. At the time of this non-Compose run, the DB-backed CF-011 tests remained unverified
and the historical status was `OPEN — EVIDENCE REQUIRED`. That status was superseded by the
isolated acceptance record above. No app, configuration, test, database, or external service was
changed to bypass this boundary.

Evidence: `evidence/2026-09-23-rails-loader-environment-boundary-H7J8.md`.

#### Historical CF-011 integer input boundary correction (2026-09-23)

An adversarial value review found that Ruby's `Integer(value)` conversion silently truncated
fractional numeric values. Retry-policy limits/delays/attempt numbers and verified-receipt
generations now reject non-integral numeric types while retaining accepted integer-string
normalization. TDD RED/green coverage passes for both value boundaries (`4 runs / 15 assertions`
and `6 runs / 24 assertions`); targeted RuboCop, Brakeman, syntax, and diff checks pass. This is a
provider-neutral value-boundary correction and does not close the outstanding DB-backed CF-011
evidence requirement. Evidence: `evidence/2026-09-23-processor-integer-boundary-I9J0.md`.

The same adversarial integer-boundary review found that the bounded retry sweep accepted fractional
`batch_size` values through Ruby's truncating `Integer()` conversion. The public job now accepts
only integer or integer-string batch sizes before applying the existing `1..500` bound. The
regression test is present, but its Rails assertions remain unverified because the current process
cannot resolve `primary`; syntax, repository-wide RuboCop, Brakeman, and diff checks pass. This is a
local bounded-processing correction and does not change the configured batch limit. The acceptance
gap is recorded in the same evidence file.

#### Historical CF-011 state-transition bypass review (2026-09-23)

The follow-up adversarial search found no additional production state-write path that bypasses the
public notification transitions. `NOTIFIED` remains reachable only through the adapter-verified
receipt path, and manual recovery remains a separate authorized operation that advances the
delivery generation. No public controller or route currently invokes manual recovery, so this
review does not invent a new operator role or permission contract. Direct low-level writes found by
the search are confined to tests and migrations. Pure value tests passed, while the required
PostgreSQL/Valkey preflight still fails in the current process because `primary` and `valkey-kvs`
do not resolve; DB-backed state, migration, constraint, and concurrency acceptance therefore
remain unverified. Evidence: `evidence/2026-09-23-cf011-state-bypass-review-K2L3.md`.

The subsequent static revalidation passed the two pure value-contract files, repository-wide
RuboCop (`4773 files inspected, no offenses`), Brakeman (`0 errors, 0 security warnings`),
`zeitwerk:check`, and `git diff --check`. The Rails job assertions and all PostgreSQL/Valkey-backed
CF-011 acceptance remain unverified in the current process. Evidence:
`evidence/2026-09-23-cf011-static-revalidation-L4M5.md`.

#### Boot-dependency classification re-audit (2026-09-23)

The requested distinction between a repository configuration defect and an unavailable runtime was
rechecked from the current source. Test application cache is intentionally `MemoryStore`, but test
rate-limit and Auth-state isolation intentionally construct Valkey-backed stores from
`VALKEY_KVS_HOST` / `VALKEY_KVS_PORT`; `test/test_helper.rb` also cleans those namespaces for every
test. `config/database.yml` independently requires the configured test PostgreSQL host. The
current `primary` and `valkey-kvs` resolution failure is therefore `ENVIRONMENT_UNAVAILABLE`, not
a reason to remove the test KVS dependency or substitute localhost. Evidence:
`evidence/2026-09-23-rails-loader-environment-boundary-H7J8.md`.

The approved provider-neutral CF-011 contract was also extended with a public-job regression for a
provider permanent failure: the notification becomes immutable `PERMANENT_FAILURE`, and a later
normal worker invocation cannot create another attempt. Syntax, targeted RuboCop, and diff checks
pass; the Rails assertion remains unverified until the configured PostgreSQL/Valkey services are
reachable. Evidence: `evidence/2026-09-23-cf011-permanent-failure-test-M6N7.md`.

#### Historical current-session CF-011 and boot-boundary recheck (2026-09-23; superseded by isolated acceptance)

The required preflight and the focused delivery-contract Rails test were rerun with the explicit
devcontainer environment and `PARALLEL_WORKERS=1`. Both stopped before assertions because this
process cannot resolve the configured `primary` PostgreSQL service; `getent hosts primary` and
`getent hosts valkey-kvs` returned no records. The process also has no Podman/Docker client or
Podman socket with which to enter the Compose network. This is the already classified
`ENVIRONMENT_UNAVAILABLE` boundary, not evidence of a repository configuration defect and not a
reason to substitute localhost or remove the intentional test Valkey dependency.

The provider permanent-failure regression, locked-operator recovery rejection, terminal
`NOTIFIED` recovery rejection, and manual-recovery audit-event assertion are present but remain
`UNVERIFIED` until the same commands run in the isolated PostgreSQL/Valkey topology. Retry-policy
and receipt-value boundary tests passed
without Rails boot; repository-wide RuboCop, Brakeman, and `git diff --check` also passed. At that
historical point CF-011 was `OPEN — EVIDENCE REQUIRED`, and CF-003/CF-004 and CF-007 were still
decision-gated. The current blocker table at the top of this plan supersedes those dispositions.
Evidence: `evidence/2026-09-23-cf011-permanent-failure-test-M6N7.md`.
