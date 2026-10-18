# Sign-In State Machine Phase 4 Session Issuer

Phase 4 adds `SignIn::SessionIssuer` as the DB transaction boundary for active session issuance.

The service is intentionally controller-free. Controllers will write cookies and headers only after
this service returns successfully in the later surface wiring phase.

Current behavior:

- accepts only cycles at `SESSION_ISSUANCE_PENDING`;
- requires the cycle to be bound to the actor by `principal_id`;
- rejects replay when `token_id` is already present;
- creates the active token, rotates the refresh token, binds `cycle.token_id`, and advances to
  `CHECKPOINT_PENDING` in one transaction on the cycle/token database;
- leaves token step-up fields blank, so fresh sign-in remains AAL1 and does not satisfy withdrawal
  AAL2.

Controller integration remains in the later controller wiring phase.
