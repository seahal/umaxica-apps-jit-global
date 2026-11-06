# O-10 RP-local passkey removal verification

Date: 2026-11-04

Commit: `b30345216886c98af1f04cbd434f067f12decf01`

Worktree: extensively dirty before and during this verification; results apply to the listed scoped
changes and this exact worktree state, not to a clean checkout.

## Changes

- APP and ORG RP-local passkey removal now resolves its root token from verified Step-Up event
  `sid`, then rechecks the live event and management policy under actor/passkey locks.
- The writer rejects enclosing OP or Zenith transactions, holds OP authority locks through the
  Zenith outbox receipt and credential deletion commit, and resolves a lost Zenith COMMIT
  acknowledgement only by a matching durable receipt plus passkey absence.
- A preflight `CredentialSecurityTransition` invalidates Step-Up freshness and unfinished admissions
  while retaining the current root. These invalidations are not atomic with the later deletion and
  remain if deletion is refused or fails; this fail-closed over-invalidation is recorded in
  `six.md`.
- Updated the lock-order inventory and removed stale O-10 IAM “not connected” statements. The IAM
  endpoint is active; full acceptance remains open.

## Verification

- `bin/rails test test/integration/base_passkey_mutation_step_up_test.rb test/operations/passkey_mutation_concurrency_test.rb test/operations/identity_credential_removal_committer_test.rb test/operations/passkey_removal_authorization_test.rb test/resolvers/step_up_evidence_verifier_test.rb`
  — **34 runs, 342 assertions, 0 failures, 0 errors, 0 skips**.
- `bin/rails test test/operations/org_iam_owner_mutation_test.rb test/operations/org_iam_principal_commit_test.rb test/integration/base_org_iam_owner_api_test.rb test/operations/org_iam_audited_commit_test.rb test/operations/org_iam_operation_outcome_constraints_test.rb test/concurrency/org_iam_capability_revocation_race_test.rb test/concurrency/org_iam_principal_commit_race_test.rb test/concurrency/org_iam_target_eligibility_race_test.rb`
  — **9 runs, 101 assertions, 0 failures, 0 errors, 0 skips**.
- Scoped RuboCop on the passkey removal committer, IAM owner mutation, Step-Up verifier, and three
  directly edited test files — **6 files, no offenses**.
- `git diff --check` on the scoped implementation, tests, lock inventory, IAM design, `zero.md` and
  `six.md` — passed.

O-9 remains disconnected pending design review. Q-1, contact-registration migration, the complete
reverse-lock inventory and remaining O-10 writers remain open. No preference schema, route, cookie
or JWT shape changed in this work.
