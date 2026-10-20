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
  table ownership metadata, primary-key shape, sequence/identity metadata, candidate-name hints, and
  index access/validity facts without reading application rows. It is evidence for the catalog
  portion only; semantic ownership classification, producer/consumer mapping, exception review, and
  all-table acceptance remain separate work. No file-name search or historical migration text proves
  current types.

## ID-2 — Issuance, capacity and ordinary creation

- Basis: I03/I06/I07. Scope: self-controlled non-secret opaque IDs, regardless of column name.
- Given an ordinary new resource, create it through normal, validation-disabled and bulk writers.
  New IDs use the one approved CSPRNG-backed NanoID mechanism, length 21 and the library alphabet;
  standard string/varchar capacity is 25. The shared `PublicId` model boundary enforces that storage
  maximum separately from the 21-character generator. Ordinary clients cannot supply their own
  resource identity. Explicit authorized imports have a separate contract. Read/update does not
  regenerate a missing ID.
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

The setting-preference database boundary is exercised by
`test/models/setting_preference_public_id_immutability_test.rb`: APP, COM and ORG each attempt
replacement through `update_columns`, `update_all`, `upsert_all` and direct SQL. The tests require
database rejection and unchanged identity; their existence does not establish a passing result.
Current revision-scoped results belong in the acceptance evidence. The approved setting-only trigger
mechanism and reverse-order cleanup are defined in `adr/database-trigger-usage-boundary.md`. Same-ID
assignment and unrelated state updates must remain valid; logical deletion must not permit a
different ID. This does not extend immutability to reference or token-state columns or authorize
triggers for additional tables.

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
  `visitor_preferences.public_id`, `operator_preferences.public_id` and `client_passkeys.public_id`;
  these are owned management identities, not provider credential values or cross-realm identifiers.
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
  identities, and it does not establish full consumer cutover, all-table identifier acceptance, or
  production/shared-data application.
- Check: the explicit model contract in
  [`test/models/public_id_not_null_contract_test.rb`](../../test/models/public_id_not_null_contract_test.rb),
  the NULL-only operation tests in
  [`test/operations/public_id_null_only_backfill_operation_test.rb`](../../test/operations/public_id_null_only_backfill_operation_test.rb),
  focused preference/passkey model tests, the preference collision/immutability boundary in
  [`test/models/preference_public_id_collision_test.rb`](../../test/models/preference_public_id_collision_test.rb),
  the six P12a migrations, and a fresh isolated schema reconstruction plus down/up rehearsal. Direct
  catalog checks must distinguish current nullable state, temporary checks and final `attnotnull`;
  do not treat a generated schema file alone as a clean migration proof. The model boundary does not
  replace the direct-SQL/database-enforcement portion of ID-4.

## ID-4c — Staff identity audit-event keys have an identity-preserving bigint cutover

- Basis: I09–I11, MIG-1, P12a. Scope: `org_zenith.staff_identity_audit_events.id` and the
  `staff_identity_audits.event_id` reference; this is an identity-preserving conversion of the
  legacy string catalogue key, not a new remote or polymorphic reference.
- Given an existing string event code and any audit rows referring to it, the bounded additive stage
  retains the code in `legacy_id`, assigns one bounded bigint in `id_bigint`, and maps every audit
  row to `event_id_bigint` without changing the original columns or deleting rows. A missing
  mapping, conflicting mapping, exhausted bigint range or unrelated constraint failure stops
  explicitly; no guessed event, force-cast, truncation or silent fallback is allowed.
- After the mapping is complete, the final cutover makes `staff_identity_audit_events.id` a non-null
  bigint primary key and `staff_identity_audits.event_id` a non-null bigint foreign key to it. The
  original codes remain required in `legacy_id` and `legacy_event_id`; no temporary mapping columns
  or old string foreign key remain. Every synthetic event/reference pair keeps the same legacy code
  and resolves to the same bigint after the cutover. The cutover is staged with `NOT VALID` checks,
  separate validation, and an explicit reversible down path; it refuses an incomplete or conflicting
  mapping before changing the key authority.
- The retained maintenance operation is bounded and idempotent before cutover and an explicit no-op
  after cutover. A dry run never writes. Repeating either state does not assign a second identity or
  regenerate a code. The fixed catalogue has no automatic sequence requirement; IDs are supplied by
  the reviewed mapping rather than cast from the old code.
- This criterion does not claim application to production/shared rows, complete ID-1 inventory or
  any unrelated consumer migration. The isolated rehearsal is evidence for the migration mechanics
  and identity preservation only.
- Check: `test/models/staff_identity_audit_event_bigint_transition_test.rb`,
  `test/operations/staff_identity_audit_event_bigint_backfill_operation_test.rb`, migrations
  `20261012085039_convert_staff_identity_audit_events_to_bigint.rb`,
  `20261012100000_cut_over_staff_identity_audit_event_bigint_keys.rb` and
  `20261012100100_validate_staff_identity_audit_event_bigint_foreign_key.rb`, plus the run-owned
  down/up rehearsal with a synthetic event/reference and PostgreSQL catalog checks. An empty current
  table alone is not proof; the synthetic pair must be used for the preservation check.

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
  `LogoutTransaction.issue!` and its named-index retry/limit tests are additional concrete examples;
  the three realm-specific EnforcementCase writers are covered by
  [`test/models/enforcement_case_public_id_test.rb`](../../test/models/enforcement_case_public_id_test.rb),
  and the APP TOTP credential management identity is covered by
  [`test/models/client_totp_credential_public_id_collision_test.rb`](../../test/models/client_totp_credential_public_id_collision_test.rb).
  Large random samples do not prove collision safety.

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
  Coverage of all semantic index consumers and partition behavior remains separate from this catalog
  report.

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
  `test/models/visitor_test.rb`, migrations `20261012091000`/`20261012091001`, direct SQL rejection
  in a savepoint, catalog check expression and isolated down/up rehearsal. This is a scoped capacity
  result, not all-table identifier acceptance or production/shared-data evidence.

## ID-4f — Classified self-controlled identifiers have bounded database capacity

- Basis: I04/I06/I07, P12a. Scope: the explicitly classified, self-controlled non-secret `public_id`
  columns in the current P12a capacity slice: `app_zenith` application and enterprise records,
  `com_zenith` visitor and company records, `org_zenith` agent and bureau records, app/com/org
  ticket and signal records, the app `members` and legacy logout transaction resource, and Avatar
  group, Avatar, membership, handle, post and post-version records. The complete table list is the
  `CAPACITY_TABLES` inventory in
  [`test/models/public_id_capacity_contract_test.rb`](../../test/models/public_id_capacity_contract_test.rb).
  Provider/protocol identifiers, the ORG human-entered operator code, and the two retired legacy
  tables `app_zenith.legacy_replaced_clients` and `org_zenith.legacy_operator_department_accounts`
  are outside this criterion until their consumer and retention meaning is resolved. Other
  unclassified inventory candidates are also outside this criterion.
- Given any table in that explicit inventory, a direct SQL or bulk writer that attempts a
  `public_id` longer than 25 characters is rejected by PostgreSQL after the named database check has
  been validated. Existing rows and issued identities remain unchanged; no value is truncated,
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
  is recorded in [`V2J6`](../../evidence/2026-10-12-public-id-capacity-extension-V2J6.md). This
  criterion proves only the listed disposable-schema boundary; it does not close the remaining
  identifier inventory, approve a global type narrowing, validate shared/production rows, or
  establish the final staff-event bigint cutover.

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

## ID-3e — Email and Telephone sign-up transaction references

- Basis: I04/I06/I07/I10 and ID-3; scope: APP and COM Email/Telephone sign-up transaction issuance,
  resend, delayed delivery, session binding and verification. This criterion is separate from the
  credential-registration and TOTP-enrollment transaction criteria above.
- Given a newly issued sign-up transaction, its self-controlled, non-secret `transaction_id` is a
  NanoID-21 generated through the shared public-ID mechanism. Existing UUID-v4 transaction rows
  remain readable during the bounded transition. The OTP `generation` remains a UUID-v4 one-time
  proof identity and is not replaced by the transaction reference.
- A delivery or session binding must match the correct realm, surface, channel, flow, purpose,
  actor/root binding, transaction reference, generation and expiry. It accepts the explicitly
  supported NanoID-21 or legacy UUID-v4 transaction form and rejects malformed, missing, stale,
  wrong-flow, wrong-purpose, wrong-surface or cross-purpose references without a silent lookup
  fallback. A transaction reference cannot be used as a generation, grant or result identity.
- When a newly generated transaction collides, only the concrete table's named single-column
  `transaction_id` unique B-tree collision may be retried. Each retry uses a fresh reference inside
  a savepoint and the finite shared collision budget. Caller-supplied IDs, unrelated validation or
  uniqueness failures, and exhausted retries remain explicit failures.
- Check: `test/operations/email_sign_up_otp_issuer_test.rb`,
  `test/operations/telephone_sign_up_otp_issuer_test.rb`,
  `test/values/sign_up_otp_delivery_binding_value_test.rb`,
  `test/values/email_sign_up_otp_delivery_binding_value_test.rb`,
  `test/operations/sign_up_otp_delivery_guard_test.rb`,
  `test/integration/signup_otp_delayed_transport_test.rb` and
  `test/integration/telephone_sign_up_otp_delivery_test.rb`. Direct inspection must confirm the
  issuer, binding value and consumer preserve the same purpose/surface boundary; static checks do
  not prove delayed delivery, concurrent collision recovery or external runtime behavior.
- This criterion does not classify unexamined sign-up transaction, grant, result or OTP-generation
  issuers, and it does not authorize a global UUID-to-NanoID rewrite or a cross-realm identifier
  fallback. Current run evidence is revision-scoped; it is not a permanent PASS for future code.

## ID-3f — Email and Telephone sign-up grant references

- Basis: I04/I06/I07/I10 and ID-3; scope: APP and COM Email/Telephone sign-up grant issuance, signed
  grant/result claims, replay validation and delivery/verification handoff. The grant identity is
  separate from the sign-up transaction, OTP generation and eventual result identity.
- Given a newly created sign-up transaction, its generated `grant_jti` is a NanoID-21 from the
  shared public-ID mechanism. Existing UUID-v4 grant values remain accepted as opaque claims; no
  caller or provider value is reformatted. A grant reference is checked against the same concrete
  transaction and realm before a grant or result is accepted.
- A generated `grant_jti` collision may be retried only when the concrete table identifies its
  named, single-column `grant_jti` unique B-tree index. The retry uses a fresh transaction and grant
  reference inside a savepoint and the finite shared collision budget. A collision on the separate
  `transaction_id` index follows its own rule; unrelated validation or uniqueness errors and
  exhausted retries remain explicit failures.
- Check: `test/operations/email_sign_up_otp_issuer_test.rb` and
  `test/operations/telephone_sign_up_otp_issuer_test.rb`, including generated-format and grant/
  transaction collision cases, plus the sign-up delivery/transport and binding tests listed in
  ID-3e. Direct inspection must confirm that grant, transaction, generation and result values are
  not substituted across purposes or surfaces. The locale fallback labels only prevent validation
  error reporting from failing; they are not an acceptance substitute.
- This criterion does not classify other sign-up, credential-registration, step-up, passkey, social,
  TOTP or secret-credential grant issuers, and it does not authorize changing external protocol
  identifiers. Current evidence is revision-scoped and does not establish complete ID-3 or ID-4
  acceptance.

## ID-3g — Credential-registration Email and Telephone grant references

- Basis: I04/I06/I07/I10 and ID-3; scope: APP, COM and ORG Email/Telephone credential-registration
  transaction issuance and its grant-bound proof handoff. The `grant_jti` is a self-controlled,
  non-secret grant identity separate from `transaction_id`, OTP `generation`, result identities,
  actor/session references and provider or protocol values.
- Given a newly issued credential-registration transaction, its generated `grant_jti` is a NanoID-21
  from the shared public-ID mechanism. Existing UUID-v4 grant values remain opaque and readable
  where the current contract permits them; they are not reformatted. The grant remains bound to the
  concrete realm, channel, transaction, actor, candidate and purpose, and cannot be substituted for
  a transaction, generation or result reference.
- A generated collision may be retried only for the concrete table's named, single-column
  `grant_jti` or `transaction_id` unique B-tree index. Each retry uses fresh generated references
  inside a database savepoint and the finite shared collision budget. Caller-supplied values,
  unrelated validation or uniqueness errors and exhausted retries remain explicit failures; no
  cross-purpose or cross-surface fallback is permitted.
- Check: `test/operations/email_credential_registration_otp_issuer_test.rb`,
  `test/operations/telephone_credential_registration_otp_issuer_test.rb`,
  `test/operations/contact_registration_otp_issuer_test.rb`,
  `test/values/credential_registration_otp_session_value_test.rb`,
  `test/values/contact_registration_otp_delivery_binding_value_test.rb` and
  `test/values/email_credential_registration_otp_delivery_binding_value_test.rb`. Direct inspection
  must confirm that transaction, grant, generation and proof/session bindings retain their existing
  purpose and realm boundaries. The current evidence is revision-scoped and does not classify every
  other credential-registration grant or result issuer.

## ID-3h — Email recovery and withdrawal reentry references

- Basis: I04/I06/I07/I10 and ID-3; scope: Email reentry OTP issuance and delivery for APP, COM and
  ORG recovery, plus APP and COM withdrawal. ORG withdrawal remains explicitly unsupported. The
  transaction and grant references are self-controlled, non-secret ceremony identities; the
  browser/session reference and OTP generation remain separate UUID-bound contracts.
- Given an allowed reentry request, a newly created concrete Email ceremony transaction carries a
  NanoID-21 `transaction_id` and a separate NanoID-21 `grant_jti`. Existing UUID transaction values
  remain readable during the bounded transition. The binding accepts either transaction form but
  still requires a UUID OTP generation, preserves the operation (`recovery` or `withdrawal`) and
  rejects other-purpose or malformed references without fallback.
- A generated transaction or grant collision may be retried only for the concrete table's named,
  single-column unique B-tree index, using fresh values inside a savepoint and the finite collision
  budget. Unrelated validation or uniqueness failures and exhausted retries remain explicit
  failures. A rejected ORG withdrawal creates no transaction or delivery.
- Check: `test/operations/email_reentry_otp_issuer_test.rb`,
  `test/operations/email_reentry_otp_verification_committer_test.rb`,
  `test/values/email_reentry_otp_delivery_binding_value_test.rb` and
  `test/notifiers/notify/email_reentry_otp_delivery_test.rb`. The current execution record is
  [`Q4M8`](../../evidence/2026-10-12-email-reentry-references-Q4M8.md); it is revision-scoped and
  does not classify other Email/Telephone ceremony issuers.

## ID-3i — Secret Credential ceremony transaction and grant references

- Basis: I04/I06/I07/I10 and ID-3; scope: APP, COM and ORG Secret Credential ceremony transaction
  creation, signed grant binding, replay lookup and result handoff. `transaction_id` and `grant_jti`
  are self-controlled, non-secret ceremony identities; `result_jti`, credential candidate refs,
  secret material and actor/session references remain separate contracts.
- Given a newly created Secret Credential ceremony transaction, a generated `transaction_id` and
  `grant_jti` are separate NanoID-21 values from the shared public-ID mechanism. Explicitly supplied
  values remain explicit inputs; this criterion does not reformat existing rows or classify the
  result identity.
- A generated collision may be retried only for the concrete table's named, single-column
  `transaction_id` or `grant_jti` unique B-tree index. Each retry uses fresh generated values inside
  a savepoint and the finite shared collision budget. Caller-supplied values, unrelated validation
  or uniqueness failures and exhausted retries remain explicit failures; no cross-surface or
  cross-purpose lookup fallback is permitted.
- Check: `test/services/identity_secret_credential_ceremony_replay_store_test.rb` and the related
  Secret Credential contract, result-issuer, final-committer, consumer and purger tests listed in
  the execution evidence. Direct inspection must confirm that the three concrete transaction models
  retain their surface binding and that transaction, grant, result and candidate references are not
  substituted. Static checks do not prove concurrent committed collision behavior.
- This criterion does not classify Secret Credential `result_jti`, the underlying permanent secret
  credential identity, provider/protocol values or other ceremony transaction/grant issuers. Current
  evidence is revision-scoped and is not a permanent PASS for future code.

## ID-3j — Social ceremony transaction and grant references

- Basis: I04/I06/I07/I10 and ID-3; scope: the APP Social ceremony grant issuer, signed grant/result
  binding, provider callback handoff and replay transaction. Provider subject values, OAuth/OIDC
  state, candidate capability references and result identities remain separate contracts.
- Given a newly issued Social ceremony grant, the internally generated `transaction_id` and
  `grant_jti` are separate NanoID-21 values from the shared public-ID mechanism. Provider-managed
  subject identifiers and the explicit candidate capability reference are not reformatted or used as
  the transaction or grant identity.
- A generated collision may be retried only for the concrete table's named, single-column
  `transaction_id` or `grant_jti` unique B-tree index. Each retry uses fresh generated values inside
  a savepoint and the finite shared collision budget. Caller-supplied values, unrelated validation
  or uniqueness failures and exhausted retries remain explicit failures; no provider, surface or
  purpose fallback is permitted.
- Check: `test/models/concerns/social_ceremony_transactionable_test.rb`, the Social ceremony
  contract, result-issuer, consumer and transaction integration tests. Direct inspection must
  confirm that provider subject binding, verified callback validation and result consumption retain
  their existing trust boundaries. Static checks do not prove concurrent committed collision
  behavior or live provider behavior.
- This criterion does not classify Social `result_jti`, provider subject values, candidate `ref`,
  OAuth/OIDC state, permanent external-identity identifiers or other ceremony issuers. Current
  evidence is revision-scoped and is not a permanent PASS for future code.

## ID-3k — Step-up ceremony transaction and grant references

- Basis: I04/I06/I07/I10 and ID-3; scope: APP, COM and ORG Step-up ceremony transaction creation,
  signed grant admission, verification result handoff and replay lookup. `transaction_id` and
  `grant_jti` are self-controlled, non-secret ceremony identities; `result_jti`, session and
  credential references, OTP/protocol values and authorization evidence remain separate contracts.
- Given a newly created Step-up ceremony transaction, generated `transaction_id` and `grant_jti` are
  separate NanoID-21 values from the shared public-ID mechanism. Explicitly supplied values remain
  explicit inputs. The existing purpose, surface, actor, session, audience, allowed-method, expiry
  and assurance guards remain authoritative; this criterion does not reformat result or
  authentication-protocol identities.
- A generated collision may be retried only for the concrete table's named, single-column
  `transaction_id` or `grant_jti` unique B-tree index. Each retry uses fresh generated values inside
  a savepoint and the finite shared collision budget. Caller-supplied values, unrelated validation
  or uniqueness failures and exhausted retries remain explicit failures; no cross-surface,
  cross-purpose or session-issuance fallback is permitted.
- Check: `test/services/identity/step_up_ceremony_acme_transaction_test.rb` and the related Step-up
  contract, replay-store, transition, admission, verification, purge and integration tests executed
  for this slice. Direct inspection must confirm that `result_jti`, signed result claims,
  actor/session binding and purpose-specific authorization remain separate. Static checks do not
  prove concurrent committed collision behavior, external authenticator behavior or production
  deployment behavior.
- This criterion does not classify Step-up `result_jti`, OTP/email/passkey/TOTP proof values,
  credential identities, provider/protocol values, session identifiers or other unclassified
  ceremony issuers. Current evidence is revision-scoped and is not a permanent PASS for future code.

## ID-3l — OIDC authorization transaction references

- Basis: I04/I06/I07/I10 and ID-3; scope: the three concrete APP, COM and ORG OIDC authorization
  transaction writers and their coordinator, admission, token-exchange and purge consumers.
  `transaction_id` is an internally generated, non-secret durable transaction identity. OIDC
  `state`, `nonce`, PKCE challenge, login challenge and provider/client values retain their own
  protocol or request contracts.
- Given a newly issued OIDC authorization transaction, its generated `transaction_id` is a NanoID-21
  value from the shared public-ID mechanism. Existing opaque transaction values remain readable; no
  state, nonce, PKCE, login challenge or external provider value is reformatted or substituted.
- A generated collision may be retried only for the concrete table's named, single-column
  `transaction_id` unique B-tree index. Each retry uses a fresh generated value inside a savepoint
  and the finite shared collision budget. Login-challenge uniqueness, caller/request validation,
  other uniqueness failures and exhausted retries remain explicit failures; no cross-surface or
  protocol fallback is permitted.
- Check: `test/models/concerns/oidc_authorization_transactionable_test.rb` plus the coordinator,
  admission-binding, token-exchange, purge and OIDC integration tests selected for this slice.
  Direct inspection must confirm that authorization parameters, surface class, durable admission
  binding, result generation and token exchange continue to resolve the same transaction. Static
  checks do not prove concurrent external-provider behavior or production deployment behavior.
- This criterion does not classify OIDC `state`, `nonce`, PKCE, login challenges, provider/client
  identifiers, protocol `jti`/`sid` values or other unclassified transaction and result issuers.
  Current evidence is revision-scoped and is not a permanent PASS for future code.

## ID-3m — Passkey ceremony transaction references

- Basis: I04/I06/I07/I10 and ID-3; scope: the concrete APP, COM and ORG Passkey ceremony transaction
  models, their replay/result/purge consumers and the public transaction factory. `transaction_id`
  and `grant_jti` are self-controlled, non-secret ceremony identities. Relying-party identifiers and
  origins, credential-candidate references, WebAuthn challenges/results, credential identities and
  protocol values retain separate contracts.
- Given a newly created Passkey ceremony transaction through the public factory, generated
  `transaction_id` and `grant_jti` are separate NanoID-21 values from the shared public-ID
  mechanism. Existing opaque values remain readable. The factory preserves the concrete surface,
  actor/session binding, operation, relying-party configuration, candidate data and expiry; it does
  not substitute a challenge, credential identifier or protocol value for either reference.
- A generated collision may be retried only for the concrete table's named, single-column
  `transaction_id` or `grant_jti` unique B-tree index. Each retry uses fresh generated values inside
  a savepoint and the finite shared collision budget. Caller-supplied values, unrelated validation
  or uniqueness failures and exhausted retries remain explicit failures; no cross-surface,
  cross-purpose or WebAuthn fallback is permitted.
- Check: `test/models/concerns/ceremony_transactionable_test.rb` and the related Passkey
  replay-store, contract, result-issuer, final-committer, purger, registration-committer,
  authorization and numeric-date tests selected for this slice. Direct inspection must confirm that
  the existing WebAuthn challenge/protocol boundary and concrete surface bindings remain
  authoritative. Static checks do not prove concurrent committed collision behavior or live
  authenticator behavior.
- This criterion does not classify WebAuthn credential IDs, challenge/client-data values, RP
  identifiers, result identities, protocol/session values or other unclassified ceremony issuers.
  Current evidence is revision-scoped and is not a permanent PASS for future code.

## ID-3n — Email ceremony transaction references

- Basis: I04/I06/I07/I10 and ID-3; scope: the concrete APP, COM and ORG Email ceremony transaction
  models, the Email Verification Protocol challenge factory, replay/finalization/result/purge
  consumers and the related delivery paths. `transaction_id` and `grant_jti` are self-controlled,
  non-secret ceremony identities; EVP nonce/token material, OTP generations, result identities,
  candidate values and actor/session references retain separate contracts.
- Given a newly created Email ceremony transaction through `EmailCeremonyTransactionable` or the
  public EVP challenge factory, generated `transaction_id` and `grant_jti` are separate NanoID-21
  values from the shared public-ID mechanism. Existing opaque transaction and grant values remain
  readable. Surface, operation, actor/session binding, candidate/digest fields, EVP state and expiry
  remain authoritative; no challenge, token, generation or result value is substituted for either
  reference.
- A generated collision may be retried only for the concrete table's named, single-column
  `transaction_id` or `grant_jti` unique B-tree index. Each retry uses fresh generated values inside
  a savepoint and the finite shared collision budget. Caller-supplied values, unrelated validation
  or uniqueness failures and exhausted retries remain explicit failures; no cross-surface,
  cross-purpose or proof fallback is permitted.
- Check: `test/models/concerns/ceremony_transactionable_test.rb`,
  `test/models/email_verification_challengeable_test.rb` and the Email ceremony contract,
  replay-store, final-committer, result-issuer, purger, delivery and integration tests selected for
  this slice. Direct inspection must confirm that EVP nonce/token verification and the existing
  delivery/session boundaries remain separate. Static checks do not prove concurrent committed
  collision behavior or external delivery behavior.
- This criterion does not classify OTP `generation`, EVP nonce/token digests, result identities,
  candidate or provider values, protocol/session identifiers or other unclassified ceremony issuers.
  Current evidence is revision-scoped and is not a permanent PASS for future code.

## ID-3o — Telephone ceremony transaction references

- Basis: I04/I06/I07/I10 and ID-3; scope: the concrete APP, COM and ORG Telephone ceremony
  transaction models, the typed replay store and their result/finalization/purge consumers.
  `transaction_id` and `grant_jti` are self-controlled, non-secret ceremony identities; telephone
  OTP generations, delivery/proof values, result identities, candidate values and actor/session
  references retain separate contracts.
- Given a newly created Telephone ceremony transaction through `TelephoneCeremonyTransactionable`,
  generated `transaction_id` and `grant_jti` are separate NanoID-21 values from the shared public-ID
  mechanism. Existing opaque values remain readable. Surface, operation, actor/session binding,
  candidate/digest fields and expiry remain authoritative; no OTP generation, result, delivery or
  protocol value is substituted for either reference.
- A generated collision may be retried only for the concrete table's named, single-column
  `transaction_id` or `grant_jti` unique B-tree index. Each retry uses fresh generated values inside
  a savepoint and the finite shared collision budget. Caller-supplied values, unrelated validation
  or uniqueness failures and exhausted retries remain explicit failures; no cross-surface,
  cross-purpose or proof fallback is permitted.
- Check: `test/models/concerns/ceremony_transactionable_test.rb`,
  `test/services/identity_telephone_ceremony_transaction_coverage_test.rb` and the Telephone
  contract, replay-store, finalization, result, purge, OTP issuer, delivery and integration tests
  selected for this slice. Direct inspection must confirm that the existing Telephone delivery and
  proof/session boundaries remain separate. Static checks do not prove concurrent committed
  collision behavior or live SMS delivery behavior.
- This criterion does not classify Telephone OTP generation, delivery/proof values, result
  identities, protocol/session identifiers or other unclassified ceremony issuers. The legacy
  value-object defaults now use the shared NanoID-21 issuer as well; explicitly supplied UUID-v4
  transaction and grant values remain readable during the bounded transition. Current evidence is
  revision-scoped and is not a permanent PASS for future code.

## ID-3p — Social candidate capability references

- Basis: I04/I06/I07/I10 and ID-3; scope: the APP Social link candidate store, link-completion
  request boundary and the candidate's verified callback/result consumers. Provider subject values,
  OAuth/OIDC state, signed result identities and transaction/grant references remain separate
  contracts.
- Given a newly stored Social candidate, its self-controlled non-secret `ref` is a NanoID-21 value
  generated through the shared public-ID mechanism. An already issued UUID-v4 candidate remains
  readable during this bounded transition; no existing candidate is rewritten and no shared UUID
  admission pattern is widened for unrelated flows.
- A link-completion request accepts only a strict Social candidate reference: the new NanoID-21 form
  or the retained UUID-v4 form. Missing, malformed, cross-purpose or unknown references are rejected
  without a lookup fallback to another identity column. Provider callback verification,
  actor/session binding, expiry and one-shot consumption remain authoritative.
- A generated collision may be retried only for the concrete candidate table's named, single-column
  `ref` unique B-tree index. Each retry uses a fresh value inside a savepoint and the finite shared
  collision budget. Caller-supplied legacy values, unrelated validation or uniqueness failures and
  exhausted retries remain explicit failures; provider values and candidate capability references
  are never substituted for transaction or result identities.
- Check: `test/services/identity/social_ceremony_contract_test.rb`,
  `test/integration/acme_social_link_completion_test.rb` and
  `test/integration/social_auth_link_test.rb`, plus direct inspection of
  `IdentitySocialCeremonyCandidateStore` and `Auth::App::Social::LinkCompletionsController`. Static
  checks do not prove concurrent committed collision behavior or live provider behavior. Evidence is
  revision-scoped and is not a permanent PASS for future code.

## ID-3q — Step-Up passkey challenge references

- Basis: I04/I06/I07/I10 and ID-3; scope: the APP, COM and ORG Step-Up session
  `passkey_challenge_ref` issuance and its row-bound WebAuthn admission. This reference is a
  server-generated, non-secret, expiring workflow-state identity. The WebAuthn challenge,
  relying-party/origin values, credential identity, session binding and result identities retain
  separate contracts.
- Given a new Step-Up passkey challenge, `passkey_challenge_ref` is a NanoID-21 value issued by the
  shared `PublicId` mechanism. Existing opaque UUID-v4 references remain readable through the exact
  row-bound lookup; no existing value is rewritten and no protocol challenge is reformatted.
- A generated reference collision may be retried only when the concrete session table reports its
  named, single-column, non-partial unique B-tree index for `passkey_challenge_ref`. Each retry uses
  a fresh value inside a savepoint and the finite challenge-reference retry budget. Unrelated
  validation or uniqueness failures, malformed bindings, cross-surface references and exhausted
  retries remain explicit failures; no fallback lookup or new challenge is authorized by the
  reference alone.
- Check: the public Step-Up admission tests and `test/models/step_up_passkey_challenge_test.rb`,
  plus direct inspection of `StepUpSessionConsumable`. Verification must also confirm that challenge
  bytes, RP/origin, expiry, burn and session-issuance boundaries are unchanged. Static checks do not
  prove committed concurrent collision behavior or live WebAuthn-provider behavior. Evidence is
  revision-scoped and is not a permanent PASS for future code.

## ID-3r — Publishing immutable taxonomy snapshot references

- Basis: ID-3/ID-4 and the accepted
  [Publishing taxonomy architecture](../../adr/publishing-taxonomy-architecture.md). Scope: both
  `vocabulary_public_id_snapshot` and `term_public_id_snapshot` on the 24 single/multiple version
  assignment models, not the resource's own `public_id` or a new issuing domain.
- Preserve the current 21-character physical snapshot-reference capacity independently of the shared
  owned-ID capacity 25. Creating a snapshot with a 22-character reference is rejected by the model;
  raw SQL independently encounters the existing varchar bound before derivation. Empty/nil model
  references retain their existing presence errors.
- Given nonblank supplied references of length 20/21 or an existing accepted string-cast false,
  creation still succeeds and stores the live authoritative vocabulary/term identifiers. Persisted
  snapshot identity is canonical, never the supplied forgery. Existing DB derivation and deferred
  completeness checks remain authoritative; no new trigger or source-identity rewrite is implied.
- Given an existing snapshot, attempted overlong replacement still raises the established
  ReadOnlyRecord error; direct bounded SQL mutation remains refused and leaves history unchanged.
- Check:
  [all-family snapshot capacity tests](../../test/models/publishing/snapshot_public_id_capacity_contract_test.rb),
  snapshot integrity/immutability tests and actual DB column/check definitions. This criterion does
  not resolve the separate owned-Publishing-ID capacity/ADR conflict or authorize schema expansion.
