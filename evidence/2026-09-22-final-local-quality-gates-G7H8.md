# Final local quality-gate revalidation

- Date: 2026-09-22 UTC
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: existing implementation, documentation, test, and evidence changes were preserved.
- External writes: none; no GitHub, AWS, Cloudflare, provider, production, shared database,
  email, or SMS service was contacted or modified.
- Coverage: intentionally not used as a release gate for this task; thresholds and exclusions
  were not changed.

## Results

With `UMAXICA_ENV_FILE` set to `.env.devcontainer.example` and the isolated test database list
configured, the final Rails suite passed:

```text
bin/rails test
11530 runs, 73419 assertions, 0 failures, 0 errors, 8 skips
```

The corrected cross-realm OIDC logout test was included in that run. The earlier false failure was
caused by searching complete HTML for a short value that occurred inside a random CSP nonce; the
test now inspects the public Inertia props JSON.

Additional checks:

```text
bin/rails zeitwerk:check
Hold on, I am eager loading the application.
Otherwise, all is good!

bin/brakeman --no-pager
Errors: 0
Security Warnings: 0

bundle exec rubocop <changed Ruby files>
7 files inspected, no offenses detected

git diff --check
passed
```

Zeitwerk emitted only the existing advisory that the `rails_db` gem directory is not in the
application eager-load paths; no application autoload error was reported.

The JavaScript quality gates also passed:

```text
bun run test
Test Files  85 passed (85)
Tests       1065 passed (1065)

bun run check
format, lint, typecheck, dead-code, and OpenAPI lint/verification passed
```

The check reported four existing Knip configuration hints but exited successfully. Generated
OpenAPI bundles were unchanged.
