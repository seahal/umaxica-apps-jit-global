# Rails test after authenticated-sign-in guard alignment

- Command: `bin/rails test`
- Result: 12874 runs, 75181 assertions, 0 failures, 0 errors, 2 skips.
- Prior failing run on the same worktree: 23 failures, 12 errors. Failures were guard placement, rate-limit ordering, stale overwrite-oriented tests, `/x` health regexes, and a few unrelated coverage harnesses.
