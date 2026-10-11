# Merging origin/feature into feature, and verifying it

## Scope

Merged `origin/feature` (366423f4d) into the local `feature` branch (7554692da) on 2026-09-05 and
established whether the merge introduced any test regression. Both branches had diverged from
`3bdc6bd0a`: local `feature` carried two coverage commits, `origin/feature` carried five.

## Where the merge was performed

Not in `/home/global/workspace`. `.github`, `.devcontainer` and `bin` are read-only bind mounts
there, and the merge updates `.github/workflows/ci.yml` and `.devcontainer/compose.override.yml`:

```text
error: unable to unlink old '.devcontainer/compose.override.yml': Read-only file system
error: unable to unlink old '.github/workflows/ci.yml': Read-only file system
Merge with strategy ort failed.
```

The merge was done in a linked worktree at `/home/global/merge-check` instead. Before that, 249
untracked files in the main worktree were verified byte-identical to their `origin/feature` blobs
and stashed as `stash@{0}`, so nothing local was discarded.

## Conflicts

50 files conflicted. 32 were the same conflict: both branches had independently built rate-limit
store isolation for tests, naming the opt-in helper `counts_rate_limits!` (ours) and
`rate_limit_counters!` (theirs).

| Area                                              | Resolution | Reason                                                                                                                                                                         |
| ------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Test cache-store indirection                      | theirs     | `TestSupport::SwappableCacheStore` is a superset (`backend`, `with`, `reset!`). `RateLimitStoreOverride` deleted as superseded.                                                |
| `config/environments/{development,production}.rb` | ours       | Keeps `valkey_store_error_handler`. The auto-merged rate-limit store config references it, so theirs raises `NameError` at boot.                                               |
| `config/environments/test.rb`                     | theirs     | Follows the adopted `TestSupport::` namespace.                                                                                                                                 |
| `OidcClientAssertionJwt` replay check             | ours       | Theirs kept an injectable `replay_store` documented as "Tests may inject a deterministic store" — test-only behaviour in application code. Its one dependent test was aligned. |
| `IdentityOneTimeReveal` cache accessor            | theirs     | Superseded by the PostgreSQL-backed `SecurityOneTimeReveal`; the accessor was dead code after the merge.                                                                       |
| `docs/*`                                          | ours       | Theirs still described a Memorize store, Redis-backed sessions and a CI Valkey service, all of which are gone.                                                                 |

## Three defects the merge introduced without conflicting

Git merged both sides cleanly in each case, so none appeared in `git diff --diff-filter=U`:

- `SecurityConsumedJti::PURPOSES` gained a duplicate `:oidc_client_assertion` key, because each
  branch added it at a different position. Ruby warned and silently overwrote.
- `test/test_helper.rb` kept `require_relative "support/rate_limit_store_override"` for the file
  deleted during resolution, which aborted the whole suite with `LoadError`.
- `SolidInfrastructureTest` asserted `{ database: { writing: :queue, reading: :queue_replica } }`,
  but `origin/feature` had removed the `queue_replica` connection from `config/database.yml`
  entirely. Confirmed intentional; Solid Queue is writer-only.

Commits: `aef364cd4` (merge), `d17d2911a` (the three fixes).

## Result

Full Minitest suite, merged tree, `RAILS_ENV=test bin/rails test`:

```text
12359 runs, 70157 assertions, 8 failures, 182 errors, 1 skips
```

Same command on a clean `origin/feature` worktree (`/home/global/base-check`, 366423f4d):

```text
12348 runs, 70090 assertions, 10 failures, 182 errors, 1 skips
```

Comparing the two runs' failing test names as sets:

- merge-introduced failures: none. The merged run's failing set is a strict subset of the
  baseline's.
- fixed by the merge:
  `HostAuthorizationContractTest#test_development_accepts_published_site_hosts_from_public_url_env_and_nothing_else`
  and `#test_effective_development_middleware_accepts_private_origins_and_rejects_an_unknown_host`,
  which pass because the resolution kept our `DEVELOPMENT_BOOT_ENV` constant.

`pnpm test` on the merged tree: 84 files, 1020 tests, all passing.

RuboCop over the 45 conflict-resolved files reported 4 offenses; all 4 are present at the same lines
on `origin/feature`, so the resolutions added none. `git diff --check` was clean.

## The 190 pre-existing non-passing cases

181 of the 182 errors are `PG::UndefinedTable` for the twelve-family publishing tables
(`publishing_docs_app_vocabularies`, `publishing_docs_app_entries`, and so on). No migration or
structure dump creates them anywhere on `origin/feature`:

```bash
git grep -l 'publishing_docs_app_vocabularies' origin/feature -- db/   # no match
grep -c 'CREATE TABLE' db/publishing_structure.sql                     # 0
```

Only the ADR, the models and the tests reference those tables. The remaining error is
`NameError: uninitialized constant Publishing::PromoteRevisionOperation::IDEMPOTENCY_INDEX`, also
reproduced on the baseline. The 8 failures are the publishing schema guards, the flat-source-layout
invariant and one health-snapshot title contract — all reproduced on the baseline.

This was not investigated further: it is incomplete work on `origin/feature`, not a merge outcome.

## Not verified

The merge has not been applied to `/home/global/workspace`, because the read-only mounts above still
block it there. It exists only as commits reachable from `/home/global/merge-check`.

## Note on shared state

The test PostgreSQL server is shared with the main workspace. `db:prepare` and `db:migrate` in the
merge worktree created `security_one_time_reveals` in `test_app_tickets_db`. The change is additive;
no destructive operation was run.
