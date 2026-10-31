# Auth phase refusal response boundary

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting these results.

With test schema maintenance disabled, the response-boundary, admitted OTP, and invitation-parent tests passed: 16 runs, 148 assertions, no failures, errors, or skips. The admitted Switch test checks the conflict response, fixed body, no-store, no redirect, and preservation of the existing SID and parent. Boundary tests cover each protected cookie and DBSC header, exact-name filtering, unrelated cookies, Expires commas, HEAD, malformed headers, unmarked responses, and downstream errors.

`bin/rails middleware` placed `AuthPhaseRefusalResponseBoundary` outside `CredentialDeletionFinalizer`, `ActionDispatch::Cookies`, and `ActionDispatch::Session::CookieStore`. This does not establish that every Visa or Auth phase-refusal path marks its response, that all phase checks precede mutation, or that the two-tab delayed-response scenario works in a browser; those remain unverified.
