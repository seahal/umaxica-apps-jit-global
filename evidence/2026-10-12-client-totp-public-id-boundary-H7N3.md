# APP TOTP credential public-ID boundary

Date: 2026-10-12

Repository: `/home/global/workspace` (`feature`)

Code revision under test: `01b8af8d5566265f848d71db00d3a9574e58b21f` (the worktree was dirty; the
APP TOTP model and new test were uncommitted during these checks). Existing unrelated staged,
unstaged and untracked changes were preserved.

## Scope

This slice covers only the APP `ClientTotpCredential` management `public_id`. It is a realm-local,
self-controlled, non-secret row identity. It is separate from the encrypted TOTP secret, failure
counter, OTP proof, provider/authenticator identifiers and the database primary key.

## Red and focused checks

Before the production change, a deterministic generated duplicate reached normal model validation
and raised `ActiveRecord::RecordInvalid` instead of entering the shared bounded collision path:

```text
3 runs, 8 assertions, 0 failures, 1 error, 0 skips
```

The model then stopped generating its own identifier during initialization and used the existing
`PublicId` creation boundary. The final focused collection passed:

```text
RAILS_ENV=test PARALLEL_WORKERS=1 ... bundle exec rails test \
  test/models/client_totp_credential_public_id_collision_test.rb \
  test/models/client_totp_credential_test.rb \
  test/models/concerns/public_id_test.rb
27 runs, 54 assertions, 0 failures, 0 errors, 0 skips
```

The contract covers normal validation, validation-disabled creation against the real PostgreSQL
unique index, caller-supplied duplicate values without regeneration and ordinary post-creation
mutation rejection. The focused test uses synthetic values only and does not expose a TOTP secret.

Targeted style verification passed:

```text
bundle exec rubocop app/models/client_totp_credential.rb \
  test/models/client_totp_credential_public_id_collision_test.rb
2 files inspected, no offenses detected
```

## Periodic full gate

Using the run-owned twenty-database manifest `tmp/acceptance-isolated-20261010p8b-primary.json`,
Rails ran with four workers:

```text
... bundle exec rails test
15163 runs, 128328 assertions, 0 failures, 0 errors, 0 skips
```

The repository JavaScript script then passed:

```text
bun run test
99 test files passed; 1140 tests passed
```

The Rails run used only the configured run-owned PostgreSQL test databases. No CI, Podman,
production or shared destructive operation was used.

## Limits

This evidence proves the model creation/update boundary only. It does not prove direct-SQL or
database-level immutability for every permanent identifier, complete identifier inventory, D-11
committed-transaction isolation, Avatar cutover/write barriers, privacy-retention policy or
independent acceptance by another AI. The model and test remain uncommitted in the worktree.
