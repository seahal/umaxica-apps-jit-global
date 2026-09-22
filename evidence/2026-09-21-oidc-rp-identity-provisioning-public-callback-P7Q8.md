# OIDC RP identity provisioning public-callback regression

- Date: 2026-09-21
- Scope: public OIDC callback actor binding and RP identity provisioning
- Target HEAD at verification: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing uncommitted changes were preserved; no external service was contacted.

## Change

The callback integration test now exercises `OidcCallback#show` with the production
`OidcRpIdentityProvisioning` concern instead of overriding provisioning in the test controller.
It verifies that a verified `client` subject is bound to the matching `Client`, that the identity
record is created with the active state, and that an audience mismatch is rejected before actor
lookup, login, or identity creation.

## Verification

Environment was loaded from `/home/global/workspace/.env.devcontainer.example`; test values and
credentials were not printed.

```text
PARALLEL_WORKERS=1 bin/rails test test/controllers/concerns/oidc/callback_test.rb
19 runs, 90 assertions, 0 failures, 0 errors, 0 skips

After adding the Core bridge assertion, the focused result was:

```text
PARALLEL_WORKERS=1 bin/rails test test/controllers/concerns/oidc/callback_test.rb
19 runs, 92 assertions, 0 failures, 0 errors, 0 skips
```

The final focused result also covered reuse of an existing identity and bridge without creating
duplicates:

```text
PARALLEL_WORKERS=1 bin/rails test test/controllers/concerns/oidc/callback_test.rb
20 runs, 102 assertions, 0 failures, 0 errors, 0 skips
```

bundle exec rubocop test/controllers/concerns/oidc/callback_test.rb --format simple
1 file inspected, no offenses detected

bin/rails test
11486 runs, 73379 assertions, 0 failures, 0 errors, 6 skips
```

The six skipped tests are existing repository skips. No test was deleted, skipped, weakened, or
replaced with a mock to obtain these results.
