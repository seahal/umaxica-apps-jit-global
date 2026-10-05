# APP contact history refusal through the Base mutation

HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, 2026-10-04 UTC, with uncommitted authentication changes and unrelated concurrent work present.

Migrated APP email-registration setup from direct AAL2/freshness fields, legacy verification-cookie issuance and a test-session header to actor-owned synthetic Passkey evidence finalized by the public Base operation. The fixture Base login is retained; these tests isolate contact mutations and do not prove cryptographic assurance or independent login.

Added cookie-authenticated mutation coverage with separate browser jars for revoked Passkey, inactive TOTP and revoked TOTP history. Each actor has no configured method, fails the existing bootstrap-history predicate, receives 422 for contact creation, creates neither an email nor a step-up transaction, retains a usable root session and receives no freshness. This extends the actual HTTP evidence for the shared guard correction recorded in `2026-10-04-com-contact-bootstrap-and-expiry-7K2R.md`.

Using owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, preparation restricted to `codex_integrity_20261003auth6f3_app_ticket`, and one worker:

- APP registration file: 17 tests, 77 assertions, green, seed 57714.
- APP/COM registration files plus Base bootstrap issuer: 33 tests, 189 assertions, green, seed 29873.
- RuboCop corrected two formatting issues and reported no remaining offenses.
- `git diff --check`: passed.

No additional production changes were needed after the shared history guard fix. Browser execution and live-provider checks were not performed; OTP logging remediation was untouched. Passkey registration candidates, admitted credential management, atomic last-method removal and full legacy retirement remain open.
