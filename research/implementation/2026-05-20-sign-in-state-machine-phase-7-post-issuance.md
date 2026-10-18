# Sign-In State Machine Phase 7 Post-Issuance Participants

Phase 7 adds DB-backed participant services for checkpoint, dashboard, and return handling.

Current behavior:

- `SignIn::CheckpointParticipant` evaluates an ordered stack and advances clear cycles from
  `CHECKPOINT_PENDING` to `DASHBOARD_PENDING`;
- blocking checkpoint items stop without mutating the cycle;
- `SignIn::DashboardParticipant` evaluates display items and advances the sequence dashboard from
  `DASHBOARD_PENDING` to `RETURN_PENDING`;
- `SignIn::ReturnParticipant` consumes only safe same-origin relative return paths, clears
  `cycle.return_to`, and completes the sign-in cycle;
- unsafe return paths fall back to the supplied default destination and are discarded.

This phase does not yet wire the participant services into surface controllers. Ordinary dashboard
access remains separate from the sequence dashboard service until the controller wiring phase.
