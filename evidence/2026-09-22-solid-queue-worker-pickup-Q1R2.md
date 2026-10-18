# Solid Queue test worker pickup

- Date: 2026-09-22 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: dirty; unrelated user and prior-agent changes were preserved.
- Scope: verify one real Solid Queue worker pickup without touching development, production,
  provider, AWS, Cloudflare, or shared external resources.

## Procedure

The test environment used the repository's explicit `.env.devcontainer.example` and the isolated
test queue database. One existing `SignUpExpiryJob` was enqueued with the Solid Queue adapter. The
supervisor was then run in async mode for 12 seconds with recurring scheduling disabled:

```text
env RAILS_ENV=test UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
  POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,\
test_org_ticket_db,test_queue_db \
  bundle exec bin/jobs start --mode=async --skip-recurring
```

The bounded process exited with status 124 because the timeout intentionally stopped it. The
specific queued job was then read from the isolated queue database and reported:

```text
queue_job_present=true
queue_job_finished=true
queue_job_failed=false
```

The one verification job was removed afterward. No application code, queue configuration, recurring
schedule, external service, or non-test database was changed.

## Result and limits

This proves that the configured test Solid Queue supervisor can pick up and finish one existing
application job. It does not prove production worker process topology, recurring scheduler
enqueue, retry/recovery under process failure, or external email/SMS/OIDC provider delivery. Those
remain separate verification items.
