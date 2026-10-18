# Logout Dashboard guidance and interrupted full suite

Performed 2026-10-04, approximately 06:08–06:13 UTC (Etc/UTC).
Rails feature HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5; 430 dirty paths
at initial capture and 433 at final capture, including concurrent work.
Results include uncommitted changes and are not CI results.

## Base specification alignment

The full-suite run reproduced old app/org logout expectations: after successful
sign-out and anonymous Home, requesting Dashboard with the revoked session now
returns local /sign guidance instead of the former 404. The specification
explicitly supersedes anonymous HTML Dashboard 404 on all three faces.

The existing app/com/org sign-out tests now require 302 to the same configured
host at /sign?ri=jp and recheck that the original Token remains revoked. Existing
Home rendering/history-clearing assertions remain intact. No logout, Cookie,
session issuance or production controller behavior changed in this slice.
Legacy test helpers were not copied or expanded.

`bundle exec ruby /tmp/umaxica-registration-fresh-db-task.rb test
test/controllers/base/app/sign_outs_controller_test.rb
test/controllers/base/com/sign_outs_controller_test.rb
test/controllers/base/org/sign_outs_controller_test.rb
test/integration/base_dashboard_authentication_guidance_test.rb`:
**35 tests, 311 assertions, zero failures/errors/skips**.

`bundle exec rubocop` on the three changed controller test files: three files,
no offenses. `git diff --check`: PASS.

## Full-suite attempt did not complete

`bundle exec ruby /tmp/umaxica-registration-fresh-db-task.rb test` ran against
the guarded task-owned disposable fleet, with seed 44467. The process stopped
making progress while a client_email_test worker and the main Ruby thread waited
on futexes. The relevant existing email race test contains Queue waits and joins
without deadlines. The log and CPU time remained unchanged across observations.
The exact deadlock cause has not been established.

The task-owned Ruby PID 717994 was interrupted with SIGINT; its tool session
42787 then returned exit 1. Interrupted output summarized **2,440 tests,
21,801 assertions, 38 failures, 37 errors, zero skips**, 230.991116 seconds.
This is a partial failing run, not completion or full-suite acceptance.

The observed failing classes include social Auth app contracts, app/com MFA
challenge paths, invalid-Cookie recovery and org session-limit controllers.
Their existing-versus-new regression attribution remains unverified. Some old
Dashboard expectations were subsequently corrected as described above; that does
not explain or resolve the other failures. The shared tree changed during this
attempt, so it is not evidence for a pristine-HEAD baseline.

NOT_RUN: remaining full-suite tests, repaired email race, browser/logout/Jump
integration, production routing or deployment. No test was skipped, weakened,
or mocked into success. The Secret delivery/claim/Chronicle/purge workstreams and
pending shape decisions remain incomplete.
