# Critical blocker decision inputs

- Date: 2026-09-23
- Scope: pre-deployment repository cycle
- Frozen Plan: `plans/backlog/2026-09-17-integrated-hardening-plan.md`
- External activity: none; no production, provider, AWS, Cloudflare, or GitHub write was performed.

This document narrows the remaining human decisions. It does not invent owner mappings, regional
registrations, credentials, or production data. CF-005 and CF-011 are already closed for the
pre-deployment scope; their later deployment/provider gates remain in the Frozen Plan.

## Approved decision amendment (2026-09-23)

The following decisions are now approved. The choice tables later in this file are preserved as a
historical record of the input request and are not current open decisions.

### CF-003 / CF-004

Choice A is approved: the explicit surface-local ownership relation is the only owner authority
after family cutover. The mapping is `Client -> Persona/Enterprise` on app, `Visitor ->
Individual/Company` on com, and `Operator -> Agent/Bureau` on org. There is no shared owner table,
STI, polymorphic owner FK, or cross-surface owner relation. Legacy identity bindings, assignments,
memberships, administrator relations, legacy owner fields, and legacy `Organization` hierarchy
data are candidate evidence only; legacy `Organization` is not `Bureau`.

Ownership fact and authority eligibility are separate. Suspended principals retain the relation but
cannot exercise it; inactive/discarded/deleted principals and inactive/retained resources do not
become new authority candidates. Zero, multiple, inactive-only, membership-only, administrator-only,
cross-surface, legacy-only, and contradictory candidates are rejected or retained for
manual-review/ownerless disposition, never tie-broken. A family cutover requires zero unresolved
authority-required active rows. Rollback is permitted only before the first consumer reads the new
authority; thereafter recovery is forward-only and legacy authority is not restored.

### CF-007

Choice B is approved: Core and Side app/com/org have independent JP and US RPs, while `edit-org`
remains global. The approved logical IDs are:

`core-app-jp`, `core-app-us`, `core-com-jp`, `core-com-us`, `core-org-jp`, `core-org-us`,
`side-app-jp`, `side-app-us`, `side-com-jp`, `side-com-us`, `side-org-jp`, `side-org-us`, and
`edit-org`.

Each cell has independent client binding, audience semantics, exact redirect/logout/backchannel
bindings, private-key-JWT namespace, and RP Session binding. Existing protocol-level `side-*`
names remain; Side/Wide to Warp renaming is not part of this migration. The current seven-client
registry and `core-next-rp` remain under expand-and-contract until explicit caller/session/code
retirement is proven. Missing URI/audience values must come from a canonical repository SSOT or
remain unimplemented; arbitrary Host-derived registrations and guessed values are forbidden.

Real Base registration, credential fingerprints, deployed callers, production data, and live
retirement are later deployment gates, not current pre-deployment requirements.

## Historical decision-input record: CF-003 / CF-004 — owner authority and cutover

### Repository facts already established

- The six adopted resource families are app `Persona`/`Enterprise`, com `Individual`/`Company`,
  and org `Agent`/`Bureau`.
- Their existing identity bindings, assignments, and memberships do not by themselves prove the
  adopted Client/Visitor/Operator owner relation.
- Legacy org `Organization` is a separate resource with nullable `operator_id` and legacy hierarchy
  data; it cannot be mechanically equated with the adopted `Bureau` authority.
- The isolated owner inventory currently contains zero authority-bearing resource rows. That proves
  the inventory path and empty test state, not a production mapping.
- The authored surface-local owner tables and creators are not enabled in runtime routes. A
  repository-only direct-binding backfill operation now exists and is covered by isolated tests; no
  production backfill, destructive cutover, or legacy-consumer retirement has been performed.

### Historical human decision request (superseded by the approved amendment above)

Approve one source-of-truth policy for each resource family, including the legacy org resource:

| Choice | Meaning | Security/data impact | Migration cost |
| --- | --- | --- | --- |
| **A — new authority relation** | The explicit surface-local owner relation becomes authoritative after cutover; identity bindings, assignments, and memberships are migration inputs only. | Clear authority and unique-owner enforcement; unresolved rows must remain ownerless/manual-review. | Highest: mapping, backfill, consumer cutover, rollback/forward recovery. |
| **B — legacy source retained** | Existing assignment/membership or legacy owner fields remain authoritative and the authored owner graph is not enabled. | Avoids destructive migration but does not satisfy the adopted explicit-owner contract. | Lowest now; leaves target authority work open. |
| **C — dual authority** | Both old and new sources remain authoritative or are read interchangeably. | Unsafe unless a separately approved reconciliation authority exists; creates disagreement and split-brain risk. | Highest ongoing complexity; not acceptable by default. |

For Choice A, the approval must also state:

1. the exact owner mapping rule for every resource family;
2. lifecycle eligibility for active, suspended, discarded, deleted, and retained resources;
3. conflict disposition for zero, one, multiple, inactive, cross-surface, legacy-only, and ownerless candidates;
4. whether unresolved rows are skipped as ownerless or block the entire cutover;
5. cutover ordering and the exact point at which the new relation becomes the only authority;
6. rollback versus forward-recovery behavior after any consumer has read the new authority;
7. whether the legacy source is retained as historical data, and when its reads/writes are retired.

No implementation may select the first assignment, promote a membership, promote an administrator,
or silently discard an ambiguous row.

### Required repository work after approval

1. Encode the approved mapping and conflict rules in the existing inventory/backfill operations;
2. add isolated fixtures for every approved disposition;
3. run migration/backfill idempotency, unique-owner, conflict rejection, rollback, and
   forward-recovery tests on disposable databases;
4. cut consumers over only after the new relation is proven authoritative;
5. retain production row inventory, real cutover, and post-cutover proof as deployment gates.

### Minimum acceptance evidence

- Approved mapping and lifecycle/conflict matrix;
- every isolated fixture classified deterministically;
- duplicate/ambiguous ownership rejected or explicitly manual-review/ownerless;
- repeated backfill produces no duplicate owner or duplicate side effect;
- rollback/forward recovery is demonstrated without exposing a split authority;
- a post-cutover test proves all enabled consumers use exactly one approved source of truth.

## Historical decision-input record: CF-007 — regional RP identity matrix

### Repository facts already established

- The accepted ADR currently defines seven logical first-party browser RPs:
  `core-app`, `core-com`, `core-org`, `side-app`, `side-com`, `side-org`, and `edit-org`.
- The registry currently gives those seven independent JWT namespaces and private-key-JWT bindings.
- `core-next-rp` remains a compatibility registration with a live local bridge path; it cannot be
  retired solely because local tests pass.
- Current local evidence proves registry behavior and cross-realm rejection, but not any external
  Base registration, deployed caller, or regional credential fingerprint.
- A separate target requirement calls for JP/US-independent regional RP identities for regional
  surfaces, while allowing a genuinely global RP such as `edit-org` to remain regionless. The exact
  migration contract from the accepted seven-client ADR is not yet approved.

### Historical human decision request (superseded by the approved amendment above)

Approve one matrix before changing registry IDs or key namespaces:

| Choice | Logical browser clients | Impact | Migration cost |
| --- | --- | --- | --- |
| **A — seven logical RPs** | Keep the accepted seven IDs; JP/US are URI/deployment faces of each logical RP. | Preserves current ADR and local callers, but does not provide independent regional client/key authority. | Lowest; cannot satisfy a strict independent-region credential requirement. |
| **B — regional expansion** | One independent client for each regional Core/Side surface and audience, plus regionless global `edit-org` (expected 13 if all app/com/org Core and Side surfaces are regional). | Strong JP/US isolation with separate IDs, audiences, redirect/logout/backchannel URIs, keys, and RP bindings. | Highest; requires caller mapping, Base registry rollout, migration order, and retirement of old sessions/keys. |
| **C — explicitly scoped hybrid** | Approve exactly which surfaces are regional and which are global; do not infer the omitted entries. | Can minimize migration but must specify every exception and prevent cross-region acceptance. | Depends on the exact matrix; requires explicit test and cutover rules. |

The approval must provide:

1. canonical client ID for every matrix cell;
2. audience and resource type;
3. exact public/private redirect URI, post-logout URI, and backchannel logout URI;
4. independent private-key-JWT namespace/key for every independent RP;
5. Base registry record mapping and RP Session client binding;
6. caller-to-client mapping for Core/Side/Edit and the `core-next-rp` migration order;
7. rollback and retirement behavior for old IDs, sessions, codes, and credentials.

The registry must not create an entry for an unapproved region or derive an RP from an arbitrary
Host header. JP credentials must fail for US redirect/client/audience bindings and vice versa.

### Required repository work after approval

1. Amend the accepted ADR with the approved matrix and supersession rationale;
2. update the static registry and explicit key namespace mapping;
3. migrate callers in the approved order, keeping `core-next-rp` until its real call path is retired;
4. add exact URI/audience/key/client-binding and JP/US cross-acceptance rejection tests;
5. document external Base registry and deployment steps without performing them locally.

### Minimum acceptance evidence

- Repository test fixture contains every approved matrix cell and no unapproved cell;
- each client has independent client ID, audience, exact redirect/logout/backchannel bindings, and
  key namespace;
- JP and US cross-acceptance is rejected before code consumption, rotation, or session issuance;
- `core-next-rp` migration/rollback order is tested without deleting a still-live compatibility path;
- external Base registry, credential fingerprint, and deployed-caller checks remain later deployment
  acceptance gates.

## Current status after approval

- `CF-003/CF-004`: `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`. The approved mapping,
  lifecycle/conflict rules, administrator-only manual-review disposition, immutable cutover marker,
  atomic/idempotent backfill, post-marker rejection, and repository-side consumer boundary passed
  the isolated PostgreSQL acceptance set (`97 runs / 690 assertions / 0 failures / 0 errors / 0
  skips`). Production inventory, live cutover, and operational forward-recovery rehearsal remain
  deployment gates.
- `CF-007`: `OPEN — CONTRACT CONTRADICTION` for the remaining repository contract inputs. The
  approved 13-cell logical matrix and expected registry shape are implemented, but no canonical Side
  US host source or regional audience SSOT exists. No value may be guessed or derived from Host
  headers; the active registry therefore remains unchanged.
- `CF-005`: `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`
- `CF-011`: `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`

The next implementation cycle may proceed within the approved pre-deployment boundary. It may add
repository contracts, isolated tests, and local implementation slices, but it must not perform
production owner backfill, authority cutover, regional credential generation, external registration,
or deployment retirement. A blocker remains open until the Frozen Plan's pre-deployment acceptance
evidence is complete.

The 2026-09-23 current-process acceptance recheck completed the CF-003/CF-004 pre-deployment
scope. See `evidence/2026-09-23-cf003-cf007-predeployment-acceptance-F7G8.md`. This does not close
CF-007: its missing canonical Side US host and regional audience source remain a repository contract
contradiction, and no guessed regional registration was activated.
