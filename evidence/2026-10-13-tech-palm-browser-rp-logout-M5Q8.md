# Tech and Palm Browser RP logout follow-up

Recorded 2026-10-13 against full HEAD
`aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`, branch `feature`. The worktree had extensive
uncommitted changes, including unrelated work; those changes were preserved.

The user confirmed one.md's strict Base/Auth CSRF requirement: an unsafe request needs a valid
Rails authenticity token even with same-origin Fetch Metadata. This follow-up keeps Tech's unsafe
sign-out and completion requests behind Origin, Fetch Metadata and Rails token checks, while
letting the logout boundary validate its existing RP credential without first attempting a
capability-gated refresh. This allows logout after `tech.access` is revoked and allows origin
cleanup after authority revocation.

The shared logout transaction now accepts Palm and Tech as Browser RP origins. Palm and Tech
completion URLs use their dedicated `/sign/out/completion` route. The shared confirmation form
posts to the completion route and omits DELETE cancellation for a live logout challenge. The logout
state diagram and transition inventory describe legacy and Browser RP sequences separately.
Existing Base logout tests now preload the associations they inspect under strict loading; the
Palm completion assertion follows its dedicated route.

The final focused test selection passed: 151 runs, 827 assertions, 0 failures, 0 errors and 0
skips. It covered Tech landing, callback, protected access and logout boundaries; Palm callback and
retired native clients; capability revocation; shared logout transactions; the authority-first
logout integration; Base logout controller cases; and Jump receiver isolation. The test command
used `RAILS_ENV=test`, `PARALLEL_WORKERS=1`, and an unset
`POSTGRESQL_ISOLATED_TEST_RUN_ID`, so only the ordinary Rails test databases were used. No database
reset or migration was run. RuboCop passed for 17 touched Ruby files, and `git diff --check` passed.

This verifies the local Tech and Palm logout paths but does not complete one.md Steps 13–15. The
full registered-RP matrix and real browser/manual acceptance remain outstanding, as do the
dependency-gated global logout and BCL removal work.
