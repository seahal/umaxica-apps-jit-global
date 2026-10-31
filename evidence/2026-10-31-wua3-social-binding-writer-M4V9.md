# Social admission binding writer read

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting this check.

The social admission check in `AuthCeremonyContext` read a security-relevant binding using the request's current database role. It is used by both social start and callback. The lookup now uses the binding's existing OP writer connection, matching the adjacent admission intent lookup. No storage shape or status semantics were changed.

A new non-transactional APP test confirms that a freshly committed admission can start social sign-in; it passed both before and after the change, so it does not demonstrate a replica-lag failure or a real provider callback. `PARALLEL_WORKERS=1 bin/rails test test/integration/sign_in_otp_resend_committed_http_test.rb test/integration/admission_curfew_test.rb` passed: 13 runs, 101 assertions. Scoped RuboCop passed.

A broader run including `test/controllers/auth/app/social/ceremony_entry_test.rb` had 18 runs, 101 assertions and 5 errors. All five test IDs occur in `plans/2026-10-28-baseline-failing-tests.md`; their setup failed while parsing the admission relay page. Actual provider callbacks, an independent lagging replica with a changed binding, and full-suite behavior were not verified.
