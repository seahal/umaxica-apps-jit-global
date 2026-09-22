# Static and suite revalidation

- Date: 2026-09-22 UTC
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: existing user and implementation changes were preserved. The only changes made in
  this revalidation were four formatting corrections in already-modified test files; no production,
  database, migration, authentication, retention, or external-service behavior was changed.
- External writes: none; no GitHub, AWS, Cloudflare, provider, production, or shared database write
  was performed.

## Verification

Focused Rails tests after the formatting corrections:

```text
env RAILS_ENV=test UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
  POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db \
  PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/concerns/oidc/callback_test.rb \
  test/controllers/palm/app/sign/outs_controller_test.rb \
  test/integration/routes/neutral_rp_entry_contract_test.rb
```

Result: `33 runs, 326 assertions, 0 failures, 0 errors, 0 skips`.

Full Rails suite:

```text
env RAILS_ENV=test UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
  POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_queue_db,test_occurrence_db \
  bin/rails test
```

Result: `11,503 runs, 73,303 assertions, 0 failures, 0 errors, 5 skips`.

Repository-wide static checks:

- `bundle exec rubocop`: `4,754 files inspected, no offenses detected`.
- `bundle exec brakeman -q`: 0 errors and 0 security warnings.
- `ruby /tmp/umaxica-frozen-plan/validate_plan.rb`: `result=PASS`; all mandatory mappings and
  negative verifications were present.
- `git diff --check`: passed.

The five skipped tests were not changed or added by this revalidation. Coverage was not run as a
release gate, per the current task instruction.
