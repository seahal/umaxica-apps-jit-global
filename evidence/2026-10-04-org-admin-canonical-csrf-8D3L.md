# ORG administrative CSRF with canonical authority

Commit `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted authentication changes and unrelated parallel work.

Migrated `test/integration/org_admin_csrf_test.rb` away from legacy signed grant/result issuers and its test-session header. Base authentication uses the existing host-bound access-token API and selector preparation. Synthetic credential evidence is recorded on the exact DB parent/continuity and finalized by the public Base committer before testing each mutation. This isolates mutation CSRF; the separate administrative ceremony file proves HTTP completion and real signature verification.

Support revocation, IAM grant and enforcement apply retain the Fetch Metadata/Origin/token matrix. Every rejected case now explicitly asserts the 422 CSRF response and no business mutation instead of merely rescuing an exception or observing no write. Cases include hostile cross-site origin, absent Fetch Metadata, mismatched same-origin Origin, Referer without a token, forged token and a raw JSON body without a token. Same-origin requests and absent-metadata requests with a genuine page CSRF token still succeed. Existing forgery-protection toggling is restored in ensure.

Command: `bin/rails test test/integration/org_admin_csrf_test.rb test/integration/org_admin_step_up_ceremony_test.rb`, with owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, one worker and preparation restricted to `codex_integrity_20261003auth6f3_app_ticket`.

Result: 11 runs, 167 assertions, no failures/errors/skips (seed 50320). RuboCop on the changed CSRF file passed; `git diff --check` passed.

While tightening assertions, exception-based expectations exposed a deprecated Rails exception constant and then the actual middleware-rendered 422 behavior. Assertions now use that observed public response; production forgery protection and response contracts were not changed.

Initial Base login remains a fixture. This is not browser or external-provider verification, and not proof of all administrative operations. No schema changes, OTP logging remediation or deployment occurred. Other legacy callers, registration/credential management and whole-plan gates remain unfinished.
