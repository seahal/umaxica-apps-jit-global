# Step-up refusal without session-backed flash

HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, 2026-10-04 UTC; authentication edits and unrelated concurrent work were uncommitted.

A new assertion in the real ORG Normal login/Passkey/step-up journey reproduced a session-backed alert after Base redirected the birthdate read to verification (1 test, 32 assertions, 1 failure, seed 39493). Removed the explicit flash write from the shared guard and the forwarded alert shortcut from its unavailable-method HTML redirect. Feedback remains the existing verification page or inline JSON/plain error. Updated the guard comment to describe redirect/status behavior without flash.

Using owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, preparation limited to `codex_integrity_20261003auth6f3_app_ticket`, and one worker:

- ORG root/step-up journey, ORG administrative ceremony and APP/COM Base contact registration: 40 tests, 291 assertions, green, seed 21435.
- Extended the COM revoked-history mutation case to cover HTML refusal as well as JSON: no email write, 303 to Base verification, no flash. Selected case: 1 test, 15 assertions, green, seed 29024.
- RuboCop on changed guard files and integration tests: no offenses.
- `git diff --check`: passed.

The extended COM case was added after the 40-test run; production code was unchanged between those checks. This verifies two affected refusal paths, not every feedback path. Browser execution was not performed. OTP logging remediation remains excluded. Credential management/removal and legacy retirement remain open.
