# ORG administrative canonical negative cases

Commit `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted authentication changes and unrelated parallel work.

Completed migration of `test/integration/org_admin_step_up_ceremony_test.rb` to the canonical DB parent/continuity and opaque result interfaces. The file no longer calls legacy grant/result issuers, the artificial Auth authentication helper or the old completion-form helper. Its existing authorization categories remain represented:

- A correctly finalized different scope still triggers Support-specific step-up.
- An Emergency Base session cannot start administrative step-up, without deleting fixture sessions to establish that condition.
- Another session's or surface's opaque result cannot consume the exact parent stored by the Base browser. Foreign evidence remains verified/unconsumed and neither session receives freshness.
- The legitimate result completes the stored Base transaction, and retry preserves its original authentication event.
- Support confirmation accepts freshness one microsecond before expiry and refuses it exactly at and one microsecond after expiry, without rewriting the event.
- Forged return targets and scope/target mismatches are rejected on both GET and admission POST without creating a transaction.
- The success case continues to exercise a real signed assertion, final protected mutation and audit, followed by refusal after capability revocation.

Synthetic verification evidence is used in transport/scope/time negatives; the success case performs cryptographic verification. Selector initialization precedes evidence establishment. Initial attempts prepared the selector afterwards and correctly lost freshness through selection invalidation; the test setup was corrected rather than changing production invalidation.

Command: `bin/rails test test/integration/org_admin_step_up_ceremony_test.rb`, using owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, one worker and preparation restricted to `codex_integrity_20261003auth6f3_app_ticket`.

Result: 9 runs, 96 assertions, no failures/errors/skips (seed 45470). RuboCop on the integration file passed; `git diff --check` passed. Source search found no remaining legacy grant/result or authentication-helper calls in this file.

The Base token remains a fixture, not a completed root-login journey. Turnstile is stubbed, Jump transport is decoded and browser checks remain user-owned. Other files still need migration, and registration/credential-management/full-plan completion remains unproven. No schema changes, OTP logging remediation or deployment occurred.
