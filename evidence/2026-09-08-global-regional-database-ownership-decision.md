# Global / Regional Database Ownership — Documentation Pass

## Scope

Documentation-only pass that records the formally decided Global / Regional database ownership so
the upcoming clone-and-prune of `umaxica-apps-global` into `umaxica-apps-regional` has a written
authority. No `config/database.yml`, schema, migration, model behavior, service, controller, job,
Compose, Neon, CI, Solid Queue, Flipper, Valkey, or storage change was made. The only source edits
are two comment-only header lines in `app/models/{app,com}_rp_record.rb` (detailed in section E).

This pass resolves the `M1` question left open by
`evidence/2026-09-08-global-regional-database-split-assessment.md`.

## Methodology

Reviewed the existing ADR conventions (`adr/README.md` — kebab-case descriptive filenames, no
numbering, `Status: Accepted` + date, supersession recorded both in-file and in `adr/README.md`) and
the affected architecture / identity / operations documents. Authored one new ADR, added
cross-reference banners to the affected docs, updated `adr/README.md` and
`adr/principal-zenith-physical-consolidation.md` supersession notes, corrected the two contradicting
model header comments, and ran a repository-wide consistency grep.

## A. ADR

**New:** `adr/global-regional-database-ownership.md` — Status `Accepted` 2026-09-08.

Decision summary:

- `app_zenith` / `org_zenith` / `com_zenith` are **Global-only**; the Account / Identity /
  Organization / principal graph they hold is Global canonical authority. `M1` resolved.
- `app_ticket` / `org_ticket` / `com_ticket` are **Global-only** (sessions, tokens, OIDC, ceremony
  state). Regional trusts acme-issued downstream tokens; it never reads a Global ticket database.
- `app_setting` / `org_setting` / `com_setting` are **Global-only** (preference architecture as-is).
- `app_signal` / `org_signal` / `com_signal` are **Global-only** and retained as the Global
  notification-state subsystem despite limited current implementation — not `DELETE`.
- `avatar` is **Global-only** (Avatar identity, handle/moniker, social graph, Avatar↔account
  bindings). Regional references Avatar by `avatar_public_id` through a contract only.
- `publishing` is **Global-only**; Regional consumes content only through
  `GET /api/v0/entries(/:slug)`.
- `chronicle`, `occurrence`, `platform`, `queue` exist in **both** repositories as **completely
  independent** databases — same subsystem concept, possibly the same starting schema, separate
  connections / data / state / migration history / runtime ownership. Never a shared database.
- Regional owns **one new Regional application database** (name and full domain fixed at
  implementation time). Any Global-entity projection it holds is a read-side copy keyed by an
  immutable public identifier; Regional is never a second writer of canonical mutable Global data.
- `search`, `storage` (zero migrations), and `db/audit_schema.rb` (orphan stub) are deletion
  candidates for the split — no deletion performed here.
- No-shared-database invariant and the explicit cross-boundary contract rule (HTTP/API, signed
  token, JWKS, event/message, outbox, immutable public identifier, local projection) are recorded.
- Rejected alternative: regionalizing `*_zenith` — rejected because it introduces distributed
  identity, uniqueness, authorization, cascade, and transaction complexity with no benefit given
  `adr/identity-authority-boundary.md` already places account/identity authority in this repository.

`adr/README.md` updated: new entry under "Current database naming decisions"; supersession notes
added to the `adr/principal-zenith-physical-consolidation.md` and
`adr/split-into-regional-and-global-repos.md` list entries.

## B. Docs updated

Cross-reference banners pointing at `adr/global-regional-database-ownership.md` as the normative
ownership decision were added to:

- `docs/architecture/database-authority-placement.md` — banner; the reserved-`*_principal`
  "regional-ready" role is marked retired.
- `docs/architecture/model-database-inventory.md` — banner; "target authority" / "future
  regional-ready" columns marked as predating the decision.
- `docs/architecture/principal-zenith-membership-organization-placement.md` — banner; `Member` /
  `ClientMembership` / `Organization` confirmed Global, decomposition is an internal Global matter.
- `docs/architecture/regional-content.md` — banner; database ownership map lives in the ADR, this
  doc is the delivery boundary.
- `docs/architecture/database-boundaries.md` — banner; `*_principal` regional-ready role retired,
  `search` / `storage` are deletion candidates.
- `docs/identity/authority-boundary.md` — banner; the databases backing acme authority (`*_zenith`,
  `*_ticket`, `*_setting`) are Global-only and never Regional-owned.
- `docs/operations/db-workflow.md` — new "Global / Regional Split (planned)" section: which
  databases stay, which are duplicated-but-independent, independent migration history after the
  split, deletion candidates.

Role separation preserved: the ADR is the normative decision; the architecture docs remain
current-topology / explanatory and now reference the ADR; `db-workflow.md` carries the operational
consequence. The same information was not copied verbatim into every file.

`adr/principal-zenith-physical-consolidation.md` — in-file "Partially superseded (2026-09-08)"
banner added: the migration-history consolidation and semantic base classes stand; the reserved
`*_principal` regional-ready role is retired; the investigation also found the reserved directories
/ connection keys were never created.

## C. M1 resolution

```text
M1 RESOLVED:
*_zenith remains GLOBAL.
```

`app_zenith`, `org_zenith`, and `com_zenith` are Global-only databases holding Global canonical
Account / Identity / Organization authority. Regional never owns or writes these records. This is
consistent with `adr/identity-authority-boundary.md` (`acme/www` is the Account / Session / Token /
Preference / Authorization / downstream-token Authority) and
`docs/architecture/model-database-inventory.md` (zenith as the account / identity graph). The
contradicting reading ("Local. Region-specific.") is rejected and its two occurrences are corrected
(section E).

## D. Final database ownership

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
platform
queue

REGIONAL ONLY
-------------
regional application database (new; name and full domain decided at implementation time)

DELETION CANDIDATES (not retained; no deletion performed this pass)
------------------------------------------------------------------
search          (0 migrations, no models)
storage         (0 migrations, superseded by S3 / Shrine)
db/audit_schema.rb   (orphan stub for a non-existent connection)
```

## E. Contradictions fixed

1. **`app/models/app_rp_record.rb` and `app/models/com_rp_record.rb`** header comments read
   `# Deployment scope: Local` /
   `# Region-specific. Each region ... has its own isolated database instance.` — a direct
   contradiction of the now-accepted decision and of the sibling `app/models/org_rp_record.rb` which
   already read `# Deployment scope: Global`. Changed to the Global wording plus a one-line pointer
   to `adr/global-regional-database-ownership.md`. **Comment-only change.
   `connects_to database: { writing: :app_zenith, reading: :app_zenith_replica }` (and the com
   equivalent) is untouched; no behavior, connection, or migration path changed.** No test asserts
   on these comment lines (`grep -rn "Deployment scope\|Region-specific" test/` → no matches).

2. **`adr/principal-zenith-physical-consolidation.md`** stated the reserved empty `*_principal`
   databases "are available for a future regional-ready application-data role." Superseded in-file
   and in `adr/README.md`: `*_zenith` is Global authority; regional-ready data lives in the Regional
   repository's own application database. Also noted: the reserved directories / connection keys it
   names were never actually created (Phase 1.5 finding).

3. **`docs/architecture/database-authority-placement.md` / `model-database-inventory.md` /
   `principal-zenith-membership-organization-placement.md` / `database-boundaries.md` /
   `regional-content.md`** treated `*_zenith` as a "target authority" / "future regional" placement
   that was still undecided. Banners added making the Global ownership normative and pointing at the
   ADR.

### Contradiction found but deliberately NOT changed

- **`app/models/search_record.rb`** header still reads `# Deployment scope: Local` /
  `# Region-specific.`. The `search` database has zero migrations and no models; the ADR classifies
  it as a deletion candidate rather than assigning it Global or Regional ownership. Rewriting the
  comment would imply a classification the ADR intentionally does not make. Left for the deletion
  work in the implementation phase.
- **`docs/architecture/principal-zenith-membership-organization-placement.md`** body still lists
  "regional membership" as one possible future mapping for `ClientMembership` inside its
  decomposition analysis. The new banner states `Member` / `ClientMembership` / `Organization` are
  Global; the decomposition ADR
  (`adr/member-client-membership-organization-decomposition-before-placement.md`) is still open, so
  the body's exploratory options were left intact under the banner rather than rewritten.

## F. Remaining ambiguous domains

- **Regional application database — name and full domain.** The ADR fixes that it exists and that it
  is Regional-only and never a second writer of Global data; it does not fix its name or its
  complete table set. To be decided in the implementation phase against
  `adr/surface-database-connection-naming.md` / `adr/actor-db-naming-policy.md`.
- **Cross-boundary contract protocol design** — downstream token claims, JWKS distribution and
  revocation propagation, `Core*Bridge` provisioning as an event/API, audit/telemetry egress from
  Regional `chronicle`/`occurrence`. The seams are identified; the wire protocol is
  implementation-phase work.
- **`Member` / `ClientMembership` / `Organization` internal decomposition** — still governed by
  `adr/member-client-membership-organization-decomposition-before-placement.md`; unaffected by this
  decision except that the rows are confirmed Global.
- **`ClientOidcConnection` / `OperatorOidcConnection` / `VisitorOidcConnection` placement** — the
  Phase 1.5 assessment listed these as `UNCLEAR` between ticket-side and a future authority
  placement. They remain ticket-side (Global) for now; no change.
- **`db/audit_schema.rb`, `search`, `storage`, orphaned trigger functions, stale CI env matrix** —
  agreed deletion candidates; deletion deferred to the implementation phase.

## G. Verification

- `bin/rails test test/tooling/evidence_layout_test.rb` — 3 runs, 6 assertions, 0 failures, 0
  errors, 0 skips.
- Consistency grep across `docs/` and `adr/` for `zenith.*(local|region)`, `shared database` /
  `common database`, `regionaliz`, `per-region (identity|account|zenith)`,
  `each region.*isolated.*database`: no remaining Global/Regional shared-database language and no
  remaining "zenith is Local/Regional" claim except the two items in section E that were
  deliberately left (`search_record.rb` comment; the `ClientMembership` decomposition options under
  the new banner). The `token-symbol-mark-database-boundary.md` "one shared database" reference is
  about the historical single token/symbol/mark database, not a Global/Regional claim.
- No test asserts on `Deployment scope` / `Region-specific` comment text (`grep -rn` over `test/` →
  no matches), so the two comment-only edits are safe.
- No schema, migration, `database.yml`, Compose, CI, or runtime-config file was modified.

## Final note

This pass fixes the design decision in documentation only. Repository split and database
implementation have not begun. The earlier investigation record
(`evidence/2026-09-08-global-regional-database-split-assessment.md`) is unchanged and remains
accurate as of its date; its `M1` is resolved by `adr/global-regional-database-ownership.md`.
