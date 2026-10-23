# WU-32: ORG normal sign-in durable halt audit

- Date: 2026-10-23. Base commit `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`; change uncommitted.
- Decisions: D-90, D-134. Closes `plans/backlog/org-normal-sign-in-durable-halt-audit.md`.

## Red

Restored the positive audit assertion in
`test/controllers/auth/org/in/passkeys_controller_test.rb` ("normal passkey binding refusal …"):
the stale-generation POST changed the `SIGN_FLOW_HALTED` count by 0 instead of 1 (C6R2 reproduced).

## Change

- `OrgNormalSignInTransaction#record_org_normal_sign_in_halt!` writes one `OperatorChronicle` row
  (actor = the Entra-selected Operator, context: transaction public id, halt generation, reason,
  surface, request id; no binding, token or contact value) before the session is marked halted.
  `ActiveRecord::RecordNotUnique` means "already recorded"; any other failure propagates.
- Chronicle migrations: CHECK `chk_operator_chronicles_sign_flow_halted_keys` (event 18 requires
  both keys), partial unique index `uniq_operator_chronicles_sign_flow_halted`, and the missing
  fixed reference row `operator_chronicle_events.id = 18` (a migration-built database lacked it, so
  every halt write would have failed validation). `db/chronicle_structure.sql` updated by hand with
  only these objects (a full dump also reformatted unrelated CHECKs under the local PostgreSQL 18).
  The separate chronicle migration role of `adr/chronicle-tamper-resistance.md` does not exist yet;
  the migration ran under the ordinary role.
- Test fixture `operator_chronicle_events.yml` gains id 18.

## Green

- ORG passkey controller tests: 17 runs, 0 failures; replay writes no second row; 409, HALT and no
  token/challenge preserved (A32-1, A32-2, A32-4).
- `test/models/operator_chronicle_sign_flow_halted_test.rb`: duplicate (same transaction and
  generation) rejected, other generations accepted, missing keys rejected, other events unaffected
  (A32-5 at the database level). 4 runs, 0 failures.
- A32-3 (Chronicle write failure) **Not run**: no real failing-write mechanism without mocking the
  model; the code lets the exception propagate.
- Development and test chronicle databases migrated.
