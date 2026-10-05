# Credential revocation/finalization race

Commit `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted authentication changes and unrelated parallel work.

Added APP/COM/ORG independent-writer races between Base finalization and credential revocation followed by the existing CredentialSecurityTransition public API. The revocation branch holds the actor and credential locks while changing the existing status and invalidating authority. Each case verifies distinct PostgreSQL backend IDs, a revoked credential, cleared token freshness, resolver refusal and rejection of result reuse. The retained current root session remains usable under the explicit revocation flags. Retained revoked credentials also prevent bootstrap eligibility.

Both legitimate outcomes are accepted: if finalization wins, the consumed parent/completed continuity remain historical records and subsequent revocation clears their authority; if revocation wins, the parent and continuity become revoked and finalization is refused. The races do not force both orders in every run. Synthetic verification evidence isolates this concurrency boundary rather than proving signatures or assurance levels.

Command: `bin/rails test test/models/auth_ceremony_revocation_concurrency_test.rb test/services/credential_security_transition_test.rb`, with owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, one worker and preparation restricted to `codex_integrity_20261003auth6f3_app_ticket`.

Result: 42 runs, 361 assertions, no failures/errors/skips (seed 56804). RuboCop on the changed concurrency file passed; `git diff --check` passed.

This verifies the explicit status-change/transition sequence. It does not demonstrate that every settings controller invokes that sequence. Existing physical Passkey deletion still needs atomic inventory protection, retained deletion history and admitted management context. No production or schema changes, browser checks, OTP logging remediation or deployment occurred in this slice.
