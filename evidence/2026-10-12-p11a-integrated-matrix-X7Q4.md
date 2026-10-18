# P11a integrated history and retention matrix recheck

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- Worktree: existing staged, unstaged and untracked changes were preserved; no reset, cleanup,
  commit or push was performed.
- Scope: run-owned PostgreSQL fleet `20261010p8b`, four Rails workers, no production or shared
  database.

## Command

The command used the twenty database names from
`tmp/acceptance-isolated-20261010p8b-primary.json` through the repository's isolated test
configuration:

```text
bundle exec rails test \
  test/models/dead_identifier_history_contract_test.rb \
  test/models/dead_identifier_destroy_test.rb \
  test/operations/dead_identifier_purge_test.rb \
  test/operations/dead_identifier_purge_concurrency_test.rb \
  test/security/invariants/dead_identifier_history_visibility_invariant_test.rb \
  test/jobs/dead_identifier_retention_test.rb \
  test/models/otp_failure_retention_test.rb \
  test/services/realm_identifier_hmac_rotation_test.rb \
  test/services/identifier_hmac_maintenance_boundary_test.rb \
  test/integration/identifier_encryption_rotation_drill_test.rb
```

## Result

`110 runs, 1066 assertions, 0 failures, 0 errors, 0 skips` in 5.977 seconds.

The collection combines the current six-model dead-history/purge checks with OTP failure
retention, realm/channel HMAC rotation and maintenance isolation, and realm encryption rotation.
It is current focused evidence for the executable P11a/P3e boundary. It does not authorize
real-data purge or close every CONTACT-4/5 route, the complete source/fixture inventory,
cross-database transport campaign, whole-owner/legal-retention partition, or the full D-11
committed-transaction matrix.
