# Sign-In State Machine Phase 10 Documentation And Cleanup

Phase 10 aligns stable docs with the implemented sign-in state-machine behavior.

Current behavior:

- stable sign-in docs describe the explicit DB-backed cycle states from primary through return;
- no current app/model/service/doc implementation uses `POST_LOGIN_PENDING` as an active sign-in
  cycle state;
- `SessionLimitGate` is documented only as compatibility fallback, while
  `SignIn::SessionLimitManager` is the cycle-backed session-limit authority;
- session-limit hard reject is documented as `403 Forbidden`;
- withdrawal docs state that schedule, recovery, and early termination require recent exact-scope
  `withdrawal` AAL2 step-up;
- AAL docs state that scoped sensitive actions require exact token `last_step_up_scope` equality.

The legacy gate and pending-login session keys remain in code until every sign-in entry route is
fully wired through DB-backed cycle locators. They should not be used as the long-term authority for
new sign-in behavior.

Cleanup performed:

- Added a code comment to `SessionLimitGate` marking it as a legacy compatibility gate.
- Linked this implementation note from the active sign-in state-machine plan.
