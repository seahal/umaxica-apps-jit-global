# WU-11: process-local negative cache for failed self-fetches (D-174)

- Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`. The worktree held extensive uncommitted work by other agents; this change is
  uncommitted (`app/adapters/oidc_op_jwks_client.rb` and one new test file).
- Contract: `two.md` 6.3 row "Window active, `last.ok`, `kid` ∈ `last.kids`" plus D-174.

## Change

- `OidcOpJwksClient::SELF_FETCH_FAILURE_TTL = 30.seconds`. After this process's own fetch for a
  `kid` listed by the coordinator fails, a lookup of that `kid` within `0 <= age < 30 s` answers
  `unavailable("recent_self_fetch_failed")` without fetching (an allowed-stale cached key still
  verifies). A success clears the entry. Entries are keyed by `kid` and reachable only for kids
  in the coordinator's recent successful fetch.

## Executed checks

- Red: `bin/rails test test/adapters/oidc_jwks_self_fetch_negative_cache_test.rb` before the change:
  6 runs, 18 assertions, 1 failure (29.999 s case answered `fetch_failed` after a second fetch).
  The other five cases (first failure, at 30 s, at 30.001 s, another kid, success after the window)
  passed already: they pin the unchanged behavior.
- Green: the new file with `oidc_jwks_concurrent_lookup_test.rb`, `oidc_jwks_refetch_limiter_test.rb`
  and `oidc_op_protocol_verifiers_test.rb`: 27 runs, 176 assertions, 0 failures/errors/skips.
- `bundle exec rubocop` on the adapter and the new test: no offenses after autocorrect (layout).

## Limits

- Per process and per client instance; not shared through Valkey. No full-suite run.
