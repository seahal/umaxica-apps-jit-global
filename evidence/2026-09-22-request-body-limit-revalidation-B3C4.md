# Request body limit revalidation

- Date: 2026-09-22 UTC
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing user and implementation changes were preserved; this revalidation changed
  no application code, middleware, configuration, schema, or external service.
- External writes: none; no Cloudflare, AWS, provider, production, shared database, or GitHub
  service was contacted.

## Current Rails boundary

`RequestBodySizeLimit` is inserted after `ActionDispatch::RequestId` and before the application
routes. It applies to `application/json` and structured `+json` media types, rejects bodies over
1 MiB before downstream parameter parsing, reads at most one byte beyond the limit when the length
is not usable, rejects malformed/negative declared lengths, and rejects unsupported compressed JSON.
Multipart and other uploads remain outside this JSON-specific boundary.

## Verification

```text
env RAILS_ENV=test UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db PARALLEL_WORKERS=1 bin/rails test test/middleware/request_body_size_limit_test.rb test/integration/core_browser_api_boundary_test.rb
```

Result: `25 runs, 110 assertions, 0 failures, 0 errors, 0 skips`.

The full Rails suite subsequently passed with `11,501 runs, 73,297 assertions, 0 failures, 0
errors, 5 skips`. This evidence proves the Rails JSON origin boundary only; it does not prove
Cloudflare/proxy limits, production ingress behavior, or non-JSON upload limits.
