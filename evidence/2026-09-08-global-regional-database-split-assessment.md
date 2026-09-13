# Global / Regional Database-Split Feasibility Assessment

## Scope

Investigation only. No code, migration, schema, `config/database.yml`, or configuration file was
modified. The question: can the current data model and its runtime dependencies be divided into two
completely independent database groups — one owned by `umaxica-apps-global` (this repository), one
owned by a future `umaxica-apps-regional` clone — with **no shared application database, schema,
Rails multi-database database, cross-repository foreign key, cross-repository ActiveRecord
association, cross-repository migration ownership, cross-repository database-availability
dependency, or cross-boundary direct SQL**. Any required Global↔Regional coupling must become an
explicit application boundary (API, signed token, event/message, or replicated immutable
identifier). A shared database is not an acceptable answer.

## Methodology

Source priority:
`current code > database schema (migrations — note `db/*_structure.sql` are 18-line stubs with no DDL) > tests > architecture documentation > runtime configuration`.
Every source-to-source conflict is reported, not silently resolved.

Reviewed directly: `config/database.yml`, `config/{queue,recurring,cable}.yml`,
`config/initializers/*`, `config/routes*`, `db/` tree, and ~30 ADRs / architecture / security
documents (`adr/split-into-regional-and-global-repos.md`, `adr/identity-authority-boundary.md`,
`adr/cross-db-reference-policy.md`, `adr/publishing-db-content-authority.md`,
`adr/avatar-db-content-db-boundary.md`, `adr/unified-enforcement.md`,
`adr/four-app-solid-cache-and-solid-queue.md`, `docs/architecture/model-database-inventory.md`,
`docs/architecture/database-authority-placement.md`, `docs/architecture/database-boundaries.md`,
`docs/architecture/regional-content.md`,
`docs/architecture/principal-zenith-membership-organization-placement.md`,
`docs/architecture/content-surface-matrix.md`, `docs/identity/authority-boundary.md`,
`docs/operations/db-workflow.md`, `docs/operations/global-portability.md`,
`docs/security/sign-up-*.md`, `evidence/2026-09-07-global-portability.md`, and others).

Three parallel read-only exploration agents covered: (A) full database + infrastructure topology,
Solid Queue/Cache/Cable placement, DB extensions/triggers/functions, CI and Compose provisioning;
(B) the complete cross-database ActiveRecord association / foreign-key / bridge-model graph; (C)
transactions, callbacks, background jobs, authorization, uniqueness constraints, cross-DB queries,
and multi-domain tests.

---

## A. Executive verdict

**`DB_SPLIT_FEASIBLE_WITH_ARCHITECTURAL_CHANGES`**, conditional on one architectural decision the
repository has not settled and that this investigation will not guess:

> **Does the `*_zenith` account / identity / organization graph — `Persona` / `Agent` /
> `Individual`, `ClientIdentity` / `OperatorIdentity` / `VisitorIdentity`, `Enterprise` / `Bureau` /
> `Company`, `Member`, `Client` / `Operator` / `Visitor` and their credentials — stay GLOBAL, or
> does each region own its own copy?**

The sources disagree:

| Source                                                                                               | Treats `*_zenith` as                                                                                                                 |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `app/models/app_rp_record.rb`, `app/models/com_rp_record.rb` headers                                 | **"Local. Region-specific."**                                                                                                        |
| `app/models/org_rp_record.rb` header                                                                 | **"Global."** (contradicts app/com — likely stale)                                                                                   |
| `docs/architecture/model-database-inventory.md`, `docs/architecture/database-authority-placement.md` | **target authority** for Account / Identity / Organization → Global-authoritative                                                    |
| `adr/identity-authority-boundary.md`, `docs/identity/authority-boundary.md`                          | `acme/www` (this repository) is **the** Session / Token / Account / Preference / Authorization / downstream-token Authority → Global |

- **Decision A — `*_zenith` stays GLOBAL** (recommended; consistent with the accepted identity
  authority ADR and with Regional being a downstream relying party that trusts acme-issued
  downstream tokens): the split is **EASY→MODERATE**. Every currently-populated database is Global.
  Regional owns essentially no data today. No transaction, uniqueness, cascade, authorization, or
  query dependency crosses the Global/Regional line. Remaining work: give each repository an
  independent `queue` and `platform` database, remove the single-PostgreSQL-cluster assumptions from
  infrastructure/config, formalize the Global→Regional contract (downstream signed token +
  `GET /api/v0/entries` read API + immutable `public_id` references + `Core*Bridge` provisioning
  events), and decide what the currently-empty Regional application database will hold. **Verdict
  under Decision A: `DB_SPLIT_FEASIBLE`.**

- **Decision B — `*_zenith` regionalises** (each region owns its accounts / identities): **HARD,
  with hard blockers.** Per-surface email / telephone / OIDC-subject uniqueness (three independent
  unique indexes across `app_zenith` / `com_zenith` / `org_zenith`) fragments further; the
  `BaseSelectorBootstrapAuthority` nested cross-database transaction (on the path of every sign-up
  and every organization invitation acceptance) becomes distributed; every `avatar`↔`*_zenith`
  binding, all seven `MemberAvatar*` tables, and every `*_ticket`↔`*_zenith` `dependent: :destroy`
  becomes cross-region; Unified Enforcement and `RetentionPurgeJob` span regions;
  `OrganizationPolicy` authorization joins break. **Verdict under Decision B:
  `DB_SPLIT_CURRENTLY_BLOCKED`** pending the architectural work in section L.

The remainder of this assessment is written for **Decision A** and flags where Decision B changes a
classification.

**No `BLOCKED_BY_NO_SHARED_DATABASE` condition was found.** Nothing in the code, schema, or
invariant set _requires_ a shared database: every cross-database pattern already avoids native
foreign keys and already tolerates non-atomic completion, and Decision A keeps all coupled data on
the Global side.

---

## B. Current database topology

Roughly 20 logical PostgreSQL databases. Each has a writer connection (`POSTGRESQL_<NAME>_PUB`) and,
except `queue` and `platform`, a physical streaming read replica (`_SUB`). Development / test /
production are triplicated; production points every writer at a single `NEON_PGHOST` and every
replica at a single `NEON_REPLICA_PGHOST`. `schema_format` is `:sql`, but the `db/*_structure.sql`
files are 18-line session-setting stubs with no DDL — the `db/*_migrate/` directories are the
reconstruction authority (`docs/operations/db-workflow.md`,
`test/tooling/database_reconstruction_authority_test.rb`).

| Logical DB                                    | Replica | Migration path(s)                                                                     |         Migs | Role                                                                                                                                  | Major models / subsystems                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| --------------------------------------------- | ------- | ------------------------------------------------------------------------------------- | -----------: | ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app_zenith`                                  | yes     | `db/app_principals_migrate` + `db/app_zenith_migrate`                                 |     322 + 32 | app-surface **consolidated principal + RP** store (the 2026-06-30 physical consolidation collapsed `app_principal` into `app_zenith`) | `Client` + credentials/contact (`ClientEmail`/`Telephone`/`Passkey`/`SecretCredential`/`TotpCredential`), `ClientExternalIdentity`, `Persona`, `ClientIdentity`, `ClientAccount`, `PersonaAssignment`/`Membership`, `Enterprise`/`Unit`/`Closure`, `Member`, `ClientMembership`, `ClientProfile`, privacy/retention/withdrawal rows, `AppEnforcementCase` + effects, `ClientBanner`/`Bulletin`, `CoreAppClientBridge`, `Docs`/`Help`/`NewsAppContentEntry`; 2 live BEFORE-DELETE enforcement triggers |
| `org_zenith`                                  | yes     | `db/org_principals_migrate` + `db/org_zenith_migrate`                                 |     223 + 36 | org-surface equivalent                                                                                                                | `Operator` + credentials, `Agent`, `OperatorIdentity`, `OperatorAccount`, `Bureau`/`Unit`/`Closure`, `Organization`, `Division`, `Department`, `OperatorWorkspaceAccount`, `OperatorEntraIdentity`, `OrganizationEntraConnection`, `OrgEnforcementCase` + effects, `CoreOrgOperatorBridge`                                                                                                                                                                                                            |
| `com_zenith`                                  | yes     | `db/com_principals_migrate` + `db/com_zenith_migrate`                                 |      63 + 29 | com-surface equivalent                                                                                                                | `Visitor` + credentials, `Individual`, `VisitorIdentity`, `VisitorAccount`, `Company`/`Unit`/`Closure`, `ComEnforcementCase` + effects, `CoreComVisitorBridge`                                                                                                                                                                                                                                                                                                                                        |
| `app_ticket` / `org_ticket` / `com_ticket`    | yes     | `db/*_tickets_migrate`                                                                | 62 / 43 / 54 | **sessions / tokens / OIDC / ceremonies**                                                                                             | `*Token`, `*DeviceSession`, `*AuthorizationCode`, `*OidcConnection`, `*OidcAuthorizationTransaction`, `*SignInFlow`/`SignUpFlow`/`SignOutFlow`, `*Verification`, `*StepUpSession`, `*CeremonyTransaction` (email/passkey/social/step-up/telephone/totp/secret), `LogoutTransaction`, `AcmeLogoutTransaction`, `*DpopProofState`, `SecurityConsumedJti`, `SecurityOneTimeReveal`, `TurnstileReplay`                                                                                                    |
| `app_setting` / `org_setting` / `com_setting` | yes     | `db/*_settings_migrate` (each headed by `db/initial_schemas/*_setting.rb`)            |    8 / 7 / 7 | login-independent surface preferences                                                                                                 | `*Preference` (session-side, **no actor association**) + ~40 `*_preference_*` facet/option tables. The actor-local mirrors `ClientPreference` / `OperatorPreference` / `VisitorPreference` live in `*_zenith`, not here.                                                                                                                                                                                                                                                                              |
| `app_signal` / `org_signal` / `com_signal`    | yes     | `db/*_signals_migrate`                                                                |       3 each | notification-origin state                                                                                                             | `Client`/`Operator`/`VisitorNotificationRecord`, `member_notifications`, `operator_notifications`                                                                                                                                                                                                                                                                                                                                                                                                     |
| `avatar`                                      | yes     | `db/avatars_migrate`                                                                  |           38 | Avatar actor authority + social graph + Avatar↔Account bridges                                                                        | `Avatar`, `Handle`/`HandleAssignment`, `AvatarMoniker`, `AvatarAssignment`, `AvatarMembership`, `AvatarPersonaBinding`/`AvatarAgentBinding`/`AvatarIndividualBinding`, `AvatarFollow`/`Block`/`Mute`, `AvatarGroup`, `GroupAvatarMembership`, `MemberAvatar*` ×7, `AvatarLifecycleState`. **Also historical `posts` / `post_versions` / `post_reviews` — a known UGC-in-avatar violation (`adr/umaxica-v1-architecture-lock.md`).**                                                                   |
| `publishing`                                  | yes     | `db/publishing_migrate` (schema built by `db/migration_support/publishing_schema.rb`) |            4 | **sole content authority** for info/docs/news/help × app/com/org (12 physical family trees)                                           | `Publishing::{info,docs,news,help}::{app,com,org}::*` (entries/slugs/revisions/versions/publications/taxonomy) + global `Publishing::MediaFile`; `btree_gist`, 10 plpgsql functions, 12 per-family trigger sets; persistence polymorphism prohibited                                                                                                                                                                                                                                                  |
| `chronicle`                                   | yes     | `db/chronicle_migrate` (headed by `db/initial_schemas/chronicle.rb`)                  |           19 | append-only audit / activity journal; must outlive actor purge                                                                        | `Chronicle` (+ intent/result/outbox), `ClientChronicle`, `OperatorChronicle`, `{App,Com,Org}PreferenceChronicle`, `AccountAccessEvent`, `EnforcementEvent`, `{app,com,org}_{document,timeline}_{audit,behavior}s`, `staff_activities`, `chronicle_retention_policies`, `chronicle_visibilities`                                                                                                                                                                                                       |
| `occurrence`                                  | yes     | `db/occurrences_migrate`                                                              |          114 | abuse / anomaly telemetry (HMAC-keyed)                                                                                                | `{area,client,operator,visitor,ip,email,telephone,domain,zip,jwt}_occurrence(s)` cross-matrix + statuses, `jwt_anomaly_events`. **No cross-DB associations; references actors only by hashed string.**                                                                                                                                                                                                                                                                                                |
| `queue`                                       | **no**  | `db/queues_migrate`                                                                   |            5 | Solid Queue (Active Job); writer role only                                                                                            | `solid_queue_*` (jobs, executions, processes, pauses, semaphores, recurring, batches)                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `platform`                                    | **no**  | `db/platform_migrate`                                                                 |            1 | Flipper feature flags (durable; no replica so a just-toggled flag reads back)                                                         | `flipper_features`, `flipper_gates` — **no ActiveRecord models**                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `search`                                      | yes     | `db/searches_migrate`                                                                 |        **0** | reserved, empty                                                                                                                       | none                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `storage`                                     | yes     | `db/storages_migrate`                                                                 |        **0** | reserved, empty (Shrine uses S3 / FakeCloud, not this DB)                                                                             | none                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |

Not databases:

- `Rails.cache` and rate-limiting are **separate Valkey stores** (`CACHE_REDIS_URL`,
  `RATE_LIMIT_REDIS_URL`). Solid Cache was removed 2026-09-05
  (`adr/solid-cache-removal-and-valkey-cache-separation.md`); there is no `cache` connection.
- Action Cable is `adapter: async` (in-process), no database.
- `db/audit_schema.rb` is an **orphan stub** for a non-existent `audit` connection.
- `pg_cron` is created on the development `primary` container, but no migration or code schedules
  any job — exploratory only.
- The `*_principal` reserved connection keys and `*_principal_reserved_migrate` directories
  described in the authority-placement documents **were never created**.
  `db/{app,com,org}_principals_migrate` are non-empty histories that the corresponding `*_zenith`
  connection loads as its first migration path.

---

## C. Proposed Global database topology (Decision A)

Global keeps **every currently-populated database**: `app_zenith`, `org_zenith`, `com_zenith`;
`app_ticket`, `org_ticket`, `com_ticket`; `app_setting`, `org_setting`, `com_setting`; `app_signal`,
`org_signal`, `com_signal`; `avatar`; `publishing`; `chronicle`; `occurrence` (all with their
replicas); plus its own `queue` and `platform`.

Drop from Global: `search`, `storage` (unused reserved), `db/audit_schema.rb` (orphan). The
`config/routes/{core,side,palm}.rb` files carry the credential/BFF half of regional surfaces (OIDC
callbacks, session and token endpoints); the token _issuance_ is Global (downstream-token
authority), so those routes largely stay — only the assumption that Regional RP delivery lives here
is removed.

## D. Proposed Regional database topology (Decision A)

Regional starts from the clone and, after pruning, owns:

- **`queue`** — its own Solid Queue database, same `db/queues_migrate` schema, independent migration
  history and data. `DUPLICATED_INFRASTRUCTURE`, not shared.
- **`platform`** — its own Flipper database. `DUPLICATED_INFRASTRUCTURE`.
- **A Regional application database (new; currently empty).** Candidate contents: regional content
  or UGC not owned by `publishing`; region-specific RP session / BFF state for `core`/`side`/`palm`/
  `line`; and **local projections** of Global entities keyed by immutable `public_id` /
  `avatar_public_id` (never bigint, never a foreign key). The zenith _schema_ may be re-instantiated
  here for Regional's own surfaces' data, but Regional must not be the authority for any row Global
  is authoritative for (single-writer rule).
- Recommended: its own `chronicle` and `occurrence` databases (`BOTH, SEPARATE DB`) so Regional has
  local audit / telemetry and is never blocked on Global database availability. Regional-origin
  events Global needs for compliance flow over the contract.

Regional does **not** receive `avatar`, `publishing`, or the Global `*_zenith` / `*_ticket` /
`*_setting` / `*_signal` data. It reads Global content via `GET /api/v0/entries(/:slug)` and
authenticates users via acme-issued downstream tokens.

---

## E. Table ownership

### GLOBAL

All `*_zenith` tables (principals; credentials / contact; `Persona` / `Agent` / `Individual`;
`*Identity`; `*Account`; `*Assignment` / `*Membership`; `Enterprise` / `Bureau` / `Company` +
unit/closure; `Member`; `ClientMembership`; `ClientProfile`; privacy / retention / withdrawal rows;
`AppEnforcementCase` + all `*_enforcement_*` effects; `Organization` / `Division` / `Department`;
`OperatorWorkspaceAccount`; `OperatorEntraIdentity`; `OrganizationEntraConnection`). All `*_ticket`
tables (tokens, device sessions, OIDC connections and authorization transactions, sign-in/up/out
flows, all `*_ceremony_transactions`, step-up sessions, logout transactions, DPoP proof state,
`security_consumed_jtis`, `security_one_time_reveals`, `turnstile_replays`). All `*_setting` tables
(`*_preferences` + facet/option tables). All `*_signal` tables. All `avatar` tables (handles,
monikers, assignments, memberships, the three Avatar↔account bindings, social graph,
`MemberAvatar*`, lifecycle states). All `publishing` tables (12 families + `media_files` +
taxonomy). All `chronicle` tables. All `occurrence` tables.

_(Under Decision B the entire `*_zenith` block moves to REGIONAL and most of sections G, H, and M
become hard blockers.)_

### REGIONAL

Nothing populated today. Future: regional content / UGC outside `publishing`; `core` / `side` /
`palm` / `line` BFF / session state; `public_id`-keyed local projections of Global entities.

### DUPLICATED_INFRASTRUCTURE

Same code and schema, independent database + data + migration history per repository: Solid Queue
(`queue` / `solid_queue_*`); Flipper (`platform` / `flipper_features`, `flipper_gates`); recommended
also `chronicle` and `occurrence` if Regional needs local audit / telemetry. "Both" here always
means _same subsystem, independent databases and state_ — never a shared database.

### DELETE

- `search` database (0 migrations, no models).
- `storage` database (0 migrations, superseded by S3 / Shrine).
- `db/audit_schema.rb` (orphan stub for a non-existent connection).
- Historical `posts` / `post_versions` / `post_reviews` in the `avatar` database (known
  `adr/umaxica-v1-architecture-lock.md` UGC violation — remove or relocate before defining the
  Regional content domain).
- 5 orphaned trigger functions from `db/app_principals_migrate/20251218120010*` and siblings (dead;
  documented in `adr/database-trigger-usage-boundary.md`).
- The stale unused per-database `POSTGRESQL_*` env matrix in `.github/workflows/ci.yml` (obsolete
  names; already ignored because test reads a single `POSTGRESQL_TEST_HOST`).

### UNCLEAR (do not classify by guess)

- **The entire `*_zenith` block** until Decision A vs B is made (section A).
- `Member`, `ClientMembership` (its `workspace_id` maps to no model or table), and `Organization` —
  flagged transitional / ambiguous in
  `docs/architecture/principal-zenith-membership-organization-placement.md`; must be decomposed
  before any move, regardless of the split.
- `ClientOidcConnection` / `OperatorOidcConnection` / `VisitorOidcConnection` — long-lived
  connection rows currently ticket-side; candidate authority placement unresolved.
- `Avatar.owner_organization_id` / `representing_organization_id` semantics
  (`docs/architecture/database-authority-placement.md`, "Ambiguities").
- Whether `core` / `side` / `palm` / `line` BFF state is Global or Regional (the route files live
  here but serve Regional surfaces — `docs/architecture/regional-content.md`).

---

## F. Cross-boundary dependencies

Under **Decision A none of the following crosses the Global/Regional line** — they are all
Global-internal, pre-existing multi-database coupling. They are listed because Decision B would turn
each into a cross-region dependency.

### Associations (all raw bigint, no native foreign key — `adr/cross-db-reference-policy.md`)

- **`avatar` ↔ `*_zenith`** (the structurally significant cluster; the avatar side holds both the
  FK-less pointers and the reverse cascade callbacks):
  - `Avatar.belongs_to :member` via `avatars.client_id` (nullable, compatibility-only per ADR);
    reverse `Member.has_many :avatars, dependent: :nullify`.
  - `AvatarAssignment.belongs_to :user → Client` (`user_id`, required, no FK); `Client` role
    throughs (`owned_avatars`, `administrators`, `editors`, `reviewers`, `viewers`) use
    `disable_joins: true` cross-database reads.
  - `AvatarPersonaBinding → Persona (app_zenith)`; `AvatarAgentBinding → Agent (org_zenith)`;
    `AvatarIndividualBinding → Individual (com_zenith)`. **These binding tables carry no foreign
    keys at all.** Each has a reverse `has_one … dependent: :destroy` from the account model.
  - `MemberAvatar{Access,Visibility,Oversight,Extraction,Impersonation,Suspension,Deletion}` ×7
    (avatar DB) `belongs_to :member → Member (app_zenith)`, no FK; reverse
    `Member.has_many … dependent: :destroy` ×7.
  - Avatar is the **only** structural link among the three surface zeniths.
  - `Avatar.owner_organization_id` / `representing_organization_id` and
    `AvatarOwnershipPeriod.owner_organization_id` are **string `public_id` values** (the correct
    pattern).
- **`*_ticket` → `*_zenith`**: every `*Token`, `*DeviceSession`, `*AuthorizationCode`,
  `*OidcConnection`, `*OidcAuthorizationTransaction`, `*CeremonyTransaction`, `*Verification`,
  `*SignInFlow`, `LogoutTransaction`, `AcmeLogoutTransaction` `belongs_to` the actor (`Client` /
  `Operator` / `Visitor`) by bare id.
- **`*_signal` → `*_zenith`**: `Client` / `Operator` / `VisitorNotificationRecord.belongs_to` actor
  (required, bare id, no reverse cascade).
- **`chronicle` → all actors**: `Chronicle.belongs_to :actor / :subject, polymorphic, optional`;
  `ClientChronicle` uses a **string `subject_id`** ("cross-DB compatibility, no FK"); reverse
  associations deliberately carry **no `dependent:`** (append-only).
- **`*_setting` → `chronicle`**:
  `{App,Com,Org}Preference.has_many :*_preference_chronicles, foreign_key: :subject_id`
  (`subject_id` is `preference.id.to_s`).
- **Reserved-`*_principal` shape (code already treats as cross-DB)**:
  `OrganizationEntraConnection.organization_id` (bare id, no `belongs_to`; header: "cross-DB; no
  enforced FK"); `Member` / `ClientMembership.belongs_to :user → Client`;
  `Member.division_id → Division`.

### Cross-database `dependent:` chains (run in-app, non-atomic, can half-complete — no DB cascade backs them)

`Member → member_avatar_* ×7 (:destroy)` and `Member → avatars (:nullify)`; `Persona` / `Agent` /
`Individual → avatar_*_binding (:destroy)`;
`Client → client_tokens / client_device_sessions / oidc_connections (:destroy)` (+ `Operator`,
`Visitor` mirrors; `Visitor` also `visitor_tokens :delete_all`);
`{App,Com,Org}Preference → *_preference_chronicles (:destroy)`. Deliberately safe (no cross-DB
`dependent:`): `Client.client_chronicles`, `Client.staff_chronicles`, `Client.notification_records`,
`Client.avatar_assignments`.

### Bridge models — the Regional contract seam

`Core{App,Com,Org}{Client,Visitor,Operator}Bridge` live in `*_zenith` (`*RpRecord`). Columns:
`audience` (e.g. `umaxica-core-app`), `host` (e.g. `jpx.umaxica.app`), `public_id` (unique),
`rp_client_id` (e.g. `core_app`), and the actor id (bare bigint, no FK, unique together with
`rp_client_id`). They `belongs_to` the same-DB actor and are created at application bootstrap by
`AcmeSelectorBootstrapAuthority` / `Base*BootstrapAuthority`. They already encode "this Global actor
is known to the regional `core-*` relying party" — the natural anchor for a signed-token or event
contract.

### App-orchestrated dual-write

`*_setting` ↔ `*_zenith` for signed-in preference edits (see C3 in section G).

### Islands with zero cross-database coupling

`publishing`, `occurrence`, `search`. `publishing` is the clean Global→Regional read contract
(`GET /api/v0/entries`).

### Foreign-key graph

`db/*_structure.sql` are stubs; schema lives only in migrations and model annotations. Consistent
with `adr/cross-db-reference-policy.md`, **every foreign key is intra-database**. Notable intra-DB
`ON DELETE` behavior that matters for split ordering:
`client_sign_up_flows.token_id → client_tokens.id ON DELETE CASCADE` (app_ticket);
`members.user_id → clients.id ON DELETE NULLIFY` (app_zenith);
`client_preferences.user_id → clients.id ON DELETE CASCADE` (app_zenith);
`personas.client_identity_id → client_identities.id ON DELETE RESTRICT` (app_zenith); `agents` /
`individuals` mirror; `avatar_assignments.avatar_id → avatars ON DELETE CASCADE`, block/mute
relationship FKs `ON DELETE CASCADE` (avatar).

---

## G. Transaction blockers

There are roughly 55 `.transaction` sites; **every one opens on a single logical database**. There
is no `ActiveRecord::Base.transaction` spanning connections. Two deliberate best-effort
cross-database nested-transaction constructs exist (C2, C3). Under **Decision A all of the following
are Global-internal and are not split blockers**; they are the blockers for Decision B and are
pre-existing risks either way.

| ID  | Operation                                                      | Entry point                                                                                                                              | Databases written                                                                                                                                  | Atomicity today                                                                                                                                                                                                                                                                                                             | Invariant                                                                                                                                               | If it crossed the boundary                                                     |
| --- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| C1  | Sign-up finalization (app/com email/telephone/social)          | `app/controllers/concerns/sign_up_sequence_controller_support.rb:257`                                                                    | `*_ticket`, `*_zenith`, `avatar`, `chronicle`, `*_setting`, `occurrence`, `queue` (7)                                                              | Not atomic; only a `*_ticket` cycle row-lock. `docs/security/sign-up-compensation.md` defines finalization-failure and sign-in-failure as separate compensation domains and forbids deleting completed account data.                                                                                                        | One durable identity graph per ticket; `rp_account` uniqueness.                                                                                         | Needs a saga / outbox; contract half-designed via the compensation domains.    |
| C2  | Identity graph provisioning (`BaseSelectorBootstrapAuthority`) | `app/services/base_selector_bootstrap_authority.rb:41,53-58`                                                                             | `*_zenith` + `*_ticket` + `avatar`                                                                                                                 | **Best-effort nested real `transaction` per DB** (zenith → rp_account → token → avatar). In-request raise rolls all back; a process crash between inner commits leaves a partial graph.                                                                                                                                     | Account + identity + collective + avatar created together or not at all. On the path of **every sign-up and every organization invitation acceptance**. | **Primary blocker under Decision B** — becomes a distributed transaction.      |
| C3  | Preference dual-write                                          | `app/controllers/concerns/preference_resource_sync.rb` `with_dual_write_transaction`                                                     | `*_setting` (source of truth) + `*_zenith` (exact mirror)                                                                                          | Best-effort nested; residual crash window between the inner (resource) commit and outer (token) commit, reconciled at next login by `Preference::Adoption` whole-record recency (`adr/preference-relogin-reconciliation-record-recency.md`). Previously had a swallowed-failure bug, now raises `PreferenceOperationError`. | token = source of truth; resource = exact mirror.                                                                                                       | Reconciliation becomes cross-region; window widens.                            |
| C4  | Unified Enforcement — apply / expiry / reconciliation          | `app/operations/enforcement_case_apply_operation.rb:34`; `enforcement_expiry_job`; `enforcement_reconciliation_job`                      | `*_zenith` (Case + Effects + `admin_locked` boolean on the principal row), then **after commit** `*_ticket` session revocation + `chronicle` audit | **Deliberately fail-forward.** The committed `*_zenith` row is the atomic security decision; side effects run after commit with a nullable `sessions_revoked_at` / `audited_at` ledger and a reconciliation job. "A committed security decision must never be rolled back."                                                 | Runtime enforcement reads only the committed `admin_locked` boolean (same query as resolving the actor) → atomic and fail-closed.                       | **This is the template to follow** for any real cross-boundary need.           |
| C5  | Withdrawal terminate + `RetentionPurgeJob` anonymize           | `app/services/withdrawal_lifecycle.rb:95`; `app/jobs/retention_purge_job.rb:145`; `app/services/retention_cross_database_child_purge.rb` | `*_zenith`, `*_signal`, `avatar`, `org_zenith`, `occurrence`; `chronicle` deliberately retained                                                    | Explicitly non-atomic, ordered; `terminated_at` is set only after anonymization succeeds; re-runs are idempotent.                                                                                                                                                                                                           | GDPR erasure completeness; no cross-database orphans; identifier capture must precede anonymization.                                                    | Cross-region erasure fan-out; needs per-region purge plus a completion signal. |
| C6  | Organization operator invitation acceptance                    | `app/services/org_operator_lifecycle_invitation_acceptance.rb:71-120`                                                                    | `OrganizationInvitation` + `Operator` + `operator_emails` + rp_account + C2                                                                        | Nested `transaction` plus an **explicit `compensate_operator_creation!`** written for a principal/RP database split that the 2026-06-30 consolidation removed. Today it is a savepoint — stale / defensive.                                                                                                                 | Invitation consumed ⇔ operator + email + account created; the email UNIQUE index is not left blocking retries.                                          | Becomes load-bearing again; **verify it actually works before relying on it.** |
| C7  | OIDC token exchange                                            | `app/services/oidc_token_exchange_coordinator.rb:159`                                                                                    | Single `*_ticket` transaction; `chronicle` audit outside                                                                                           | Single-DB.                                                                                                                                                                                                                                                                                                                  | Downstream token issuance atomic with respect to the RP token row.                                                                                      | Fine — token issuance stays Global.                                            |
| C8  | Secret-credential create / update / destroy                    | `app/services/{client,operator,visitor}_secret_credentials_*.rb`                                                                         | **`chronicle` transaction wrapping a `*_zenith` transaction** — the one place a domain write nests inside a chronicle transaction                  | Nested cross-database.                                                                                                                                                                                                                                                                                                      | Every credential mutation has a matching audit row.                                                                                                     | Migrate to the C9 intent/result outbox before any split.                       |
| C9  | Chronicle capture / audit generally                            | `app/models/concerns/chronicle_capturable.rb`; `app/operations/chronicle_intent_writer.rb`                                               | `chronicle` only (intent → work → result / invalidate), with a `ChronicleOutboxEntry` degradation path                                             | Intentionally decoupled outbox; never blocks or rolls back the domain operation.                                                                                                                                                                                                                                            | Audit durability best-effort.                                                                                                                           | Already the right pattern.                                                     |

**Callbacks:** there are essentially no cross-aggregate model callbacks. No `counter_cache`, no
`touch: true`, no cross-aggregate `after_commit` / `after_save` in `app/models` outside concerns.
`ChronicleCapturable` and `EnforcementCaseApplicable` install no callbacks
(`memos/2026-08-29-chronicle-and-enforcement-write-dependencies.md`). The only `before_destroy`
hooks (`ClientEmail` / `VisitorEmail` / `OperatorEmail` `prevent_destroy_when_undeletable`) act on
the same row.

---

## H. Uniqueness / identity risks

`db/*_structure.sql` are stubs; the authoritative unique indexes are in the `db/*_migrate/`
directories.

1. **Email / telephone uniqueness is per-surface, never system-wide.** Three independent unique
   indexes: `app_zenith` (`clients`, `client_emails.lower(address)` + `address_digest` + partial
   `address_bidx`, `client_telephones.lower(number)` + `number_digest`), `com_zenith`
   (`customer_*`), `org_zenith` (`staff_*`). The same email can simultaneously be a `Client`, a
   `Visitor`, and an `Operator`. The withdrawal anonymizer rewrites addresses to
   `withdrawn-…@anonymous.invalid` and nulls the digest, freeing them. **Under Decision A this is
   unchanged.** Under Decision B it fragments further — the same email would be registerable as a
   `Client` in two regions → **hard blocker** unless a Global identifier registry is introduced.
2. **OIDC `subject` uniqueness is `(issuer, subject, audience)` per zenith database.**
   `client_identities` / `operator_identities` / `visitor_identities` each carry the composite
   unique index in their own `*_zenith` database. Acme is the sole OpenID Provider
   (`docs/identity/authority-boundary.md`). Decision B requires subject stability and this index to
   be enforced Global; today it is regional-per-surface.
3. **`Persona` / `Agent` / `Individual` are 1:1 with their `*_identity_id`** (unique,
   `ON DELETE RESTRICT`); `*Account` rows are 1:1 with the actor id. All same-database today.
4. **Avatar `handle` / `moniker` uniqueness is a single partial unique index in the one `avatar`
   database.** Avatar must not be regionalised or handle uniqueness collapses — Avatar stays Global
   under both decisions.
5. **`public_id`** (21-character nanoid, `app/models/concerns/public_id.rb`) has **no cross-database
   uniqueness enforcement** and is the de-facto join key between every logical database. A region
   split multiplies the id space and the reliance on it. The Global→Regional contract must treat
   `public_id` / `avatar_public_id` as the only stable cross-boundary reference — which
   `adr/cross-db-reference-policy.md` already mandates.
6. **Several cross-database references are still bare bigint values** (`Avatar.client_id`,
   `AvatarAssignment.user_id`, `AvatarPersonaBinding.persona_id`, `AccountAccessEvent.account_id`).
   Acknowledged debt; must be migrated to `public_id` before any boundary runs between the two ends.
7. **Enforcement Identifier-Effect ban-list is per-realm HMAC, not global**
   (`adr/unified-enforcement.md`, "Realm isolation") — a banned identifier can re-register in
   another realm; separate region keys make it worse under Decision B.
8. **`OperatorEntraIdentity` `(entra_tenant_id, entra_object_id)` unique index plus its retention
   window** is the only thing preventing Entra-object reuse before the purge runs
   (`RetentionCrossDatabaseChildPurge#purge_operator`). Regionalising operators defeats it (Decision
   B).
9. **`Organization.domain`** unique within `org_zenith`.
10. **`Chronicle.event_uuid`** unique within `chronicle`; ceremony `jti` / `nonce` / digests unique
    per `*_ticket` database.

**Sequence / ID collision.** All primary keys are `bigint` identity (Rails default;
`docs/DB_ID_BIGINT_SHIFT_AND_FK_FIX.md`). No custom sequences, no UUID / ULID primary keys. After a
split, `Global id = 123` and `Regional id = 123` will both exist — **safe only because no
external-facing or cross-boundary reference uses the internal bigint**; every cross-boundary
reference already uses `public_id`. The remaining bigint cross-database columns in item 6 must be
converted first.

---

## I. Query / authorization blockers

- **No Action Policy rule performs a cross-database join, and no request-path query does either.**
  No `find_by_sql`, no `connection.execute` / `select`, no raw `JOIN` strings, no cross-database
  `.joins` / `.includes` anywhere in `app/`.
- `OrganizationPolicy` and `OrganizationMembershipPolicy` do
  `.joins(persona: :client_identity).exists?(…)` and similar — **realm-partitioned so each branch
  stays inside one `*_zenith` database**, and this works only because principal↔zenith is physically
  consolidated. Under **Decision B** (separating `Client` from `Persona` / `ClientIdentity`) these
  joins break; authorization would need cross-region data → **security-sensitive blocker** (the
  brief forbids weakening authorization to enable the split).
- Enforcement is checked on the **hot path by a boolean `admin_locked` column on the principal row
  itself** (`oidc_access_token_authenticator.rb:44`, `palm_access_token_authenticator.rb:47`) — the
  same `*_zenith` query as resolving the actor. Enforcement _Cases_ (and all `*_enforcement_*`
  effects, which live in the principal's own `*_zenith` database — there is no dedicated enforcement
  database and no projection) are consulted only on cold paths (retention purge protection, recovery
  and reactivation controllers, sign-up identifier gating, appeal review, `AccountStandingResolver`
  which "never performs a cross-surface lookup"). Under Decision A all of this stays Global and
  intact.
- **Multi-database assembly in a request is always sequential Ruby queries, never a join.** Sign-in
  and dashboard compose the actor (`*_zenith`) + sessions (`*_ticket`) + preferences (`*_setting`) +
  standing (`*_zenith`) + activity (`chronicle`) in Ruby. "My sessions sorted by last-seen" queries
  the actor's `*_ticket` rows by `user_id` value and sorts within `*_ticket`. So pagination,
  sorting, and filtering do **not** depend on cross-database joins — this materially lowers split
  difficulty.
- `publishing` cursor pagination and custom `ORDER BY` (`Arel.sql`) are entirely within the
  `publishing` database (`app/queries/publishing_published_entries_query.rb`).

---

## J. Solid Queue and infrastructure databases

- **Solid Queue** is the only Solid\* component on PostgreSQL: a dedicated `queue` database,
  **writer role only, no replica**, adapter `:solid_queue` (development / production) and `:test` in
  test (`config/environments/*.rb`), `config/queue.yml` a single config for all environments.
  `config/recurring.yml` schedules the purge jobs. → **BOTH, SEPARATE DB.** Each repository runs its
  own `db/queues_migrate` against its own `queue` database with its own migration history and job
  data. Solid Queue must be reachable from every process that enqueues _within that repository_ —
  never across repositories.
- **Flipper / `platform`** — durable feature flags, no replica, no ActiveRecord models. → **BOTH,
  SEPARATE DB.** The same flag _names_ may exist in both; flag _state_ is independent.
- **Solid Cache** — removed. `Rails.cache` is Valkey (`CACHE_REDIS_URL`); rate-limiting is a
  separate Valkey store (`RATE_LIMIT_REDIS_URL`). Neither is a correctness datastore; both are out
  of scope. Each repository points at its own Valkey instances.
- **Action Cable** — `adapter: async`, in-process, no database.
- **`chronicle` / `occurrence`** — currently Global-only. Recommendation: **BOTH, SEPARATE DB**, so
  Regional has local audit / telemetry and is never blocked on Global database availability;
  Regional-origin events Global needs for compliance flow over the contract (sections K and L).
  `chronicle` already has a `chronicle_outbox_entries` table — the outbox pattern is in place.
- **`search`, `storage`** — 0 migrations, unused. DELETE from both, or recreate per repository on
  demand.

---

## K. Migration implications

- Because `db/*_structure.sql` are stubs and **migrations are the reconstruction authority**, a
  clone can freely prune each side's `db/*_migrate/` history and rebuild from `db:migrate` /
  `db:prepare`. Migration duplication and later history cleanup are acceptable — **not a blocker.**
- Under **Decision A**: Global keeps all `db/*_migrate` directories except `db/searches_migrate` and
  `db/storages_migrate` (delete), and can delete `db/audit_schema.rb`. Regional keeps
  `db/queues_migrate` and `db/platform_migrate` (and optionally `db/chronicle_migrate`,
  `db/occurrences_migrate`) and starts a fresh `db/<regional>_migrate` for its application database.
  Neither repository runs the other's migrations.
- Per-migration split difficulty:
  - **Table-level clean separation** — `db/queues_migrate`, `db/platform_migrate`,
    `db/searches_migrate`, `db/storages_migrate`, `db/publishing_migrate`, `db/occurrences_migrate`,
    `db/chronicle_migrate`, `db/*_signals_migrate`, `db/*_settings_migrate` (each owns exactly one
    logical database; no cross-domain mixing).
  - **Mixed within a path but one physical database** — each `db/*_zenith` connection loads two
    paths (`db/*_principals_migrate` + `db/*_zenith_migrate`); fine, both target one database.
  - **Raw SQL / extension / trigger / function dependencies** — `publishing` (`btree_gist` + 10
    plpgsql functions + 12 per-family trigger sets, all built by
    `db/migration_support/publishing_schema.rb`); `app_zenith` (2 live BEFORE-DELETE enforcement
    trigger functions, same-database only); `db/initial_schemas/*` enable `citext` + `pgcrypto`;
    every principal / ticket / occurrence path enables `pgcrypto` / `citext`. All **intra-database**
    — no cross-database data migration, no cross-database trigger. Each repository keeps the
    extension-enabling migrations for the databases it owns.
  - **Data migrations** — none cross a logical database boundary (`adr/cross-db-reference-policy.md`
    enforced).
  - `db/initial_schemas/*.rb` and `db/migration_support/publishing_schema.rb` are loaded by the
    first migration of their path — the clone must carry them for any database it keeps.
  - `config/initializers/{schema_migration_if_not_exists,migration_safe_table_rename,pg_cron_test_fallback}.rb`
    and `lib/tasks/{test_db_prepare,db_verify_no_schema_drift}.rake` are stub-`structure.sql`
    workarounds — carry them, or resolve the underlying `schema_format` question, per repository.
- The stale `POSTGRESQL_*` env matrix in `.github/workflows/ci.yml` (obsolete names, currently
  ignored) should be cleaned up as part of the split, per repository.

---

## L. Required architectural changes before split

### Infrastructure / configuration — single-PostgreSQL-cluster assumptions to remove (Decision A and B)

1. `config/database.yml` production block — all 20 writers resolve to one `NEON_PGHOST`, all 18
   replicas to one `NEON_REPLICA_PGHOST`; there is no per-database host variable in production. Each
   repository needs its own Neon project (or at minimum its own connection endpoints) and, ideally,
   per-logical-database host variables.
2. `config/database.yml` test block and line 2 — all test databases share one
   `POSTGRESQL_TEST_HOST`.
3. `docker/psql-{pub,sub}` and `podman/psql-*` — **whole-cluster physical streaming replication**
   (`pg_basebackup` + one replication slot). This structurally forces every logical database onto
   the one `primary` cluster. Each repository needs its own primary + replica pair (or per-database
   replication) covering only its own databases.
4. `compose.yaml` / `compose.env` — single `primary` + `replica`; `POSTGRESQL_<DB>_PUB=primary` for
   all. Split the Compose infrastructure per repository.
5. `.github/workflows/ci.yml` — single `postgres:18` service + `bin/rails db:prepare`, plus the
   stale per-database env matrix. Per-repository CI, each preparing only its own databases.
6. `docs/operations/db-workflow.md` — treats the ~25-database fleet as one `db:migrate:reset` unit;
   update per repository.
7. `config/initializers/multi_db.rb` — the global `DatabaseSelector` (Session resolver, 10-second
   delay) requires **every** connection a web request can touch to expose both a `writing` and a
   `reading` pool. Preserve this per repository for every database that repository keeps.
8. Delete `db/audit_schema.rb`, `db/searches_migrate`, `db/storages_migrate` from both.

### Cross-boundary contract — the seams to formalize (Decision A)

9. **Downstream signed token.** Global (`acme/www`) already is the downstream-token authority
   (`adr/identity-authority-boundary.md`); Regional (`core` / `side` / `palm` / `line`) trusts
   acme-issued tokens instead of reading any Global database. Formalize the token claims, JWKS
   distribution, and revocation propagation (the `oidc_backchannel_logout_delivery_job` machinery
   already exists).
10. **`Core{App,Com,Org}{Client,Visitor,Operator}Bridge` provisioning events.** Today these rows are
    written into Global `*_zenith` at bootstrap. Convert "regional relying party X now knows Global
    actor Y (by `public_id`)" into an event or API call to Regional, rather than a Global database
    row Regional would need to read.
11. **Content read API.** `GET /api/v0/entries(/:slug)` is already the Global→Regional content
    contract; no change beyond ensuring Regional never assumes database access to `publishing`.
12. **Audit / telemetry egress.** If `chronicle` / `occurrence` are `BOTH, SEPARATE DB`, define how
    Regional-origin compliance events reach Global (outbox → API / message;
    `chronicle_outbox_entries` already exists).
13. Convert the remaining **bigint cross-database columns** at any seam that will run between the
    two repositories to `public_id` / `avatar_public_id` (`Avatar.client_id`,
    `AvatarAssignment.user_id`, the three `Avatar*Binding.*_id`, `AccountAccessEvent.account_id`).
    Under Decision A these seams stay Global-internal, so this is lower priority than under Decision
    B.

### Decomposition work that must precede Decision B specifically (good hygiene regardless)

14. Decompose `Client` / `Operator` / `Visitor` into runtime-actor vs credential vs lifecycle vs
    session-adjacent portions
    (`docs/architecture/principal-zenith-membership-organization-placement.md`).
15. Resolve `Member` / `ClientMembership` (`workspace_id` maps to nothing) / `Organization`
    placement via a dedicated ADR.
16. Introduce a Global identifier registry if system-wide email / telephone / subject uniqueness is
    required across regions (currently only per-surface).
17. Replace the `BaseSelectorBootstrapAuthority` (C2) and sign-up finalization (C1) nested
    cross-database transactions with a saga / outbox that tolerates a boundary between `*_zenith`
    and `avatar` / `*_ticket`.
18. Migrate secret-credential mutation (C8) off the `chronicle`-wrapping transaction onto the C9
    intent/result outbox.
19. Verify the `org_operator_lifecycle_invitation_acceptance` compensation (C6) actually works
    before relying on it.

---

## M. Hard blockers

### Under Decision A: one, and it is a decision rather than a code defect

| #   | File / model / conflict                                                                                                                                                                                                   | Current behavior                                                                                                                               | Violated invariant                                           | Why DB separation breaks it                                                                                                                                                                           | Remediation direction                                                                                                                                                           |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| M1  | `app/models/app_rp_record.rb` and `com_rp_record.rb` ("Local. Region-specific.") vs `app/models/org_rp_record.rb` ("Global.") vs `docs/architecture/model-database-inventory.md` and `adr/identity-authority-boundary.md` | The repository does not consistently state whether `*_zenith` (accounts / identities / organizations) is Global-authoritative or region-owned. | Single-writer / single-authority for canonical mutable data. | If `*_zenith` is Regional, Global's `www` / `acme` primary relying party has no account store and `adr/identity-authority-boundary.md` is contradicted. If Global, the `*RpRecord` headers are wrong. | **Decide and record in an ADR.** Recommended: `*_zenith` = Global; Regional holds only `public_id`-keyed projections and trusts downstream tokens. Fix the stale model headers. |

### Additional hard blockers that apply only under Decision B (`*_zenith` regionalised)

| #   | Area                                                                                                                                                                                                                                           | Violated invariant                                                                                                                     | Why separation breaks it                                                                                                        | Remediation                                                                                                                                                              |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| M2  | `client_emails` / `customer_emails` / `staff_emails` unique indexes (`app_zenith` / `com_zenith` / `org_zenith`) + `client_identities (issuer, subject, audience)`                                                                             | Per-surface identifier uniqueness                                                                                                      | The same email or OIDC subject would be registerable in two regions.                                                            | Global identifier registry (L.16) — not solvable without a Global authority.                                                                                             |
| M3  | `app/services/base_selector_bootstrap_authority.rb:41` (C2) + `sign_up_sequence_controller_support.rb:257` (C1)                                                                                                                                | Account + identity + collective + avatar created atomically                                                                            | Nested real `transaction` across `*_zenith` + `*_ticket` + `avatar` becomes distributed.                                        | Saga / outbox with compensation (partly designed in `docs/security/sign-up-compensation.md`).                                                                            |
| M4  | `OrganizationPolicy` / `OrganizationMembershipPolicy` (`app/policies/organization_policy.rb:16`)                                                                                                                                               | Authorization decided from `Persona` / `PersonaMembership` / `ClientIdentity` joins                                                    | PostgreSQL cannot join across databases or regions; the brief forbids weakening authorization.                                  | Move the authorization-relevant projection to where the decision is made, or keep `Persona` + `ClientIdentity` + `Client` co-located (Decision A).                       |
| M5  | `avatar` ↔ `*_zenith`: `AvatarPersonaBinding` / `AvatarAgentBinding` / `AvatarIndividualBinding`, `MemberAvatar*` ×7, `AvatarAssignment`, `Avatar.client_id`; reverse `dependent: :destroy` from `Persona` / `Agent` / `Individual` / `Member` | Avatar↔Account binding integrity; account deletion cleans up avatar-side rows                                                          | Bindings carry no foreign key; cascades run in-app; across regions they become cross-region calls that can half-complete.       | `public_id` references + asynchronous reconciliation / cleanup (`adr/cross-db-reference-policy.md` already mandates `avatar_public_id`). Avatar stays Global regardless. |
| M6  | `*_ticket` ↔ `*_zenith`: `Client.has_many :client_tokens / :client_device_sessions / :oidc_connections dependent: :destroy` (+ `Operator`, `Visitor`)                                                                                          | Session / token revocation on account deletion                                                                                         | Cross-region cascade.                                                                                                           | Avatar and ticket stay Global (Decision A). Under B: event-driven revocation.                                                                                            |
| M7  | `RetentionPurgeJob` (`app/jobs/retention_purge_job.rb`) + `EnforcementExpiryJob` / `EnforcementReconciliationJob`                                                                                                                              | GDPR erasure completeness; enforcement convergence; FK-cascade ordering (`client_sign_up_flows` → `client_tokens` `ON DELETE CASCADE`) | One job iterates nearly every logical database (7 databases for the enforcement jobs); the delete ordering assumes co-location. | Per-region jobs + completion signals; the C4 fail-forward pattern is the template.                                                                                       |

**`BLOCKED_BY_NO_SHARED_DATABASE`: none.**

---

## N. Complexity map

| Domain / subsystem                                         | Decision A                                                                      | Decision B                     |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------- | ------------------------------ |
| Solid Queue (`queue`)                                      | **EASY** — duplicate schema, independent database                               | EASY                           |
| Flipper (`platform`)                                       | **EASY**                                                                        | EASY                           |
| `search` / `storage`                                       | **EASY** — delete (unused)                                                      | EASY                           |
| `publishing` (content)                                     | **EASY** — stays Global; `GET /api/v0/entries` is the contract; clean island    | EASY                           |
| `occurrence` (telemetry)                                   | **EASY** — stays Global, or `BOTH, SEPARATE DB`; clean island                   | MODERATE                       |
| `chronicle` (audit)                                        | **MODERATE** — stays Global, or `BOTH, SEPARATE DB` + outbox egress             | MODERATE                       |
| `*_signal` (notifications)                                 | **EASY** — stays Global                                                         | MODERATE (actor references)    |
| `*_setting` (preferences)                                  | **MODERATE** — dual-write C3 stays Global-internal                              | HARD (cross-region dual-write) |
| `avatar`                                                   | **MODERATE** — stays Global; convert remaining bigint references to `public_id` | HARD (M5)                      |
| `*_ticket` (sessions / OIDC)                               | **MODERATE** — stays Global; downstream-token contract for Regional             | HARD (M6)                      |
| `*_zenith` (accounts / identity / organization)            | **MODERATE** — stays Global; resolve M1; decompose `Member` / `Organization`    | **BLOCKED** (M1–M4)            |
| Unified Enforcement                                        | **MODERATE** — stays Global; already fail-forward                               | HARD (M7)                      |
| Sign-up / bootstrap (C1 / C2)                              | **MODERATE** — Global-internal; still worth hardening                           | **BLOCKED** (M3)               |
| Infrastructure / config single-cluster assumptions (L.1–8) | **MODERATE** — mechanical but broad                                             | MODERATE                       |
| Regional application database (define from empty)          | **MODERATE** — greenfield; needs product input                                  | HARD                           |

---

## O. Recommended split order

1. **Resolve M1** — an ADR fixing whether `*_zenith` is Global (recommended) or Regional. Everything
   else depends on it. Fix the stale `*_rp_record.rb` headers to match.
2. **Delete the dead weight now, in Global** (safe, no split needed): `db/audit_schema.rb`,
   `db/searches_migrate`, `db/storages_migrate`, the orphan trigger functions, the stale CI env
   matrix, and the historical `posts*` tables in `avatar`.
3. **Split the infrastructure / configuration layer** (L.1–8): per-repository Neon endpoints,
   per-repository primary/replica + replication, per-repository Compose, per-repository CI,
   per-repository `db-workflow.md`. This is prerequisite to running two independent stacks at all.
4. **Stand up the `DUPLICATED_INFRASTRUCTURE` databases**: design a per-repository `queue` and
   `platform`; decide `chronicle` / `occurrence` = Global-only vs `BOTH, SEPARATE DB`.
5. **Formalize the Global→Regional contract** (L.9–12): downstream token claims + JWKS + revocation;
   `Core*Bridge` provisioning as an event / API; confirm `GET /api/v0/entries` is the only content
   path; audit / telemetry egress if `BOTH, SEPARATE DB`.
6. **Convert the remaining bigint cross-database columns to `public_id`** at any seam that will run
   between repositories (L.13).
7. **Clone into `umaxica-apps-regional`.** Immediately prune: Regional deletes `avatar`,
   `publishing`, and the Global `*_zenith` / `*_ticket` / `*_setting` / `*_signal` data and
   migrations; keeps `queue` and `platform` (and possibly `chronicle` / `occurrence`); starts a
   fresh regional application database. Global deletes the regional-RP-delivery assumptions in
   `core` / `side` / `palm` and (optionally) the `Core*Bridge` rows once the event contract replaces
   them.
8. **Define the Regional application data domain** (needs product input — currently empty): regional
   content / UGC outside `publishing`, `core` / `side` / `palm` / `line` BFF / session state,
   `public_id`-keyed local projections.
9. **Only if Decision B was taken in step 1**: perform the L.14–19 decomposition (Client / Operator
   / Visitor split, Member / Organization ADR, Global identifier registry, C1 / C2 saga, C8 outbox).
   These are the M2–M7 remediations and are large, multi-quarter efforts.
10. **Independent verification per repository**: `bin/rails test`; `bin/rails db:prepare` from a
    fresh database; `test/tooling/database_reconstruction_authority_test.rb`;
    `test/tooling/database_migration_path_ownership_test.rb`; and a boot with the other repository's
    databases unreachable (proves no cross-repository database dependency).

---

## Final verdict

**`DB_SPLIT_FEASIBLE_WITH_ARCHITECTURAL_CHANGES`.**

- If `*_zenith` (accounts / identity / organization) stays **Global** — the reading consistent with
  `adr/identity-authority-boundary.md` and the recommended path — the split is **feasible now** with
  moderate, mostly mechanical work: independent `queue` / `platform` (and preferably `chronicle` /
  `occurrence`) databases, removal of the single-PostgreSQL-cluster assumptions in infrastructure
  and configuration, and formalization of an already-half-designed Global→Regional contract
  (downstream signed tokens, the `entries` read API, `public_id` references, `Core*Bridge` events).
  No transaction, uniqueness, cascade, authorization, or query dependency crosses the boundary; no
  invariant requires a shared database.
- If `*_zenith` **regionalises**, the split is **currently blocked** on per-surface identifier
  uniqueness, the sign-up / bootstrap nested cross-database transactions, cross-region
  avatar↔account and ticket↔account cascades, cross-region authorization joins, and cross-region
  enforcement / retention jobs. These are solvable but require a Global identifier registry and a
  saga / outbox redesign — multi-quarter work.

The one hard blocker under either reading is that **the repository has not decided which reading is
correct**, and the model file headers contradict the architecture documents. That decision (M1) is
the required first step.

No code, migration, schema, `config/database.yml`, or configuration file was modified during this
investigation.
