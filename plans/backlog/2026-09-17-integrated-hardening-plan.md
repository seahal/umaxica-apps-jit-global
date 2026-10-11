# Integrated hardening and reachability implementation plan

## Status

GO_FOR_UNBLOCKED_SLICES. Phase 0 is complete as an initial inventory. The observability correction,
dashboard reachability, URL policy, OIDC delivery failure classification, explicit Solid Queue
configuration, Phase 1 vocabulary migration, the Phase 2 authority schema foundation, static
RP-session realm/revocation hardening, enforcement appeal recovery, sign-up guardrail enforcement,
OTP resend serialization, and one-time OTP consumption are implemented as local slices. Historical
focused Rails runs for the authority vocabulary/schema and creator/concurrency contracts are
recorded, but the current session cannot reproduce database-backed tests because the isolated
PostgreSQL and Valkey services are unavailable. The broader Rails runtime, database
migration/rollback proofs, and real worker execution remain unverified. The adopted
Persona/Organization redesign is not enabled until its source-owner inventory, connection proof,
lifecycle gates, and migration gates are complete. #845 remains blocked by the absence of an
approved origin/edge body-size contract, and #846 remains blocked by the unresolved Auth/Base
issuance handoff contract; neither is silently implemented with guessed semantics.

## Current handoff (2026-09-18)

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

### Current source-to-owner dry-run inventory

| Surface / resource        | Current owner-like source                                                                                                 | What the source actually proves                                                                                                             | Migration status                                         |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| app `Persona`             | `personas.client_identity_id`, unique and non-null; `ClientIdentity` has one `persona`.                                   | One RP binding is linked to one concrete resource; it does not prove that the linked `Client` is the adopted owner principal.               | `BLOCKED`; live row inventory `UNRUN`.                   |
| app `Enterprise`          | No owner column. `PersonaMembership` links Personas to an Enterprise and unit; `primary` applies to a Persona membership. | Membership/primary state is not a single owner relation.                                                                                    | `BLOCKED`; never auto-promote a membership or first row. |
| com `Individual`          | `individuals.visitor_identity_id`, unique and non-null; `VisitorIdentity` has one `individual`.                           | One RP binding is linked to one concrete resource; it does not prove an adopted `Visitor` owner row.                                        | `BLOCKED`; live row inventory `UNRUN`.                   |
| com `Company`             | No owner column. `IndividualMembership` links Individuals to a Company and unit.                                          | Membership/primary state is not a single owner relation.                                                                                    | `BLOCKED`; no owner guess.                               |
| org `Agent`               | `agents.operator_identity_id`, unique and non-null; `OperatorIdentity` has one `agent`.                                   | One RP binding is linked to one concrete resource; it does not prove an adopted `Operator` owner row.                                       | `BLOCKED`; live row inventory `UNRUN`.                   |
| org `Bureau`              | No owner column. `AgentMembership` links Agents to a Bureau and unit.                                                     | Membership/primary state is not a single owner relation.                                                                                    | `BLOCKED`; no owner guess.                               |
| legacy org `Organization` | Nullable `organizations.operator_id` plus legacy hierarchy and `user_organizations`.                                      | A legacy operator reference may exist, but its principal/table/approval semantics are not equivalent to the adopted Operator ownership row. | `BLOCKED`; requires consumer and data inventory.         |

The required dry run must report counts and opaque identifiers for missing owners, multiple
candidates, disabled principals, cross-surface mismatches, duplicate public IDs, and inconsistent
assignments. It has not run in this session because the test/database boundary is unavailable. There
is no safe basis to select the first assignment, promote an administrator, or silently skip an
ambiguous row.

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
  The new authority migrations are authored but have not been applied in this environment, and live
  row counts are unverified.
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
- Tests: Ruby syntax, scoped RuboCop, and diff checks pass. The Rails contract test was attempted
  with explicit loopback test PostgreSQL/Valkey variables and could not boot because PostgreSQL was
  not listening at `127.0.0.1:5432`; no development or production datastore fallback was used.
- Documentation: this section records the implementation boundary; CF-003 remains blocked until the
  report runs against isolated databases and ambiguous rows are reviewed. Evidence records the
  static pass and the unavailable runtime prerequisite.
- Completion criteria: static implementation checks pass, the isolated report produces counts and
  opaque identifiers for every surface/resource kind, an approved mapping resolves all ambiguous
  rows, and only then may a separate migration/cutover slice be designed. This sub-slice does not
  satisfy the owner-mapping or authorization-cutover gate by itself.

## Requirement ledger

| Requirement group                        | Repository evidence                                                                                                                                                                                                                                                                                                       | Current decision                                                                                                                                                                                                                                                                                   | Planned position                                                                                                                                         |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Dashboard reachability                   | Base root pages are the signed-in dashboards. They linked to identity, accounts/organizations, selector/switcher, and machine protocol endpoints. `BasePreferenceIndexPage` omitted calendar, clock, and currency. The identity hubs already expose surface-local human-facing children.                                  | GO for the missing intentional links and Preference hub links; remove machine endpoint links and keep child pages under their hubs. Exclude mutation-only, callback, ceremony, and bearer-capability URLs.                                                                                         | Phase 2 implementation is complete; the selected runtime reachability subset passes, while the sign-out path remains blocked by unavailable test Valkey. |
| Identity hub                             | `base/app`, `base/com`, and `base/org` identity controllers already have surface-local sections and routes.                                                                                                                                                                                                               | GO for only verified omissions; no dashboard deep-link dump.                                                                                                                                                                                                                                       | Phase 2 audit and tests.                                                                                                                                 |
| Avatar                                   | Org Avatar has `show`, `edit`, `update`, and `destroy`; the current show props do not yet prove a show-to-edit link. The adopted Persona prompt explicitly excludes Avatar design/RBAC/lifecycle work.                                                                                                                    | Do not expand Avatar behavior in the Persona slice. Any navigation-only change must remain isolated and be re-evaluated against that exclusion.                                                                                                                                                    | Conflict CF-006; no enabling change until scoped.                                                                                                        |
| Promotional unsubscribe                  | Tokenized unsubscribe capability is a real bearer capability. No dashboard token embedding is permitted.                                                                                                                                                                                                                  | No real token in HTML. A preview is optional and must be a development/test-only read-only mechanism; otherwise defer.                                                                                                                                                                             | Phase 2 security review; likely deferred unless an existing preview is found.                                                                            |
| Offline page                             | Rails PWA offline routes exist on Base/Side/Auth/Palm surfaces and are GET-only framework routes.                                                                                                                                                                                                                         | Base app/com/org offline links are safe if exact helpers exist; never link the service worker as a human page.                                                                                                                                                                                     | Phase 2.                                                                                                                                                 |
| Solid Queue                              | The original `config/queue.yml` used YAML anchors and `queues: "*"`; recurring entries omitted explicit queue/priority/args and development/production sets differed. Concrete jobs and gem defaults have now been inventoried.                                                                                           | Exact environment mappings, workers, dispatcher/scheduler values, recurring entries, and retention isolation are implemented. Real `bin/jobs check`/worker execution remains unverified because Rails boot/services are unavailable.                                                               | Phase 3 implementation is complete; runtime verification is blocked by CF-002.                                                                           |
| OTel correlation                         | `ActorSupport#set_current_observability` and Core Browser API installed `request.request_id` as `trace_id`; Lograge emitted only `request_id` and `host`.                                                                                                                                                                 | A small resolver now reads only a valid OTel SpanContext, Actor and Lograge use it, and request ID remains separate. OTel remains disabled in test and opt-in in development. The configured Lograge callable and Actor/invariant tests pass; deployed lifecycle remains outside this environment. | Phase 1 implementation complete; deployed/runtime collector verification remains unverified.                                                             |
| URL reserved characters                  | The current prompt allocates `@` only to Core Avatar handles and reserves `~`, `$` in URLs, `#`, `?`, `/`, `\\`, and `!`.                                                                                                                                                                                                 | Document and test the policy without introducing routes or changing Avatar. Search current routes/identifiers for conflicts first.                                                                                                                                                                 | Phase 4 documentation/static contract slice.                                                                                                             |
| RP/session hardening                     | Current repository uses surface-local principals, tokens, RP records, Valkey ceremony state, and multiple auth boundaries. The adopted contract requires parent-session/RP uniqueness, explicit realm/client binding, PostgreSQL revocation authority, and no request-time RP lookup.                                     | Security-critical; no guessed migration or compatibility fallback. Build an evidence-backed session/RP matrix and add regression tests before any schema change.                                                                                                                                   | Phase 5; blocked until connection/contract inventory is complete.                                                                                        |
| OTP/signup/enforcement/body limits       | Existing ceremony, enforcement, request parsing, and rate-limit code is distributed across controllers, concerns, values, and jobs.                                                                                                                                                                                       | #841 guardrail bypass is fixed for contact-verified email/telephone tickets; the state machine and policies require the guardrail before checkpoint. Social callback completion remains its existing separate path. Other OTP/body-limit claims require path-specific evidence.                    | Phase 5, separate vertical slices; guardrail sub-slice implemented.                                                                                      |
| Expired signup cleanup                   | `SignUpTermination` and `SignUpArtifactCleanup` already provide the domain boundary; no expiry sweep was wired at the historical reference.                                                                                                                                                                               | `SignUpExpiryJob` now re-discovers expired app/com flows on `retention`, delegates the existing operation, and is explicitly scheduled in development/production. Request-time expiry remains authoritative. Worker/race execution is unverified.                                                  | Phase 3 implementation complete; isolated Solid Queue verification remains blocked by CF-002.                                                            |
| Chronicle/audit/retention                | Chronicle and fallback writers exist across DB boundaries; retention uses explicit model lists and cross-database cleanup.                                                                                                                                                                                                | Preserve accepted non-atomic audit gap; no new transactional outbox. Retention deletion stays blocked where holds, archive, or legal policy are unverified.                                                                                                                                        | Phase 5/6 audit and dry-run slices.                                                                                                                      |
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
  OTel-disabled behavior remains nil/absent without SDK startup. Rails request/runtime tests are
  still unverified until CF-002 is cleared.

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
  and all selected human pages are reachable through the intended hierarchy. Runtime reachability
  remains unverified until CF-002 is cleared.

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
- Auth currently creates the browser session during its authentication sequence, retains the
  `sign-rp` client identity, and then registers a Base result/resume handoff. The adopted Base-only
  issuer contract does not yet define the complete browser binding, one-shot result, issuer/realm,
  AAL/AMR, session-limit, stale-result, and rollback semantics needed for a safe relocation. The
  affected work remains `CF-010`; no partial issuer cutover was made.

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

### Phase 7 — Persona/Organization vocabulary and authority migration

- Purpose: migrate the existing concrete model graph to the adopted independent surface-local
  Persona/Organization interfaces and explicit Client/Visitor/Operator authority.
- Current state: concrete names and concerns overlap the adopted vocabulary, current resource rows
  reference RP Identity records, and assignments/memberships encode existing authority assumptions.
- Target state: interfaces are real concerns/contracts, concrete table mappings are explicit,
  authority tables are surface-local, one ownership row is enforced, roles are independent, and old
  authority paths are retired only after validated cutover.
- Dependencies: complete rename/reference matrix, source-owner dry-run, schema shape approval,
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
- `Acme::AccountQuotaPolicy` and `Acme::OrganizationQuotaPolicy` now derive their default counts
  from the surface-local ownership relation and intersect optional resource scopes with that set.
  Unsupported concrete principals fail closed. This does not implement lifecycle-aware quota
  filtering; ACTIVE/SUSPENDED/DISCARDED semantics remain blocked by CF-004.
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
- Current state: the bundled PostgreSQL adapter is available (`pg 1.6.3`). Rails boot and the
  focused authority/RP lock-order suites succeed when the required loopback test Valkey variables
  are supplied explicitly against the available isolated surface databases. The configured
  hostname-based Valkey service and the complete primary test topology remain incomplete; the
  non-Bundler preflight script also cannot load `pg` when invoked with the system Ruby.
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
   reachability subset passes with 110 runs / 2,957 assertions; sign-out notice persistence remains
   blocked by unavailable test Valkey.
3. Queue and recurring configuration is explicit, queue workers are exact, recurring task arguments
   are explicit, five ceremony purgers are isolated to `retention`, and `SignUpExpiryJob` is wired.
   OIDC delivery now distinguishes success, retryable failure, and permanent failure. Static config
   checks and RuboCop pass; worker execution and delivery remain unverified.
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
7. The current source review for #845 and #846 is recorded as `CF-009` and `CF-010`. No body-size or
   issuer migration was added without an approved contract; endpoint-specific bounds and the
   existing explicit Auth/Base handoff remain intact.

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
boundaries, restore the repository's isolated test services, and rerun the narrow Rails suites
before extending policy or lifecycle behavior. The JWT anomaly subscriber now makes missing catalog
rows observable without fabricating reference data; the additive current-runtime catalog transition
is authored but its database apply and persistence behavior remain blocked by CF-013 until they are
verified on an isolated occurrence database. The next blocked action is executing the authority
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
