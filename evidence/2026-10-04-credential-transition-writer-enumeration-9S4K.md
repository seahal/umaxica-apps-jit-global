# Credential transition writer enumeration

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

`bin/rails test test/services/credential_security_transition_test.rb` passed
**6 runs, 57 assertions, no failures/errors/skips**, seed 6845.
RuboCop inspected the changed test file with no offenses. `git diff --check` passed.

Three new surface-specific tests invoke the production credential transition from a read-only
ticket connection context. SQL notifications observe the connection role used to enumerate and
lock Client, Visitor and Operator token rows. Every observed token SELECT uses the writer.
The current root session remains usable and another session is revoked. Existing pending-ceremony
revocation, freshness clearing, audit and unsupported-reason cases also pass.

The writer hypothesis was disproved: the current principal writer boundary already switches the
applicable shared connection class. No application change was needed. Initial COM/ORG test setup
failed because COM has no `one` fixture and existing ORG sessions exhausted the two-session limit.
The corrected tests use the actual reserved visitor fixture and explicitly revoke existing sessions
through the production API before constructing their two-session scenario.

These tests establish connection-role selection, not physical replication lag behavior. They do
not prove cross-database audit durability, credential-change races, or the pending purpose-scoped
Auth management workflows. Full R01–R16 remains incomplete. OTP logging remediation is excluded
and browser verification is user-owned.
