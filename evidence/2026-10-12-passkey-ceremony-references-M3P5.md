# Passkey ceremony references verification

This record is revision-scoped evidence for the Passkey ceremony reference slice. It is not a
permanent acceptance result or an independent review.

## Scope

- Repository: `/home/global/workspace`
- Branch: `feature`
- Tested `HEAD` before the documentation commit: `f1a945c72961b541a97c966dcb0b121287055b16`
- The worktree contained unrelated staged/unstaged changes from the authorized identifier work; no
  unrelated paths were staged or reset.
- The change was limited to the public Passkey ceremony transaction factory and its public model
  contract tests. WebAuthn challenge issuance, relying-party protocol values, credential identity,
  controller routing and production configuration were not redesigned.

## TDD and focused verification

The focused Red run reproduced the former UUID generation and missing generated-collision recovery:

```text
9 runs, 228 assertions, 3 failures, 0 errors, 0 skips
```

The smallest Green implementation makes missing `transaction_id` and `grant_jti` values use the
shared NanoID-21 generator. It retries only a named single-column non-partial unique B-tree
collision inside a savepoint, within the finite collision budget. Explicit values and unrelated
validation or uniqueness failures remain explicit.

The focused Green run passed:

```text
9 runs, 233 assertions, 0 failures, 0 errors, 0 skips
```

The related Passkey collection passed:

```text
65 runs, 644 assertions, 0 failures, 0 errors, 0 skips
```

The command selected the concrete Passkey transaction, replay-store, contract, result-issuer,
final-committer, purger, registration-committer, authorization and numeric-date tests. Targeted
RuboCop passed for the changed concern and test:

```text
2 files inspected, no offenses detected
```

## Gate 2

The run-owned twenty-database Rails suite used the authorized isolated manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, four workers, and the repository's
`bundle exec rails test` command. It passed:

```text
15188 runs, 128470 assertions, 0 failures, 0 errors, 0 skips
```

The Vitest whole suite passed:

```text
99 files passed
1140 tests passed
```

No CI, Podman, production database, shared destructive operation, external provider, or remote
synchronization was used. The Rails run emitted pre-existing warning/debug lines; none produced a
test failure.

## Limits

This evidence does not establish database-level immutability for every identifier, committed
multi-connection collision behavior, live authenticator behavior, host-side Alloy recreation,
production deployment safety, or independent acceptance by another AI. Those remain governed by the
applicable acceptance criteria and later verification gates.
