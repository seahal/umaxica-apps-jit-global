# Review of the Codex WU-15/16/22 and Visa changes; WU-38 fail-closed completion

Revision: `bde2346c17e2aa911acc95de1f6035f80498f2da`, with extensive uncommitted work (Codex, earlier agents and this change).

## Performed

- Static check of the seven root-revocation callers against D-173: all pass the mapped cause
  (`revoke_others` x4, `browser_logout`, `administrative`, `risk` x2).
- The owner reset the test databases (`RAILS_ENV=test bin/rails db:reset`). The schema loaded; the
  seed step failed on removed constants. `db/seeds.rb` was corrected: the protocol-epoch block
  (removed by WU-17) was deleted, and `*MfaLevel` references were replaced by the Security Mode
  models (APP sample NORMAL, ORG sample ADVANCED, D-92) with their fixed rows inserted.
  `RAILS_ENV=test bin/rails db:seed` then exited 0.
- Before the reset, 305 key runs gave 295 errors, all `PG::ForeignKeyViolation` on
  `op_app_authority_stop_root_targets` (stale root id 980190963). After the reset the same 17 files:
  305 runs, 2,912 assertions, 1 failure, 1 error, both in the half-written WU-38 tests.
- WU-38 fail-closed (D-177): the stale-hint case was a real defect. After an earlier attempt was
  terminal and cleaned, a new admission was still refused as an ownership mismatch because the
  session hint and `SignUpSessionState.sequence_id` named the old attempt.
  `SignUpCycleLocator#current` now drops a hint for another admission's attempt only when that
  attempt is terminal with completed cleanup; `SignUpFlowEntry#current_sign_up_flow_ticket` drops
  the matching sequence id. Tests adjusted: the re-entry test takes a new Base admission; the deadline
  test travels past the deadline (the curfew refuses with 400, nothing created); the locator
  nonterminal test no longer violates the lifetime CHECK.
- `bin/rails test` on the APP/COM email/telephone up controllers, the locator and the hold refusal:
  204 runs, 1,991 assertions, 0 failures, 0 errors.

## Not performed

Full suite, the Codex broader cause-writer set (5 failures/45 errors recorded by Codex), the
architecture guard (two failures recorded by Codex), `db:verify_no_schema_drift`, and a fix that
stops committed tests from leaving authority-stop rows behind.
