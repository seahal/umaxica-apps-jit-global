# WU-A2/A3 Step-Up admission repeat boundary

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The shared worktree had 550 changed tracked paths
and 269 untracked paths, with none staged. Existing changes were preserved; no commit was created.

The App and Org public verification entry contract was checked against the accepted same-browser
continuation rule and `two.md` §5.3. Tests now expect a foreign browser using a redeemed admission
to receive 409, while an expired repeat at or after the original 10-second window remains a bad
request. The Org test suite's existing fixture-backed case fails before its body because the shared
fixture set has an `operator_device_sessions.current_refresh_token_id` row without its matching
token; no fixture or application setup was changed to hide that failure. A new fixture-free Org
public HTTP case constructs the Operator and admission directly and verifies the same boundary
through the actual Auth route.

The final focused command was:

`PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/verifications_controller_test.rb:196 test/controllers/auth/org/verification_admission_replay_test.rb`

It passed with 2 runs, 43 assertions, 0 failures, 0 errors and 0 skips. Across APP and ORG, the
checks establish that a repeat by the currently bound browser redirects to the clean verification
URL without issuing another Auth SID or creating another admitted ceremony; a foreign browser gets
409 without an Auth SID; a same-browser repeat at 9 seconds redirects, while repeats at 10 and 11
seconds are refused without changing the admitted session. The Root token's Step-Up evidence stayed
unset.

Scoped RuboCop passed on the two existing verification test files and the new fixture-free Org test
(3 files, no offenses). Ruby syntax checks and scoped `git diff --check` passed. No production code,
database schema, migration, documentation diagram or persistent development data changed in this
slice. The full Rails suite was not run.
