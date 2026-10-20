# Decisions required before affected changes

## D1 — Publishing taxonomy duplicate exception contract

Status: decided by the user on 2026-10-19: preserve the existing contract and retain all twelve
reports as unresolved; continue independent remediation. No behavior change is authorized for D1.

The twelve physical TaxonomyTerm models share `PublishingTaxonomyTermRecord`. Each actual table has
`UNIQUE(vocabulary_id, locale, slug)` (for example `uidx_docs_app_term_slug`). Its same-family,
same-vocabulary, same-locale duplicate raises `ActiveRecord::RecordNotUnique` from normal create!; a
different locale remains valid. Archived slugs stay reserved. These are observable contracts in
`TaxonomyConstraintsTest` and `TaxonomyRetirementTest`, backed by the actual current indexes and
`adr/publishing-taxonomy-architecture.md`.

`UniqueIndexChecker` requires a matching uniqueness validator even when the database is deliberately
the authority. A standard matching validator changes create! failure to RecordInvalid and adds a
SELECT to each validation. Removing or relaxing the unique index weakens integrity. Neither option
is justified by achieving zero reports. No checker suppression or definition change is authorized as
a workaround.

Concrete alternatives:

1. Preserve the existing database exception contract and keep these twelve reports unresolved in the
   ledger. Continue independent correct fixes. Zero findings remains unachieved.
2. Obtain an explicit specification change for model preflight errors and associated callers/query
   budgets before implementing any validators. This changes an existing valid failure contract and
   cannot be applied solely to satisfy the checker.

The user explicitly selected alternative 1. The conflict does not block unrelated work and is not
completion. The owning Concern carries a FIXME; the twelve report rows remain open with the recorded
decision D1.

## D2 — Public-ID column expansion and rollback

Status: investigation; no migration generated or applied.

Before: 216 modeled `public_id varchar(21)` columns with shared validation capacity 25. After
candidate: the same columns at varchar(25), preserving values, collation, nullability, indexes and
normal NanoID-21 issuance. This follows the identifier ADR capacity rather than shrinking the shared
validator. Some concrete models also declare a stricter maximum 21; consumer/effective-validator
mapping is still required, and no such validator is removed here.

Each owning database needs its own migration. Widening requires a lock; preserve the configured lock
timeout and fail/retry operationally instead of extending it silently. A rollback to capacity 21 can
lose or reject future values of length 22–25 and requires a reviewed data-preserving recovery plan.
Local aggregate maxima do not authorize production assumptions or a narrowing down migration.
Complete table inventory and consumer review precede any final implementation proposal.

## D3 — Grant historical token references versus stable device-session ownership

Status: decided by the user on 2026-10-19: preserve the current lifecycle and retain all three
reports as unresolved; continue independent remediation. No token FK addition is authorized.

Three ForeignKey reports request token FKs on OpAppGrant.client_token_id,
OpComGrant.visitor_token_id and OpOrgGrant.operator_token_id. The read-only local preflight found
all three source tables empty, but this does not establish that adding the constraints is correct.

`DeviceSessionRootAndRpBinding.add_rp_device_session_constraints!` deliberately removes each token
FK after adding and validating the stable device_session_id FK and moving live-grant uniqueness to
(device_session_id, oidc_client_id). The 2026-10-06 delivered reconciliation in
`adr/device-session-dbsc-device-id-boundary.md` names the stable device session as the parent.
`RpSessionTest` explicitly requires the grant to survive physical deletion of the old rotating token
and remain usable across token rotation through the device session. Its source contract was
inspected and the full RpSessionTest file passed in the isolated 127-test and 215-test C4 slices.

A new token FK with RESTRICT blocks the tested old-token deletion; CASCADE destroys the retained
grant. NULLIFY requires nullability/data-contract changes. Removing the association merely to
silence the checker discards an existing API and does not solve historical-reference semantics. No
such change is authorized by the consistency task. Retain all three reports and the existing
references/device-session authority unless the user approves a separate lifecycle redesign.

## D2a — first bounded public-ID capacity migration: MediaFile

Status: approved by the user on 2026-10-19 for the exact local shape, targets, dump scope and
capacity-preserving recovery below. Implementation and rehearsal remain pending.

```text
Before: publishing.publishing_media_files.public_id varchar(21) NOT NULL
        UNIQUE index_publishing_media_files_on_public_id (public_id)
After:  publishing.publishing_media_files.public_id varchar(25) NOT NULL
        UNIQUE index_publishing_media_files_on_public_id (public_id)
```

Authority: identifier-contract ADR separates NanoID-21 issuance from storage capacity 25. The model
already uses PublicId's maximum 25 without a stricter local validator. Issuance remains NanoID-21.
No existing identifier, metadata, storage key, encryption, foreign reference, nullability or unique
constraint is rewritten. There is no tuple/enum change. Normal uploads and lookups retain their
current inputs and outputs.

Actual local consumers are the Shrine attachment and object-storage verification task; revision and
version media usages reference media_files.id (BIGINT), not public_id. Current application/lib
search found no fixed-21 parser for this model's public_id. This does not authorize the other 215
public-ID expansions: vocabulary/term snapshots, for example, have separate exact-21 constraints and
need their own compatibility decision. Never widen every similarly named reference blindly.

Proposed generated migration body (with explicit owner/type preconditions added before execution):

```ruby
def up
  change_column :publishing_media_files, :public_id, :string, limit: 25
end

def down
  raise ActiveRecord::IrreversibleMigration,
        "Keep capacity 25 when rolling application code back; narrowing requires a separate data-preserving approval"
end
```

Recovery decision requested: rolling application code back retains the expanded capacity. A schema
rollback never automatically narrows, truncates, deletes or rewrites a value. Any later request to
return to 21 requires a separate permitted-target length inventory and safe recovery approval. This
is an explicit exception to automatic schema reversibility, not a claim that shrinking is safe.

Execution scope requested: local schema rehearsal on a newly created, receipt-owned disposable
Publishing clone, then the existing manifest-verified isolated Publishing parent
`codex_integrity_20261017c1a2_publishing` for model/integration checks. No normal development DB,
production DB or unrelated parent database is selected. Confirm logical owner, actual database
identity, current varchar(21), NOT NULL and unique-index definition before applying. Preserve the
configured short lock timeout. PostgreSQL ALTER TYPE requires a strong table lock; local relation
and index identities/timings must be measured rather than assuming no rewrite. See the
[PostgreSQL 18 ALTER TABLE documentation](https://www.postgresql.org/docs/18/sql-altertable.html). A
timeout or unexpected target stops the operation without a retry that relaxes safeguards.

Rehearsal: verify a preexisting valid row and schema/index identity survive widening; exercise
24/25/26 model and direct-SQL bounds, duplicate/NULL DB refusal, ordinary NanoID-21 upload and
BIGINT-linked media usage/promotion. No new trigger or model-side uniqueness query is needed. Record
actual migrations and test results, including any blocked check.

Artifact scope requested: regenerate only db/publishing_structure.sql from the verified
post-migration schema, replacing its currently observed empty-schema output. Preserve all other
concurrently changed dumps/configuration/ADR files. Generate into tmp first and review the exact
schema diff. The full schema-drift command must run in an isolated checkout/copy if it would
overwrite unrelated main worktree dumps. Production prerequisites remain explicitly unverified;
local approval is not production execution approval.

### D2a stopped after Red: omitted exact-length constraint

The user approved the capacity-only local migration and capacity-preserving recovery. Subsequent Red
tests exposed a material omission in that proposal: the actual table, HEAD structure dump and
`db/migration_support/publishing_schema.rb` also define `chk_media_files_pid` as
`char_length(public_id) = 21`. Thus widening varchar alone cannot support 22–25 characters. The
proposal incorrectly treated only snapshot columns as exact-length constrained. Do not execute it or
regenerate the dump. A new decision is pending; retain the existing CHECK.

The first draft boundary tests produced two expected DB exceptions (nine tests/34 assertions): 20
characters violated the exact-length CHECK; 24 characters exceeded varchar(21). Their proposed
capacity expectations were not an approved complete schema contract. Replaced those newly authored
draft tests with characterization of the actual exact-length requirement, generated IDs and DB
uniqueness/null refusal; no established test was removed or weakened.

Rails test startup automatically registered the still-empty generated migration on the verified
isolated Publishing parent. Before changing its body, ran its empty `down` through the owning
migration context and confirmed varchar(21); this removed only that migration registration. No DDL,
data rewrite or dump generation occurred. Destroyed the unused generator artifact. Future Red runs
must precede generation of a pending migration because Rails test startup migrates it.

User disposition after the corrected constraint disclosure: preserve the existing constraint, leave
this one report unresolved and continue independent fixes. The previous local DDL approval is not an
authorization to alter or remove the exact-length CHECK. No pending migration remains.

## D4 — bounded RP reverse-reference index proposal

Status: proposed, no migration generated/applied. Begin with rp_base_app only; the other eleven
cells' analogous findings remain independent pending the first verified slice.

```text
Connection: rp_base_app
Before: no index with the following FK as a leading column
After:  rp_identity_bindings(principal_id)           nonunique btree, all rows
        rp_op_session_bindings(identity_binding_id) nonunique btree, all rows
        rp_refresh_attempts(session_id)             nonunique btree, all rows
        rp_event_receipts(op_session_binding_id)    nonunique btree, all rows
```

Authoritative columns and NO ACTION/restrict relations already exist in that same physical DB. The
current create migration explicitly disables automatic reference indexes, then creates only
identity/expiry/public-ID indexes. The real catalog confirms none covers these reverse lookups. The
four parent has_many associations execute these predicates, including restrict_with_error existence
checks. No realm/client filter, uniqueness, NULL semantics, predicate, INCLUDE or operator class is
changed. Nullable identity_binding_id remains nullable. No validation SELECT is added.

Proposed one reversible schema-only Rails migration using disable_ddl_transaction! and four explicit
add_index algorithm: :concurrently declarations, distinct connection-prefixed names. Rollback
removes only these new indexes concurrently; existing constraints/indexes/data remain. A failed
concurrent build can leave an invalid index: stop and inspect its exact catalog identity before any
permitted cleanup/retry. Do not use if_not_exists to conceal partial or mismatched state. Keep short
lock timeout. Four index writes per four corresponding tables add storage/WAL/update maintenance;
measure local build times, sizes, validity and EXPLAIN, and disclose that empty local tables do not
establish production performance. No quantitative production gain is assumed.

Local scope: new receipt-owned disposable clone of manifest-verified
codex_integrity_20261017c1a2_rp_base_app for up/down/up rehearsal and preexisting-row preservation,
then this isolated parent only. Never apply while the full suite is using its snapshots. Generate
only db/rp_base_app_structure.sql via the standard workflow into tmp first; replacement of the
concurrently empty dump needs scoped approval. Other dumps/configuration are untouched. All-cell
extension, normal development DB and production execution are outside this proposal.

Protect actual principal/identity/session/receipt behavior using existing RP refresh, logout and
cell-readiness tests. Verify indexes/catalog/query plans operationally, not with
environment-construction Minitest cases. Production table sizes, long transactions, I/O capacity and
build scheduling remain unverified deployment prerequisites.

## D5 — projected-record saves and required-attribute checker mismatch

Status: implementation stopped; preserving the original guards is the safe interim state. User
disposition is requested before any alternative model contract. C7's nine-report reduction is
withdrawn, not counted as resolved.

Six new public save/update tests load existing records without title and reproduce C7 rejecting
formerly accepted updates. The original implementation accepts all six; three additional tests cover
Organization projections without name. Required attributes assigned explicitly to nil/blank still
fail whole-record validation; partial updates retain the stored required attribute and its DB NOT
NULL guarantee. The checker's WEAK_OPTIONS handling treats has_attribute? as a nullable-column
condition without modeling attribute projection. Removing it changes a real persistence boundary.

C7's five implementation files were restored to original declarations after guarded task-diff
comparison. Only explanatory FIXME comments and the tests remain. No validator order/configuration
change hides the nine returned findings. The final preservation slice passed 344 tests/5,542
assertions, zero failures/errors/skips. A first draft deadline comparison in new nullable tests
compared in-memory nanoseconds with persisted microseconds; corrected the baseline by reloading
before capture, without changing production code or using a tolerance assertion.

## D6 — nine intentional nullable step-up evidence fields

Status: preserve pending/revoked evidence semantics; no NOT NULL/default rewrite authorized. User
disposition is requested before changing authentication evidence.

Three ceremony user_verified columns are nil while pending and become actual boolean evidence only
through record_verification!. Six root-token last_step_up_user_verified/full_reauthentication fields
are explicitly cleared to nil by revoke_step_up_authority!; root token status/deadline remain
intact. The new six-test all-surface characterization passed as part of the 344-test preservation
slice. This confirms the actual lifecycle, not merely nullable catalog columns. NOT NULL would
reject ordinary creation/revocation; defaulting false would conflate absent/cleared evidence with
recorded negative evidence. Keep all nine ThreeStateBoolean reports open. The other six passkey
backup flags still require their own semantics/compatibility review.

D4 operational reference:
[PostgreSQL 18 CREATE INDEX, concurrent builds](https://www.postgresql.org/docs/18/sql-createindex.html#SQL-CREATEINDEX-CONCURRENTLY).
It confirms extra scans/waiting and possible invalid indexes after failure; concurrency is not a
claim of zero cost or zero locking.

## 2026-10-20 reaffirmation

The user explicitly reconfirmed preserving existing duplicate-error and public-ID capacity
contracts, retaining the conflicting reports unresolved and proceeding with independent safe
remediation. This authorizes neither a uniqueness-preflight contract change nor an exact-21 CHECK
removal. No D2/D2a capacity migration is introduced by the current digest-validation slice.
