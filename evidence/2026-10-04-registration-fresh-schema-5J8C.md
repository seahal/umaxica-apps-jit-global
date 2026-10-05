# Registration regression on a fresh disposable database fleet

Performed 2026-10-04, completed at 04:20 UTC (Etc/UTC).
Rails `feature`, HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5.
The shared worktree had 378 dirty paths at the preceding capture, including
concurrent work. Results include uncommitted changes, not CI or clean-commit results.

The previous task fleet's registration check differed from current migration and
structure definitions despite recording that migration as applied. This run
created a separate empty fleet rather than rewriting its history, replacing its
constraint or resetting any existing database.

## Construction and inspection

- Copied the existing guarded temporary wrapper to
  `/tmp/umaxica-registration-fresh-db-task.rb`, changing only its isolated run ID
  to `20261004registration`. `bundle exec ruby <wrapper> provision` created twenty
  new `codex_integrity_20261004registration_*` databases and an OID/owner manifest.
  The provisioner refused existing names; no database was dropped or truncated.
- `bundle exec ruby <wrapper> db:schema:load`: PASS. This is construction from
  current structure snapshots, not proof of replaying every historical migration.
- Read-only runner `/tmp/umaxica-registration-db-shape.rb` confirmed the fresh
  app Ticket database's check distinguishes registration evidence from existing
  authenticator Step-Up evidence. Both migration versions are recorded. Ordinary
  Step-Up still requires a nonempty verified credential reference.
- The first regression attempt encountered twelve missing-reference-data errors
  after schema-only construction: 23 tests/76 assertions, zero failures, twelve
  errors. These setup errors are not product Red or behavioral failures.
- A temporary runner prepared fixed defaults for 23 explicitly named reference
  models and the two fixed OperatorPasskeyStatus IDs. Every destination was
  checked against this new fleet prefix. The first runner attempt incorrectly
  called ensure_defaults! on OperatorPasskeyStatus; that model lacks the API.
  Corrected that explicit case to fixed-ID insertion, then preparation completed.
  No Client, credential, token, sample account or external service was seeded.

## Behavioral regression

Command: `bundle exec ruby /tmp/umaxica-registration-fresh-db-task.rb test`
with these files:

- test/operations/app_secret_step_up_binding_test.rb
- test/operations/base_step_up_admission_issuer_test.rb
- test/integration/app_passkey_secret_session_step_up_test.rb
- test/integration/totp_registration_boundary_test.rb

Result: **23 tests, 303 assertions, zero failures/errors/skips**. The previously
failing TOTP registration boundaries pass with current schema and fixed reference
data. Secret-root bootstrap refusal and separately bound Passkey Step-Up remain
covered. Existing synthetic evidence/transport boundaries in those tests are not
real-browser or full cryptographic ceremony proof.

The old `20261003secret` fleet remains untouched and still has its observed schema
mismatch. Fresh construction and this regression do not prove the old fleet can
be repaired safely or that the complete migration history replays successfully.
No production/shared database, deployment, new repository setup test, schema
change or weakened constraint was introduced.
