# Auth Step-Up handoff referrer policy

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- The ORG verified-Passkey handoff page initially returned `strict-origin-when-cross-origin` instead of origin-only referrer policy (1 run, 8 assertions, 1 failure). Under that policy a same-origin request may carry the full source URL.
- The Auth Step-Up result handoff now supplies `strict-origin` in the response and HTML metadata before its existing same-origin POST. The ORG Step-Up verification and Auth admission suites passed: 13 runs, 170 assertions, 0 failures, 0 errors, 0 skips. Scoped `git diff --check` passed.
- The successful ORG test exercises the GET, same-origin form POST and subsequent Base result consumption. APP browser handoff and deployed HTTPS behavior were not separately verified in this slice; this is not full WU-A12 acceptance.
- RuboCop subsequently passed on the changed Auth handoff concern (1 file, no offenses).
