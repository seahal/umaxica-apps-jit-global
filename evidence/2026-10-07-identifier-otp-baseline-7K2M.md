# Identifier and OTP baseline

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
The worktree was clean when the checks ran. No application or schema changes preceded them.

Command: `bin/rails test test/models/concerns/otp_lockable_test.rb`.
Result: exit 1 before test execution because Rails reported 14 pending migrations.
The pending migrations target APP/COM principal signup and credential-registration OTP contexts,
and APP/COM ticket authentication OTP-context validation and proof preservation. No test case
passed or failed; this is a baseline database-preparation failure, not a regression from this task.
No migration or database reset was performed during this check.

Inspection confirmed that both identifier concerns include `OtpLockable`; its time-window anchor
falls back to `created_at` when `otp_last_sent_at` is absent. Identifier rows still own HOTP secret,
counter and expiry. `IdentifierBlindIndex` selects global channel keys without a realm argument.
The encryption provider configures a global current/previous keyring and permits publicly derived
keys in local environments. Existing Email/Telephone ceremony operation contracts permit only
`registration` and `replacement`.

The requested paths `plans/rails-model-gentle-creek.md` and `checklist-4-swift-map.md` were absent.
Current OTP-sharing descriptions remain in the concern tests, OTP audit documentation and state
machine inventory. These observations do not establish implementation or acceptance of the new
contract.
