# WU-24c/d Binding curfew and explicit intent; WU-24g reconciliation

- Date: 2026-10-23.
- Commit: `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`.
- Worktree: pre-existing staged/unstaged/untracked work plus this cycle's uncommitted changes.
  Staging changed during the session; no commit or index reset was performed by this work.
- Authority: `two.md` 6.1 and 6.13; D-72, D-74, D-75, D-129, D-157, D-159 and D-168.
  This record covers storage, not WU-06 consumer deadline alignment or all-cycle acceptance.

## Delivered schema and behavior

- Three realm-specific curfew migrations add `curfew_at` with no default and final NOT NULL.
  The add and immediate NOT NULL DDL share one transaction; there is no nullable runtime phase
  or backfill. This also respects the repository's lint policy without adding a masking default
  or disabling a cop. Empty-table constraint enforcement is explicitly safety-assured under D-159.
- Three intent migrations replace the old nullable Switch-only constraint with NOT NULL and a
  purpose CHECK. Authorization purposes use `sign_in`/`sign_up`; the five re-verification purposes
  use `not_applicable`. All three models validate the same rule explicitly.
- Issuance resolves and stores intent and the OP writer's issuance clock plus 30 minutes.
  Both facts are immutable through the model update boundary. A Switch requires original
  redeemed/cancelled history, preserves its deadline and refuses inconsistent deadlines.
- Migration IDs: APP `20261023190906`, `20261023191141`; COM `20261023191115`, `20261023191145`;
  ORG `20261023191130`, `20261023191149`. All were created with `bin/rails generate migration
  <name> --database op_base_<realm>` and reviewed before execution. No schema dump was hand-edited.
- WU-24g was already implemented by the WU-01 `2026102312000x` migrations: no
  `local_sign_up_flow_ref` remains in `app/` or any of the three generated OP dumps, including
  CHECK/FK references. The `rotate_and_admit!` signature has no such parameter. No duplicate
  retirement migration was added.

## Runtime migration verification

- D-159/D-168 authorized fresh databases and data loss. Development APP had five Binding rows;
  COM/ORG had zero. The three development OP databases and then the three test OP databases
  were rebuilt through `db:drop:op_base_<realm>`, `db:create:op_base_<realm>` and
  `db:migrate:op_base_<realm>` for APP/COM/ORG. Existing data in those local OP databases was lost.
  Other databases were not dropped by this slice. No row backfill, forced expiry or row settlement
  was performed.
- Final migrations were rolled back and reapplied in development and test using
  `STEP=2 ... bin/rails db:rollback:op_base_app db:rollback:op_base_com db:rollback:op_base_org`
  followed by the three scoped migrate tasks. All commands exited 0. Development inspection after
  rollback showed `curfew=false`, `intent_null=true` on all three Binding tables; reapplication
  restored NOT NULL and the purpose constraints.
- Rollback was exercised on empty rebuilt tables. Dropping curfew loses deadline facts, and the
  old intent constraint cannot accept newly written `not_applicable` rows. A populated rolling
  downgrade is not verified; D-159/D-168 recovery is a rebuild, not value reinterpretation.
- Generated the three OP dumps with the development `db:schema:dump:op_base_<realm>` tasks.
  Reviewed the new columns/CHECKs and migration-version entries. Additional dump differences
  reflect the existing WU-01/WU-17 migrations and PostgreSQL's generated constraint rendering.
- Ran the actual `SchemaDriftVerification.dump_matches?` implementation for exactly the three OP
  writer configurations in development and test, each using a temporary dump directory.
  All six comparisons returned true. The diagnostic runner was `/tmp/two-op-schema-verification.rb`;
  it loaded the ordinary Rails tasks and changed no application code or verification semantics.

## Tests and checks

- Red: `bin/rails test test/services/admission_binding_deadline_intent_test.rb`:
  9 runs, 7 assertions, 7 failures, 2 errors. Ordinary intents were NULL, curfew readers were absent,
  and the existing database did not enforce the new facts.
- First Green attempt (deadline/intent file, model file and parent-purger file): 27 runs,
  257 assertions, 1 failure. The stricter purpose/intent CHECK rejected a wrong-purpose row before
  the existing parent CHECK. Updated that test's inputs to isolate the parent rule and pinned
  the actual new rejection for retired purposes; all refusal assertions remain.
- Corrected narrow run: 27 runs, 384 assertions, no failures/errors/skips.
- Broad run: `rg -l -0 --glob '*_test.rb'
  'BaseAuthAdmissionCoordinator|AuthCeremonyAdmission|AuthCeremonyContext' test | xargs -0
  bin/rails test` with deadline/model/purger/entry/resolver files and the six selected invariant
  guards appended: 1598 runs, 19582 assertions, 47 failures, 1 error, 0 skips; 54.088181 seconds.
  Every failing identity occurs in the full intake baseline; no new failing identity was found.
  This is not a passing G-1 claim; those failures remain unwaived.
- Strengthened Switch coverage to exercise zero original Bindings (refused without a row), one
  original Binding and repeated Switches over multiple redeemed Bindings with one deadline.
  Final focused run of deadline/intent, model, parent-purger and Auth redemption-input boundary
  files: 111 runs, 1067 assertions, no failures/errors/skips. This also exercises successful
  admission after retained-reference refusals across APP/COM/ORG for A24-9.
- RuboCop on the 14 changed/new Ruby files: no offenses. The final strengthened test file was
  linted again: no offenses. Scoped diff whitespace checks passed.

## Failed and unverified checks

- Normal development `bin/rails db:verify_no_schema_drift` failed before completing with:
  `HMAC definer role does not match database development_com_zenith_db`.
- Normal test `RAILS_ENV=test bin/rails db:verify_no_schema_drift` failed with drift in
  `db/app_zenith_structure.sql`, `db/com_zenith_structure.sql`, `db/org_zenith_structure.sql`.
  These Zenith databases were not rebuilt or changed by the OP migrations. Their cause still
  needs investigation; the scoped six OP comparisons do not replace the required global check.
- No full-suite rerun, production migration, WU-24h E1 ownership or WU-06 consumer-curfew acceptance
  is claimed. The full goal and cycle gates remain open.
