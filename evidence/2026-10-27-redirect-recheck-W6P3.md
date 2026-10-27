# Redirect failure recheck

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; the worktree contained uncommitted cycle changes.
- The full-suite run `bin/rails test` reported 18,445 runs, 156,070 assertions, 166 failures and 246 errors, 0 skips. Its temporary log was inspected for redirect failures.
- WU-02 moves the OP to Visa; several tests still assert the Base host before opening an OP authorization form. Their subsequent requests and Origin headers also use the Base host, so changing only the host assertion would not repair the browser flow.
- For `test/integration/org_social_login_blocked_test.rb`, following the Visa confirmation redirect with `Sec-Fetch-Mode: navigate` and `Sec-Fetch-Dest: document` returned 400. `PARALLEL_WORKERS=1 bin/rails test test/integration/org_social_login_blocked_test.rb` with that exploratory change: 5 runs, 10 assertions, 1 failure, 0 errors. The old setup directly confirms a binding and does not establish the Visa browser state needed for the later confirmation. The exploratory edit was removed; the original assertion remains.
- The step-up completion retries redirect to `/sign` with 302, whereas their expected 303 is followed by checks of the completion target and unchanged freshness. A status-only change would not preserve those checks; the cause is not established.
- No redirect behavior or expectation was changed in this investigation. Further repairs and verification remain outstanding.
