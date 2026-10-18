# Sign-In State Machine Phase 9 Withdrawal AAL2 Check

Phase 9 verifies that sign-in session issuance remains AAL1 and does not weaken withdrawal.

Decisions:

- Scoped step-up satisfaction now requires exact `last_step_up_scope` equality.
- The legacy generic `"verification"` scope no longer satisfies scoped sensitive actions.
- Verification cookie records are still usable only when no explicit scope is required.
- Withdrawal schedule, recovery, and early termination entry points require recent token-scoped
  `"withdrawal"` step-up.

Coverage added:

- App and com withdrawal scheduling reject fresh AAL1 sessions.
- App and com withdrawal scheduling reject generic `"verification"` and unrelated scopes.
- App and com withdrawal scheduling reject expired `"withdrawal"` step-up.
- App and com recovery and early termination reject missing withdrawal step-up.

Related existing coverage confirms fresh sign-in session issuance leaves `last_step_up_at` and
`last_step_up_scope` unset.
