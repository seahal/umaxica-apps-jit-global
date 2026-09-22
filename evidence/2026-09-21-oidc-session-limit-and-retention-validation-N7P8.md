# OIDC session-limit and retention validation

- Date: 2026-09-21
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing and task-local uncommitted changes were present; no commit, push, PR, or GitHub write was performed.

## Environment

Tests ran from `/home/global/workspace` with `UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example` and the four requested PostgreSQL test databases. The Rails test environment reached PostgreSQL `primary` and Valkey `valkey-kvs` through the configured Compose network. Secret values were not printed.

## Verification

- `PARALLEL_WORKERS=1 bin/rails test test/integration/oidc_rp_browser_flow_test.rb test/controllers/auth/app/in/sessions_controller_test.rb`: 44 runs, 237 assertions, 0 failures, 0 errors, 0 skips.
- Related regression set covering OIDC completion, identity revocation, FQDN gating, architecture baseline, and public entrypoint inventory: 72 runs, 4300 assertions, 0 failures, 0 errors, 0 skips.
- `PARALLEL_WORKERS=1 bin/rails test test/jobs/retention_purge_job_test.rb`: 12 runs, 53 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop` on the four changed production/test files: clean.
- `ruby /tmp/umaxica-frozen-plan/validate_plan.rb`: PASS; 70 source rows and 70 frequency rows, with zero mapping, verification, placeholder, or closure errors.
- `bin/rails test`: 11491 runs, 73433 assertions, 0 failures, 0 errors, 5 skips.

The five skips were existing suite skips; no skip was added for this work. Coverage improvement was not evaluated per the task instruction.

## Observed behavior

The session-limit browser flow now exercises the Core RP `/sign` entry, Base authorization, Auth ceremony handoff, Base session-limit resolution, Core callback, RP credential cookies, and Core session probe. It verifies that the resolution path does not create a second root `ClientToken` and that a restricted session can reach the explicitly allowlisted resolution controller.

Retention acceptance was re-baselined against the existing explicit model allowlist, bounded batch processing, database-clock eligibility checks, holds, enforcement blocks, and kill switch. Dry-run, preview, simulation APIs, and dry-run-only schema or audit records are not required and were not added.
