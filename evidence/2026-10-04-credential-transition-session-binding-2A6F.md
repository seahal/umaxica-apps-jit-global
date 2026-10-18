# Credential transition session binding

Commit `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted authentication changes and unrelated parallel work.

CredentialSecurityTransition previously accepted a current-session token from another actor or surface, then compared session IDs without requiring the same token model. The public contract now rejects a supplied token unless its actor-specific type and owner match, before any authority or session write. Exact token identity also includes its class. A nil current-session reference remains supported and obeys the independent other-session revocation flag.

Added real-token tests for foreign actor and foreign surface on APP/COM/ORG, plus nil-reference behavior on each surface. No test-only interface or reflective dispatch was added.

All Rails runs used owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, one worker and preparation restricted to `codex_integrity_20261003auth6f3_app_ticket`.

- Before correction: `bin/rails test test/services/credential_security_transition_test.rb`: 27 runs, 141 assertions, six failures (seed 18245).
- After correction, that file plus `test/models/auth_ceremony_revocation_concurrency_test.rb`: 39 runs, 306 assertions, no failures/errors/skips (seed 11019).
- RuboCop on the two changed files completed successfully after guard-clause and layout corrections. `git diff --check` passed.

These are service-boundary and existing concurrency checks, not browser or full-route evidence. Passkey removal, registration completion and other full-plan requirements remain unfinished. No schema changes, OTP logging remediation or deployment occurred.
