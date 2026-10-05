# Secret logical discard cannot be reversed

Performed 2026-10-04, approximately 06:00–06:03 UTC (Etc/UTC).
Rails feature HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5; 427 dirty paths
at capture, including concurrent work. Results include uncommitted changes.

The public persistence reproduction changed a confirmed fixture Secret's
discard_at to a finite writer timestamp, then restored Infinity through update!.
Before the fix, no exception was raised. Focused Red: one test, one assertion,
one failure; the initial nil-input run also failed, but was not the resurrection
proof used to establish the defect.

ClientSecretCredential now treats an already persisted finite discard_at as an
immutable fact at its ordinary writer and fixed Rails persistence hooks. The
first transition from Infinity remains available to existing cancellation,
expiry and audited revocation operations. Name updates preserve the discard fact.
No columns, API/event shapes, duration defaults or new authorization bypasses
were introduced. The stable Secret reference describes this implemented guard.

Verification used the guarded registration disposable fleet:

- `bundle exec ruby /tmp/umaxica-registration-fresh-db-task.rb test
  test/models/client_secret_credential_rebuild_test.rb
  test/operations/client_secret_manual_issuance_invalidator_test.rb
  test/operations/client_secret_issuance_expiry_invalidator_test.rb
  test/operations/client_secret_revocation_committer_test.rb`:
  34 tests, 527 assertions, zero failures/errors/skips.
- Expanded selection included issuance/outbox/receipt models, capacity/lookup,
  count policy, manual reservation/concurrency, cancellation/expiry, name/revocation
  and storage confirmation/concurrency: 99 tests, 1,275 assertions, zero
  failures/errors/skips across 15 files.
- Cases cover Infinity, nil, finite timestamp minus/equal/plus one microsecond;
  update!, write_attribute, update_column(s), touch and unchanged persistence
  snapshots. A name change on the discarded record does not restore availability.
- `bundle exec rubocop app/models/client_secret_credential.rb
  test/models/client_secret_credential_rebuild_test.rb`: two files, no offenses.
  An initial multiline-array comma offense was corrected without suppression.
- `git diff --check`: PASS.

NOT_RUN: full suite, HTTP/UI retirement, arbitrary bulk SQL protection, claim and
Chronicle/purge integration. This guard does not fix the independently reproduced
generic physical-purge audit bypass. The withdrawal anonymizer also retains an
old app Secret status reference; its replacement requires a coherent withdrawal
authorization/audit lifecycle and is not claimed implemented here.
