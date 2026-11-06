# OP-mediated step-up test database repair

Date: 2026-11-04

Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`

The worktree was already extensively dirty before this step (`git status --short` reported 1,369
paths). No commit was created. The worktree was still dirty after the repair; unrelated changes were
preserved.

## Scope and database repair

Read the 2026-11-04 10:00 owner instruction at the end of `zero.md`. `RAILS_ENV=test` catalog
verification identified PostgreSQL at `primary:5432`, server 18.6, administrative database `db`, 50
configured test databases and 26 writable test database targets.
`DatabaseSafety.prepare_database_names!` confirmed the 26 targets cover all writable test databases.
No replica-role database was selected for a write.

The task implementation differs from the owner note's description: `lib/tasks/test_db_prepare.rake`
overrides `db:test:prepare` to migrate selected existing databases; it does not purge them. To
realize the explicitly authorized test-database rebuild without changing the task or touching other
environments, ran the per-database Rails reset tasks under `RAILS_ENV=test` for exactly these 26
logical databases, then ran `RAILS_ENV=test bin/rails db:test:prepare`:

```text
app_setting, app_signal, app_zenith, avatar, chronicle, com_setting, occurrence,
op_base_app, op_base_org, org_setting, org_signal, org_zenith, primary, publishing,
queue, rp_base_app, rp_base_org, rp_core_app, rp_core_org, rp_edit_org, rp_palm_app,
rp_tech_org, rp_warp_app, rp_warp_org, search, storage
```

The reset task invocation and `db:test:prepare` both exited 0. The prepare task reported the
expected 26 writable test databases and completed without the previous `PG::DuplicateTable` error. A
read-only post-check found zero pending migrations in all 26 writable test databases.
`test_publishing_db` now has 159 public tables and 6 `schema_migrations` rows; before repair it had
159 tables and 0 migration rows.

No development database was written. Development was used only for read-only migration-state checks
and structure dumps. No replica-role write, production/Neon access, `leak_template_*` access or
fixture edit occurred. The five header-only structure dumps outside the owner's named 20 paths
(`chronicle`, `op_base_app`, `op_base_org`, `rp_base_app`, `rp_base_org`) were restored
byte-for-byte to their pre-reset worktree contents after the reset tasks.

## Structure dumps

Each of the 20 owner-listed files was 18 lines before repair. The migration-directory check found 16
files with no changes since `HEAD`; those were restored from `HEAD`. It also found schema migration
changes for `app_zenith` and `org_zenith`, beyond the two setting databases anticipated by the owner
note. Their target migrations were confirmed applied in their development databases, so these two
files were generated from development instead of restoring stale `HEAD` schemas. The two setting
dumps were also generated from development after their specified migration versions were confirmed
applied. The schema dump normalizer found no `CREATE UNLOGGED TABLE` or `CREATE UNLOGGED SEQUENCE`
declarations.

| Structure dump | Before |  After | Source      |
| -------------- | -----: | -----: | ----------- |
| `app_setting`  |     18 |  1,877 | development |
| `app_signal`   |     18 |    200 | `HEAD`      |
| `app_zenith`   |     18 | 10,151 | development |
| `avatar`       |     18 |  4,853 | `HEAD`      |
| `com_setting`  |     18 |  1,890 | `HEAD`      |
| `occurrence`   |     18 |  4,063 | `HEAD`      |
| `org_setting`  |     18 |  1,877 | development |
| `org_signal`   |     18 |    200 | `HEAD`      |
| `org_zenith`   |     18 |  8,242 | development |
| `publishing`   |     18 | 18,403 | `HEAD`      |
| `queue`        |     18 |    992 | `HEAD`      |
| `rp_core_app`  |     18 |    493 | `HEAD`      |
| `rp_core_org`  |     18 |    493 | `HEAD`      |
| `rp_edit_org`  |     18 |    493 | `HEAD`      |
| `rp_palm_app`  |     18 |    493 | `HEAD`      |
| `rp_tech_org`  |     18 |    493 | `HEAD`      |
| `rp_warp_app`  |     18 |    493 | `HEAD`      |
| `rp_warp_org`  |     18 |    493 | `HEAD`      |
| `search`       |     18 |     76 | `HEAD`      |
| `storage`      |     18 |     76 | `HEAD`      |

All 20 repaired dumps contain public table definitions. The 16 `HEAD`-sourced files were compared
byte-for-byte with `HEAD`; the four generated dumps each contain tables. The development migrations
checked were `20261031220000` (`app_setting`), `20261101025006` (`org_setting`), `20261031220002`
(`app_zenith`) and `20261031220003` (`org_zenith`); all were applied in their respective development
databases. The dump truncation writer remains unknown; prior investigation is in
`evidence/2026-10-31-wux-structure-dumps-R7T3.md`.

## Focused tests after repair

Each Rails test command below ran with `RAILS_ENV=test PARALLEL_WORKERS=1`; each passed through the
repaired `db:test:prepare` task. Existing `nanoid` future-frozen-string warnings appeared in the
Rails test runs.

- Unit 1: the 26 persistence model paths listed in the initial verification section of
  `evidence/2026-11-03-op-mediated-step-up-unit-1-2-9K4M.md`; 54 runs, 172 assertions, 0 failures, 0
  errors, 0 skips.
- Unit 2: `test/jobs/step_up_audit_delivery_job_test.rb`,
  `test/models/client_step_up_audit_outbox_test.rb`,
  `test/models/client_step_up_audit_outbox_attempt_test.rb`,
  `test/policies/chronicle_record_policy_test.rb`; 39 runs, 156 assertions, 0 failures, 0 errors, 0
  skips.
- Unit 3: `test/services/oidc/token_exchange_service_test.rb`,
  `test/resolvers/oidc_authorize_request_resolver_test.rb`,
  `test/controllers/auth/step_up_admission_test.rb`,
  `test/operations/oidc_step_up_authorization_issuer_test.rb`,
  `test/operations/oidc_step_up_authorization_completion_committer_test.rb`,
  `test/operations/oidc_step_up_authorization_cancellation_committer_test.rb`; 131 runs, 691
  assertions, 0 failures, 11 errors, 0 skips. Reported errors include
  `BaseAuthAdmissionCoordinator::Denied: step-up requirement binding missing`. No test or
  implementation changes were made to address these errors.
- Unit 4: `test/operations/rp_step_up_start_issuer_test.rb`,
  `test/operations/rp_step_up_callback_dispatcher_test.rb`,
  `test/operations/rp_step_up_callback_concurrency_test.rb`,
  `test/operations/rp_step_up_dispatch_recovery_test.rb`,
  `test/resolvers/step_up_evidence_resolver_test.rb`,
  `test/controllers/base/edge_v0_token_refresh_binding_test.rb`,
  `test/adapters/step_up_pkce_verifier_cipher_adapter_test.rb`, `test/values/oidc_pkce_test.rb`,
  `test/adapters/oidc_op_protocol_verifiers_test.rb`, `test/adapters/oidc_op_token_client_test.rb`,
  `test/services/oidc_client_assertion_jwt_test.rb`; 90 runs, 445 assertions, 0 failures, 0 errors,
  0 skips.
- Unit 5 Rails: `test/integration/step_up_required_response_shape_test.rb`; 6 runs, 43 assertions, 0
  failures, 0 errors, 0 skips.
- Unit 5 Vitest: `gait/lib/step_up_challenge.test.ts`, `gait/controllers/passkey_ceremony.test.ts`,
  `gait/entrypoints/inertia.test.ts`,
  `gait/features/auth/verification/passkey_verification_interaction.test.tsx`,
  `gait/features/auth/passkeys/passkey_panels.test.tsx`,
  `gait/features/auth/signup/signup_passkey_registration.test.tsx`; 6 files, 102 tests passed.

The Unit 5 production build, typecheck and i18n scans were not rerun in this database-repair step.
No Unit 6 reconciliation or Unit 7 design proposal work was started.
