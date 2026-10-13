# Persistent identifier contract

## Status

Accepted user contract, recorded 2026-10-11. Implementation and verification remain in progress.
This records the I requirements adopted by `nine.md`, Sections 5 and 10, and C01–C15; it does not
grant additional SQL, trigger, role, deployment or destructive-operation permission.

## Context

Database row identity, external resource identity, references, shared correlation values, late
results, token state, externally governed values, human codes and secrets have different lifecycles.
Applying one column-name rule to all of them can break authorization, protocol entropy, historical
identity and legitimate one-to-many relationships. Current code and old test results show
implementation state rather than amend this accepted contract.

## Decision

### Database-local row identity

UMAXICA-owned persistent tables, including reference/status/catalog tables, use one `id` primary key
with actual PostgreSQL bigint width. Bigserial and bigint identity qualify. Fixed catalog rows need
not acquire a sequence. Framework/extension-owned tables retain their dependency contracts;
ownership must be evidenced rather than inferred from the absence of a Rails model.

Bigint provides a conventional local join/index representation and separates storage identity from
external compatibility. It does not imply business time, commit order or freedom from secondary
index maintenance. Native cross-database references and new remote bigint references remain
prohibited by the cross-DB policy. JSON/JavaScript consumers must preserve integer precision in
existing permitted paths.

### Self-controlled non-secret opaque identity

Use the existing CSPRNG-backed NanoID implementation with its verified alphabet and standard
generation length 21. Standard string/varchar storage capacity is 25. The extra capacity is not
permission to generate arbitrary lengths or accept arbitrary legacy formats. Generation, storage
capacity and explicitly supported compatibility are independently verified.

NanoID avoids embedding time, sequence, region or business membership into an opaque value. Do not
replace it with a custom PRNG, post-generation case transformation, binary storage or fixed-width
char based on unmeasured performance assumptions. Share generation mechanics, not the meaning,
lifetime or authority of sid, jti, resource IDs and transaction IDs. Do not add an otherwise unused
opaque column to every table.

### Meaning, resolution and uniqueness

A logical issuing domain, resource kind and identifier together determine the resource. An
entrypoint that fixes the first two need not store them redundantly. Jobs, events, caches and
generic resolution must retain that context. Physical database/host names, region, language and
current organization are not default issuing domains. Untrusted resource kinds cannot select
arbitrary models; resolution uses permitted families and verified issuing context.

Classify each candidate as owned identity, reference, shared correlation, late result, current
token/state pointer, externally governed identifier, human code or secret/protocol value. A
permanent owned identity is required, nonblank, unique in its actual ownership scope and immutable
after creation, including logically deleted rows. References/shared IDs do not automatically receive
single-column uniqueness or immutability. Unavailable results remain NULL rather than receiving
dummy identities. Separate shard-local uniqueness from any evidenced distributed guarantee; do not
invent a central identifier service for hypothetical future needs.

Short-lived receiver capabilities that only index a purpose- and surface-bound Valkey record are
references, not durable resource identities or signed result evidence. An established UUID-v4
admission transport may retain that format when its receiver validates the same contract; changing
it requires a consumer-specific transition with an exact legacy reader. The NanoID rule alone does
not authorize reformatting a capability, weakening its receiver validation, or adding a
cross-surface lookup fallback.

### Database protection and authorized mechanisms

Model validation alone cannot establish integrity for update_columns/update_all/upsert/bulk or
direct SQL. Map every required guarantee to its actual constraint, privilege or narrowly approved
mechanism before implementation. CHECK, FOREIGN KEY, UNIQUE and EXCLUDE are preferred where
sufficient. A forbidden mutation fails explicitly and leaves original identity/references intact;
valid reference and token-state changes remain permitted.

The 2026-10-13 user decision permits narrowly scoped permanent-ID triggers for APP/COM/ORG setting
Preferences with no ordinary update exception; see the named exception in
`adr/database-trigger-usage-boundary.md`. Other tables require their own enforcement assessment.

The trigger ADR's general boundary and Avatar D-3/D-4/D-10 approvals do not authorize a general
identifier immutability trigger. Existing proof triggers remain scoped to their named proof
invariants. If authorized mechanisms cannot enforce an identified invariant, hold that invariant,
record the exact gap and smallest required decision, and continue unrelated verified work. This ADR
neither claims a missing guarantee exists nor creates the extra approval.

### Collisions, retries and indexing

The real database uniqueness constraint is authoritative. Only a confirmed collision on the exact
internally generated target identity constraint may cause bounded regeneration. Recover the failed
transaction/savepoint first; propagate unrelated business/external/import uniqueness errors. An
exists? preflight and large random sample do not prove safety. Ensure retry does not duplicate
notification or other external effects. Business-request idempotency remains an independent
contract, including the Avatar registry and stable UUID request keys.

Identifier indexes default to B-tree, not Hash. Inspect actual key expressions, uniqueness,
predicate, INCLUDE distinction and valid/ready/live flags. Do not add a redundant index, treat a
composite/partial/partition-local index as identifier-wide uniqueness, or rewrite unrelated
GIN/GiST/BRIN indexes. Any retained Hash exception needs specific grounds and reconsideration
conditions. Opaque values retain case-sensitive comparison; change collation only with actual
collision and rebuild-impact evidence. Time ordering uses appropriate time columns, preserving safe
existing keyset tie-breakers and external cursor contracts without exposing local PKs.

### Externally governed values and secrets

Format authority, rather than generator identity or column name, determines an external exception.
Provider/protocol credential IDs, UUIDs, PKCE, nonce/challenge, verifier and cryptographic keys
retain their actual format, entropy, comparison, lifetime and uniqueness scope. Native UUID may
remain native UUID. No automatic 25-character cap, truncation, case conversion or replacement
mapping/public-ID layer is permitted merely to match the local standard. Unknown external bounds
remain explicitly unknown with existing safe input controls.

For each actual exception, leave a short code reason and ADR reference, the authoritative ADR
rationale/scope/rejected alternatives, and a table/column guideline with format, bounds, comparison
and uniqueness. "Legacy", library defaults and unexplained existing code are not permanent exception
rationales. Separate legitimate permanent exceptions, transitional compatibility with consumer/exit
conditions, existing violations and unverified facts.

### Identity-preserving migration

New issuance does not authorize changing already issued identifiers. Preserve
URL/API/authentication, revocation, cookies, audit, jobs, caches, storage and cross-DB consumer
meanings. Logical restore, recreation, merge and transfer must distinguish the same continuing
resource from a new one; permanent identities are not intentionally reassigned to another resource.
No unneeded universal permanent-ID ledger is introduced.

Before narrowing bounds or enforcing constraints, inspect aggregate null/blank/length/duplicate and
comparison-collision facts, references and every writer. Do not output PII/secrets or delete an
ambiguous row to clear a constraint. Existing non-bigint PK migration preserves old values and
references through a staged mapping; it never drops/truncates the table or force-casts text IDs. Use
additive migrations and bounded, resumable operational backfills as applicable; preserve existing
correct IDs and applied migration history. Writer control, new/old application coexistence, locks,
index-build failure and rollback/forward recovery require explicit procedures. Do not run trial
nextval or automatic sequence repair during inventory. No production/shared destructive operation is
authorized here.

## Consequences and current limitations

Consistency is defined by semantic role rather than matching spelling. Capacity 25 does not justify
invalidating valid long issued references: any necessary bounded transition must name its actual
consumers and exit condition. Ordinary creation does not accept arbitrary caller-specified owned
identity; authorized import is a separate path. Bulk writers explicitly supply identities or fail at
the database, and cannot hide missing inserted rows as successful completion.

Acceptance definitions live in the durable identifier checklist, not in this ADR's status. The
current ORG Telephone expansion/backfill and physical catalog findings are revision-scoped evidence;
complete NOT NULL, permanent DB immutability, safe cutover and comprehensive executable
classification guards remain unproven. This decision does not introduce GUID-surface persistence,
resolver behavior or a global ID service; `guid-identifier-surface.md` continues to own that
separate bootstrap and its unresolved public API.

## Related

- [Persistent identifier acceptance](../docs/checklists/identifier-contracts.md)
- [Integrated acceptance](../docs/checklists/integrated-stack.md)
- [Cross-DB reference policy](cross-db-reference-policy.md)
- [Database trigger boundary](database-trigger-usage-boundary.md)
- [GUID surface](guid-identifier-surface.md)
- [Realm-separated identifiers and dead history](realm-separated-identifiers-and-dead-history.md)
- [Database workflow](../docs/operations/db-workflow.md)
