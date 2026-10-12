# Telephone ceremony references verification

This record is revision-scoped evidence for the Telephone ceremony reference slice. It is not a
permanent acceptance result or an independent review.

## Scope

- Repository: `/home/global/workspace`
- Branch: `feature`
- Tested `HEAD` before the documentation commit: `45ec2d50e9bb02cb7740dc6c01ae01a9f6d7bb0f`
- The worktree contained unrelated staged/unstaged changes from the authorized identifier work; no
  unrelated paths were staged or reset.
- The change covered the concrete Telephone ceremony transaction factory and its typed replay,
  result, finalization and purge consumers. Existing explicit PublicId issuers, OTP generation,
  delivery/proof material, result identities, the legacy value object and production configuration
  were not redesigned in this slice.

## TDD and focused verification

The focused Red run reproduced the former UUID generation and missing generated-collision recovery:

```text
15 runs, 246 assertions, 3 failures, 0 errors, 0 skips
```

The smallest Green implementation makes missing `transaction_id` and `grant_jti` values use the
shared NanoID-21 generator. It retries only a named single-column non-partial unique B-tree
collision inside a savepoint, within the finite collision budget. Explicit values and unrelated
validation or uniqueness failures remain explicit.

The focused Green/refactor run passed:

```text
18 runs, 273 assertions, 0 failures, 0 errors, 0 skips
```

The related Telephone contract, replay-store, coverage, result/finalization, purge, OTP issuer,
delivery and integration collection passed:

```text
199 runs, 2296 assertions, 0 failures, 0 errors, 0 skips
```

Targeted RuboCop passed for the changed concern and transaction tests after alignment-only
autocorrection.

## Gate 2

The run-owned twenty-database Rails suite used the authorized isolated manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, four workers, and the repository's
`bundle exec rails test` command. It passed:

```text
15194 runs, 128472 assertions, 0 failures, 0 errors, 0 skips
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
multi-connection collision behavior, live SMS delivery behavior, OTP proof retirement, realm key
resolution, the legacy value-object contract, host-side Alloy recreation, production deployment
safety, or independent acceptance by another AI. Those remain governed by the applicable acceptance
criteria and later verification gates.
