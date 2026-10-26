# WU-24h Base Social result ownership

Revision: `ba570a0007b1d40eabe32990a34831317fd98a93`.
Observed 2026-10-24 with uncommitted H8P2 and this implementation/test/documentation change in the
worktree. No migration, deployment, production mutation or external provider request was performed.

## Observed defect and change

The legacy Social final committer validated signed result/candidate/session agreement but selected
the Flow by `actor_ref` alone. Four Google/Apple cases with a valid signature and a foreign or
missing Admission owner failed to raise: **6 runs, 76 assertions, 4 failures, 0 errors/skips**.
The matching-owner controls succeeded. These were meaningful Red cases before the repair.

The committer now reads the OP writer and resolves only a Flow whose required
`auth_admission_binding_id` matches the signed session reference's redeemed, non-retired sign-up
Binding. It checks before principal creation or fresh result/candidate consumption and applies the
same check when reading a committed signup receipt. The Base receiver scopes its completion-ref
read and write queries to its independently validated Binding as well.

An existing signup test fixture now sets its signed session reference from the Flow's actual
Binding instead of an unrelated generated string. Assertions and link/login test behavior were
preserved. No test helper was introduced and `test/test_helper.rb` was not changed.

## Verification

- Added public-interface cases for Google and Apple with matching, foreign and missing ownership,
  including already committed foreign/missing-owner history. Matching results commit once and
  allow the receipt read. Refused fresh results leave Flow, Bindings, principals, identities and
  result/candidate consumption unchanged. Refused historical receipts preserve registered
  identities and the already consumed facts; no Root token is issued.
- Base HTTP cases first prove an independent browser/Admission binding valid, then use a real
  encrypted Rails nonce cookie and the receiver's GET form and CSRF token. Fresh and historical
  foreign-Flow results are refused with 422, no redirect and no-store, without changing the source
  Flow, principal/identity counts, Root count or candidate consumption. These are current legacy
  receiver responses, not certification of WU-07's future common responder.
- Final focused command:

  ```sh
  bin/rails test test/services/identity/social_signup_admission_ownership_test.rb test/services/identity/social_ceremony_acme_transaction_test.rb test/integration/social_completion_cross_host_csrf_test.rb test/integration/social_completion_signup_handoff_test.rb test/integration/acme_social_link_completion_test.rb test/unit/security/identity_authority_inversion_guard_test.rb test/security/invariants/sign_up_admission_owner_write_invariant_test.rb
  ```

  Result: **45 runs, 501 assertions, 0 failures, 0 errors, 0 skips**.
- Broadened the H8P2 Flow-related command with the new ownership test, Base Social HTTP tests,
  `social_auth_app_flow_contract_test.rb` and the identity-authority guard. Result:
  **642 runs, 6191 assertions, 4 failures, 0 errors, 0 skips**. Failure identities:
  - Google signup entry creates one client and one active social identity without email.
  - Apple signup entry creates one client and one active social identity without email.
  - Google sign-in reuses an existing social identity and refreshes credentials.
  - Apple sign-in reuses an existing social identity and refreshes credentials.

  All four identities are already in the cycle baseline. The current signup failures occur at the
  Auth callback's expected guard redirect, before Base Social completion. The sign-in failures are
  RP callback credential-presence assertions. They remain unwaived and need requirement-level
  reconciliation; matching identities do not prove unchanged causes or G-1 closure.
- Four changed/new Ruby files passed RuboCop. Scoped `git diff --check` passed. No test process
  remained running at the checkpoint.
- Next-unit intake also ran `checkpoint_passkeys_controller_test.rb`,
  `sign_up_secret_lock_order_test.rb` and `sign_up_cleanup_principal_lock_test.rb` together:
  **20 runs, 401 assertions, 0 failures, 0 errors, 0 skips**. These existing cases do not exercise
  the required simultaneous HTTP save/termination race; this result does not close A35-2.

## Limits and next work

This closes the explicit Base Social FK-agreement follow-up listed by H8P2. It does not unify
Social Finalization, remove the legacy receiver, implement curfew enforcement or complete Sign In
First. Those remain WU-05/WU-06 work. WU-24e's actual Passkey-save/termination HTTP race, the global
schema gate recorded in H8P2, and the complete 44-unit acceptance audit remain open.
