# Dead identifier history slices

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; uncommitted changes affected these checks.

- History contract RED: 2 tests failed because the new models did not exist. Three generated
  forward Principal migrations then created six minimal history tables successfully on test DBs.
- Fingerprint RED after explicit local keys: 27 tests, 1 assertion, 1 failure and 26 errors because
  the primitive did not exist. No test was deleted or skipped.
- `bin/rails test test/models/dead_identifier_history_contract_test.rb test/lib/identifier_history_fingerprint_verifier_test.rb`
  passed 29 tests, 368 assertions with no failures/errors/skips. Costs are pinned to production
  Argon2id m=65536,t=3,p=4, not the Rails test password profile.
- Purger RED after correcting the unavailable Visitor fixture name: 6 tests, 2 failures and
  4 errors from missing purgers. First implementation exposed the actual Zenith connection-owner
  requirement; the semantic Principal subclasses cannot call connected_to.
- `bin/rails test test/operations/dead_identifier_purge_test.rb` passed 8 tests, 51 assertions,
  including active legal holds and rollback of history when protected Source destruction fails.
  The same tests passed unchanged after splitting only the new purge eligibility predicate;
  focused RuboCop on both new purgers passed.
- Retention integration initially could not reach collection because local Secret lifetime ENV
  configuration was missing. Explicit non-secret local configuration resolved that environment
  failure. The behavioral RED then showed Source deletion with zero histories.
- `bin/rails test test/jobs/dead_identifier_retention_test.rb test/operations/dead_identifier_purge_test.rb`
  passed 9 tests, 55 assertions, no failures/errors/skips after history-aware Contact collection.

Operator purge integration, withdrawal anonymization, history visibility/legal deletion procedures,
all-realm purge concurrency and full regression verification remain incomplete. FK ownership is
realm-local; normal updates are rejected and formal deletion remains possible. No production
database, secret or external service was changed.

Expanded `bin/rails test test/operations/dead_identifier_purge_test.rb` passed 10 tests and
65 assertions, no failures/errors/skips. ORG Email and Telephone public purge operations reject
recoverable owners, produce one history after owner retention ends, and permit another owner to
reuse the dead identifier. Whole-Operator collection and the other incomplete items above remain
unverified.

`bin/rails test test/operations/dead_identifier_purge_concurrency_test.rb` passed 6 tests and
24 assertions. Two real database connections purging the same Source produce one history and one
no-op in every realm/channel. Following formatting, the combined terminal-OTP, purge and purge-race
selection passed 18 tests and 95 assertions without failures, errors or skips.

Owner-substitution RED ran 16 tests, 71 assertions and 6 failures: every realm/channel could
attribute the actual Source deletion to a different owner supplied only in memory. Adding argument
partitions produced 18 tests, 83 assertions and 8 failures including unsaved Source no-ops. The
purgers now require persisted/deleted Source input and compare the locked database owner FK before
any history insertion or Source deletion.
`bin/rails test test/operations/dead_identifier_purge_test.rb test/operations/dead_identifier_purge_concurrency_test.rb test/jobs/dead_identifier_retention_test.rb`
passed 25 tests and 123 assertions, no failures/errors/skips. No caller-owned FK can redirect the
dead history to another Identity.
