# OP Step-Up continuation: RP test rebaseline

Date: 2026-11-05

Commit: `b30345216886c98af1f04cbd434f067f12decf01`. The worktree was extensively uncommitted; the
test file already had a broad unrelated worktree diff, preserved here.

## Test harness change

`test/integration/app_passkey_secret_session_step_up_test.rb` does not reference global fixtures and
creates its own actors. Its implicit `fixtures :all` caused Rails to toggle foreign-key enforcement
across the configured test databases. Test setup failed before assertions because the existing ORG
Zenith test database contains an orphan `operator_authority_locks.operator_id = 980190963`. I set
`fixture_table_names = []` on this test class to avoid unrelated fixture loading. I did not delete
or modify database records.

## Result

`RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/app_passkey_secret_session_step_up_test.rb`
ran **3 tests / 9 assertions / 3 failures / 0 errors / 0 skips** after fixture isolation. Each test
expected HTTP 200 but received 303 because its browser setup supplies an OP access/refresh cookie
without the RP-local session cookie required by the current Base RP route owner. This file still
needs migration to the current RP-local session and Visa-mediated flow. Its tests do not verify the
present contract yet.

The initial run before fixture isolation failed at setup with the foreign-key error above (0
assertions). No manual database cleanup was performed; only configured test databases were accessed
by the test process.

`ruby -c` passed. Scoped RuboCop reports one pre-existing `Minitest/MultipleAssertions` offense in
the 32-assertion `A29-8` test; this edit only adds the empty fixture-table declaration. Scoped
`git diff --check` passed.

## Remaining implementation gates

The O-9 Visa flow design still needs owner review before connecting its endpoints. Q-1's
preserve-current session transition, contact-registration owner API, and O-10 registration receipts
still require acceptance of their concrete request/persistence shapes. An asynchronous decision
request was sent for those three design gates. These gates are separate from the RP test-fixture
correction.
