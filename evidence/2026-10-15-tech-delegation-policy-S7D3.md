# Tech capability delegation coverage

Recorded on 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with
uncommitted tests and documentation in the worktree.

REQ-053's delegation acceptance specifically names tech.access. Existing policy coverage used
support capabilities. Added a public policy sequence proving an IAM read/grant holder without Tech
access cannot delegate it, the same actor with a current Tech grant can delegate to another
operator, self-grant is refused, and revoking the actor's Tech grant refuses delegation again. The
existing policy already satisfied the new cases; no authorization condition was changed.

Executed:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/policies/operator_capability_policies_test.rb test/models/operator_capability_grant_test.rb
bin/rubocop test/policies/operator_capability_policies_test.rb
git diff --check -- test/policies/operator_capability_policies_test.rb
```

Results: 26 runs, 101 assertions, 0 failures, 0 errors, 0 skips; one RuboCop file without offenses;
clean scoped diff check. Only normal Rails test databases were used. This verifies the policy and
model selection, not a live IAM HTTP grant, audit delivery or production bootstrap.
