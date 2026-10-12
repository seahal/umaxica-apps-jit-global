# OIDC authorization transaction reference evidence

- Date: 2026-10-12
- Repository: `/home/global/workspace`
- Branch: `feature`
- Tested HEAD before this documentation update: `bac1885097f1b6f137f0d30e0cbb7a9c929e5609`
- Worktree: contained earlier implementation changes and the current OIDC implementation/test
  changes as uncommitted work. No unrelated change was reset, stashed, discarded or staged by
  inference.

## Scope

This record covers only the generated `transaction_id` of the concrete APP, COM and ORG OIDC
authorization transaction writers. OIDC state, nonce, PKCE, login challenge, provider/client values
and protocol identifiers remain separate contracts. This record does not establish acceptance for
database-level identifier immutability, external-provider behavior, production deployment or the
independent acceptance investigation.

## Checks performed

1. The focused Red run of `test/models/concerns/oidc_authorization_transactionable_test.rb`
   reproduced the former UUID generation and missing collision retry:
   `13 runs, 189 assertions, 2 failures, 0 errors, 0 skips`.
2. After the smallest implementation change, the focused Green run passed
   `13 runs, 191 assertions, 0 failures, 0 errors, 0 skips`.
3. The related model, coordinator, admission-binding, token-exchange, purge and OIDC integration
   collection (9 explicitly named test files) passed
   `185 runs, 1610 assertions, 0 failures, 0 errors, 0 skips` with the run-owned twenty-database
   manifest `tmp/acceptance-isolated-20261010p8b-primary.json` and four workers.
4. Targeted RuboCop passed for `app/models/concerns/oidc_authorization_transactionable.rb` and
   `test/models/concerns/oidc_authorization_transactionable_test.rb` with no offenses after one
   parameter-alignment correction.
5. The Rails Gate 2 command was the repository's full `bundle exec rails test` under the same
   run-owned test manifest and four workers. It passed
   `15185 runs, 128451 assertions, 0 failures, 0 errors, 0 skips`.
6. The Vitest Gate 2 command `bun run test` passed `99 files` and `1140 tests`.

The Rails run emitted existing OmniAuth and Flipper diagnostic output; it did not produce test
failures. No CI, Podman, production database, external provider, shared destructive operation or
remote synchronization was used. This evidence is a record of the listed revision and execution
environment, not a permanent PASS for later code.
