# Work cycles

## C0 — baseline and feasibility

- Full default CLI: 2,119 findings, exit 1; no internal checker errors. Baseline and inventory are
  retained locally in `tmp/database-consistency-20261019/`.
- 893 concrete table-backed models, 30 model-owned development connections; 32 configured test
  writers. Development and test inventories show no pending migrations.
- Initial characterization invocation stopped before tests: inherited prepare names included retired
  test_app_ticket_db, test_com_ticket_db and test_org_ticket_db. Repeated using the exact checked-in
  `.env.container.devcontainer` prepare list for this process only; safeguards remained active.
- Existing generator, capacity and three reference-model tests: 63 runs, 190 assertions, zero
  failures/errors/skips. This verifies only those tests, not the entire application.
- PublicId ADR/implementation agree on generation 21 and capacity 25; 216 checker failures need
  per-table capacity/consumer assessment. No narrowing is authorized by these warnings.
- See the ledger for unresolved issue dispositions and the plan for adversarial review.

## C1 — reference catalog inverse token associations

- Cause: parent model naming inferred client_token_kind_id/operator_token_kind_id/
  operator_token_status_id, but retained child keys and actual DB FKs use user_token_kind_id/
  staff_token_kind_id/staff_token_status_id. Existing child belongs_to declarations establish the
  intended relationship. Three missing-index reports were derivative of those same missing columns.
- Scope: ClientTokenKind/client_token_kinds (op_base_app), OperatorTokenKind/operator_token_kinds
  and OperatorTokenStatus/operator_token_statuses (op_base_org), plus their three existing test
  files.
- Characterization: initial existing slice passed (63/190); three new direct-DB restriction tests
  passed before the model fix. PostgreSQL RESTRICT surfaces as StatementInvalid with
  PG::RestrictViolation, not InvalidForeignKey on this pinned stack. The tests assert the exact
  cause and retained parent/child rows.
- Red: after correcting test setup to eager-load associations under strict_loading and asserting the
  actual database exception, 19 runs/39 assertions, 0 failures/6 errors/0 skips. All six errors were
  the expected nonexistent FK columns in association reads and dependent-restriction checks.
- Green: explicit foreign_key and inverse_of declarations, preserving public association names and
  restrict_with_error. Final relevant slice: 154 runs/500 assertions, zero failures/errors/skips.
  Includes the existing ClientToken/OperatorToken tests and public-ID generator/capacity tests.
- Refactor: no abstraction or callbacks introduced. Comments explain the retained keys as naming
  exceptions. Six changed Ruby files pass RuboCop; no test deletion or weakening.
- Full CLI: 2,119 → 2,113 displayed failure groups, exit 1, no added failures or internal errors.
  Correcting for grouped output: 2,177 → 2,171 individual failures. One non-failure warning is also
  present in raw reports and must be tracked separately rather than hidden by the default writer.
- Compatibility: valid association reads now work; attempted catalog destruction returns the
  existing intended restriction error rather than UndefinedColumn. DB restriction is unchanged.
  Session issuance, token lifecycle state, database ownership and external APIs are unchanged.
- Risk: no migration, data transformation, extra uniqueness SELECT, cascade or deletion behavior
  added. The existing restriction check now queries an existing indexed FK.
- Disposition: this logical unit is verified locally. Whole application acceptance remains open.

## C2 — Publishing contract conflict and index safety investigation

- Characterization: the existing taxonomy constraints, taxonomy retirement, schema/models and media
  ownership files passed: 40 runs, 283 assertions, zero failures/errors/skips, exit 0.
- D1: normal duplicate taxonomy slugs raise RecordNotUnique and archived slugs remain reserved. A
  standard uniqueness validator changes that exception and adds SELECTs. The user explicitly chose
  to preserve the existing contract and retain the twelve affected reports as unresolved.
- A FIXME at the shared slug validator links the decision. It changes no behavior and resolves no
  warning. The ledger marks these twelve rows with the decision and test grounds.
- Recheck after the comment/decision: full default CLI exit 1, 2,113 displayed failure groups,
  byte-equivalent finding set to C1; no new internal error. Individual counts remain 2,171 failures
  plus one warning. No model validation or DB constraint was changed for this cycle.
- Read-only index catalog: inspected all 112 redundant-index candidates and their covering indexes.
  None has a local pg_constraint.conindid dependency; all 3,557 inventoried indexes are valid/ready.
  This does not establish performance redundancy. Exact candidate and covering definitions are in
  index-review.md; workload/EXPLAIN and production-target verification are pending. No index
  removed.
- The full Rails suite has been launched with the existing validated prepare list; completion and
  failure attribution are pending. It must not be treated as passing on the basis of focused tests.

## C3 — shared capacity scope and FK preflight

- PublicId inspection enumerated all 264 concrete includers. Of the 216 reported length failures,
  197 have only maximum 25, nine additionally have maximum 21 and ten additionally require
  exactly 21. The checker reads only the first validator. No declaration reordering or narrowing was
  used to hide this limitation; all 216 remain unresolved pending semantic/capacity review. Full
  inventory is in public-id-review.md.
- Read-only FK preflight covers all 27 individual reports, representing 26 distinct reference
  tuples. All source tables were empty locally, so zero local orphans does not establish production
  eligibility. See foreign-key-review.md.
- D3: three token FKs were deliberately removed for stable device-session grant ownership. Adding
  RESTRICT/CASCADE would conflict with retained grants after old-token deletion. The user explicitly
  chose to preserve current behavior and keep these three reports unresolved. Three owning models
  carry FIXME comments; no association or lifecycle behavior was changed.
- Security review applied the relevant security-and-hardening prompts: surface/device ownership,
  stale token authority, rotation, deletion races, partial failure and irreversible audit/grant
  loss. The concrete defense is preserving the existing device FK and lifecycle, not adding token
  FKs or cascade. No new authorization path, state writer, cookie/audit write or secret logging was
  added.
- RuboCop on nine applicable Ruby files: no offenses. The changed shared taxonomy Concern contains
  existing concern/style debt; its change is a comment only.
- Full Rails suite is still running. Observed failures include Inertia clearHistory expectations and
  committed-concurrency tests refusing execution without run-owned worker receipts. No test
  safeguard was bypassed, skipped or weakened. Failure attribution remains unverified.
- During this cycle, five initially clean tracked database_consistency_*.txt diagnostics and the two
  initially untracked diagnostics disappeared from the worktree. No command in this task requested
  their deletion; cause/ownership of this concurrent change is not established. They were not
  restored over a potentially unrelated deletion. The task's captured baseline/raw reports remain in
  tmp/. Do not claim the entire initial worktree is unchanged without resolving this observation.

## C4 — revision sequence invariant in all twelve Publishing families

- Root cause: revision models had no sequence validation although every real table has NOT NULL,
  CHECK(sequence > 0), and the native PostgreSQL integer ceiling. Create/revise/restore operations
  assign 1 or max+1; sequence is not supplied by management requests.
- Scope: all twelve concrete EntryRevision models via PublishingEntryRevisionRecord. One bounded
  integer numericality declaration; no schema/migration, callback, new SELECT, trigger or deletion.
- Characterization/Red: 48 tests, 252 assertions, twelve expected model-validation failures, zero
  errors/skips. All normal integer/string saves and direct-DB constraint checks passed before the
  fix.
- First Green exposed twelve missing translated attribute labels when rendering validation errors.
  Added attributes.sequence explicitly in each of the four canonical bundles. No locale fallback,
  error suppression or weaker assertion was introduced. Subsequent assertions include full messages.
- Green: 127 relevant tests/1,130 assertions, zero failures/errors/skips. Expanded final
  verification: 215 tests/1,742 assertions, zero failures/errors/skips. Covers all twelve family
  boundary tests, promotion, version immutability/snapshots, taxonomy, RP grant retention/rotation,
  token reference models, public-ID generation/capacity and existing locale checks.
- Bounds: 0/1/2 and 2^31-2/2^31-1/2^31; NULL, empty string, false, negative, fractional and
  malformed inputs. Actual SQL bypasses AR type serialization/validation; tests assert exact
  PostgreSQL NOT NULL/CHECK/native-overflow failures and retained original data inside savepoints.
- Refactor: retained the explicit shared declaration; no abstraction introduced. Integer-string
  assignment remains accepted. Invalid sequences are now rejected by the model before persistence;
  database guarantees remain authoritative for bypass writes.
- Full checker: 2,113 → 2,101 displayed failure groups; twelve NullConstraint sequence reports
  removed, no new finding. The complete finding set matched exactly when repeated against the
  verified isolated schema fleet after the concurrent normal DB configuration changes.
- One expanded verification attempt collided with a simultaneous read-only parent checker during
  template cloning and stopped before tests. It was rerun sequentially after the checker exited; the
  215-test passing result is the completed retry, not that interrupted setup attempt.
- Current normal development/test configuration and structure dumps were concurrently changed by
  work outside this task. The initial whole-suite result is 15,595 runs/130,388 assertions, six
  failures/358 errors/zero skips; 340 errors were NoDatabaseError, fourteen required owned worker
  receipts, three were KeyError and one RuntimeRole::UnownedRoute. Do not attribute these to the
  model fixes or call this a valid passing baseline. The isolated fleet remains identity-verified.
- Disposition: behavior slice verified locally; current dump reconstruction and full-suite success
  remain open. Two root cause families fixed so far: three inverse models plus twelve revision
  models; zero migrations; nine plus 48 regression/characterization tests verified. The separate
  version-sequence test file is a new pending unit and is not included in this completed count.

## C5 — immutable version creation sequence

- Same storage invariant as C4, applied to all twelve EntryVersion families. Creation now checks the
  positive 32-bit integer range. Validation is deliberately on create: persisted versions keep the
  existing ReadOnlyRecord refusal even when an attempted update supplies an invalid sequence.
- Red: 48 tests/324 assertions, twelve expected missing-sequence validation failures, zero
  errors/skips. Normal saves, integer strings, immutable-update refusal and direct SQL constraint
  tests passed before the change.
- Green: combined 263 tests/2,894 assertions, zero failures/errors/skips. Includes all C4-related
  scopes plus twelve version families and true/false sentinels in both sequence test files.
- Four sequence implementation/test files passed RuboCop. No schema, trigger, query, state or
  deletion changes. The existing sequence label serves both revision and version errors.
- Full checker: 2,101 → 2,089 displayed failure groups; twelve version sequence NullConstraint
  reports removed, no new finding or internal error. Raw: 18,269 OK, 2,147 fail, one warning.
  Baseline and after reported the exact same 873 application model targets.
- Disposition: verified locally. C4/C5 are two implementation slices of the same Publishing sequence
  cause family; thirty individual findings total have been removed since C0, across the inverse-key
  and sequence families. Behavior changed in three reference models plus twelve revisions plus
  twelve versions. Zero migrations; 105 new tests in verified slices. The new position unit remains
  pending and is not counted as verified.

## C6 — ordered taxonomy positions across twelve Publishing families

- Root cause: 24 ordered revision/version assignment models lacked position validation despite
  existing NOT NULL, CHECK(position >= 0) and native integer32 constraints. Added bounded integer
  validation; immutable versions validate on creation only. Unordered assignments are unchanged.
- Red: 60 tests/780 assertions, 24 expected failures. A first draft also assumed false should be
  rejected. The framework explicitly casts false to 0; before-change characterization against the
  original 24 model files confirmed that existing behavior (12 tests/540 assertions passing).
  Corrected the new expectation to preserve that contract; existing tests were not weakened.
- Green: 255 tests/4,587 assertions, no failures/errors/skips, including all twelve families,
  promotion, immutability, DB bypass rejection and unchanged stored values. Added position labels in
  all four canonical locale bundles. No migration, callback, deletion or additional SELECT.
- Full default checker exit 1 with no internal error: 2,089 -> 2,065 displayed groups; raw 2,147 ->
  2,123 failures, one warning unchanged. Same 873 application model targets.
- Disposition: locally verified. Cumulative 54 findings removed in three cause families, 51
  behavior-changed models, 165 newly added verified tests, zero migrations applied. Full-suite
  success and production conditions remain open. D2a was subsequently explicitly approved by the
  user; its generated migration remains a separate pending unit.

## C7 — required attributes owned by concrete Organization/Persona schemas

- Cause: presence declarations used runtime has_attribute? guards for attributes that are always
  present on their actual hosts. All four Organization hosts have name; only three have title. All
  three Persona hosts have title. Schema probing confused the checker and concealed ownership.
- Refactor: make shared Organization name unconditional; move the unchanged title declaration to
  Enterprise/Company/Bureau; remove only Persona title's capability guard. Legacy organizations
  retain name validation without gaining title. Existing status guard and authority graph untouched.
- Characterization before change: 67 tests/563 assertions, all passing. Initial new test drafting
  incorrectly expected two legacy errors (actual public errors deduplicate to one); corrected the
  new expectation against the unchanged implementation. Accessing translated title messages also
  exposed a preexisting missing attribute label; tests assert structured error attributes instead.
  No established assertion or translation fallback changed. The missing-label issue remains open.
- Green: 242 tests/4,736 assertions, no failures/errors/skips. Covers all seven hosts, persistence,
  range/format/sentinel cases, direct DB NOT NULL, membership/root units, token inverses, all
  sequence/position families, and MediaFile exact-length/upload/usage characterization.
- Seven implementation/test files pass RuboCop. SQL translation annotations apply only to internal
  SQL, never checker suppression. No schema, callback, lifecycle, query or deletion changes.
- Checker: 2,065 -> 2,056 displayed groups, 2,123 -> 2,114 raw failures, one warning unchanged.
  Exactly nine ColumnPresence findings removed, no new finding; identical 873 application targets.
- Disposition: locally verified, behavior preserved. Cumulative 63 findings removed in four root
  cause families; 58 affected concrete models (51 with previously documented behavior fixes), zero
  applied migrations, 188 newly added tests including the three MediaFile characterizations. Full
  isolated Ruby suite launched after the final checker/target capture; result pending.

### C7 correction — declaration refactor rolled back for projected-record compatibility

The earlier local C7 disposition was too broad: whole-record tests did not cover partial SELECTs.
Additional public save/update tests on existing records projected without title failed in all six
concrete resource models under C7 (six tests, six errors). The new required validation rejected an
unloaded title; RecordInvalid rendering also exposed the already noted missing title label.

Restored only our exact C7 changes in five model/Concern files, after comparing each with its
expected task-owned diff to protect concurrent work. The original has_attribute? guards distinguish
unloaded attributes as well as absent schema columns. They cannot be treated as schema-only probes.
No established test was removed or weakened; added all six projected-title cases plus three
projected-name cases. Tests for explicit nil/blank still reject invalid whole records, and DB NOT
NULL remains authoritative. Legacy organization title absence remains unchanged.

The nine removed ColumnPresence findings are not accepted remediation and must return to open in the
next raw capture. Cumulative accepted reduction returns to 54 in three root cause families, 51
behavior-changed models, zero applied migrations. Additional compatibility and nullable-evidence
characterization is running; do not claim it passed before its terminal result.

### C7 preservation verification and nullable-evidence characterization

- Final Green after restoring original declarations: **344 tests/5,542 assertions**, zero
  failures/errors/skips. All nine projected title/name updates pass alongside all seven resource
  hosts, DB NULL refusal, membership graphs, all position/sequence families and token inverses.
- Six new nullable-evidence tests pass across all three surfaces: pending transaction evidence is
  nil; actual verification records a boolean; root-token step-up revocation clears both nullable
  flags while retaining token status and its persisted deadline. No authentication implementation
  changed. D5/D6 request disposition for eighteen incompatible checker requirements; reports stay
  open.
- Six scoped files pass RuboCop, git diff --check clean. The compatibility tests were added after
  full-suite discovery, so the focused result, not the whole-suite result, verifies them.
- Full isolated run completed before this reversion: 15,774 tests/137,348 assertions, eight
  failures, four errors, zero skips (exit 1). Three failures read retained empty dumps, three are
  activity presenter assertions, two are authentication/route inventories; errors are three
  clearHistory KeyErrors and one unowned route. None was skipped or hidden. Exact attribution beyond
  observed implementing paths remains open; the whole suite is not green.
- Accepted implementation remains C1/C4/C5/C6: three root cause families, 51 concrete
  behavior-changed models, zero applied migrations. 203 additional tests now have completed relevant
  execution (including characterization retained from C7 and the stopped MediaFile proposal). No
  DDL, dump replacement or production execution was performed. D4 remains a pending local four-index
  proposal.

## C8 — render the existing title validation errors without missing-label exceptions

- Supporting defect found during C7 characterization: all six concrete Organization/Persona models
  reject invalid titles correctly but errors.full_messages_for(:title) raises
  MissingTranslationData. This obstructs protecting the intended abnormal behavior; changing
  validation to avoid it is wrong.
- Red: six tests/twelve assertions, six expected missing-translation errors, no skips. Covers nil,
  empty, malformed and eleven-character inputs in English and Japanese through the public error API.
- Green: 83 tests/975 assertions, zero failures/errors/skips, after adding explicit title labels for
  exactly agent/bureau/client_persona/company/enterprise/individual in all four canonical bundles.
  Normal saves, all projected-save characterizations and nullable step-up evidence stay green.
- Refactor: narrowed an initial shared-label draft to the six model namespaces so unrelated title
  error contracts do not change. A scoped-edit script stopped on existing YAML layout differences;
  no test result from that intermediate state is used as final verification. The completed final
  edit was parsed in all four bundles and followed by the passing final-scoped test run.
- Six added regression tests; cumulative new tests 209. No validator, model association, database
  shape, extra uniqueness SELECT, trigger or deletion change. This is one supporting translation
  cause family in addition to the three accepted checker-remediation families, not six findings.
- Full default checker verification is running; do not count any additional violation reduction.
  Whole-suite failures and pending D4/D5/D6 decisions remain open.

### Additional independent index evidence

Fresh read-only properties/dependencies and actual equality-query EXPLAINs confirm three ordinary
reference indexes (ClientPersona/Individual/Agent) have the same complete access keys as retained
UNIQUE indexes, not just a prefix relationship. No constraint/replica identity/CLUSTER/extension
ownership was found on the inspected candidates. All three local tables are empty, so EXPLAIN does
not establish production workload equivalence. See equal-key-index-review.md. No removal migration
or dump update is authorized/executed, and these three findings remain unresolved.

C8 verification closure: default checker completed without internal error, exit 1, 2,065 displayed
groups / 2,123 individual failures / one warning. Same non-OK identities, 873 targets and enabled
checkers as before. Scoped test RuboCop and diff whitespace checks passed. C8 fixes the observed
error-rendering defect; it does not resolve an additional consistency report.

## C9 — capacity of frozen taxonomy snapshot references

- Root cause: the 24 immutable version-assignment models had presence but no bound on their two
  varchar(21) snapshot-reference fields. These are copied historical references, not generated owned
  IDs; PublicId's shared capacity 25 remains unchanged. Existing source and snapshot checks require
  canonical persisted length 21.
- Red: 72 tests/1,008 assertions, 24 expected missing-bound failures, zero errors/skips. All 24
  concrete models already passed short-input derivation, direct DB length rejection and immutable
  model/DB update tests before the change, establishing the behavior to protect.
- Green: 182 tests/4,311 assertions, zero failures/errors/skips. New 72 tests plus relevant ordered
  assignments, snapshots, immutability, promotion, retirement/constraints and locale integrity.
- Minimal change: maximum 21 on create for two snapshot fields in the existing shared Concern. Never
  exact-length validation: supplied 20-character values and string-cast false remain accepted and
  are replaced by the authoritative DB derivation. Never update validation: attempted overlong
  mutations retain ReadOnlyRecord. Source identities, generation, existing values and DB triggers
  are untouched. No migration, callback, SELECT or uniqueness validation added.
- Direct SQL tests establish that 22-character input is refused by varchar before the existing
  trigger; bounded mutations still encounter the existing immutable-row trigger. Savepoints retain
  every original value, and actual deferred completeness checks are exercised for every family.
- Added two attribute labels in all four canonical bundles; full errors are rendered in both
  languages. Catalog inventory limits these two attribute names to the same 24 snapshot tables. Two
  implementation/test files pass RuboCop and diff whitespace check is clean.
- Durable mapping/acceptance: identifier-conventions.md and ID-3r in identifier-contracts.md. These
  do not settle the separate owned-Publishing-ID capacity conflict.
- Full checker and current-includer/raw report capture pending. Do not count the anticipated 48
  removals until that capture confirms the exact finding identities and no new finding.

## C9 — current-run verification on 2026-10-20

The refreshed default full checker and raw-report capture confirm absence of precisely the 48
snapshot-reference length identities anticipated above. The snapshot capacity test file passed in
the 185-test/3,180-assertion resumption slice. This session did not author or reapply the retained
C9 implementation; its prior Red/Green receipts remain historical. All project targets are
unchanged.

## C10 — bounded content-digest creation validation

- Target: LengthConstraintChecker, content_digest on all twelve EntryRevision and twelve
  EntryVersion tables in the publishing connection. One shared missing creation invariant, 24
  findings.
- Grounds: accepted twelve-family encrypted-persistence ADR; canonical plaintext SHA-256 producer;
  create/revise compute it, restore/promotion copy it; varchar(64), NOT NULL and lowercase-hex
  CHECKs.
- Red: 24 tests/612 assertions, 12 expected model-rejection failures, no errors/skips. All twelve
  characterization cases passed normal digest persistence, independent SQL constraints and immutable
  version mutation refusal before the implementation change.
- Green: 133 tests/4,860 assertions; broadened Publishing model/operation, digest and locale bundle
  checks: 376 tests/9,659 assertions, no failures/errors/skips. Final public save!/promoted-revision
  guard assertions have their own completed receipt in the session evidence.
- Change: length exactly 64 plus lowercase hexadecimal alphabet, only on creation, in the existing
  PublishingEncryptedContent Concern; explicit content_digest labels in the four canonical bundles.
  One new test file has 24 tests covering all 24 consumers. No schema or migration changes.
- Behavior: valid writers, encryption, canonical digest generation, promotion/restore and immutable
  updates retain their existing contracts. Malformed create! now raises RecordInvalid before SQL;
  validation-disabled SQL retains NOT NULL/CHECK/varchar enforcement. No uniqueness query is added.
- Checker: individual failures 1,910 -> 1,886; displayed groups 1,895 -> 1,871; warning remains one.
  Exactly 24 content_digest LengthConstraint identities disappear, no new report. All 873 checker
  targets and all checker enabled states are retained. The 24 content_digest NullConstraint reports
  remain: the checker recognizes neither exact length nor format as nil rejection. Do not add
  redundant presence or hide those reports merely to improve the count.
- Risk: no data transformation, deletion, authorization, DB-boundary, lifecycle or migration change.
  The independent schema-drift task stopped on a preexisting HMAC definer-role/database-name
  mismatch; schema and migration safety remain unverified. Whole-suite success is not established by
  scoped tests.

## C11 — required Publishing creation fields

- Authority: 2026-10-20 user instruction delegates validation specifications and requests NOT NULL
  findings and mistakes be corrected. Existing data/security/compatibility constraints continue.
- Actual columns: locale on twelve Entry, EntrySlug, EntryRevision, EntryVersion models and
  effective_from on twelve Publication models already have NOT NULL, no default/callback value.
- Cause: model creation admitted nil until the DB rejected it. Implement nil-only exclusion for
  locale (not presence), because nonnull empty/whitespace and false/zero string casts are valid in
  the existing tables. Publication effective_from gets creation-time presence. No schema migration.
- Red: 36 runs/1,392 assertions, 24 expected failures, no errors/skips; twelve all-family
  persistence, six locale partitions, direct SQL null refusal and immutable-update characterizations
  passed.
- Green: relevant Publishing model/operation/locale tests: 407 runs/11,836 assertions, no
  failures/errors/skips. A final combined run adds projected-publication update protection.
- Full checker after C11: 60 NullConstraint reports removed, twelve new ColumnPresence possible_null
  reports, net 48 fewer failures (1,886 -> 1,838). The checker treats any presence :on context as
  possibly nullable without considering existing NOT NULL enforcement. Keep creation scope to
  preserve projected saves; retain all twelve reports, original IDs, no checker workaround. A FIXME
  in the owning Concern records the conflict. No migration or extra validation SELECT.

## C12 — nonnullable Avatar catalog booleans

- Cause: nine required AvatarLifecycleState booleans had neither defaults nor model validation.
  Inclusion of true/false on creation rejects omitted/empty inputs while retaining false. All
  canonical catalog rows/values, state axes/edges, event and authorization writers are unchanged.
- Red: 23 runs/70 assertions, nine expected failures, zero errors/skips. All false/true persistence,
  raw DB NULL refusal and existing catalog/terminal restrictions passed before implementation.
- First broadened run: 49 runs/253 assertions, zero failures, five errors, no skips. Five
  independent committed-ownership tests require run-owned worker receipts, unavailable in the
  one-worker runner. This is a failed check, not a waiver or a passing ownership test. No global
  test setup was changed.
- Focused model/binding/lifecycle transition/authority invariant/locale bundle run: 53 runs/253
  assertions, zero failures/errors/skips. Full checker captures and final combined receipts are in
  the evidence record. No data/schema migration or boolean default was added.
- Security review: nil cannot silently become an authority default; both true and false persist,
  validation-disabled NULL fails in PostgreSQL, and restricted/deleted state behavior remains
  tested. No request ordering, membership, grant, surface or audit boundary changes. This is scoped
  validation evidence, not a general security audit or migration-production acceptance.

## C13 — family-local vocabulary key uniqueness

- User prioritizes UniqueIndexChecker; ordinary validation design is delegated. D1's normal
  term-slug duplicate exception contract remains unchanged. Shape review of all 605 reports: 369
  ordinary, 122 PK-containing (94 referenced by real FKs), 102 partial and twelve NULLS NOT DISTINCT
  indexes. The matched indexes were unique/ready/valid in current read-only catalogs. No checker or
  index changed.
- Root cause: twelve Vocabulary.key indexes lacked ordinary create-time preflight. The accepted
  taxonomy ADR requires family-table scope, independent of kind/locale/archival. No ordinary key
  collision handler was found; existing DB-duplicate tests bypass validation. Add one create-only
  uniqueness declaration; preserve the PostgreSQL frozen-key restriction on updates. Four explicit
  Key labels added; no archive predicate, scope, normalization or case-folding introduced.
- Red: 37 tests/180 assertions, 24 expected failures, zero errors/skips. Thirteen normal
  cross-family, DB uniqueness and immutable-key characterization tests passed before implementation.
- Green: all relevant Publishing models/operations and locale integrity, 444 tests/12,268
  assertions, zero failures/errors/skips. Extending format characterization initially placed a test
  declaration inside a running test and caused one draft-run error (37/408); corrected the
  declaration placement, without weakening assertions or changing production behavior to accommodate
  it.
- Final strengthened run: 456 tests/12,472 assertions, zero failures/errors/skips. New file has 49
  tests, covering all twelve models, same-family/cross-family keys, archived reservation, different
  kinds, nil/empty/whitespace/zero/invalid format, false-to-string casting and minimum valid lengths
  1/2. SQL NULL/CHECK/UNIQUE refusals and unchanged-key/immutable-key behavior are preserved.
- Performance: sql.active_record measurements establish exactly one added key probe per new-record
  validation, none on unchanged existing-record validation. No uniqueness preflight is race-proof;
  independent validation-disabled duplicate tests confirm PostgreSQL remains authoritative.
- Compatibility: normal duplicate vocabulary create! changes to RecordInvalid with key:taken;
  explicit bypass retains RecordNotUnique, immutable updates retain PostgreSQL RestrictViolation.
  This bounded administrative preflight is a validation decision within the delegated scope, not
  permission to change D1 or idempotency/retry contracts elsewhere.
- Full default checker: UniqueIndex 605 -> 593; individual total 1,829 -> 1,817; displayed groups
  1,814 -> 1,802; one warning unchanged. Exactly twelve key-index report identities removed, no new
  non-OK report. One root cause, twelve affected models, 49 added tests, zero migrations.
- Partial and NULLS NOT DISTINCT reports, FK-target id reports, D1, and remaining caller/exception
  contracts remain open in unique-index-review.md/current-findings.md. No production, schema
  migration, deletion, auth path or audit-retention change. Full-suite and production safety
  acceptance remain open.

C13 terminal refresh: during the slice, an independent `20261020090000` migration and R7M2 evidence
appeared. Its 24 unused three-column locale unique indexes were removed concurrently. The final
456-test run's preparation automatically applied that newly introduced migration to the test DB (the
stdout records the version and successful migration); C13 authored no migration. Preserve that work
and do not attribute its changes to the key validator. A fresh full check and raw capture show **569
UniqueIndex failures, zero RedundantUniqueIndex failures, 1,769 total individual failures, 1,754
displayed failures and one warning**. The extra 48 absent identities are 24 UniqueIndex plus 24
RedundantUniqueIndex, separate from C13's twelve. This corrects the earlier post-validator count as
a historical checkpoint rather than the latest concurrent worktree result. Schema/dump safety for
that independent migration is not re-audited or claimed by C13.

## C14 — concrete resource/principal Grant uniqueness

- User authorizes all safe UniqueIndex fixes, with scoped reversion on behavior regressions. The 21
  ordinary two-FK indexes have no predicate/NULL ambiguity. Add explicit resource-FK uniqueness
  scoped to principal FK in each existing concrete model; no generic authority abstraction or
  permission change.
- First characterization draft: 63 runs/707 assertions, 28 failures, zero errors/skips. Seven were
  wrong sentinel expectations: Client id 0 is a real fixture row, and false integer-casts to it.
  Correct the new tests to preserve that behavior; do not reject existing principals to satisfy
  them.
- Confirmed Red: 63 runs/791 assertions, 21 expected missing-validation failures, no errors/skips.
  Same-resource/different-principal, same-principal/different-resource, raw DB uniqueness, unchanged
  saves and refusal to infer ownership from grants were protected for all six families.
- Green: 81 runs/1,031 assertions. Broadened all six model-family/creator, owner scope, backfill,
  replay/legacy RP, taxonomy/promotion and locale checks: 224 runs/1,657 assertions, all passing, no
  errors/skips. Final new file includes 84 tests with one added pair SELECT on new validation and
  zero on unchanged persisted validation for all 21 models.
- Scope-changing collisions reject before SQL without modifying the row; raw duplicate writes still
  raise RecordNotUnique. Added explicit FK labels in the four canonical locale bundles.
- Full default checker: UniqueIndex 569 -> 548. DB indexes, state, owners, role eligibility,
  locking, retry handlers, auth paths, migration/schema and checker configuration remain unchanged.

## C15 — one Ownership/Lifecycle per resource

- Twelve ordinary single-FK indexes have one-row-per-resource semantics. Six creators allocate new
  resources; backfills explicitly lock, find and return existing rows rather than relying on
  create_or_find_by! duplicate exceptions. Add explicit resource-FK uniqueness in each model.
- Red: 36 runs/156 assertions, 24 expected duplicate/query-budget failures, zero errors/skips; all
  twelve ordinary save/different-resource/raw DB duplicate characterizations passed.
- Green with Grant/owner-scope/creator/idempotent-backfill/locale regressions: 152 runs/1,457
  assertions, zero failures/errors/skips. New file has 36 tests, including missing/empty/zero/false
  FKs, attempted reparenting collisions, one creation SELECT and zero unchanged-key SELECTs. Raw
  UNIQUE remains.
- Full default checker: UniqueIndex 548 -> 536. No authority, ownership-transfer protocol, state
  values/edges, lifecycle writers, session or schema change. No migration authored or executed.
- No implementation regression was observed in C14/C15, so no successful declaration was reverted.
  Existing exception-driven lock/replay/slug/promotion contracts were never edited.

## C16 — partial uniqueness for unrevoked RP-cell sessions

- All twelve cell tables require one unrevoked row per op_session_binding_id. The exact predicate is
  revoked_at IS NULL, not active?/unexpired. Correct preflight applies only to creation of an
  unrevoked candidate, so history and refresh/revocation updates add no uniqueness query.
- Red: 24 runs/120 assertions, twelve expected failures, zero errors/skips; all twelve history,
  anchor-scope, expired-unrevoked DB collision, explicit revocation/replacement characterizations
  passed.
- Green with real callback enrollment/replay, cell revocation, local-cookie readiness and locale
  checks: 54 runs/307 assertions, zero failures/errors/skips. The writer's anchor locks, expired-row
  closing, tombstone and already_enrolled results remain unchanged; no root issuance path is added.
- Full default checker: UniqueIndex 536 -> 524. Both existing-row conditions and candidate
  eligibility match the physical predicate. New normal duplicate model creation raises
  RecordInvalid; disabled validation still yields RecordNotUnique. No index, migration, DB/session
  boundary or cookie change.

## C17 — one appeal and PrincipalEffect per Case

- Six ordinary Case-FK indexes across app/com/org are distinct from the open-effect supersession
  predicates. Add only explicit Case-FK uniqueness in the six concrete models. No state value,
  transition, reviewer separation, access-blocking, associated-effect ordering or audit writer
  changes.
- Red: twelve tests/42 assertions, six expected missing-validation failures, no errors/skips; all
  same/different-Case, ordinary unchanged saves and raw UNIQUE characterizations passed.
- Green with appeal reviewer/redaction/audit, apply-ordering/failure and locale checks: 28 tests/151
  assertions, zero failures/errors/skips. Normal duplicates get RecordInvalid; raw duplicates still
  RecordNotUnique. Global explicit Case-FK labels render both languages.

## C18 — active account-assignment pairs

- Three pair predicates are revoked_at IS NULL, independently scoped to the concrete resource and
  identity. Bootstrap already handles RecordInvalid and RecordNotUnique in create_unique, so no
  exception-driven writer changes. Add exact create-only active-pair validation in concrete models.
- Red: six tests/27 assertions, three expected failures, zero errors/skips. Alternate pairs, revoked
  duplicates, revoke/reassign and direct DB unique refusal were already passing.

C18 Green: assignment/selector-bootstrap/selector/locale tests passed, 34 runs/197 assertions, zero
failures/errors/skips; full default UniqueIndex 518 -> 515.

## C19 — pending ownership-request slots

- Six existing model tables allow one status=pending row per resource; terminal history and distinct
  resources are separate partitions. Expiry alone does not make a pending row leave the index. Add
  only create-time, candidate-pending, exact pending-predicate validation in concrete models.
- Red: twelve tests/48 assertions, six expected failures, zero errors/skips; raw uniqueness, closed
  history, resource scope and cancel/recreate characterizations passed before implementation.
- Green with party/expiry, Grant/Ownership/Lifecycle, backfill and locale checks: 167 runs/1,579
  assertions, zero failures/errors/skips. No ownership-transfer route, authorization, lifecycle edge
  or protocol is introduced; this remains the existing model/DB intent boundary only.

C19 full default UniqueIndex: 515 -> 509.

## C20 — sibling-position validation trial reverted

- The twelve NULLS NOT DISTINCT indexes can technically be represented by a position uniqueness
  scope including vocabulary/locale/nullable parent. However D1 protects normal duplicate-slug
  RecordNotUnique, including inputs that conflict on both slug and sibling position.
- Characterization before trial: 24 tests/132 assertions, zero failures/errors/skips. NULL roots
  share a sibling slot; alternate locale and distinct parents retain independent slots. Both single
  and double uniqueness-conflict slug creates retain RecordNotUnique.
- Trial: one create-time position uniqueness declaration in the existing term Concern. Protected
  tests: 24 runs/96 assertions, twelve expected failures, no errors/skips, because RecordInvalid
  replaced D1's RecordNotUnique for double conflicts. Removed exactly the trial declaration, keeping
  prior work and adding a FIXME explaining the conflict. No checker reduction was counted.
- Restored contract plus existing taxonomy constraints/retirement checks passed; see receipt in
  session evidence. All twelve sibling-position findings remain unresolved pending a contract
  change. No validator condition, exception shim, checker configuration or DB index was manipulated
  to hide them.

## C21 — active Avatar capability tuples

- Two indexes cover ownership period, subject public reference and capability, revoked_at IS NULL.
  Use exact create-only candidate-unrevoked preflight; preserve capability separation and revoked
  history. The actual issuing service, current-period and membership locks are untouched.
- Red: four runs/24 assertions, two expected failures, zero errors/skips. Raw UNIQUE, capability
  scope, history and actual reissue after revocation already passed for app Persona and org Agent.
- First broad command referenced a nonexistent standalone membership-lock test file and stopped
  during loading; no tests ran. Corrected to actual service/invariant files, without removing tests.
- Corrected Green: 29 runs/113 assertions, zero failures/errors/skips. Independent root/RP issuance,
  cooldown, callback/revocation/cookie readiness, lifecycle writer and identity authority guards
  also passed: 102 runs/1,101 assertions, zero failures/errors/skips.
- Full default UniqueIndex: 509 -> 507. No role, owner, membership, temporal authorization, state,
  session, storage, schema or checker change. Subject-reference labels added in all four bundles.

## C22 — global Member public-reference uniqueness

- Add only the missing global uniqueness validator. No owned-ID
  generator/format/length/immutability, owner assignment, retention writer or legacy association
  changes are introduced.
- Red: two runs/six assertions, one expected failure, zero errors/skips; ordinary distinct
  references, unchanged-reference relabelling and cross-owner direct DB UNIQUE/NULL refusal were
  passing.

C22 Green: 12 runs/30 assertions, no failures/errors/skips. Full default UniqueIndex: 507 -> 506.

## C23 — storage reference creation preflight

- Red: 3 runs/9 assertions, one expected failure, no errors/skips. Real upload resynchronization and
  raw DB UNIQUE/NULL already passed.
- Add creation-only storage_key uniqueness, preserving the metadata-update DB exception and
  callback. Add four locale labels.
- Initial broad command used a nonexistent media_file_test.rb; it loaded no tests. Corrected
  existing attachment/usage and locale suite: 27 runs/123 assertions, zero failures/errors/skips.
  Test preparation also applied existing test-database migrations; these were not authored by this
  slice and are not production evidence.
- Full default UniqueIndex: 506 -> 505. No storage namespace, object deletion, schema or identifier
  change.

## C24 — entry-local revision sequences

- Red: 24 runs/72 assertions, twelve expected failures, zero errors/skips. All-family
  adjacent/cross-entry values and raw UNIQUE were already valid.
- Twelve concrete declarations: sequence uniqueness scoped by entry_id, on creation only. No legacy
  Concern expansion or version/promotion exception change.
- Green: 98 runs/1180 assertions, zero failures/errors/skips, including numeric boundaries, revision
  editing, promotion and version immutability.

C24 full default UniqueIndex: 505 -> 493.

## C25 — complete RP sender keys

- Thirty-six concrete creation-only validators cover SID, subject and receipt JTI in all twelve
  cells. Each scope matches the DB index, including issuer and receipt event_type; no scope omits
  realm/client.
- Red: 72 runs/300 assertions, 36 expected failures, zero errors/skips. Raw UNIQUE, scope
  partitions, tombstone updates and immutable identity mapping were already passing.
- Initial Green found twelve missing subject attribute translations, not a persistence regression;
  added the missing label in all four bundles. Corrected Green: 114 runs/643 assertions, zero
  failures, errors or skips, including callback and revoker duplicate delivery/local history tests.
- Full default UniqueIndex: 493 -> 457. Anchor upserts still bypass validations atomically; creation
  of identity or receipt adds one indexed SELECT each. No root/session writer or cell binding
  changes.

## C26 — one concrete transfer detail per reservation

- Four ordinary single-column unique indexes. ReservationCreator retries only named reservation
  indexes and returns an existing detail for identical replay; detail uniqueness is not its retry
  signal.
- Red: four runs/12 assertions, four expected failures, zero errors/skips; real reservation creation
  and raw DB UNIQUE already passed. Add create-only reservation FK uniqueness and four label
  bundles.
- Green: 32 runs/179 assertions, zero failures/errors/skips, including actual transfer operation
  suite and same-input reservation replay. No reservation-state, ownership or retry-handler changes.

## C27 — one infinite concrete ownership period per Avatar

- Initial test setup used a moniker above its existing sixteen-character limit and produced two
  errors before reaching the subject. Corrected only the new fixture input, retaining that limit.
- Confirmed Red: two runs/eight assertions, two expected failures, zero errors/skips. Raw DB UNIQUE
  already rejects a second infinite period in both concrete owner tables.
- Add exact infinity predicate and candidate guard on creation only. A future start does not free
  the infinite slot; finite candidates skip this particular preflight and keep DB temporal checks.
- Narrow Green with real transfers/details/locales: 34 runs/199 assertions, zero
  failures/errors/skips. Broader owned two-worker concurrency and commit verification is recorded
  separately when completed.

C26/C27 full default refresh: UniqueIndex 457 -> 451 (four detail and two infinite-period reports).
The first ordinary two-worker command completed with eleven receipt-guard errors and no failed
assertions; no guard was relaxed. The corrected isolated run with run-owned worker receipts passed
71 tests/385 assertions, zero failures/errors/skips. Final serialized aggregate across all new cases
and related contracts passed 475 tests/3,999 assertions, zero failures/errors/skips. Scoped RuboCop:
70 files, no offenses. Full checker exits 1 for 1,644 individual failures and one warning (1,629
grouped failure lines); all current reports map to retained stable IDs. See U9K4 evidence. These are
partial progress, not completion of all safely fixable remaining consumer reviews.

## C28 — processor delivery attempt tuple

- The notification models remain unchanged: their find_or_create_by! caller depends on DB collision
  retry. Only the two attempt models receive attempt_number uniqueness scoped by notification FK and
  delivery_generation, on creation. Existing row locks, lease claims, retry/receipt/erasure writers
  and their audit records remain intact.
- Initial new test loading failed on an incorrect VisitorVisibility::USER constant; corrected the
  new test to the existing VISITOR constant without changing application defaults.
- Confirmed Red: four runs/16 assertions, two expected failures, no errors/skips. Actual repeated
  begin_attempt!, retry ordinal increment, raw UNIQUE and generation partitions were already valid.
- Green: 41 runs/147 assertions, zero failures/errors/skips, including existing state, delivery,
  independent-connection concurrency, notification/retry jobs and locale tests. One added indexed
  SELECT on attempt creation, none on updates. No migrations or data conversion.

## C29 — OP admission client/epoch tuple

- Three concrete creation-only client_id uniqueness validators scoped to contract_epoch. The named
  writer still locks the epoch row, finds/initializes exactly that tuple and updates it;
  enable/disable decisions and audit facts remain with existing writer/query.
- Red: six runs/21 assertions, three expected failures, no errors/skips. Different client/epoch,
  false-state updates and raw UNIQUE were already valid.
- Green: 20 runs/54 assertions, zero failures/errors/skips, including the real writer, admission
  gate and locale suite. One added indexed SELECT on initial insertion, none on same-row updates.

## C30 — Secret issuance operation ordinal

- One creation-only attempt_number uniqueness validator scoped to origin_operation_id, globally
  across clients. Existing reservation/reattempt writers first lock and return matching prior work;
  no tuple-exception retry was found. Immutable facts and PublicId retry logic remain unchanged.
- Red: two runs/six assertions, one expected failure, no errors/skips. Distinct operation/ordinal,
  unchanged omission state, persisted save and raw DB uniqueness were already valid.
- Green: 44 runs/861 assertions, zero failures/errors/skips, including issuance state, manual and
  registered Passkey reservations, reattempt, capacity concurrency and invalidation, plus locales.
  Existing validate:false different-constraint collision test remains passing. One new indexed
  creation SELECT; no persisted-transition query. No authorization, lifecycle or audit writer
  changes.

## C31 — OP event receipt sender tuple

- Three concrete creation-only event_id validators scoped to issuer/realm/client_id; event_type
  deliberately remains outside the key, matching the index. No inbound receipt, epoch-cutoff,
  root-revocation, queue, connection or durable retry writer changes.
- Red: six runs/27 assertions, three expected failures, zero errors/skips. Sender/client/event
  partitions and raw DB uniqueness already passed.
- Green: 18 runs/70 assertions, zero failures/errors/skips, including actual epoch invalidation,
  duplicate redelivery, unavailable-OP enqueue and sweep, plus locale validation. One new indexed
  creation SELECT; none on persisted updates or already-recorded deliveries.

C28–C31 full default check: UniqueIndex **451 -> 442**. CLI exit 1 for 1,620 grouped failures; raw
capture completed with 1,635 failures and one warning. All current non-OK identities map to the
ledger. Final serialized aggregate: 124 runs/1,222 assertions, zero failures/errors/skips. Final
scoped RuboCop: thirteen files, no offenses. See S2V6 evidence.

## C32 — exact session-limit parent and actor predicates

- Six reports on three concrete models. Creation-only sign_in_flow_id validation uses OPEN_STATES
  (10,20); actor_ref validation independently uses waiting_slot=1. Both candidate guards match the
  DB predicates. An elapsed open child still occupies each key. Do not replace these with active_at.
- Confirmed Red: six runs/30 assertions, three expected failures, zero errors/skips. Actual issue
  replay, occupied-slot refusal, raw uniqueness and cancel/reissue/history already passed in all
  realms.
- Initial Green: 52 runs/375 assertions, zero failures/errors/skips, including real resolution,
  refusal/gate, app/com promotion/cookie/audit boundaries and identity/lifecycle guards. Added
  separate parent-only and actor-only collisions, elapsed candidate and closed candidate eligibility
  before the final rerun. No transition, actor/root/session ownership or writer changed; two indexed
  probes on open creation and none on existing transitions/replay. Error labels added in four
  bundles.
- Mermaid README summary says code pending, but concrete resolution diagrams, detailed transition
  inventory and current code/tests describe the implemented waiting-slot policy. This pre-existing
  discrepancy is recorded; validators preserve that policy and introduce no state edge.

C32 final expanded Green: 52 runs/405 assertions, zero failures/errors/skips. Scoped RuboCop: four
files, no offenses. Full default UniqueIndex **442 -> 436**; CLI exit 1 for 1,614 grouped failures,
raw capture completes with 1,629 failures and one warning, all stable IDs mapped. C28–C32 combined:
fifteen reports on twelve concrete models, five new test files/twenty-four tests, no migrations. All
safely-fixable remaining consumer review is still incomplete; do not mark the goal complete.

## C33 — Step-up transaction reference on creation and reuse

- Three ordinary unique nullable FK columns. The Base issuer may assign a new transaction to a
  persisted session, so validation covers creation and updates, with allow_nil (not allow_blank).
  Passkey challenge refs remain DB-authoritative for the existing named collision retry.
- Initial new fixtures used random references without creating the actual FK parents; nine setup
  errors exposed the real FK. Corrected the test to create genuine ceremony transactions through
  their public API; the DB constraint and production model were not weakened.
- Confirmed Red: nine runs/21 assertions, six expected failures, no errors/skips. Multiple nil rows,
  genuine FK parents, raw unique updates and unchanged existing keys already passed.
- Green: 96 runs/873 assertions, zero failures/errors/skips, across all realm models, Base issuer,
  Passkey named-index collision retry, email challenge, revocation and locale bundles.
- Query-budget extension initially exceeded the existing two-root cap for com/org and used an
  over-specific SQL prefix for the client probe. Corrected only new fixture ownership (fresh actor)
  and SELECT classification; kept root caps and the one-probe expectation intact. Corrected budget:
  nine runs/57 assertions, zero failures/errors/skips. One probe for a new nonnil ref and none for
  unchanged existing ref. Changed persisted refs are validated; nil creates/clears remain allowed.

## C34 — nonnil root token on sign-in flow

- Three partial indexes exclude only nil token_id. Actual root issuance and sequence attachment
  update existing flows; creation-only validation would miss that boundary. Use uniqueness with
  allow_nil and will_save_change_to_token_id? to cover actual writes without querying again on
  unrelated later transitions. No completion, root issuance, state or cookie/audit writer changes.
- Red: nine runs/33 assertions, nine expected failures, zero errors/skips (six missing duplicate
  preflights and three missing measured create probes). Nil rows, raw uniqueness and genuine token
  parents were already valid; query-budget expectations are regression assertions, not old behavior.
- Green: 74 runs/1,065 assertions, zero failures/errors/skips, including app/org root establishment,
  capacity/cooldown, session-limit promotion/refusal and identity/lifecycle guards. One indexed
  probe on a new or changed nonnil attachment; none for unchanged token IDs or nil values.
- Combined C33/C34 after formatting: 204 runs/2,192 assertions, zero failures/errors/skips. Includes
  independent-connection Secret root-login and Step-up consumption concurrency, named Passkey
  reference-collision retry, original Auth ceremony RecordNotUnique contracts, Base admission, real
  root establishment/promotion/refusal, cooldown and identity/lifecycle guards. Existing Flipper
  duplicate middleware warnings were printed; they did not fail tests and were not modified here.
