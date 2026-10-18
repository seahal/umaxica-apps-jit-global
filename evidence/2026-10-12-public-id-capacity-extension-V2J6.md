# Public-ID capacity extension gate

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty and all existing staged, unstaged and untracked paths were
preserved. The final observation contained 166 changed paths. No reset, clean, stash, worktree,
push, production operation, shared-database operation or CI run was performed.

## Red and Green

The P12a capacity contract added four independently reviewed, self-controlled resources that were
still unbounded: `app_zenith.members`, `app_ticket.logout_transactions`, and
`avatar.post_versions` plus `avatar.posts`. The retired `app_zenith.legacy_replaced_clients` table
was deliberately excluded pending consumer and retention review. The pre-migration focused result
was the expected Red:

```text
51 runs, 150 assertions, 4 failures, 0 errors, 0 skips
```

The implementation adds six migrations. Each owning path receives a named
`char_length(public_id) <= 25` check as `NOT VALID`, followed by a separate validation migration.
The app-principal pair runs through `app_zenith` because `db/app_principals_migrate` is one of its
migration paths. Existing string types and issued values remain unchanged.

The migration loader initially rejected a duplicate class name shared with the prior app-ticket
and Avatar capacity slice. The new classes were renamed to unique semantic names before any of the
new checks were applied; the corrected run then passed.

The focused command was the public-ID capacity contract together with the directly affected
Member and LogoutTransaction model suites, using the run-owned 20-database manifest and four
workers:

```text
bundle exec rails test test/models/public_id_capacity_contract_test.rb \
  test/models/member_test.rb test/models/logout_transaction_test.rb \
  test/models/acme_logout_transaction_test.rb
```

Observed result:

```text
69 runs, 233 assertions, 0 failures, 0 errors, 0 skips
```

The app_zenith, app_ticket and avatar migration pairs were each run through validation down,
additive down, additive up and validation up; every command exited zero. The three affected
structure dumps regenerated successfully. A first rehearsal invocation used the nonexistent
`app_principals` database task and was rejected before migration execution; the corrected
`app_zenith` task passed.

## Gate 2

After focused Green and the migration rehearsal, the full Rails suite ran against the same
run-owned manifest with four workers:

```text
bundle exec rails test
15147 runs, 128270 assertions, 0 failures, 0 errors, 0 skips
```

The latest worker receipts all reported completed cleanup:

- `tmp/isolated-20261010p8b-worker-0-20261012-1767767-i5a5gq.json`
- `tmp/isolated-20261010p8b-worker-1-20261012-1767767-aknjjs.json`
- `tmp/isolated-20261010p8b-worker-2-20261012-1767767-25bxui.json`
- `tmp/isolated-20261010p8b-worker-3-20261012-1767767-txy5qj.json`

Vitest passed locally:

```text
bun run test
99 files passed, 1140 tests passed
```

This evidence covers only the disposable schema and the dirty worktree at the recorded HEAD. It
does not validate shared or production rows, authorize a global type narrowing, include the
retired legacy table, close the remaining identifier inventory or staff-event final cutover,
establish D-11 isolation-level coverage, complete P10b/P12b Avatar cutover, verify host Alloy
runtime behavior or decide privacy retention.
