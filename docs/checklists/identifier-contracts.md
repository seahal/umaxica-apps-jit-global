# Persistent identifier acceptance

These are user-approved I requirements, expressed as observable criteria, not verification results.
Scope and interpretation follow C01–C15 in the [integrated acceptance index](integrated-stack.md).
An identifier-specific ADR/guideline is planned if no current owner exists; do not cite the proposed
`adr/identifier-contract.md` as an existing decision. The existing
[cross-database reference policy](../../adr/cross-db-reference-policy.md) remains a governing
source. Use the index's investigation procedure and separate evidence dispositions for every
criterion.

## ID-1 — Physical identity and ownership

- Basis: I03–I05, I09; cross-database reference policy. Scope: every UMAXICA-owned persistent table,
  including status/catalog tables and tables without models, in every configured database.
- Given the actual table/owner inventory, inspect its PK and create a synthetic row through the
  supported writer: its sole PK is `id` with actual SQL bigint width. Bigserial/bigint identity
  qualify. A fixed-ID catalog may omit a sequence; framework/extension-owned tables retain their
  actual contract.
- Existing rows and external identities do not change merely to satisfy the type rule. Application
  tables cannot be relabeled external to evade it. No UUID/text/string/NanoID new app PK or forced
  string-to-number cast is accepted.
- Check: actual PostgreSQL catalog plus generated schema and model inventory; isolated migration and
  reference-preservation exercise under MIG-1 in the
  [delivery criteria](../../specs/integrated-stack-delivery/acceptance.md). Start at `db/` and model
  connection owners. Comprehensive introspection coverage is planned/not yet established by this
  document; no file-name search or historical migration text proves current types.

## ID-2 — Issuance, capacity and ordinary creation

- Basis: I03/I06/I07. Scope: self-controlled non-secret opaque IDs, regardless of column name.
- Given an ordinary new resource, create it through normal, validation-disabled and bulk writers.
  New IDs use the one approved CSPRNG-backed NanoID mechanism, length 21 and the library alphabet;
  standard string/varchar capacity is 25. Ordinary clients cannot supply their own resource
  identity. Explicit authorized imports have a separate contract. Read/update does not regenerate a
  missing ID.
- Empty/whitespace/NULL/oversized values are refused as applicable to the classified role. Test new
  issuance length independently of storage at 24/25/26; explicitly supported legacy forms remain
  valid. Storage capacity is neither permission to issue arbitrary 1–25 lengths nor an unconditional
  length=21 CHECK. No truncation, case conversion, business meaning, binary/char conversion or
  test-only bypass.
- Check: [PublicId tests](../../test/models/concerns/public_id_test.rb), current generator source,
  model/reference validations, API schemas, forms, fixtures/seeds and direct PostgreSQL writes.
  Extend missing public/bulk boundaries; test presence is not a current pass.

## ID-3 — Semantic roles, scope and remote resolution

- Basis: I04/I08/I10, C05/C06; cross-database reference policy. Scope: owner IDs, references, shared
  session/family/correlation IDs, late results, current-token state, external values, human codes
  and secrets.
- Given each producer/consumer, follow lookup, job/event/cache and cross-DB resolution. Logical
  issuer plus resource kind plus identifier identifies the intended resource; entrypoint-fixed
  context need not be stored twice. Unknown kind/issuer is refused, not dynamically resolved. Same
  string in distinct explicitly identified domains does not authorize cross-domain access.
- Owned IDs have their true unique scope; reference/shared IDs are not made single-column UNIQUE.
  Absent results remain NULL; legitimate reference/token-state transitions stay writable. DB-local
  bigint is not a new remote/API/URL authority. Physical host/DB, region/language/current
  organization are not default issuing domains. Internal PK or secrets must not leak via
  signed/Base64 cursors, cookies or jobs; bigint JSON/JavaScript precision is preserved. Identifier
  knowledge alone grants no authorization.
- Check: producer-to-consumer inventory, authorization/public contract tests and synthetic
  wrong-domain inputs. Read [Action Policy conventions](../security/action-policy-conventions.md);
  preserve existing AUTHZ-1/2 IDs in the separately owned worktree checklist without renumbering
  them. Full role/consumer coverage is planned; record each unverified mapping.

## ID-4 — Permanent identity and database protection

- Basis: I04/I07/I08. Scope: owned permanent resource identifiers, including logically deleted rows.
- Given a persisted resource, attempt duplicate creation and identity mutation via ordinary update,
  update_columns/update_all/upsert and direct SQL. DB constraints reject NULL/blank, duplicate in
  the required ownership scope and forbidden changes explicitly; model validation alone is
  insufficient. A forbidden operation leaves the original identity and references intact. Bulk
  inserts cannot quietly lose requested rows through duplicate skipping and still report full
  success.
- Restore/recreate/merge/transfer does not deliberately assign the identifier to a different
  resource. Test valid reference/state changes separately so immutability is not applied to all
  `*_id` columns. Logical deletion does not free a permanent resource ID. No unnecessary global
  lifetime ledger.
- Check: catalog constraints and public/direct-SQL tests; use isolated transactions/savepoints after
  expected errors. Mechanism approval is checked before implementation by PROC-2; this criterion
  does not authorize new triggers/raw SQL. Complete immutability/bulk regression coverage is
  planned.

## ID-5 — Collision versus business retry

- Basis: I07, I12. Scope: internal new-ID issuance and all writers that retry it.
- Given a deterministic collision on the exact owned-ID constraint, issuance retries only within its
  finite documented bound after restoring a usable transaction. A later successful attempt inserts
  once and emits no duplicate external side effect. At the retry limit it fails explicitly.
- A collision on another business UNIQUE, external value or explicitly imported ID propagates
  without regeneration. A preflight exists? check is not sufficient; replaying the same business
  request is governed by its own idempotency contract, not NanoID uniqueness.
- Check: controlled generator dependency plus real unique constraints, unrelated-constraint failure
  and limit−1/limit/limit+1 attempts where reachable. Start from PublicId tests;
  named-constraint/side-effect coverage is planned where absent. Large random samples do not prove
  collision safety.

## ID-6 — Index, collation, partition and ordering semantics

- Basis: I03/I08/I09. Scope: identifier indexes, comparisons and pagination in actual configured
  DBs.
- Given each lookup, inspect key columns/expressions, predicate, INCLUDE, access method, uniqueness
  and valid/ready/live flags. Required uniqueness is supplied by a valid B-tree constraint/index
  without redundant indexes. Composite/partial/child-only uniqueness is not represented as
  full/global ID uniqueness; INCLUDE columns are not keys. Case-sensitive opaque comparison agrees
  across layers.
- Existing non-ID GIN/GiST/BRIN stays intact. Hash exceptions have specific
  rationale/reconsideration conditions; `_id` alone does not require an index. Collation is not
  changed without data/collision evidence. No partitioning or composite PK is invented to bypass the
  single-PK contract.
- For paging/time order, IDs do not claim business time/commit order; safe existing keyset
  tie-breakers and opaque cursor continuity remain. Check real catalog/query predicates and bounded
  isolated paging/ ordering tests; partition cases apply only when present. Sequence checks belong
  to MIG-1. Coverage of all indexes/partitions is planned, not established by reading schema text
  alone.

## ID-7 — External protocols and issued-value continuity

- Basis: I05–I07/I10/I11, C05/C12. Scope: externally governed/provider/protocol IDs, secrets and all
  already-issued public, session, sid/jti/grant_jti/result_jti/family/transaction references.
- Given an existing valid reference, exercise its original URL/API/authentication/revocation
  consumer. It keeps the same resource/purpose/issuer meaning through a format migration. Protocol
  lengths, case, entropy, comparison, lifetime and issuer/tenant/audience/RP relationship scope
  remain intact.
- No NanoID conversion of PKCE/WebAuthn/CSP nonce/refresh verifier/keys; no arbitrary 25-character
  cap, mass session invalidation, shape-based multi-table fallback, extra mapping/public-ID layer,
  or sid authority inferred from a model name. Current token pointers may rotate without reusing JWT
  identity. UUID transfer idempotency remains the explicit AV-5 exception. Self-generated ceremony
  UUIDs are classified, not automatically called external. A proved security defect is not preserved
  as compatibility.
- Check: consumer regression tests and per-exception code reason/ADR/table-column guideline; unknown
  upstream bounds stay unknown, with current safe limits. Separate permanent exceptions,
  transitional consumers with exit conditions, violations and unverified facts. Full
  exception/consumer audit is planned.

## ID-8 — Executable regression coverage

- Basis: I12–I14. Scope: schema/generator/classification checks in existing Minitest/CI paths.
- Given a deliberate isolated violation, the relevant existing guard detects a non-bigint app PK,
  unclassified new candidate, generator bypass, unjustified bounds, missing required constraints or
  immutability, invalid/wrong index, unexplained Hash, undocumented external exception,
  producer/reference mismatch or new cross-DB bigint contract. Restore the fixture/test change after
  the check; no production bypass or permissive allowlist is introduced.
- Discovery includes unloaded/model-less tables; column regex or any historical SecureRandom.uuid
  occurrence alone is not a semantic verdict. No new runtime multi-DB governance framework.
- Check: actual guard execution and current CI entry, not a sentence in a harness. Comprehensive
  identifier regression guard remains planned until Luna records actual paths and evidence; existing
  PublicId tests cover only their own public behavior.

## ID-3a — ORG Telephone ceremony references

- Basis: I04/I10 and ID-3; scope: OperatorTelephone registration, resend, form admission,
  verification/finalization and queued SMS delivery across org_zenith and org_ticket.
- Given a newly created candidate owned by an authorized Operator and a usable Root session, issuing
  registration proof stores the candidate's NanoID public identity in the ticket ceremony and
  encrypted delivery binding. Its database-local bigint is not the candidate reference.
- Resend, delivery and verification resolve and compare that same public identity together with
  actor, session, purpose, generation and expiry. A former numeric PK binding is refused rather than
  falling back to lookup by id; wrong-owner and stale proof cannot send or finalize.
- Check: public issuer test in
  `test/operations/telephone_credential_registration_otp_issuer_test.rb`, ORG HTTP registration
  tests in `test/controllers/base/org/identity/telephones/registrations_controller_test.rb`, binding
  boundary tests in `test/values/contact_registration_otp_delivery_binding_value_test.rb`, and
  actual queued transport guards. Code inspection alone does not prove asynchronous delivery.
- Before consumer cutover, control old numeric-reference writers and drain their still-valid proof,
  queued delivery and bounded original-operation receipts through their existing authorized paths.
  The candidate reference participates in the keyed OTP verifier; rewriting it alone is not a safe
  proof migration. Do not reissue a public identity on request, rewrite old verifiers without proof,
  or introduce a weaker legacy-proof fallback. Demonstrate the drain/cutover precondition with
  synthetic issued proof; merely backfilling source public IDs does not satisfy it.
- Existing-row operational backfill, NOT NULL cutover and DB immutability remain separately required
  by ID-4/MIG-1; an additive nullable column is not completion of those criteria. Local controller
  PK-based URL/session consumers remain an inventory item under ID-3, not an approved exception.

## ID-3b — ORG Telephone management URLs

- Basis: I03/I07/I10 and ID-3; scope: owner-scoped ORG Telephone index/edit/delete.
- Given an owned candidate with its public identity, the listed public_id and generated edit/delete
  links carry that public identity. Following the edit link succeeds under normal authorization;
  neither the displayed identifier nor new links carry the database PK.
- A foreign candidate's public reference returns not found and leaves both owners' credentials
  unchanged. Malformed or unknown references do not retry against a different identity column.
- Existing positive decimal PK URLs remain explicit transitional compatibility for established
  callers/bookmarks: classify at most 19 decimal digits separately from 21-character public IDs,
  always scope lookup to the authenticated Operator, and never generate new numeric links. Remove
  that legacy reader only after consumer migration and a separately authorized compatibility
  cutover; it is not a permanent exception or permission for new remote bigint references.
- Check: generated-link HTTP test in
  `test/controllers/base/org/identity/telephones/registrations_controller_test.rb`, existing numeric
  coverage in `test/integration/identity_settings_page_coverage_test.rb` and credential-removal
  integration tests. Foreign/malformed/delete coverage must be retained and extended where absent.
- Existing candidates lacking public IDs require operational backfill before new-link deployment; no
  request-time identity generation or source proof fallback is permitted.

## ID-3c — Missing ORG Telephone identity backfill

- Basis: I06/I07/I11 and ID-3a/MIG-1; scope: explicit maintenance of OperatorTelephone rows that
  lack public identity after the additive schema expansion.
- Given a bounded, explicitly selected ORG source relation, dry-run reports missing rows without
  generating IDs or changing data. Apply assigns NanoID-21 only to NULL identities under row locks,
  preserving existing public IDs, source attributes/timestamps and all ceremony/verifier facts.
  Repeating or resuming the operation does not replace a previously assigned identity.
- A collision on the actual public-ID unique constraint retries with a usable savepoint and stops at
  the documented finite bound. Exhaustion leaves that source unchanged and fails explicitly;
  unrelated uniqueness errors are not treated as ID collisions. Invalid realm/scope/mode/batch
  inputs fail before writing. Batch size is explicitly 1–1000, not an unbounded all-row load.
- Check: `test/operations/operator_telephone_public_id_backfill_operation_test.rb` and explicit Rake
  inventory/backfill tasks. Test-only construction of legacy NULL rows bypasses validations;
  ordinary creation and read/update must not become missing-ID repair paths.
- This procedure assigns missing identity only. It does not certify writer quiescence, migrate
  numeric proof bindings, activate NOT NULL, enforce DB immutability or authorize production data
  mutation. ID-3a's independent proof-drain and ID-4/MIG-1 remain required.
