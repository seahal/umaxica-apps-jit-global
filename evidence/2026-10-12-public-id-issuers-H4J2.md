# Public identifier issuer and collision evidence

Date: 2026-10-12

Code revision under test: `ad31a5a308b73471224755c303f11766ee712462`. The worktree was dirty
throughout this check (`45` unstaged tracked paths and `1` untracked test file; no staged paths).
The dirty application and test changes were preserved. This is an implementation record, not an
independent acceptance decision.

## Scope

This slice covered the internal opaque identifiers of `LogoutTransaction` and the APP, COM and ORG
`EnforcementCase` models. `LogoutTransaction.issue!` now obtains new values through
`PublicId.generate`, retries only a collision on the named `public_id` unique index within
`PublicId::MAX_COLLISION_RETRIES`, and rejects post-creation public-ID changes through its update
validation. `EnforcementCaseApplicable` uses the same shared issuer in all three realms and rejects
post-creation public-ID changes through the shared model boundary. Existing values, token digests,
policy state and realm-local uniqueness were not rewritten.

## TDD and focused checks

The initial logout format assertion failed with `8 runs, 24 assertions, 1 failure` against the
previous 22-character generator. The issuer change then passed its focused collection with
`24 runs, 101 assertions, 0 failures, 0 errors, 0 skips`. A deterministic public-ID collision
initially failed with `9 runs, 30 assertions, 0 failures, 1 error`; after the finite, named-index
retry was added it passed with `9 runs, 31 assertions, 0 failures, 0 errors, 0 skips`.

The APP/COM/ORG issuer collection first failed because the old enforcement generator emitted a
non-standard length. The corrected issuer and collision-boundary tests passed with
`39 runs, 132 assertions, 0 failures, 0 errors, 0 skips`. The added immutability tests first failed
with `34 runs, 110 assertions, 2 failures`; the shared model update guards then passed with
`40 runs, 135 assertions, 0 failures, 0 errors, 0 skips`.

The focused command used the run-owned twenty-database manifest:

```text
bundle exec rails test test/models/logout_transaction_test.rb test/models/app_enforcement_case_test.rb test/models/enforcement_case_public_id_test.rb test/models/com_enforcement_case_test.rb test/models/org_enforcement_case_test.rb
```

The actual invocation supplied `RAILS_ENV=test`, `PARALLEL_WORKERS=1`,
`POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b`,
`POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json`,
`POSTGRESQL_TEST_HOST=primary`, `POSTGRESQL_DATABASE=postgres`, and the twenty manifest database
names in `POSTGRESQL_TEST_PREPARE_DATABASES`.

## Full and static verification

After the production changes, the same run-owned scope completed:

- `bundle exec rails test` with four workers:
  `15146 runs, 128235 assertions, 0 failures, 0 errors, 0 skips`.
- `bun run test`: `99` files and `1140` tests passed.
- `bin/rubocop`: 5,378 files, no offenses.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: 0 warnings/errors.
- `bin/bundler-audit`: no vulnerabilities.
- `bun run check`: passed, including formatting, lint, typecheck, dead-code and OpenAPI checks.
- `scripts/check-repository-knowledge`: passed.
- `git diff --check` and changed-file Ruby syntax checks: passed.

Rails output contained the repository's expected OmniAuth/Flipper diagnostics; none produced a test
failure. The full Rails and Vitest runs used only disposable run-owned test databases. CI, Podman,
production services, shared destructive operations, and independent acceptance investigation were
not used.

## Limits

This record proves the tested local model/issuer behavior for this dirty worktree only. It does not
prove database-level immutability for every identifier table, complete identifier inventory
acceptance, the D-11 committed-transaction isolation matrix, Avatar/Group operational cutover, host
Alloy recreation/runtime behavior, privacy-retention policy, or the historical HMAC-role rollback
path. Those remain separately tracked holds under `nine.md`.
