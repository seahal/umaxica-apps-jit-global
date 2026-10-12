# Persistent identifier acceptance

These are user-approved I requirements, expressed as observable criteria, not verification results.
Scope and interpretation follow C01–C15 in the [integrated acceptance index](integrated-stack.md).
The accepted [identifier contract](../../adr/identifier-contract.md) records the user decisions;
[column conventions](../reference/identifier-conventions.md) supply scoped mappings. Complete
per-table classification remains incomplete and must not be inferred from ADR status. The existing
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
  connection owners. The read-only `identifiers:inventory` task is the catalog starting point: it
  scans the configured writer databases, including model-less queue/storage tables, and records
  table ownership metadata, primary-key shape, sequence/identity metadata, candidate-name hints,
  and index access/validity facts without reading application rows. It is evidence for the catalog
  portion only; semantic ownership classification, producer/consumer mapping, exception review,
  and all-table acceptance remain separate work. No file-name search or historical migration text
  proves current types.

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

## ID-4a — ORG Telephone identity survives bypass writes

- Basis: I04/I07/I08, ID-4 and the explicitly approved one-table exception in
  [the trigger boundary](../../adr/database-trigger-usage-boundary.md). Scope:
  `operator_telephones.public_id`, not Telephone reference/state columns or other identifier tables.
- Given an ORG Telephone with a non-NULL public identity, change it to another string, empty string
  or NULL through direct SQL, update_columns, update_all or an upsert conflict update. PostgreSQL
  explicitly rejects the operation with SQLSTATE 23514; the original identity, source facts and
  references remain unchanged. Recover the failed transaction before checking the persisted state.
  An unchanged identity assignment and an unrelated permitted state update succeed. No silent
  rewrite, skipped update, regenerated identity or swallowed exception qualifies.
- Given a genuinely pre-cutover NULL identity inserted through an admitted legacy/bulk writer, the
  bounded NULL-only operational backfill assigns a standard identity once and preserves source and
  ceremony facts. Repeating the backfill leaves that identity unchanged. Do not create this
  precondition by deleting an already issued identity. NULL insertion is transitional compatibility,
  not acceptance of final NOT NULL cutover; ID-4/MIG-1 still require verified writer/proof
  readiness. The reviewed two-step final-constraint migrations now enforce NOT NULL in the current
  run-owned schema; this does not authorize a real-data writer or consumer cutover.
- Check the actual function and attached trigger, exact inventory in
  [enforcement tests](../../test/models/enforcement_triggers_test.rb), direct-SQL/bulk rejection
  tests in
  [the ORG Telephone identity suite](../../test/models/operator_telephone_public_id_immutability_test.rb),
  and
  [operational backfill tests](../../test/operations/operator_telephone_public_id_backfill_operation_test.rb).
  Use only verified run-owned PostgreSQL catalogs. Approval and this criterion do not establish
  implementation, production application, or protection against intentional administrator bypass.

## ID-4b — Owned preference and Client Passkey identities become required

- Basis: I04/I06/I07/I08, P12a. Scope: `client_preferences.public_id`,
  `visitor_preferences.public_id`, `operator_preferences.public_id` and
  `client_passkeys.public_id`; these are owned management identities, not provider credential
  values or cross-realm identifiers.
- Given the existing rows and confirmed ownership meaning, inventory reports NULL, blank and
  duplicate facts before the transition. The bounded maintenance operation may assign a NanoID-21
  only to an explicitly selected NULL row during the pre-cutover rehearsal; it preserves existing
  identities, source attributes and timestamps, is idempotent, and is never called by normal read,
  create or update paths. After the final transition, no listed column accepts NULL and the
  operation is a post-cutover no-op for those schemas.
- The schema transition uses two reviewed migrations per owning database: an additive `NOT VALID`
  `public_id IS NOT NULL` check plus a separate nonblank check, followed by validation, column
  `NOT NULL` enforcement and removal of the temporary checks. The reverse migration restores both
  checks and nullable metadata. A stale NULL or whitespace value fails the transition; schema DDL
  does not invent or rewrite an identifier.
- This criterion does not make `webauthn_id`, `external_id`, or `operator_passkeys` owned public
  identities, and it does not establish full consumer cutover, all-table identifier acceptance,
  or production/shared-data application.
- Check: the explicit model contract in
  [`test/models/public_id_not_null_contract_test.rb`](../../test/models/public_id_not_null_contract_test.rb),
  the NULL-only operation tests in
  [`test/operations/public_id_null_only_backfill_operation_test.rb`](../../test/operations/public_id_null_only_backfill_operation_test.rb),
  focused preference/passkey model tests, the six P12a migrations, and a fresh isolated schema
  reconstruction plus down/up rehearsal. Direct catalog checks must distinguish current nullable
  state, temporary checks and final `attnotnull`; do not treat a generated schema file alone as a
  clean migration proof.

## ID-4c — Staff identity audit-event keys have an identity-preserving bigint cutover

- Basis: I09–I11, MIG-1, P12a. Scope: `org_zenith.staff_identity_audit_events.id` and the
  `staff_identity_audits.event_id` reference; this is an identity-preserving conversion of the
  legacy string catalogue key, not a new remote or polymorphic reference.
- Given an existing string event code and any audit rows referring to it, the bounded additive
  stage retains the code in `legacy_id`, assigns one bounded bigint in `id_bigint`, and maps every
  audit row to `event_id_bigint` without changing the original columns or deleting rows. A
  missing mapping, conflicting mapping, exhausted bigint range or unrelated constraint failure
  stops explicitly; no guessed event, force-cast, truncation or silent fallback is allowed.
- After the mapping is complete, the final cutover makes `staff_identity_audit_events.id` a
  non-null bigint primary key and `staff_identity_audits.event_id` a non-null bigint foreign key
  to it. The original codes remain required in `legacy_id` and `legacy_event_id`; no temporary
  mapping columns or old string foreign key remain. Every synthetic event/reference pair keeps the
  same legacy code and resolves to the same bigint after the cutover. The cutover is staged with
  `NOT VALID` checks, separate validation, and an explicit reversible down path; it refuses an
  incomplete or conflicting mapping before changing the key authority.
- The retained maintenance operation is bounded and idempotent before cutover and an explicit
  no-op after cutover. A dry run never writes. Repeating either state does not assign a second
  identity or regenerate a code. The fixed catalogue has no automatic sequence requirement; IDs
  are supplied by the reviewed mapping rather than cast from the old code.
- This criterion does not claim application to production/shared rows, complete ID-1 inventory or
  any unrelated consumer migration. The isolated rehearsal is evidence for the migration
  mechanics and identity preservation only.
- Check: `test/models/staff_identity_audit_event_bigint_transition_test.rb`,
  `test/operations/staff_identity_audit_event_bigint_backfill_operation_test.rb`, migrations
  `20261012085039_convert_staff_identity_audit_events_to_bigint.rb`,
  `20261012100000_cut_over_staff_identity_audit_event_bigint_keys.rb` and
  `20261012100100_validate_staff_identity_audit_event_bigint_foreign_key.rb`, plus the run-owned
  down/up rehearsal with a synthetic event/reference and PostgreSQL catalog checks. An empty
  current table alone is not proof; the synthetic pair must be used for the preservation check.

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

## ID-4d — Setting preference identities have bounded database capacity

- Basis: I04/I06/I07, P12a. Scope: `app_preferences.public_id`, `com_preferences.public_id` and
  `org_preferences.public_id`; these are realm-owned non-secret management identities generated by
  the shared NanoID mechanism.
- Given a persisted preference, a direct SQL or bulk writer that attempts a `public_id` longer than
  25 characters is rejected by PostgreSQL. The existing row, identifier and related state remain
  unchanged after the failed statement. Normal generation remains NanoID-21, and model validation
  still rejects the already narrower 22-character ordinary input; the database check supplies the
  storage boundary for bypass writers without truncation or regeneration.
- The transition adds one named `NOT VALID` check per owning setting database and validates it in a
  separate migration. Existing values are not rewritten. Reversing the validation restores the
  unvalidated check, and reversing the additive migration removes it; no schema reset or data
  deletion is part of this criterion.
- Check: `test/models/public_id_capacity_contract_test.rb`, the six setting migrations
  `20261012090000`/`20261012090001`, direct SQL rejection in a savepoint, catalog check expression
  and isolated down/up rehearsal. The run-owned disposable catalog is evidence for this slice only;
  it does not establish all-table capacity acceptance or shared/production data readiness.

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
  isolated paging/ ordering tests; partition cases apply only when present. The catalog starting
  point is `identifiers:inventory`, which reports each index's access method, key/attribute counts,
  predicate, definition, uniqueness and valid/ready/live flags. Sequence checks belong to MIG-1.
  Coverage of all semantic index consumers and partition behavior remains separate from this
  catalog report.

## ID-4e — App and Com principal identities have bounded database capacity

- Basis: I04/I06/I07, P12a. Scope: `app_zenith.clients.public_id` and
  `com_zenith.visitors.public_id`; both are realm-owned non-secret identities with ordinary
  NanoID-21 issuance. The ORG `operators.public_id` human-entered 16-character code is outside this
  criterion.
- Given a persisted Client or Visitor, a direct SQL or bulk writer that attempts a `public_id`
  longer than 25 characters is rejected by PostgreSQL. The existing row and identity remain
  unchanged after the failed statement. Normal generation and existing model validation remain
  unchanged; no value is truncated, regenerated or case-converted.
- The transition uses one named `NOT VALID` check and a separate validation migration per owning
  database. Reversing validation restores the unvalidated check, and reversing the additive
  migration removes it. No real-data reset or cross-realm uniqueness is introduced.
- Check: `test/models/public_id_capacity_contract_test.rb`, `test/models/client_test.rb`,
  `test/models/visitor_test.rb`, migrations `20261012091000`/`20261012091001`, direct SQL
  rejection in a savepoint, catalog check expression and isolated down/up rehearsal. This is a
  scoped capacity result, not all-table identifier acceptance or production/shared-data evidence.

## ID-4f — Classified self-controlled identifiers have bounded database capacity

- Basis: I04/I06/I07, P12a. Scope: the explicitly classified, self-controlled non-secret
  `public_id` columns in the current P12a capacity slice: `app_zenith` application and enterprise
  records, `com_zenith` visitor and company records, `org_zenith` agent and bureau records,
  app/com/org ticket and signal records, the app `members` and legacy logout transaction resource,
  and Avatar group, Avatar, membership, handle, post and post-version records.
  The complete table list is the `CAPACITY_TABLES` inventory in
  [`test/models/public_id_capacity_contract_test.rb`](../../test/models/public_id_capacity_contract_test.rb).
  Provider/protocol identifiers, the ORG human-entered operator code, and the two retired legacy
  tables `app_zenith.legacy_replaced_clients` and
  `org_zenith.legacy_operator_department_accounts` are outside this criterion until their
  consumer and retention meaning is resolved. Other unclassified inventory candidates are also
  outside this criterion.
- Given any table in that explicit inventory, a direct SQL or bulk writer that attempts a
  `public_id` longer than 25 characters is rejected by PostgreSQL after the named database check
  has been validated. Existing rows and issued identities remain unchanged; no value is truncated,
  regenerated, case-converted or made globally unique by this slice.
- Each owning database uses one additive migration to install its named
  `char_length(public_id) <= 25` checks as `NOT VALID`, followed by a separate validation migration.
  Reversing validation restores the unvalidated checks and reversing the additive migration removes
  them. The existing string representation and NanoID-21 issuance remain unchanged.
- Check: the metadata assertions in
  [`test/models/public_id_capacity_contract_test.rb`](../../test/models/public_id_capacity_contract_test.rb),
  the 16 P12a capacity migrations under `db/*_migrate/` with the `owned_public_id_capacity_checks`
  filenames, generated structure dumps for all eight owning databases, and isolated down/up
  rehearsal. The five concrete model targets also exercise direct oversized SQL writes inside a
  savepoint. The initial 42-table result is recorded in
  [`N9K4`](../../evidence/2026-10-12-public-id-capacity-gate-N9K4.md), and the four-table extension
  is recorded in
  [`V2J6`](../../evidence/2026-10-12-public-id-capacity-extension-V2J6.md). This criterion proves
  only the listed disposable-schema boundary; it does not close the remaining identifier inventory,
  approve a global type narrowing, validate shared/production rows, or establish the final
  staff-event bigint cutover.

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
  identifier regression coverage remains incomplete. The actual
  `test/security/invariants/identifier_generation_invariant_test.rb` detects direct production
  Nanoid-call bypass under `app/` through Ruby AST inspection, including a deliberate owned
  synthetic source violation. `test/lib/public_id_generation_test.rb` covers the public
  standard-generation API. Those checks do not establish schema/classification/exception coverage or
  detect every possible dynamic generator alias. Existing PublicId tests retain their distinct
  public persistence scope.

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
  numeric proof bindings, enforce DB immutability or authorize production data mutation. The final
  NOT NULL transition is represented by the reviewed two-step migrations and must follow the
  operational preconditions; ID-3a's independent proof-drain and ID-4/MIG-1 remain required.

## ID-3d — Legacy ORG Telephone proof-drain observations

- Basis: I07/I11, ID-3a and MIG-1. Scope: ORG registration ceremonies bound to the old canonical
  positive-decimal PK reference, distinct from current 21-character public candidates.
- Given that explicit ceremony scope, inventory reports aggregate pending-parent, deliverable-proof
  and unexpired-receipt counts without changing rows, returning raw identifiers, code or verifier
  values, or initiating delivery. Other realm/channel scopes are refused.
- A consumed proof with a still-valid original receipt remains counted after its challenge expires.
  Parent and receipt deadlines are exclusive: immediately before the relevant deadline the item
  counts; at the deadline and immediately after it does not. Current public candidates, including
  all-digit 21-character values, are not classified as old PK references.
- Check: `test/queries/operator_telephone_legacy_reference_inventory_test.rb` and the read-only
  `org_telephone_public_ids:legacy_references` Rake task. The observations are not a cutover permit,
  a distributed snapshot, proof of source reconciliation, writer quiescence or queue drain. Those
  independent prerequisites remain mandatory even when every count is zero.
