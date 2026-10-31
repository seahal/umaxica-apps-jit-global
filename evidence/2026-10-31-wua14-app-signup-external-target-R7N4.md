# APP Email signup external return target

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the check.
- The historical `signed_return_path_hardening_test.rb` at HEAD tested COM Visitor Email signup and is a tracked deletion in the current worktree. Its reported external URL is therefore not directly executable against the retired COM Auth route.
- Added a current APP Email signup HTTP test with an admitted signup ceremony and the same external `https://evil.example.test/steal` target. The request redirects to the local Email OTP path without carrying a `pt` query value; the focused test passed (1 run, 5 assertions).
- The new case and the existing explicit-consent success case passed together (2 runs, 12 assertions). RuboCop and scoped `git diff --check` passed. This checks the first redirect for one external URL, not every encoding or the entire registration and post-signup handoff. The full-suite record `2026-10-31-two-full-suite-after-corrections-N5R8.md` predates the new test.
