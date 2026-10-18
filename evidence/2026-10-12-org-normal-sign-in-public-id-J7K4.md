# ORG normal sign-in transaction identifier evidence

Date: 2026-10-12

Code revision under test: `9443a7367f903f10fce11e3f668c8727e540bccc`. The worktree was dirty
throughout this check (`45` tracked status paths and `1` untracked test file; no staged paths).
Existing application, test and configuration changes were preserved. This is an implementation
record, not an independent acceptance decision.

## Scope

This slice covered the new `OrgNormalSignInTransaction` session `public_id` issued at the ORG
Entra-to-passkey handoff. Repository inspection classified it as a self-controlled opaque
transaction identity carried inside the signed ORG binding. It is separate from the Entra provider
value, OAuth/OIDC state, PKCE material, CSRF token, nonce and any persistent primary key. The
existing session key, signed binding validation and provider authority were left unchanged.

The Red assertion observed the previous 32-character hexadecimal value. The smallest Green change
replaced that issuer with `PublicId.generate`; existing serialized sessions remain readable and only
new issuance changes format.

## TDD and focused verification

The first focused request-boundary assertion failed with:

```text
1 runs, 4 assertions, 1 failure
```

The failure was the expected old 32-character hexadecimal value rather than the required NanoID-21
shape. After the production change, the binding codec and focused ORG passkey collection passed:

```text
bundle exec rails test \
  test/controllers/auth/org/in/passkeys_controller_test.rb \
  test/services/org_normal_sign_in_binding_codec_test.rb

19 runs, 117 assertions, 0 failures, 0 errors, 0 skips
```

The run used the existing run-owned twenty-database manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, `RAILS_ENV=test`, four Rails workers, and the
manifest's isolated PostgreSQL databases. No shared or production database was used.

## Gate 2 and static check

Before another implementation slice was selected, the same complete run-owned writer scope passed:

- `bundle exec rails test`: `15146 runs, 128226 assertions, 0 failures, 0 errors, 0 skips`.
- `bun run test`: `99` files and `1140` tests passed.
- `bundle exec rubocop app/controllers/concerns/org_normal_sign_in_transaction.rb test/controllers/auth/org/in/passkeys_controller_test.rb`:
  no offenses.
- `git diff --check`: passed.

The initial RuboCop run found one formatting offense in the newly added assertion; the blank-line
correction was applied and the targeted check then passed. No migration, raw SQL, CI, Podman,
production operation, shared destructive operation or external-provider verification was used.

## Limits

This record proves only the tested new ORG transaction issuer and its existing binding boundary in
the dirty worktree. It does not prove the complete ceremony-purpose/identifier inventory,
database-level immutability for every identifier, the D-11 committed-transaction isolation matrix,
Avatar/Group operational cutover, retained legacy identifier semantics, host Alloy runtime
recreation, privacy-retention policy or any independent acceptance result. Those remain tracked
under `nine.md`.
