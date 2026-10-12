# Realm preference public-ID boundary

Date: 2026-10-12

Repository: `/home/global/workspace` (`feature`)

Code revision under test: `84638063af599f681e0190eb3d73435c5675789d` (the worktree was dirty; the
preference models, shared `PublicId` concern and new test were uncommitted during these checks).
Existing unrelated staged, unstaged and untracked changes were preserved.

## Scope

This slice covers only `ClientPreference`, `VisitorPreference` and `OperatorPreference`. They are
realm-local, self-controlled, non-secret management identities. The change reuses the existing
`PublicId` concern, preserves current values and P12a capacity migrations, and does not change
provider IDs, contact identifiers, database primary keys or cross-realm resolution.

## Red and focused checks

Before the production change, a deterministic generated duplicate reached the normal preference
validation boundary and raised `ActiveRecord::RecordInvalid`. After the models used the shared
creation boundary and its generated-value refresh, the focused contract passed:

```text
RAILS_ENV=test PARALLEL_WORKERS=1 ... bundle exec rails test \
  test/models/preference_public_id_collision_test.rb \
  test/models/concerns/public_id_test.rb
9 runs, 30 assertions, 0 failures, 0 errors, 0 skips
```

The contract covers all three realms, normal validation, validation-disabled creation, real
PostgreSQL unique-index collision, caller-supplied collision without regeneration and ordinary
post-creation model mutation rejection.

The related existing preference and capacity suites passed:

```text
... bundle exec rails test \
  test/models/client_preference_test.rb \
  test/models/visitor_preference_test.rb \
  test/models/operator_preference_test.rb \
  test/models/public_id_capacity_contract_test.rb \
  test/models/concerns/public_id_test.rb \
  test/models/preference_public_id_collision_test.rb
90 runs, 260 assertions, 0 failures, 0 errors, 0 skips
```

Targeted style verification passed:

```text
bundle exec rubocop app/models/concerns/public_id.rb \
  app/models/client_preference.rb app/models/visitor_preference.rb \
  app/models/operator_preference.rb test/models/preference_public_id_collision_test.rb
5 files inspected, no offenses detected
```

## Periodic full gate

Using the run-owned twenty-database manifest `tmp/acceptance-isolated-20261010p8b-primary.json`,
Rails ran with four workers:

```text
... bundle exec rails test
15,158 runs, 128,306 assertions, 0 failures, 0 errors, 0 skips
```

The repository JavaScript script then passed:

```text
bun run test
99 test files passed; 1,140 tests passed
```

The Rails run used only the configured run-owned PostgreSQL test databases. No CI, Podman,
production or shared destructive operation was used.

## Limits

This evidence proves the model creation/update behavior only. It does not prove direct-SQL or
database-level immutability for every permanent identifier, complete P12a inventory acceptance, D-11
committed-transaction isolation, Avatar cutover/write barriers, privacy-retention policy or
independent acceptance by another AI. The implementation remains uncommitted in the worktree.
