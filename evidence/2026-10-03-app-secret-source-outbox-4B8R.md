# app Secret source outbox

Executed on 2026-10-03, 22:21–22:31 UTC, on feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with concurrent uncommitted work.
This record covers the current dirty worktree only.

Added ClientSecretAuditOutbox using the approved Zenith table. Its public recorder
requires an open source transaction, records the verified Client actor independently
of the subject Client, permits canonical unauthenticated attribution, and preserves
actual executor job identity. Actor attribution and historical facts are readonly.
Events and reasons are fixed allowlists; no arbitrary payload is accepted. Count
types are checked before Active Record's integer coercion. Existing actor context
and nullable Chronicle actor conventions were reused.

TDD ran on the task-owned disposable `codex_integrity_20261003secret_*` fleet,
using `bundle exec ruby /tmp/umaxica-secret-db-task.rb test ...` to execute the
repository Rails runner under its existing isolated-database safety guard:

- Initial Red: `test/models/client_secret_audit_outbox_test.rb`, four missing-class
  errors after selected Client fixtures and database preparation succeeded.
- Initial implementation exposed a missing attribute translation during validation.
  Added explicit attribute labels to all four existing locale bundles, preserving
  their closed-set policy and concurrent content.
- A public count-boundary test reproduced acceptance of a string count through
  Rails coercion. The recorder now rejects strings, collections, and fractional
  values before assignment. Counts -1 and 21 fail validation; 0, 20, and absence
  are accepted. An intermediate nil assertion style failure was corrected and is
  not counted as a behavioral Red.
- A context test reproduced loss of attribution when a Client subject was labeled
  anonymous. The recorder now rejects that inconsistent context. The existing
  unauthenticated subject is a module singleton; the first identity guard used
  the wrong Ruby type test and broke anonymous cases. It was corrected to compare
  the existing canonical instance without weakening the guard.
- Final command selected `test/models/client_secret_audit_outbox_test.rb`,
  `test/models/client_secret_issuance_test.rb`, and
  `test/values/client_secret_issuance_count_value_test.rb`: PASS, **22 tests,
  135 assertions, no failures, errors, or skips**.

The database tests verify verified-actor versus subject-owner attribution,
autonomous execution identity, unknown fact rejection, count/type boundaries,
inconsistent actor rejection, and both an issuance row and its outbox row rolling
back together in an actual Zenith transaction. A separate nontransactional test
rejects writes outside the source transaction. There are no private-method calls,
success mocks, skipped assertions, or changes to test_helper.rb.

`bundle exec rubocop app/models/client_secret_audit_outbox.rb
test/models/client_secret_audit_outbox_test.rb`: PASS, two files with no offenses.
`git diff --check`: PASS.

This completes the source recorder primitive, not the audit workflow. Issuance and
credential operation callers, Chronicle delivery/deduplication, periodic scanning,
purge ordering, and browser-visible Secret functionality remain incomplete.
No additional migration, shared-database application, external delivery, or
deployment was performed in this slice.
