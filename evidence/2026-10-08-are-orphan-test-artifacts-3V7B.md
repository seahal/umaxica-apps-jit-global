# Realm encryption verification and orphan test artifacts

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
Uncommitted worktree changes affected verification.

The four-file realm encryption, re-encryption failure, re-encryption service and rotation HTTP
drill selection ran 10 tests/49 assertions, zero assertion failures, two errors, no skips
(seed 50493). Both errors are required Visitor ownership validation while re-encrypting all
persisted identifiers. No unreadable or orphan record was silently skipped.

Read-only `bin/rails runner -e test` inspection found two orphan VisitorEmail rows, IDs 212 and
214, both marked by the synthetic `purge-reuse-` identifier prefix used by this task's race
tests. Neither owner exists. Telephone orphan count is zero; email null-owner count is zero.
These are test-data artifacts, not evidence of a keyring decoding defect. No raw identifier,
key or ciphertext was printed. No row was changed or deleted during diagnosis.

A separate `bin/rails runner -e test` eager-load execution succeeded. All six concrete Contact
models loaded an ActiveRecord::Encryption::KeyProvider under their explicit APP/COM/ORG realm.
This is an executed boot check, not a new configuration-construction test.

The ARE acceptance checkbox remains incomplete. Removing the two orphan rows through ordinary
identifier destruction cannot preserve the owner-bound history invariant because their owners
are absent. No direct-delete bypass or skipped validation was added. Any targeted disposable
test-data repair must explicitly account for this boundary before rerunning the rotation drill.
