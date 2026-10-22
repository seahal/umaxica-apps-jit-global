# Org consolidation security hold verification

Revision: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`, feature branch. Worktree had
uncommitted in-scope service/test/docs/spec changes affecting these results; two pre-existing ADR
edits were preserved. No implementation commit was created. Date: 2026-10-20 UTC.

## Environment

Ruby 4.0.7; Bundler 4.0.23; bundle check succeeded. primary resolves to 10.89.0.3 and PostgreSQL
18.6 accepts connections. Rails test boot and encrypted test credentials worked. Read-only Rails
migration-context inspection found no pending migrations in all 32 configured test writers.

Initial unmodified invitation suite could not start: the inherited POSTGRESQL_TEST_PREPARE_DATABASES
included unverified test_app_ticket_db, test_com_ticket_db, test_org_ticket_db. Subsequent test
commands used PARALLEL_WORKERS=1 and this command-local verified writer list (no repository setup
files were changed):

```sh
export POSTGRESQL_TEST_PREPARE_DATABASES=test_app_setting_db,test_app_signal_db,test_app_zenith_db,test_avatar_db,test_chronicle_db,test_com_setting_db,test_com_signal_db,test_com_zenith_db,test_occurrence_db,test_op_base_app_db,test_op_base_com_db,test_op_base_org_db,test_org_setting_db,test_org_signal_db,test_org_zenith_db,test_primary_db,test_publishing_db,test_queue_db,test_rp_base_app_db,test_rp_base_com_db,test_rp_base_org_db,test_rp_core_app_db,test_rp_core_com_db,test_rp_core_org_db,test_rp_edit_org_db,test_rp_palm_app_db,test_rp_tech_org_db,test_rp_warp_app_db,test_rp_warp_com_db,test_rp_warp_org_db,test_search_db,test_storage_db
export PARALLEL_WORKERS=1
```

## Red / Green

- Baseline bin/rails test test/services/org/operator_lifecycle/invitation_acceptance_test.rb:
  9 runs, 76 assertions, zero failures/errors/skips after the environment correction.
- New invitation/issuance/controller tests against original implementation: 34 runs, 143 assertions,
  8 failures, zero errors/skips. Failures included successful unwanted Operator provisioning and
  successful legacy invitation issuance. Initial test-authoring errors (missing Bureau title and
  unsupported microsecond duration helper) were corrected before this Red observation.
- JOIN refusal test against original implementation: 5 runs, 15 assertions, 1 failure, zero errors/skips.
- Final serial focused command:

```sh
bin/rails test test/services/org/operator_lifecycle test/services/org/invitation_service_test.rb test/operations/org/operator_lifecycle/invitation_issuer_test.rb test/controllers/auth/org/up/invitations_controller_test.rb test/models/organization_invitation_test.rb
```

72 runs, 308 assertions, zero failures/errors/skips. Covers preserved lifecycle actions, refusal
before registration, repeated acceptance, coincident Bureau ID, existing email, missing/unknown
codes, consumed codes, and expiry one microsecond below/at/above the deadline. GET/POST behavior
and Turnstile rejection are covered. The former provisioning/compensation success contract was
intentionally replaced by refusal tests; low-level invitation consumption tests remain.

One intermediate rerun overlapped the baseline root-login diagnostic against the same test DBs
and deadlocked during fixture/setup (72 runs, 307 assertions, 1 error). This was execution interference,
not counted as a pass. The final serial run above passed after both processes ended.

## Broader regression

```sh
bin/rails test test/models/agent_bureau_model_layer_test.rb test/policies/organization_policy_test.rb test/policies/organization_membership_policy_test.rb test/controllers/base/org/selector_controller_test.rb test/controllers/base/org/switcher_controller_test.rb test/services/acme_selector_surface_config_test.rb test/services/acme/selector_bootstrap_authority_test.rb test/services/base_switcher_authority_test.rb test/controllers/auth/org/sign_ins_controller_test.rb test/controllers/auth/org/sign_outs_controller_test.rb test/controllers/auth/org/sign_ups_controller_test.rb test/integration/org_root_login_establishment_test.rb test/security/invariants/lifecycle_direct_state_write_invariant_test.rb test/security/invariants/csrf_verification_strategy_invariant_test.rb test/unit/security/standard_csrf_invariant_test.rb test/unit/security/identity_authority_inversion_guard_test.rb
```

77 runs, 512 assertions, 1 failure, zero errors/skips. Failing test:
OrgRootLoginEstablishmentTest, Entra and Passkey establish Normal root credentials only on Base,
line 225: repeated submission expected 303, got 400 invalid authorization request. Reproduced
independently on the unchanged HEAD in /tmp/umaxica-org-baseline: 1 run, 30 assertions, same failure.
The diagnostic checkout used symlinks to existing vendor/toolchain/test credentials, without changing
the original worktree. No claim that this authentication regression is fixed.

## Other checks

- RAILS_ENV=test bin/rails zeitwerk:check: All is good.
- RAILS_ENV=test bin/rails routes -g invitation: org invitation GET new and POST create still resolve
  to Auth::Org::Sign::Up::InvitationsController.
- RAILS_ENV=test bin/rails db:verify_no_schema_drift: no drift in 32 schema dumps.
- RAILS_ENV=test bundle exec database_consistency: failed, many FK/validator/dependent findings,
  including OperatorWorkspaceAccount retention graph and formal authority associations. Unchanged
  HEAD also reports many failures. Outputs differ; no identical-baseline or zero-new-findings claim.
- bundle exec rubocop on the four changed app/services files and six changed test files:
  10 files, no offenses after scoped formatting corrections.
- ruby scripts/check_frozen_string_literal_directives.rb: frozen_string_directive_check_ok=7525.
- scripts/check-repository-knowledge (referenced by config/ci.rb): could not execute; file missing.
- git diff --check: passed.
- Full bin/ci, full Rails suite, JS suite, browser test and Mermaid parser: not run. No frontend or
  schema change; full release readiness is not established.

Read-only development table counts, actual FK observations, migration provenance, Edge snapshot
and old-reference search limits are recorded in the linked inventory. No production queries,
backfill, DROP, schema edits, retention changes, deployment or external writes were performed.

[Inventory](../specs/org-organization-consolidation/inventory.md) ·
[Open spec](../specs/org-organization-consolidation/spec.md)
