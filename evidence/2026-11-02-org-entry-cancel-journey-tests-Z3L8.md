# ORG entry cancellation HTTP journeys with CSRF protection

- Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The shared worktree has extensive pre-existing
  uncommitted changes. This slice adds only
  `test/integration/org_entry_cancellation_journey_test.rb` and this evidence record. No
  application, frontend, route, configuration, existing test helper or database schema code was
  changed.
- Two individually named cases cover Auth ORG `/sign/in?ri=jp` and
  `/sign/in/emergency/passkey/new?ri=jp`.
- Each starts with the real Base ORG neutral entry and follows existing admission transport using
  `OidcAuthAdmissionTestHelper`. It reads the rendered page's own cancellation action, enables
  forgery protection and verifies a POST without the CSRF token returns 422 without changing the
  Auth ceremony or parent authorization. It then submits the current document's valid token and
  verifies cancellation of both records and removal of usable Auth SID state.
- The journey then visits Visa ORG, submits its cancellation continuation with its own CSRF token,
  verifies the callback targets Base ORG with `access_denied` and no authorization code, and follows
  through to Base ORG `/sign/interruption` with HTTP 200 and no further redirect. It also verifies
  no Operator token was created. Cancellation behavior is not mocked.
- Initial run: 2 failures at an overly strict test expectation that a deleted cookie would be nil;
  the test cookie jar returns an empty string. Corrected the assertion to require blank/unusable SID
  state, without changing application behavior.
- Focused new file: 2 runs, 54 assertions, 0 failures, 0 errors, 0 skips.
- Final regression command:
  `bin/rails test test/integration/org_entry_cancellation_journey_test.rb test/integration/sign_entry_exit_org_flow_test.rb test/integration/rp_sign_interruption_test.rb`:
  **10 runs, 280 assertions, 0 failures, 0 errors, 0 skips**.
- `bin/rubocop test/integration/org_entry_cancellation_journey_test.rb`: 1 file, no offenses. Scoped
  `git diff --check`: passed.
- Verification uses public HTTP endpoints and real database-backed state under the existing test
  harness. No new live-browser/mobile run, repository-wide test run or deployment was performed.
  Existing UI tests and other worktree changes were left intact.
