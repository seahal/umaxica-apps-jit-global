# Credential transition revocation flags

Commit `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted authentication changes and unrelated parallel work.

The existing CredentialSecurityTransition implementation revoked noncurrent sessions even when `revoke_other_sessions` was false. It also incremented the revoked-session count outside the conditional write. This contradicted the existing independent flags and could prevent a caller from invalidating step-up authority while preserving root sessions.

Added the four boolean combinations for APP, COM and ORG using real actor-specific tokens and public transition calls. Six tests reproduced the noncurrent-session violation. The implementation now selects the current/other flag according to exact session identity, skips targets not selected, and counts only performed revocations. The existing freshness and pending-ceremony invalidation path remains in place.

All Rails runs used owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, one worker, and preparation restricted to `codex_integrity_20261003auth6f3_app_ticket`.

- Before correction: `bin/rails test test/services/credential_security_transition_test.rb`, 18 runs, 99 assertions, six failures (seed 50485).
- After correction: that file plus `test/models/auth_ceremony_revocation_concurrency_test.rb`, 30 runs, 262 assertions, no failures/errors/skips (seed 35940).
- RuboCop on the changed service and test: no offenses. `git diff --check` passed.

Passkey removal inspection also confirmed that existing controllers still check the inventory and physically delete outside an actor lock. Atomic last-method protection, retained deletion history and admitted credential-management entry remain unfinished; this flag correction does not claim to solve those paths. No browser verification, schema changes, OTP logging remediation or deployment occurred.
