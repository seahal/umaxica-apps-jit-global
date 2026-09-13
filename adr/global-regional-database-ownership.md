# Global / Regional Database Ownership

## Status

Accepted on 2026-09-08.

Resolves the `M1` open question recorded in
`evidence/2026-09-08-global-regional-database-split-assessment.md`.

## Context

`umaxica-apps-global` (this repository) is the Global half of the two-repository structure accepted
in `adr/split-into-regional-and-global-repos.md`. A future `umaxica-apps-regional` repository will
be created by cloning this one and then pruning each side so the two applications share no database.

The Phase 1.5 feasibility assessment
(`evidence/2026-09-08-global-regional-database-split-assessment.md`) concluded
`DB_SPLIT_FEASIBLE_WITH_ARCHITECTURAL_CHANGES`, conditional on one unresolved decision it labelled
`M1`:

> Does the `*_zenith` account / identity / organization graph stay Global, or does each region own
> its own copy?

The repository was internally inconsistent on this point:

- `app/models/app_rp_record.rb` and `app/models/com_rp_record.rb` header comments said "Deployment
  scope: Local / Region-specific."
- `app/models/org_rp_record.rb` header comment said "Deployment scope: Global."
- `docs/architecture/model-database-inventory.md` and
  `docs/architecture/database-authority-placement.md` treated `*_zenith` as the **target authority**
  store for Account / Identity / Organization data.
- `adr/identity-authority-boundary.md` and `docs/identity/authority-boundary.md` make `acme/www`
  (this repository) the sole Session, Token, Account, Preference, Authorization, and
  downstream-token Authority.

`adr/principal-zenith-physical-consolidation.md` additionally reserved empty `*_principal`
connection keys "for a future regional-ready application-data role." The Phase 1.5 investigation
found those reserved connection keys and migration directories were never actually created; the
`db/{app,com,org}_principals_migrate` histories are non-empty and are applied through the matching
`*_zenith` connection.

This ADR settles the ownership of every logical database ahead of the clone-and-prune work. It
changes no code, migration, schema, `config/database.yml`, or runtime configuration.

## Decision

### 1. `*_zenith` is Global authority (M1 resolved)

`app_zenith`, `org_zenith`, and `com_zenith` are **Global-only** databases. The Account, Identity,
Organization, and principal graph they contain is Global canonical authority and is not
region-owned. Concretely, the Global canonical authority for the following is this repository:

- runtime actors: `Client`, `Operator`, `Visitor`
- accounts: `Persona`, `Agent`, `Individual`; `ClientAccount`, `OperatorAccount`, `VisitorAccount`
- identity bindings: `ClientIdentity`, `OperatorIdentity`, `VisitorIdentity`
- organization hierarchy: `Enterprise`, `Bureau`, `Company` (and their unit / closure models);
  `Organization`, `Division`, `Department`
- membership and assignment identity data: `Member`, `ClientMembership`, `PersonaAssignment` /
  `AgentAssignment` / `IndividualAssignment`, `PersonaMembership` / `AgentMembership` /
  `IndividualMembership`, `OperatorWorkspaceAccount` and its membership join
- credential and contact identity data: `ClientEmail` / `Telephone` / `Passkey` / `SecretCredential`
  / `TotpCredential`, `ClientExternalIdentity`, and the `Operator` / `Visitor` equivalents
- privacy, retention, and withdrawal state
- enforcement state: `{App,Com,Org}EnforcementCase` and all `*_enforcement_*` effect tables
- Entra federation records: `OperatorEntraIdentity`, `OrganizationEntraConnection`
- any other canonical account / identity / organization state currently stored in `*_zenith`

This is consistent with `adr/identity-authority-boundary.md`: `acme/www` is the Account, Session,
Token, Preference, and Authorization Authority, and downstream services trust acme-issued downstream
tokens rather than reading Global databases.

Regional is **never the writer** of these canonical mutable records. Regional may hold local
projections keyed by immutable public identifiers (see section 8), but a projection is a read-side
copy, never a second writer.

The physical consolidation described in `adr/principal-zenith-physical-consolidation.md` stands: the
semantic `*PrincipalRecord` bases connect to the matching `*_zenith` database. The "regional-ready
`*_principal`" role in that ADR and in `docs/architecture/database-authority-placement.md` is
**retired**: regional-ready application data belongs in the Regional repository's own application
database (section 8), not in a `*_principal` connection key in this repository.

The `Member` / `ClientMembership` / `Organization` decomposition still required by
`adr/member-client-membership-organization-decomposition-before-placement.md` is unchanged. Those
rows are Global; their internal decomposition is a separate matter.

### 2. `*_ticket` is Global

`app_ticket`, `org_ticket`, and `com_ticket` are **Global-only**. They own sessions, tokens,
authorization codes, OIDC state, OIDC connections and authorization transactions, sign-in / sign-up
/ sign-out flows, verification, step-up, ceremony transactions, logout transactions, DPoP proof
state, JTI / replay protection, and security one-time state.

Authentication, session, and token authority stay Global. Regional must not read a Global ticket
database directly. Regional↔Global authentication coupling uses the existing downstream signed
token, JWKS, and explicit contract surface (`adr/identity-authority-boundary.md`,
`docs/security/downstream-token-authority.md`,
`adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`).

### 3. `*_setting` is Global

`app_setting`, `org_setting`, and `com_setting` are **Global-only**. The current preference
architecture is Global authority: login-independent / session-side preferences, preference facet and
option reference state, and the actor-local preference mirror stored in `*_zenith`
(`adr/preference-relogin-reconciliation-record-recency.md`). Setting is not moved to Regional.
Changing this placement requires a new ADR.

### 4. `*_signal` is Global

`app_signal`, `org_signal`, and `com_signal` are **Global-only**. Signal is the Global-side
notification-state subsystem. It is retained as Global even though the current implementation is
limited or incomplete. Incompleteness is not grounds to classify it as `DELETE`; it is the intended
home for notification-origin authority as that subsystem is built out.

### 5. `avatar` is Global

`avatar` is **Global-only**. Avatar identity, handle / moniker lifecycle, the Avatar-to-Avatar
social graph, and the Avatar↔account bindings (`AvatarPersonaBinding`, `AvatarAgentBinding`,
`AvatarIndividualBinding`, `AvatarAssignment`, `MemberAvatar*`) are Global canonical authority.
Regional is not the authority for any of it. When Regional needs to reference an Avatar it uses an
explicit stable identifier (`avatar_public_id`) through a contract, never a database id or a
cross-repository foreign key, consistent with `adr/cross-db-reference-policy.md` and
`adr/avatar-db-content-db-boundary.md`.

### 6. `publishing` is Global

`publishing` is **Global-only** and the sole content authority for the twelve info / docs / news /
help × app / com / org families (`adr/publishing-db-content-authority.md`,
`adr/publishing-persistence-polymorphism-prohibition.md`). Regional consumes content through the
Global read API (`GET /api/v0/entries`, `GET /api/v0/entries/:public_id`) and never reads the
`publishing` database directly.

### 7. `chronicle`, `occurrence`, `primary`, `queue` exist independently in both repositories

These four subsystems run in **both** Global and Regional. "Both" here has a strict meaning and
never means a shared database:

- the same subsystem concept exists on both sides;
- both sides may start from the same initial schema and code at clone time;
- the databases are completely separate — separate connections, separate data, separate state;
- migration lifecycle is independent after the repository split (section 15);
- runtime and worker ownership is independent where applicable.

#### 7.1 Chronicle

Global has a Global `chronicle` database; Regional has a Regional `chronicle` database. Each side
records its own audit, activity, and operational history. Regional must not write to the Global
`chronicle` database, and Global must not read the Regional `chronicle` database directly.
Compliance or audit information that must cross the boundary travels through an explicit contract
(API, event, or the existing `chronicle_outbox_entries` outbox), not a shared database.

#### 7.2 Occurrence

Global and Regional each have their own `occurrence` database for abuse telemetry, anomaly
telemetry, security-related occurrence data, and rate / behavioural observations. Regional operation
must not depend on Global `occurrence` database availability.

#### 7.3 Primary (Flipper and other application-wide durable configuration)

Global and Regional each have their own Rails `primary` database. This is the conventional default
database (`db/migrate`) for durable, low-frequency, application-wide configuration or metadata that
does not justify a dedicated domain database. Flipper currently stores feature flags here. Flag
state is independent: the same feature name may exist on both sides with different state. Global
flag state is not Regional flag state. `primary` is not a catch-all for domain data that already
has a dedicated database.

#### 7.4 Queue (Solid Queue)

Global and Regional each run Solid Queue against their own `queue` database. Prohibited: a shared
queue database, cross-repository worker consumption, a Global worker consuming Regional jobs, a
Regional worker consuming Global jobs, and shared migration ownership. Both sides may start from the
same Solid Queue migration and schema; after the split each owns its migration history
independently.

### 8. Regional owns a new Regional application database

Regional will have a new Regional-owned application database. Its name follows the repository's
existing connection-naming conventions (`adr/surface-database-connection-naming.md`,
`adr/actor-db-naming-policy.md`) and is chosen during the implementation phase.

This ADR does not fix the full domain of that database. Candidate contents:

- regional application state;
- regional BFF / session-adjacent state for `core` / `side` / `palm` / `line`;
- regional-only product or domain data;
- regional UGC where the Global `publishing` database is not the authority;
- local projections of Global entities.

Where Regional holds a projection, it holds a read-side copy keyed by an immutable Global public
identifier. It never becomes a second writer of canonical mutable Global data. Every canonical
mutable record has exactly one writer and one canonical authority.

### 9. Database ownership map

```text
GLOBAL ONLY
-----------
app_zenith    org_zenith    com_zenith
app_ticket    org_ticket    com_ticket
app_setting   org_setting   com_setting
app_signal    org_signal    com_signal
avatar
publishing

BOTH, BUT COMPLETELY INDEPENDENT (never a shared database)
---------------------------------------------------------
chronicle
occurrence
primary
queue

REGIONAL ONLY
-------------
regional application database (new; name and full domain decided at implementation time)
```

`search` and `storage` are not in this map. Both currently have zero migrations, no active models,
and no ownership. `db/audit_schema.rb` is an orphan stub for a connection that does not exist. All
three are deletion candidates for the implementation phase and are not retained by this decision;
this ADR performs no deletion.

### 10. No-shared-database invariant

Between Global and Regional, the following are architecture invariants:

```text
NO shared application database
NO shared queue database
NO shared primary database
NO shared chronicle database
NO shared occurrence database
NO shared schema
NO cross-repository foreign key
NO cross-repository ActiveRecord association
NO cross-repository migration ownership
NO direct SQL across the Global / Regional boundary
NO dependency on the other repository's database availability
```

The words "shared database" and "common database" must not be used to describe any Global↔Regional
relationship. A subsystem that exists on both sides is duplicated, not shared.

### 11. Cross-boundary contract rule

Required Global↔Regional coordination uses an explicit application contract:

```text
HTTP / API
signed token
JWKS
event / message
outbox
immutable public identifier
local projection
```

The existing seams — downstream signed tokens (`docs/security/downstream-token-authority.md`), the
`entries` read API, the `Core{App,Com,Org}{Client,Visitor,Operator}Bridge` provisioning records, and
`avatar_public_id` references — are the starting points. Their concrete protocol design is
implementation-phase work and is out of scope here.

## Consequences

- The clone-and-prune work has a documented authority: Regional deletes `avatar`, `publishing`, and
  the Global `*_zenith` / `*_ticket` / `*_setting` / `*_signal` data and migrations; keeps `queue`
  and `primary` (and gets its own `chronicle` and `occurrence`); and stands up a new regional
  application database. Global keeps every currently-populated database.
- Because `*_zenith` stays Global, none of the cross-database transactions, cascades, uniqueness
  constraints, authorization joins, or multi-database jobs identified in the Phase 1.5 assessment
  crosses the Global/Regional boundary. They remain Global-internal concerns.
- Per-surface identifier uniqueness (email, telephone, OIDC subject) continues to be enforced by the
  Global `*_zenith` databases. No Global identifier registry is required for the split.
- `adr/principal-zenith-physical-consolidation.md` and
  `docs/architecture/database-authority-placement.md` are updated: the reserved-`*_principal`
  "regional-ready storage" role is retired in favour of a dedicated Regional application database in
  the Regional repository.
- The `app/models/app_rp_record.rb` and `app/models/com_rp_record.rb` "Deployment scope: Local /
  Region-specific." header comments contradict this decision and are corrected to "Global" as a
  comment-only change with no behavioural effect.
- Physical infrastructure independence is now an architecture goal: Global and Regional may run on
  separate PostgreSQL / Neon projects. A shared PostgreSQL server may be used as a local development
  convenience but is never an architecture-level shared-state dependency; production architecture
  keeps the two repositories independently operable.
- The repository split is treated as destructive. Development data, test data, Solid Queue contents,
  Flipper state, Chronicle and Occurrence development data, cache state, and object-storage
  development data are not migrated; both sides may be rebuilt from fresh databases. Production
  semantics, security invariants, and authorization invariants are preserved.

## Rejected alternative: regionalizing `*_zenith`

Giving each region its own copy of the account / identity / organization graph was considered and
rejected. It would:

- fragment per-surface email / telephone / OIDC-subject uniqueness across regions, requiring a new
  Global identifier registry;
- turn the `BaseSelectorBootstrapAuthority` and sign-up finalization nested cross-database
  transactions (on the path of every sign-up and every organization invitation acceptance) into
  distributed transactions;
- make every `avatar`↔`*_zenith` binding, the seven `MemberAvatar*` tables, and every
  `*_ticket`↔`*_zenith` cascade a cross-region operation;
- break the realm-partitioned `OrganizationPolicy` / `OrganizationMembershipPolicy` authorization
  joins, which PostgreSQL cannot execute across databases;
- make Unified Enforcement and `RetentionPurgeJob` span regions.

These costs introduce distributed identity, uniqueness, authorization, cascade, and transaction
complexity with no corresponding benefit, because `adr/identity-authority-boundary.md` already
places account and identity authority in this repository and Regional is a downstream relying party
that trusts acme-issued tokens.

## Migration / split implications

- Migration lifecycle separates at the split. For a duplicated subsystem such as `queue`, both
  repositories may keep `db/queues_migrate` and start from the same history; after the split each
  owns its history and the two are not synchronized. The same applies to `chronicle`, `occurrence`,
  `primary`, and `queue`.
- Because `db/*_structure.sql` are stubs and migrations are the reconstruction authority
  (`docs/operations/db-workflow.md`), each side can prune its own `db/*_migrate/` history and
  rebuild from migrations.
- No data migration crosses a logical database boundary today (`adr/cross-db-reference-policy.md`),
  so no cross-boundary data migration is created by the split.
- Actual deletion of `search`, `storage`, `db/audit_schema.rb`, the orphaned trigger functions, and
  the stale CI environment matrix is implementation-phase work, not part of this decision.

## References

- `evidence/2026-09-08-global-regional-database-split-assessment.md` — Phase 1.5 feasibility
  assessment; this ADR resolves its `M1`.
- `evidence/2026-09-08-global-regional-database-ownership-decision.md` — record of this
  documentation pass.
- `adr/split-into-regional-and-global-repos.md` — the two-repository structure this ADR builds on.
- `adr/identity-authority-boundary.md`, `docs/identity/authority-boundary.md` — `acme/www` as the
  Account / Session / Token / Preference / Authorization / downstream-token authority.
- `adr/principal-zenith-physical-consolidation.md` — physical consolidation of `*_principal` history
  into `*_zenith`; its reserved-`*_principal` regional-ready role is retired by this ADR.
- `adr/cross-db-reference-policy.md` — no cross-database foreign keys or new integer cross-database
  associations; use immutable public identifiers.
- `adr/avatar-db-content-db-boundary.md`, `adr/publishing-db-content-authority.md`,
  `adr/unified-enforcement.md`, `adr/chronicle-audit-db-consolidation.md`,
  `adr/preference-relogin-reconciliation-record-recency.md` — subsystem authority decisions this ADR
  is consistent with.
- `adr/four-app-solid-cache-and-solid-queue.md`,
  `adr/solid-cache-removal-and-valkey-cache-separation.md` — Solid Queue is PostgreSQL-backed; Solid
  Cache is removed and Valkey-backed.
- `docs/architecture/database-boundaries.md`, `docs/architecture/database-authority-placement.md`,
  `docs/architecture/model-database-inventory.md`,
  `docs/architecture/principal-zenith-membership-organization-placement.md`,
  `docs/architecture/regional-content.md` — updated to reference this decision.
