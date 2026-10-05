# Selected context step-up invalidation

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and concurrent unrelated work; no commit or deployment.
- Database: owned isolated run `20261003auth6f3`, manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, preparation limited to `codex_integrity_20261003auth6f3_app_ticket`, one worker. No schema change or rebuild in this slice.

The new real selector test first reproduced the missing invalidation: the APP transaction remained
pending after selection. Selection persistence now invalidates prior authority under the same
token writer lock/transaction when the selected tuple changes. Repeated selection retains the
authentication timestamp; invalid candidates retain state. Explicit clearing revokes authority and
clears only the concrete token's supported selection columns. COM has no Avatar selection column.

`bin/rails test test/services/selected_context_step_up_boundary_test.rb test/models/concerns/selected_actor_context_test.rb test/services/acme/selector_authority_test.rb test/models/concerns/token_status_management_test.rb test/services/credential_security_transition_test.rb test/integration/totp_registration_boundary_test.rb`
passed: **41 runs, 366 assertions, no failures/errors/skips**, seed 34814.

Coverage uses real APP/COM/ORG tokens, legitimate selector bootstrap/candidates, pending ceremony
and Auth continuity invalidation, identical selection preservation, invalid switch refusal, and
selection clearing. A COM switch between two authorized organizations invalidates stored verified
evidence without issuing a new root session. That test records evidence through the public model
API; it is a lifecycle test, not cryptographic assertion evidence. The previous reflection-based
fake selection test was replaced with public real-model behavior.

RuboCop passed on the seven changed selector/token/test files after formatting corrections;
`git diff --check` passed. An intermediate test setup omitted the existing Company's required
title; correcting that fixture input preserved the production validation.

Independent-connection completion/switch races, database fault injection and browser switching
remain unverified. The full authentication ledger is not complete. OTP logging remediation remains
excluded and browser verification remains user-owned.
