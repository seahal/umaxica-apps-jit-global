# Palm and Tech JSON CSRF refusals

Recorded 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with uncommitted
application, tests and documentation present.

Added AT-045 JSON sign-entry requests with missing and invalid authenticity tokens on Palm and Tech,
using real Rails forgery protection and same-origin Fetch Metadata. Both refuse before creating a
pending flow. The first run exposed Palm's refusal carrying no-cache instead of no-store: 10 runs,
46 assertions, 1 failure, 0 errors, 0 skips. Palm sign entry now sets its local no-store policy
before early callbacks, preserving the other Palm public cache contracts. No CSRF, refresh or
authentication acceptance was changed.

The two-file rerun passed 10 runs / 50 assertions. The final selection including Palm callback and
sign-out passed 15 runs / 94 assertions / 0 failures / 0 errors / 0 skips:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/tech/org/sign/entries_controller_test.rb test/integration/palm_jump_sign_entry_test.rb test/controllers/palm/app/oidc/callbacks_controller_test.rb test/controllers/palm/app/sign/outs_controller_test.rb
```

RuboCop inspected three changed files without offenses after formatting corrections. Scoped diff
checking passed. Only standard Rails test databases were used. These checks do not establish all
CSRF partitions or external/browser acceptance.
