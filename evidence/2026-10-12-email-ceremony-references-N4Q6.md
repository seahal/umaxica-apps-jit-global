# Email ceremony references verification

This record is revision-scoped evidence for the Email ceremony reference slice. It is not a
permanent acceptance result or an independent review.

## Scope

- Repository: `/home/global/workspace`
- Branch: `feature`
- Tested `HEAD` before the documentation commit: `4adfc2e341c7cfb492e2d045dca620c8947a193f`
- The worktree contained unrelated staged/unstaged changes from the authorized identifier work; no
  unrelated paths were staged or reset.
- The change covered the concrete Email ceremony transaction factory and its public Email
  Verification Protocol challenge caller. Telephone, OTP proof retirement, key resolution, DB
  immutability and other unclassified ceremony issuers were not changed in this slice.

## TDD and focused verification

The focused Red run reproduced the former UUID generation and missing generated-collision recovery:

```text
12 runs, 237 assertions, 3 failures, 0 errors, 0 skips
```

The smallest Green implementation makes missing `transaction_id` and `grant_jti` values use the
shared NanoID-21 generator. It retries only a named single-column non-partial unique B-tree
collision inside a savepoint, within the finite collision budget. Explicit values and unrelated
validation or uniqueness failures remain explicit.

The focused Green/refactor run passed:

```text
36 runs, 351 assertions, 0 failures, 0 errors, 0 skips
```

The related Email factory, EVP challenge, contract, replay, finalization, result, purge, delivery
and integration collection passed:

```text
149 runs, 1453 assertions, 0 failures, 0 errors, 0 skips
```

Targeted RuboCop passed for the changed concern and transaction tests after alignment-only
autocorrection.

## Gate 2

The run-owned twenty-database Rails suite used the authorized isolated manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, four workers, and the repository's
`bundle exec rails test` command. It passed:

```text
15191 runs, 128471 assertions, 0 failures, 0 errors, 0 skips
```

The Vitest whole suite passed:

```text
99 files passed
1140 tests passed
```

No CI, Podman, production database, shared destructive operation, external provider, or remote
synchronization was used. The Rails run emitted existing OAuth/OmniAuth rejection and framework
warning/debug lines; none produced a test failure.

## Limits

This evidence does not establish database-level immutability for every identifier, committed
multi-connection collision behavior, live delivery behavior, OTP proof retirement, Telephone factory
behavior, host-side Alloy recreation, production deployment safety, or independent acceptance by
another AI. Those remain governed by the applicable acceptance criteria and later verification
gates.
