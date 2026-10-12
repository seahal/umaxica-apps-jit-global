# P11a dead identifier history matrix recheck

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- Worktree: 214 changed paths were preserved; no reset, cleanup, commit or push was performed.
- Scope: run-owned PostgreSQL fleet `20261010p8b`, four Rails workers, no production or shared database.

## Command

```text
bundle exec rails test \
  test/jobs/dead_identifier_retention_test.rb \
  test/lib/identifier_history_fingerprint_verifier_test.rb \
  test/models/dead_identifier_destroy_test.rb \
  test/models/dead_identifier_history_contract_test.rb \
  test/operations/dead_identifier_purge_concurrency_test.rb \
  test/operations/dead_identifier_purge_test.rb \
  test/security/invariants/dead_identifier_history_visibility_invariant_test.rb
```

## Result

`96 runs, 776 assertions, 0 failures, 0 errors, 0 skips` in 6.710 seconds.

The collection exercised history schema and visibility contracts, fingerprint verification,
retention behavior, destroy/purge boundaries and the available concurrent purge cases. This is
current focused evidence for the P11a history boundary; it does not authorize real-data purge or
close every cross-database fault, whole-owner/legal-retention and six-model create/purge partition
that remains explicit in CONTACT-6/7/9.
