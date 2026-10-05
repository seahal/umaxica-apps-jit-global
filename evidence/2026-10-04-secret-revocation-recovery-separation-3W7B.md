# Secret revocation immutability and shared Recovery separation

Performed 2026-10-04, recorded 05:25 UTC (Etc/UTC).
Rails feature HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5, 403 dirty paths
at capture, including preserved concurrent work. Results include uncommitted
changes and are not CI results.

## Revocation boundary

A public persistence test reproduced that update_columns could clear a committed
revoked_at without raising. The final fixed Rails writer/persistence guards protect
revoked_at as well as confirmed_at. Ordinary/raw writers, update_column(s) and
touch cannot write a persisted revocation. The dedicated model transition uses a
narrow instance-scoped write interval around its validated save and closes that
interval with ensure after success or failure. Source events and lifecycle still
commit together on Zenith. No raw update, schema, global Rails setting or new
serialized shape was introduced.

The test covers nil and the terminal time one microsecond below/equal/above.
An injected UUID-generation failure reaches actual source-event validation:
credential and source audit roll back, and ordinary writes remain refused after
the exception. Existing raw-writer tests now expect refusal at assignment rather
than delayed save validation; the stored-state assertions remain.

## Recovery separation

RecoveryPasscodeTopUp explicitly refuses ClientSecretCredential instead of returning
an empty successful legacy result. Removed its app capacity, ownership, kind,
status-association and recovery-identity preload branches. Removed the app branches
from SignRecoveryPasscodeRequirement. Existing callers of the minimum Recovery
guard are com/org only; no app minimum or automatic replenishment was added.

Replaced the obsolete app Recovery-kind top-up test cases and their unused copied
helper implementation with public operation tests. Real com credentials retain
the ten-item target, one-use attributes, recoverable hash verification and empty
repeat result. The existing org no-Recovery-kind empty result remains. This does
not establish new app Passkey issuance or plaintext delivery.

## Commands and results

Only guarded codex_integrity_20261004registration_* disposable databases were used,
via `bundle exec ruby /tmp/umaxica-registration-fresh-db-task.rb test <paths>`.

- Revocation Red: 1 test, 1 assertion, 1 failure; update_columns did not refuse.
- One narrow command used an incorrect test filename and could not load it;
  this is command error, not a behavioral Red.
- Initial post-change regression exposed the prior raw-writer expectation;
  moved refusal inside the assertion and preserved database checks.
- Revocation/confirmation/rebuilt-model Green: 26 tests, 388 assertions,
  zero failures/errors/skips.
- Related Secret foundations, operations, real-writer concurrency, queries,
  ownership, method guard and inventory: 112 tests, 1,226 assertions, PASS.
- Recovery Red: app empty-result refusal failed. Initial com setup also used a
  nonexistent fixture name; that setup error is not behavioral Red.
- Real com top-up initially lacked preexisting kind reference rows on the
  schema-only disposable fleet. A guarded temporary runner called existing
  VisitorSecretCredentialKind/Status.ensure_defaults! there. No configuration
  construction test, runtime fallback or production seed behavior was added.
- Recovery Green: 3 tests, 106 assertions, zero failures/errors/skips.
- Final combined suites additionally included app Secret-session Passkey Step-Up,
  com recovery reveal HTTP and org Emergency invariants:
  **135 tests, 1,509 assertions, zero failures/errors/skips**.
- Plain `bundle exec rubocop` on model, rebuilt-model/revocation tests, both
  Recovery services and replacement test: six files, no offenses after local
  guard-clause/blank-line corrections. No suppression or gate change.
- `git diff --check`: PASS before this record.

The app Secret security document describes both changes. The installed Rails
2f75a03b05aff2610b3799ef9ebd87cfc9cf38eb persistence implementation was inspected;
update_columns and touch invoke the fixed verify_readonly_attribute hook.

NOT_RUN: full suite, management HTTP/UI, plaintext delivery, actual Passkey-bound
issuance, signup completion, atomic claim/login receipt, Chronicle delivery,
audited purge and browser Secret secrecy. WithdrawalPersonalDataAnonymizer still
references retired app status fields; removing that reference without truthful
withdrawal audit attribution would not complete its lifecycle. Its integration
remains outstanding. Pending shape approvals and the overall goal remain open.
