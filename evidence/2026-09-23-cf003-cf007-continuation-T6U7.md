# CF-003/CF-004 and CF-007 continuation verification

- Date: 2026-09-23
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved.
- External activity: no AWS, Cloudflare, provider, production, shared-database, or GitHub write
  was performed.

## Scope

This record covers the continuation of the approved pre-deployment CF-003/CF-004 and CF-007
repository slice. It does not claim production owner inventory, live authority cutover, Base
registration, real credential fingerprints, deployed-caller migration, or external retirement.

## Implemented and statically verified

- `AuthorityOwnerDirectBindingBackfillOperation` remains surface-local, lock-protected,
  idempotent, conflict-rejecting, and refuses membership/administrator/legacy-owner inference.
  A reviewed `owner_public_id` is accepted only through the configured surface-local principal
  class.
- `AuthorityOwnerCutoverGuard` is read-only and fail-closed. It blocks a family cutover when
  ownership is unresolved, the authority schema is incomplete, or the resource model exposes no
  explicit lifecycle contract. It does not switch consumers or enable authorization reads.
- `RegionalRpClientMatrix` records the approved 13-cell logical target, derives Core URI bindings
  only from `RegionalRootUrlRegistry`, derives the already-established global `edit-org` binding
  from `PUBLIC_EDIT_STAFF_URL`, exposes independent logical JWT namespaces and RP-session client
  bindings, and refuses missing Side host sources. Its regional lookup rejects the global `edit-org`
  cell rather than treating a regionless RP as regional. It does not invent audience values,
  credentials, registry entries, or Host-derived clients.

## Verification performed in this process

The required environment was selected without printing values:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_app_zenith_db
```

`config/credentials/test.key` was present. The required preflight command was attempted:

```text
bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'
```

It failed before application checks because the current process could not resolve the required
PostgreSQL service:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

Repeated read-only checks also returned no records for `getent hosts primary` and
`getent hosts valkey-kvs`. No localhost substitution, `/etc/hosts` edit, Compose edit, or
application change was used.

The requested focused command was then attempted:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/operations/authority_owner_direct_binding_backfill_operation_test.rb \
  test/operations/authority_owner_cutover_guard_test.rb \
  test/queries/authority_owner_migration_inventory_test.rb \
  test/values/regional_rp_client_matrix_test.rb \
  test/values/auth_boundary_authority_map_test.rb
```

It did not reach a test assertion because Rails stopped while connecting to `primary` during test
schema checks. No full suite was started after this failed focused prerequisite.

The following non-database checks passed:

```text
ruby -c app/operations/authority_owner_cutover_guard.rb                         # Syntax OK
ruby -c app/operations/authority_owner_direct_binding_backfill_operation.rb      # Syntax OK
ruby -c app/values/regional_rp_client_matrix.rb                                   # Syntax OK
ruby -c test/operations/authority_owner_cutover_guard_test.rb                     # Syntax OK
ruby -c test/values/regional_rp_client_matrix_test.rb                             # Syntax OK
bundle exec rubocop <the five files above>                                         # 5 files, no offenses
git diff --check                                                                   # passed
```

After the adversarial fixes described below, the affected eight Ruby files were rechecked with
syntax validation and targeted RuboCop; all eight were clean, and `git diff --check` still passed.

```text
bundle exec rubocop <the eight affected Ruby and test files>                       # 8 files, no offenses
```

The focused command was retried after the latest repository-only changes with the same explicit
test environment. It still exited before loading a test case because Rails could not resolve the
PostgreSQL service name:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/operations/authority_owner_direct_binding_backfill_operation_test.rb \
  test/operations/authority_owner_cutover_guard_test.rb \
  test/queries/authority_owner_migration_inventory_test.rb \
  test/values/regional_rp_client_matrix_test.rb \
  test/values/auth_boundary_authority_map_test.rb

ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

Focused result: 0 runs, 0 assertions, 0 failures, 1 boot error; full suite was not started because
the focused prerequisite did not pass. The process reported `/home/global` as non-writable and
Bundler selected the repository `tmp` directory as its temporary home; no application or test
file was changed to work around either condition.

After the lifecycle-candidate classification and global `edit-org` binding refinements, the same
focused command was retried once more. It produced the same pre-test `primary` DNS failure and
again yielded no test-run counts; the full suite remains intentionally unstarted in this process.

The subsequent static recheck covered the nine affected implementation/test Ruby files; syntax,
targeted RuboCop, and `git diff --check` all passed.

The database-independent frontend suite also passed:

```text
bun run test
Test Files  84 passed (84)
Tests       1036 passed (1036)
```

Coverage-independent repository quality checks also passed in this process:

- `bun run format:check`: passed across 574 files.
- `bun run lint`: passed.
- `bun run typecheck:verify && bun run typecheck`: passed.
- `bun run deadcode`: passed with configuration hints only; no failure.
- `bun run openapi:lint`: all app/com/org descriptions valid.
- `bun run openapi:verify`: passed; generated bundles matched the tracked bundles.
- `bundle exec brakeman --no-pager`: 0 errors and 0 security warnings.
- `bundle exec rubocop`: 4,779 files inspected, no offenses.

The required preflight was retried after the latest repository-only changes and failed at the same
PostgreSQL DNS boundary:

```text
bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

The focused Rails command was also retried and stopped during Rails test-schema boot with the same
`primary` resolution error. It produced no test assertions; the full Rails suite was not started.

Earlier Compose-backed focused and full-suite results remain historical evidence in
`evidence/2026-09-23-cf003-cf007-predeployment-slice-N4P5.md`; they are not reclassified as a
current-process test result here.

## Adversarial review result

- The original cutover guard filename violated the repository object-placement suffix rule. It
  was corrected to `AuthorityOwnerCutoverGuard`; no compatibility alias was retained.
- The first guard revision treated any ownership row as resolved. Review found that this could
  allow an inactive or access-blocked principal to satisfy the cutover gate. Inventory now exposes
  owner eligibility separately, and an ineligible authoritative owner is classified as unresolved;
  the guard therefore fails closed.
- Review also found that a not-yet-applied authority schema could be reported as `not_applied`
  and then queried as if its ownership tables existed. Inventory now skips ownership-table reads
  in that state while preserving the existing exception for partially applied schemas.
- The six resource tables do not expose an explicit resource lifecycle contract. Treating a
  persisted row as active would weaken the approved lifecycle rule, so the guard correctly keeps
  the cutover blocked.
  The current SQL structure confirms that `personas`, `enterprises`, `individuals`, `companies`,
  `agents`, and `bureaus` contain identity/name/title and Rails timestamps but no lifecycle state
  or lifecycle boundary column from which active, retained, or discarded can be derived.
- The guard was tightened again after review: even after a future explicit `lifecycle_active?`
  contract exists, an ownership row is not cutover-ready unless both the principal and the
  resource report eligible. No generic `active?` method is treated as a lifecycle authority.
  The guard's contract-presence check now uses the same explicit method boundary as inventory.
- Inventory classification now reports an ineligible authoritative resource separately from an
  ineligible authoritative principal, so a future lifecycle rejection cannot be misreported as a
  resolved owner fact.
- Membership inventory now distinguishes multiple legacy candidates as
  `ambiguous_legacy_candidates` and inactive-only candidates as
  `inactive_only_legacy_candidate`; neither classification can create an authority relation.
- Side JP/US canonical host sources are incomplete in the current repository. No regional Side
  URI, audience, key, or active registry entry was guessed.
- Existing active seven-client and `core-next-rp` paths remain compatibility paths. No caller,
  RP-session, audience, or external registration was silently migrated.

The CF-007 contradiction is concrete rather than a missing deployment observation:

- `config/routes/side.rb` accepts the boot-configured Side hosts plus the local
  `wide.app.localhost`, `wide.com.localhost`, and `wide.org.localhost` aliases.
- `.env.example` and `.env.devcontainer.example` provide only `PUBLIC_SIDE_SERVICE_URL`,
  `PUBLIC_SIDE_CORPORATE_URL`, and `PUBLIC_SIDE_STAFF_URL`; they do not provide independent JP
  and US Side host values.
- `docs/operations/core-nextjs-zero-cookie-edge-contract.md` names `side.jp.umaxica.app`, but
  that document is not a complete 13-cell registry source and does not define the corresponding
  US values or audience semantics.
- `app/values/oidc_client_stores_static_client_store.rb` still defines the active seven-client
  registry and `core-next-rp`; its audience values are for those old registrations, not a
  canonical regional audience mapping.

Consequently, the repository does not contain one authoritative set of exact Side JP/US URI
bindings or regional audience values from which the approved matrix can safely be activated.

## Current status

- `CF-003/CF-004`: `OPEN — IMPLEMENTATION REQUIRED`. Lifecycle representation, complete
  family-level mapping/backfill evidence, consumer cutover, and post-cutover forward-recovery
  proof remain incomplete.
- `CF-007`: `OPEN — CONTRACT CONTRADICTION`. The approved matrix and local isolation contract
  exist, but Side host sources and regional audience semantics are not uniquely defined by the
  repository; exact registry/caller/RP-session migration must not guess them.
- `CF-005`: unchanged, `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`.
- `CF-011`: unchanged, `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`.

The missing service DNS is an environment verification blocker for this process, not a reason to
weaken tests or alter application configuration. The global `edit-org` binding addition was
syntax-checked and RuboCop-checked; its focused runtime assertion remains unexecuted because the
same PostgreSQL boot dependency failed before tests loaded. A subsequent read-only environment
check found no `primary`/`valkey-kvs` entries in `/etc/hosts`, no usable route in
`/proc/net/route`, and no `podman` executable inside this process; no network or host configuration
was changed.

The Frozen Plan was also re-audited after the approved CF-003/CF-004 and CF-007 decisions. The
older resumption table is now explicitly labeled historical/superseded, so it cannot be read as
requiring production or deployed-caller evidence before pre-deployment repository work. The
current amendments remain the active scope: approved owner mapping and regional matrix work may
proceed locally, while missing lifecycle semantics, exact regional audience/Side URI sources, and
consumer migration remain fail-closed implementation/contract gaps. `git diff --check` passed after
the documentation correction.

## Additional regional host validation slice

The regional binding contract now rejects canonical host sources that embed userinfo or use a
non-HTTP(S) scheme. This prevents credentials or unsupported schemes from being carried into
redirect, post-logout, or backchannel URI bindings. Two public-behavior regression tests were added
before the implementation. The focused Rails test command was attempted, but Rails schema boot
failed before assertions with the same `primary` PostgreSQL DNS error documented above. After the
implementation, Ruby syntax, scoped RuboCop (2 files, no offenses), and `git diff --check` passed.
The database-backed assertions remain unverified until the Compose PostgreSQL/Valkey network is
available.

The first DB-free smoke exposed a portability defect in the new validation: `Array#exclude?` was
not available under the minimal Active Support load used by the value contract. The implementation
was corrected to use standard Ruby comparisons; no security condition was relaxed. The corrected
DB-free smoke passed for credential-bearing userinfo rejection, non-HTTP scheme rejection, and a
valid HTTPS origin. Syntax, scoped RuboCop, and `git diff --check` passed again.

The focused Rails test was retried after that correction with the explicit devcontainer environment
and `PARALLEL_WORKERS=1`; it again stopped during schema boot at
`PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name
resolution`, before any assertions. The full Rails suite was not started.

The subsequent static call-path audit found no production controller, policy, service, or registry
consumer of `RegionalRpClientMatrix`, and no consumer that treats `AuthorityOwnerCutoverGuard` as a
successful authorization switch. The existing quota policies and creator operations use the
surface-local ownership relations, but the legacy membership/assignment authorization paths remain
in place until the lifecycle and family-level cutover gates are satisfied. This confirms that the
new pre-deployment contracts are not silently active or partially cut over.

The plan re-audit also converted remaining present-tense blocker statements inside older CF-011
verification records into explicitly historical statements. The current status table is now the
only current disposition source for CF-003/CF-004, CF-005, CF-007, and CF-011; `git diff --check`
passed after that wording correction.

## Canonical-source recheck after approved CF-007 decision

The repository-wide source recheck was narrowed to the live configuration and registry sources;
no production or external system was queried. The following facts were confirmed:

- `app/values/regional_root_url_registry.rb` contains canonical Core roots for both `jp` and `us`
  on `app`, `com`, and `org`. `RegionalRpClientMatrix` may therefore derive the six Core URI
  bindings without using request input.
- `.env.example` and `.env.devcontainer.example` contain only the legacy aggregate Side variables
  `PUBLIC_SIDE_SERVICE_URL`, `PUBLIC_SIDE_CORPORATE_URL`, and `PUBLIC_SIDE_STAFF_URL`. They do not
  contain independent `PUBLIC_SIDE_<FACE>_JP_URL` and `PUBLIC_SIDE_<FACE>_US_URL` sources.
- `docs/operations/core-nextjs-zero-cookie-edge-contract.md` mentions a Side JP hostname but does
  not define a complete 12-cell Side registry or the corresponding US values. It is therefore not
  an authoritative complete matrix source.
- `app/values/oidc_client_stores_static_client_store.rb` still exposes the active seven-client
  registry and `core-next-rp`. Its `aud` values (`core-app`, `core-com`, `core-org`, `side-app`,
  `side-com`, `side-org`, and `edit-org`) are the existing non-regional registrations; they do not
  provide independently bound regional audience identities.
- No current repository source supplies regional audience values that can be adopted without
  inventing a wire contract. The approved decision expressly forbids deriving `aud` from the
  client ID or arbitrary Host input.

Accordingly, no regional registry entry, credential namespace activation, caller mapping, or
audience value was added to bypass this contradiction. The matrix remains a fail-closed contract
with exact approved IDs and Core URI derivation only; `CF-007` remains `OPEN — CONTRACT
CONTRADICTION` pending an authoritative Side URI/audience source or an explicit contract decision.
This is pre-deployment repository evidence, not a production/deployment blocker.

## Regional complete-binding fail-closed slice

The regional matrix previously exposed one method that returned URI, namespace, and RP-session
metadata but no audience. That shape could be mistaken for a complete OIDC registration by a future
caller. The test was tightened first to require a complete binding to fail when no canonical
audience exists. The implementation then split the public contract into:

- `uri_binding_for`: derives only the exact URI and local binding values available from approved
  repository sources;
- `binding_for`: refuses with `MissingCanonicalAudience` until a canonical audience source exists.

No audience value was invented, and no registry or caller was activated. The database-independent
public contract smoke passed:

```text
regional binding fail-closed smoke passed
```

Syntax, targeted RuboCop, and `git diff --check` also passed. The Rails test file was not counted as
executed because the required PostgreSQL service was still unavailable at the Rails boot boundary;
the focused test remains unverified rather than being weakened or skipped.

## Cross-surface owner-identifier collision slice

The owner backfill operation was adversarially reviewed against the repository's non-global
`public_id` contract. If the same public identifier exists in another principal surface, a string
alone cannot prove which surface supplied the candidate. The RED contract was added before the
implementation: an app organization owner candidate colliding with a com principal is classified
as `manual_review` with `cross_surface_owner_candidate`, and no ownership row is created.

The implementation now checks the other concrete principal classes before resolving an explicit
surface-local owner. A collision is rejected rather than choosing the local row or silently
creating a cross-surface authority relation. Syntax and targeted RuboCop passed for the operation
and its test. The required Rails preflight was then attempted with the explicit devcontainer
environment and failed before test loading:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

The focused owner/RP test set therefore remains unexecuted in this process; no test was deleted,
skipped, mocked, or weakened. The database-independent regional binding smoke remains passing.

The approved six mapping table is now also asserted explicitly in the inventory contract test:
`Client -> ClientPersona/Enterprise`, `Visitor -> Individual/Company`, and `Operator ->
Agent/Bureau`, each through its concrete surface-local ownership model. This is a regression guard,
not a cutover. The test file passed syntax and targeted RuboCop; Rails execution remains subject to
the same unavailable PostgreSQL service.

## Broad static quality recheck

After the continuation slices, repository-wide static checks were rerun without database or
external-service access:

```text
bundle exec rubocop             # 4,779 files inspected, no offenses
bundle exec brakeman --no-pager # 0 errors, 0 security warnings
git diff --check                # passed
```

These checks establish static quality only. They do not promote either open blocker to closed and
do not substitute for the unavailable PostgreSQL-backed focused tests.

The DB-independent adversarial smoke was rerun after the review. It rejected credential-bearing,
non-HTTP, path-bearing, and query-bearing Edit host sources, derived the canonical Core callback,
and rejected the incomplete regional binding because no audience source exists:

```text
regional URI and complete-binding adversarial smoke passed
```

## Current pre-deployment acceptance gap matrix

| Blocker | Acceptance item | Current evidence | Disposition |
| --- | --- | --- | --- |
| CF-003/CF-004 | Approved six principal/resource/ownership mappings | Explicit `RESOURCE_CONFIGS` and mapping regression test | Satisfied locally |
| CF-003/CF-004 | Membership, administrator, legacy, ambiguous, inactive, and cross-surface candidates never auto-promote | Inventory classification, direct backfill manual-review results, collision rejection | Satisfied locally; DB execution pending |
| CF-003/CF-004 | Idempotent backfill and unique-owner conflict rejection | Locked operation and conflict/idempotency tests | Implemented; DB execution pending |
| CF-003/CF-004 | Resource lifecycle eligibility | Six resource models expose no explicit lifecycle contract or state source | **Not satisfied; implementation/data-shape required** |
| CF-003/CF-004 | Family-level consumer cutover and point-of-no-return forward recovery | Static call-path audit shows no new consumer is active; legacy membership paths remain | **Not satisfied; depends on lifecycle and cutover design** |
| CF-007 | Approved 13 logical IDs and independent logical namespaces | `AuthBoundaryAuthorityMap` and `RegionalRpClientMatrix` | Satisfied locally |
| CF-007 | Core JP/US and global Edit exact URI derivation | `RegionalRootUrlRegistry` and explicit Edit host | Satisfied locally |
| CF-007 | Side JP/US URI source | No independent Side JP/US configuration exists | **Not satisfied; canonical source required** |
| CF-007 | Independent regional audience values | Existing registry only has non-regional audience values; no regional SSOT exists | **Not satisfied; contract/source required** |
| CF-007 | Active registry/caller/RP-session migration and cross-acceptance tests | New matrix has no production consumer; old registry remains active | **Not satisfied; depends on URI/audience contract** |

This matrix is the current repository-side acceptance boundary. It does not treat missing
production, provider, AWS, Cloudflare, or deployed-caller evidence as a current blocker; those
remain later deployment/provider gates. It also does not promote a partial implementation to a
closed status merely because the local contract objects exist.

The inventory and backfill classification was also tightened to preserve the approved distinction
between inactive and suspended principals. A principal with the approved active status but blocked
login/access is classified as `suspended_principal`; an inactive status remains
`inactive_principal`. Neither is an eligible owner candidate, and the backfill operation still
returns manual review rather than transferring or reviving ownership. This changes classification
metadata only and does not activate an authorization consumer. Syntax, targeted RuboCop, and
`git diff --check` passed; DB-backed regression execution remains unverified at the PostgreSQL
boot boundary.

## Lifecycle SSOT recheck and conflict-ledger correction

The lifecycle sources were re-read before considering another CF-003/CF-004 implementation slice.
`adr/umaxica-v1-core-resource-architecture.md` and `adr/authority-lifecycle-table-policy.md`
require explicit authority/lifecycle state tables, but do not define the concrete state relation,
state keys, transition service, or current-state pointer for the six adopted Persona/Organization
resources. `docs/architecture/persona-organization-authority.md` explicitly records that those
resource tables have no lifecycle state yet. `adr/retention-lifecycle-column-boundary.md` and the
`Retainable` concern separately reserve `discard_at` and `purge_eligible_at` for retention and
forbid using them as a resource lifecycle substitute. No new lifecycle column, table, or transition
was therefore invented in this slice.

The repository-wide conflict ledger also contained stale decision-gated CF-007 wording. Its CF-003,
CF-004, and CF-007 entries now identify the old text as historical and point to the current Frozen
Plan disposition. CF-007 now records the approved 13-client decision and the concrete remaining
repository contradiction (missing independent Side JP/US host sources and regional audience SSOT)
without activating an incomplete registry.

The regional RP ADR was checked for the same stale wording. The paragraph that described the
2026-09-17 decision as unresolved is now explicitly historical/superseded by its 2026-09-23
regional expansion amendment; deployment and external registration gates remain separate.

## Current environment and DB-free verification recheck

The required preflight was attempted in `/home/global/workspace` with
`UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example` and the approved test database
list. The process has `/run/.containerenv`, but `getent hosts primary` and `getent hosts valkey-kvs`
returned no records. The exact preflight stopped before Rails boot with:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

No host, Compose, application, or environment file was changed. The focused Rails tests and full
suite were not started after this prerequisite failure; no test was deleted, skipped, mocked, or
weakened.

The database-independent adversarial smoke was rerun after the documentation correction and passed:

```text
regional URI and complete-binding adversarial smoke passed
```

It derived the canonical `core-app-jp` URI, rejected userinfo and non-HTTP Edit origins, and
rejected a complete regional binding while no canonical audience source exists. Syntax checks for
the owner inventory, backfill operation, cutover guard, authority map, and regional matrix passed;
the ten affected Ruby/test files were RuboCop-clean; `git diff --check` passed.

The current pre-deployment dispositions remain unchanged:

- `CF-003/CF-004`: `OPEN — IMPLEMENTATION REQUIRED`; lifecycle data shape and family-level consumer
  cutover are still not defined/implemented, so no authorization read switch was made.
- `CF-005`: `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED` based on the existing isolated Compose
  evidence; the unavailable current process does not reopen that disposition.
- `CF-007`: `OPEN — CONTRACT CONTRADICTION`; the approved matrix and fail-closed local bindings are
  present, but Side JP/US host and regional audience sources are absent.
- `CF-011`: `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED` based on the existing isolated Compose
  evidence; provider/deployment gates remain separate.

## Adversarial correction: legacy owner evidence is not sufficient for mutation

A review of the approved CF-003/CF-004 decision found that the backfill operation still allowed an
active direct identity binding to create an ownership row when no reviewed `owner_public_id` was
provided. That would have promoted a legacy binding by itself, contrary to the approved rule that
legacy identity bindings are candidate evidence only. The RED test now requires an unreviewed direct
binding to return `manual_review` with `explicit_owner_required`; the GREEN implementation requires
an explicit reviewed surface-local owner for every backfill mutation, then rechecks the binding and
principal under the existing locks. The organization membership path remains manual-review without
an explicit owner, and cross-surface owner identifiers remain rejected.

Syntax and RuboCop passed for the changed operation and test. The focused Rails test command was
attempted after the correction but could not load the test environment because `primary` was not
resolvable; it produced no test runs or assertions. The DB-free regional matrix smoke remained
passing. No test was skipped, deleted, mocked, or weakened.

The post-correction repository-wide static checks also passed:

```text
bundle exec rubocop             # 4,779 files inspected, no offenses
bundle exec brakeman --no-pager # 0 errors, 0 security warnings
git diff --check                # passed
```

These results are static checks only and do not replace the unavailable PostgreSQL-backed
authority tests.

The backfill regression set was extended with the approved suspended-principal boundary: an
administratively access-blocked principal with otherwise active status is classified as
`suspended_principal` and cannot receive a new authority relation. The test is syntax-valid and
RuboCop-clean; Rails execution remains blocked before test loading by the unavailable `primary`
service.

The regional matrix regression set was also extended to assert that incomplete regional client IDs
are not exposed through the active compatibility registry. This preserves expand-and-contract
ordering and prevents a partial registry activation while Side URI and audience sources are absent.
The test is syntax-valid and RuboCop-clean; its Rails-backed execution remains unverified at the
same boot boundary.

The final DB-free regional smoke additionally rejected path-bearing and query-bearing canonical Edit
origins, as well as the incomplete audience binding, while preserving the canonical Core callback:

```text
regional URI and complete-binding adversarial smoke passed
```

## Canonical audience lookup correction

The regional matrix no longer contains a permanently nil audience placeholder. Its complete
binding path now reads `aud` only from the existing `OidcClientRegistry`; it still raises
`MissingCanonicalAudience` when the requested regional client is not registered. This preserves
the approved rule that an audience is never derived from a client ID, host, or region suffix.
The active registry still contains no regional client registrations, so this change does not
activate any new RP or alter the existing seven-client registry.

The Rails-focused test was attempted before the production change but could not reach test loading
because `primary` was not resolvable. A DB-free Ruby contract smoke then exercised both paths:
an unregistered regional client was rejected, and a registry-provided audience was returned
unchanged without client-ID derivation. Result:

```text
regional RP canonical-source smoke passed
```

The changed value/test files pass syntax and targeted RuboCop; PostgreSQL-backed assertion counts
remain unverified in this process.

## Post-change verification

After the registry-source correction, the affected ten Ruby files passed targeted RuboCop with no
offenses. The repository-wide security/static checks also passed:

```text
bundle exec brakeman --no-pager       # 0 errors, 0 security warnings
git diff --check                      # passed
bun run test                          # 84 files, 1036 tests passed
bun run format:check                 # 574 files passed
bun run lint                          # passed
bun run typecheck:verify && bun run typecheck  # passed
```

These checks do not replace the blocked Rails tests. The required environment preflight and the
focused `regional_rp_client_matrix_test.rb` command both stopped before test loading because the
current process could not resolve the PostgreSQL service name `primary`; the complete error is
recorded above. No Rails full suite was started after that failed prerequisite.

## Regional registration-binding adversarial correction

The first canonical-audience correction still accepted any registered `aud` without checking the
rest of the regional registration. The matrix now validates the existing registry's client ID,
actor/resource type, realm-specific redirect URI, post-logout URI, backchannel URI, and logical
JWT namespace against the approved cell. It also rejects an audience already used by another
registered approved cell. A missing regional registration remains `MissingCanonicalAudience` and no
client, host, audience, or credential is synthesized.

The DB-free registration-binding smoke passed after this correction:

```text
regional RP registration-binding smoke passed
```

The added public-contract tests cover an exact-URI mismatch and shared regional audience. Rails
execution remains unverified because the same focused command stopped before test loading at
`PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name
resolution`.

## Final slice adversarial review

The current slice was reviewed against the approved attack cases. A legacy identity binding can
no longer create an authority row without a reviewed local owner; membership, administrator,
legacy Organization, inactive, suspended, cross-surface, and ambiguous candidates remain
non-authoritative. The cutover guard cannot report ready without an applied authority schema, an
eligible owner for every scanned resource, and an explicit resource lifecycle contract. No
consumer was switched to the new relation, so there is no partial row-level cutover or rollback
claim to hide.

For regional RPs, arbitrary Host input is not read, missing Side host sources fail, unregistered
regional clients fail before complete binding, and registered cells with wrong actor binding,
redirect/logout/backchannel URI, JWT namespace, or shared audience fail closed. The active
compatibility registry remains unchanged; no regional caller, session, code, key, or external
registration was activated. The remaining CF-007 contradiction is therefore still the repository's
missing independent Side JP/US host source and canonical regional audience/registration source,
not missing production evidence.

The final repository-wide static recheck after the schema gate passed `bundle exec rubocop`
(4,779 files, no offenses), `bundle exec brakeman --no-pager` (0 errors, 0 security warnings),
and `git diff --check`. These checks do not replace the unavailable PostgreSQL-backed focused
tests.

## Backfill schema-gate correction

The owner backfill now checks the existing explicit authority-table inventory before looking up a
resource or entering a mutation path. An unapplied authority schema returns `manual_review` with
`authority_schema_not_applied`; a partially applied schema continues to raise the inventory's
explicit incomplete-schema error. This prevents a migration operation from reaching a missing
ownership table or treating an uninstalled schema as an empty authority graph. The new public
contract test covers the no-lookup refusal path.

The changed query, operation, and test pass syntax and targeted RuboCop. PostgreSQL-backed
execution remains subject to the current `primary` DNS/preflight boundary recorded above.
