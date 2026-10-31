# WU-7 focused acceptance recheck

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked work affected the result.
- `PARALLEL_WORKERS=1 bin/rails test` ran the selected com JWT, read/write journey, initialization, Web Push and browser contract files with the acceptance-case name filter recorded in `/tmp/wu7-acceptance-selection.log`. The selection passed: 15 runs, 612 assertions, zero failures, errors or skips.
- The selected cases exercise com/app/org issuer rejection and a same-TLD reader, prefetch GET/HEAD without database writes, invalid JWT writes from defaults, reset and binding deletion, duplicate-cookie refusal, issued cookie consistency, and the 400-day JWT boundary. These are request and codec tests, not proof of every possible browser or deployment configuration.
- The full-suite run in `2026-10-30-wu7-full-suite-recheck-W8C4.md` failed and predates the subsequent CSRF test isolation adjustment. Repository-wide schema drift remains unresolved. WU-7 closure is not established.
