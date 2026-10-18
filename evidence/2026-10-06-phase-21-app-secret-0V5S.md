# Phase 21 app Secret evidence

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`
- Date: 2026-10-06 UTC
- Worktree: dirty with generated schema dumps, Phase 24 edits, documentation/harness changes and
  unrelated concurrent edits preserved.

The targeted App Secret controller, integration, job, model, operation and query run completed with
`257 runs, 4,579 assertions, 0 failures, 0 errors, 0 skips`.

Using Argon2id operational parameters (`t_cost=3`, `m_cost=16`, `p_cost=4`), the isolated load
measurement observed:

| Case | Result | Elapsed |
| --- | --- | ---: |
| unknown identity | no-match | 0.7 ms |
| zero candidates | no-match | 0.5 ms |
| one candidate | no-match | 48.5 ms |
| twenty candidates | no-match | 813.9 ms |
| malformed input | no-match | 0.0 ms |

The fresh-process four-thread twenty-candidate run completed all four checks in about 5.48 s wall
time; individual elapsed times were approximately 2.06 s, 2.06 s, 5.24 s and 5.48 s. Memory was
observed at `VmHWM=501812 kB`, `VmRSS=366644 kB`. These are local measurements, not a production
capacity guarantee.
