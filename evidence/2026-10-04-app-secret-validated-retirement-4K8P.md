# app Secret validated retirement

Executed on 2026-10-04 UTC; observation at 01:44 UTC. Rails feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with 248 dirty paths before
this record and concurrent agent changes. Only the guarded disposable
`codex_integrity_20261003secret_*` fleet was used.

Replaced the draft conditional update_all with a dedicated model transition.
The management operation retains session, owner, scoped Step-Up and writer-clock
checks. Client and credential locks preserve the established order; source events
and save! share the Zenith transaction. Invalid existing name, password digest or
lookup digest cannot bypass model validation and cannot leave either audit event
or retirement committed. Ticket is read/locked only.

Ordinary persisted revoked_at assignment remains refused. A raw attribute save
cannot introduce revocation without its matching source event pair. An existing
revocation cannot be cleared or moved, including the neighboring PostgreSQL
microsecond timestamps. This source-record check is a persistence prerequisite,
not a replacement for the operation's authentication and Step-Up checks.

Actual commands and outcomes:

- Initial reproduction using `bundle exec ruby /tmp/umaxica-secret-db-task.rb test
  test/operations/client_secret_revocation_committer_test.rb`: 11 tests,
  163 assertions, one failure: invalid persisted metadata did not prevent the
  old transition. No errors or skips; this is behavior Red.
- First validated save exposed a missing strict lookup_digest attribute
  translation. Added that explicit label to the four existing locale bundles;
  no fallback or additional bundle was introduced. The focused two-file run
  passed 18 tests and 211 assertions.
- An additional terminal-timestamp test initially used Float microsecond
  arithmetic, which could collapse at timestamp precision. Replaced it with
  exact Rational microsecond neighbors; the contract and rejection expectations
  remain unchanged. That intermediate failed run is not claimed as product Red.
- Final regression command used the same wrapper with retirement/name operations,
  source outbox and credential models, capacity/lookup queries, ownership and
  AuthMethodGuard policies, common-identity inventory and inventory-owner tests:
  **70 tests, 534 assertions, no failures/errors/skips**.
- `bundle exec rubocop app/models/client_secret_credential.rb
  app/operations/client_secret_revocation_committer.rb
  test/operations/client_secret_revocation_committer_test.rb
  test/models/client_secret_credential_rebuild_test.rb`: PASS, four files,
  no offenses. No exclusion, suppression or threshold change was added.
- `git diff --check`: PASS before this record.

No new schema or serialized shape was introduced. HTTP management, issuance,
Secret login, canonical success-receipt writing, Chronicle delivery and audited
physical purge remain incomplete. The generic app Secret purge path must be
replaced before activating retirement over HTTP. No real browser, full suite,
shared database, production, external send or deployment was exercised here.
