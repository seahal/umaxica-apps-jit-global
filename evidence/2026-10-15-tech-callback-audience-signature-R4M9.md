# Tech callback audience and signature acceptance

Recorded 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with uncommitted
callback tests and documentation in the worktree.

Added AT-048 callback partitions: a valid operator signature with the Edit audience, and a
one-byte-modified signature on the valid Tech ID Token. Both are refused with 422 before issuing
authentication cookies or a Tech identity binding. Existing parent and candidate RP rows remain
usable. The production codec signs the audience variant; the real callback verifier validates both
variants. Existing explicit token transport doubles remain in use.

The callback file passed 9 runs / 128 assertions / 0 failures / 0 errors / 0 skips. Targeted RuboCop
inspected one file without offenses and scoped diff checking passed. The broader command below
passed 23 runs / 203 assertions / 0 failures / 0 errors / 0 skips:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/tech/org/oidc/callbacks_controller_test.rb test/controllers/tech/org/sign/entries_controller_test.rb test/controllers/tech/org/dashboards_controller_test.rb test/controllers/tech/org/sign/outs_controller_test.rb test/services/oidc/tech_operator_capability_exchange_test.rb
```

Only ordinary Rails test databases were used. These results establish the named local protocol
partitions, not all acceptance requirements or live external-provider/browser behavior.
