# Tech callback state and issuer isolation

Recorded on 2026-10-15 UTC against commit `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`, with extensive
existing uncommitted work.

Added missing AT-048/AT-049 boundary coverage to the existing Tech callback integration class. An
unknown state returns 422 before token exchange, issues no authentication cookies, and leaves the
legitimate pending flow available; that flow then completes successfully. A foreign response issuer
with the correct state returns 422/no-store before token exchange, issues no authentication cookies
or Tech identity binding, and preserves the existing parent and candidate RP row.

Executed:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/tech/org/oidc/callbacks_controller_test.rb
bin/rubocop test/controllers/tech/org/oidc/callbacks_controller_test.rb
git diff --check -- test/controllers/tech/org/oidc/callbacks_controller_test.rb
```

Results: 6 runs, 88 assertions, 0 failures, 0 errors, 0 skips; one file without RuboCop offenses;
clean scoped diff check. Only the normal Rails test databases were used. The existing token and
UserInfo transport doubles remain; the code, claims and session rows are issued through production
owners. Existing behavior passed the added cases without a production-code correction.
External-provider/manual acceptance and other plan requirements remain unverified.
