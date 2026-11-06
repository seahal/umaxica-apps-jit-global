# Post-switch APP Avatar and Step-Up regression recheck

Date: 2026-11-04

Commit: `b30345216886c98af1f04cbd434f067f12decf01`

Worktree: extensively dirty; results apply to this working tree.

Command:

```text
PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/avatar_ownership_transfers_controller_test.rb test/integration/step_up_authentication_test.rb
```

Result: **50 runs, 229 assertions, 3 failures, 0 errors, 0 skips**.

Remaining failures:

- The valid `ADVANCED → NORMAL` Security Mode change returns 422. The RP-local session has no
  `current_session_token`; Q-1 requires a durable owner-side O-10 commit and session-revocation
  boundary.
- Email registration completion returns the interim fail-closed 503 instead of redirecting to
  success.
- Email registration start returns the interim fail-closed 503 instead of the older 401 Step-Up
  response.

The revoked-root refusal case now passes with 422. No assertion was weakened in this run. The two
Email failures are the same O-11 contact-registration gap, not proof that the interim refusal is
unsafe. Q-1 and O-11 remain incomplete; see `zero.md` and
`contracts/contact-registration-rp-migration-proposal.md`.
