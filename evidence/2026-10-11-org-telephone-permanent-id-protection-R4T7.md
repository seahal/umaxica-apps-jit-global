# ORG Telephone permanent public identity protection

HEAD: `c126938480615e5b5f78434393301f162776ff26`, branch feature. Implementation, tests, migration,
generated ORG schema and architecture-baseline changes are uncommitted alongside earlier owned work
and unrelated source-policy/OTP documentation work. This document commit is not their snapshot. All
database execution used verified owned fleet `20261010p3d2`, host primary, worker 1 and the complete
twenty-catalog preparation list. No shared/production database or cluster role changed.

The scoped approval recorded in V8A2 and the trigger ADR was implemented by the generator-created
`db/org_principals_migrate/20261011024019_protect_operator_telephone_public_id.rb`. One named BEFORE
UPDATE OF public_id trigger and its function are created together. A changed non-NULL OLD identity
raises SQLSTATE 23514 without logging, rewriting, ignoring or generating data. Same-ID assignment
and unrelated writes remain legal; NULL-only backfill remains admitted. The function has no
secondary writes/locks or cross-database references. It does not claim protection against an
administrator deliberately disabling it. Final NOT NULL/cutover and other tables' immutability
remain incomplete.

## Observed checks

- Before the new migration, the public SQL/bulk/upsert test file produced intended Red: 4 runs, 6
  assertions, 3 failures, zero errors/skips, 0.623765 seconds. Each failure was an expected database
  refusal that did not occur, not unavailable API/environment/syntax.
- `bundle exec rails generate migration ProtectOperatorTelephonePublicId --database org_zenith`
  generated the exact path above. Safety verification preceded `db:migrate:org_zenith`, exit 0. The
  existing noninternal ORG inventory was observed as operator_rotation_audit_guard; the new exact
  inventory preserves it and adds only operator_telephones_public_id_immutability.
- First Green over the identity/backfill/legacy-inventory/enforcement files: 20 runs, 123
  assertions, zero failures/errors/skips, 1.167912 seconds. Tests cover SQL replacement, NULL,
  empty/blank/zero strings, update_columns/update_all, PK-conflict upsert, preservation after
  savepoint recovery, admitted unchanged-ID/attempt updates and NULL-only backfill/resume.
- `VERSION=20261011024019 bundle exec rails db:migrate:down:org_zenith` exited 0. Read-only catalog
  verification confirmed the new function absent and only the old rotation trigger remaining. The
  initial attempt to inspect via OrgPrincipalRecord failed because that semantic abstract class does
  not establish the connection; the corrected OrgZenithRecord query succeeded. This diagnostic error
  is not a Red or a database mutation. The to_regprocedure query emitted a type recognition warning
  while correctly returning NULL.
- Only after reversal, formatting of this newly owned unapplied migration was corrected. No
  historical applied migration was edited. Reapply and `db:schema:dump:org_zenith` exited 0. The
  generated diff contains the new function/trigger/comment, the earlier public-ID expansion's
  column/check/index and two actual version receipts, plus four environment-bound HMAC role-name
  substitutions. No hand editing of the dump occurred.
- Final seven-file local regression: 94 runs, 535 assertions, zero failures/errors/skips, 7.747597
  seconds. Files: the new identity test, operational backfill test, legacy-reference query test,
  enforcement inventory test, OperatorTelephone model test, Telephone concern test and ORG Telephone
  registration controller test. Scoped RuboCop passed five owned files, zero offenses.
- `bundle exec rails db:verify_no_schema_drift` exited 1 on db/org_zenith_structure.sql. Separate
  existing SchemaDriftVerification.dump_matches? execution exited 0, confirming normalized
  generated-file/catalog parity. The remaining failure is the intentional uncommitted schema diff.
  No reset or unauthorized code/schema commit was used to conceal it; the committed-schema gate
  remains unfulfilled.
- Both full Gate 2 suites started after the local checks. Vitest exited 0: 99 files, 1,140 tests,
  13.25 seconds. Rails is running; no next feature is permitted until its outcome is resolved.

ID-4a now references the actual public test. The conventions and trigger ADR reference actual
objects/migration/tests without claiming deployment, final NOT NULL readiness, independent
acceptance, or all-table I completion. No application/test/schema commit or push occurred.
