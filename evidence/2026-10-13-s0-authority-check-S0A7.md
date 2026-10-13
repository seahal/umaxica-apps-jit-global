# S0: IdP authority check

## Scope

- Plan step: S0, IdP authority check (REQ-002, DEC-040).
- Commit under test: `8dd19da294a3474312f4ae3799073120cfe47677`.
- Worktree state: the S0 controller concern and integration test had uncommitted changes that
  affected the result. The worktree was clean at GO; no unrelated changes were present.
- Frozen plan checksums remained `one.md`
  `663bb1a858f537edde4da80e53631a73e08a8022c59123fb2df391601d4cbe4c` and `two.md`
  `7297a6e0eb52fc4df2768c926e084297e654f827c0acd83f0d462c6c8ae4086d`.

## Change

Before revocation, the Authority endpoint now resolves the stored RP session and verifies that the
transaction actor, current Authority resource, token class and Device Session match the captured
parent. A mismatch returns the existing unavailable response without advancing the transaction. GET
confirmation remains read-only. App, Com and Org integration coverage exercises unauthenticated POST
refusal and successful confirmation using the matching current Authority session. App coverage also
verifies refusal for another parent and actor, and that a request-supplied `session_ref` does not
select another parent.

The regression was first run before changing the concern: a challenge-only POST advanced with a 303
and revoked the selected root, failing the expected 422 assertion. After the change, the negative
cases leave the root, RP rows and transaction step unchanged.

## Verification

PostgreSQL tests ran against the owned isolated fleet using
`tmp/acceptance-isolated-20261010p8b-primary.json`, with
`POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b`, `POSTGRESQL_TEST_HOST=primary` and
`POSTGRESQL_DATABASE=postgres`. The manifest scoped preparation to its 20
`codex_integrity_20261010p8b_*` databases; the server reported PostgreSQL 17.7. No development,
production or unknown database was used. The scoped Valkey namespace `s0-authority-20261013-g` was
released; cleanup found zero keys.

Command selector:

```text
test/integration/oidc_rp_authority_first_logout_test.rb
test/security/invariants/lifecycle_direct_state_write_invariant_test.rb
test/security/invariants/csrf_verification_strategy_invariant_test.rb
test/unit/security/standard_csrf_invariant_test.rb
test/unit/security/identity_authority_inversion_guard_test.rb
test/unit/security/forbidden_rails_patterns_test.rb
```

Environment: `RAILS_ENV=test`, `PARALLEL_WORKERS=1`, `POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b`,
`POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json`,
`POSTGRESQL_TEST_HOST=primary`, `POSTGRESQL_DATABASE=postgres`, and the scoped Valkey namespace
`s0-authority-20261013-g` / `parent`.

The test invocation derived `POSTGRESQL_TEST_PREPARE_DATABASES` from the manifest:

```sh
bundle exec ruby -rjson -e 'manifest = JSON.parse(File.read(ENV.fetch("POSTGRESQL_ISOLATED_TEST_MANIFEST"))); ENV["POSTGRESQL_TEST_PREPARE_DATABASES"] = manifest.fetch("databases").map { |entry| entry.fetch("name") }.join(","); exec("bin/rails", "test", *ARGV)' \
  test/integration/oidc_rp_authority_first_logout_test.rb \
  test/security/invariants/lifecycle_direct_state_write_invariant_test.rb \
  test/security/invariants/csrf_verification_strategy_invariant_test.rb \
  test/unit/security/standard_csrf_invariant_test.rb \
  test/unit/security/identity_authority_inversion_guard_test.rb \
  test/unit/security/forbidden_rails_patterns_test.rb
```

Result: 25 runs, 297 assertions, 0 failures, 0 errors, 0 skips; exit status 0. The Valkey run scope
was claimed before the command and released by the exit trap; cleanup deleted zero keys.

`bundle exec rubocop app/controllers/concerns/oidc_rp_logout_authority.rb test/integration/oidc_rp_authority_first_logout_test.rb`
and `git diff --check` passed; RuboCop reported no offenses in two files.

## Not verified

- Browser/manual acceptance remains for the user, per DEC-020.
- The broader AT-002 client, origin, transaction, root family/generation and expiry partitions are
  addressed by later sign-out stages; they are not claimed as verified by S0.
- Full Minitest and Vitest suites are deferred to plan step 19.
