# Social link tests use current Secret data

Performed 2026-10-04, approximately 06:18–06:20 UTC (Etc/UTC).
Rails feature HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5; 437 dirty paths
at capture, including concurrent work. Results include uncommitted changes.

SocialLinkUnlinkTest failed before assertions because its fixture declaration
still required removed client_secret_credential_kinds. Baseline: two tests,
zero assertions, two errors; these obsolete setup failures are not product TDD Red.

The declaration and setup no longer use old kind/status tables or fake password
digests. They construct a current manual issuance and confirmed server-generated
32-character Secret through validated models. The retired ClientAppleIdentity
preparation is replaced with the current ClientExternalIdentity fields used by
the actual endpoint. Legacy test helpers remain unchanged; none was added/copied.

The refusal case no longer physically destroys Secret rows or uses bulk email
updates. It updates existing emails individually with validation, retains the
Secret, and states the existing narrower social-unlink method policy explicitly.
Neither success nor refusal claims/invalidates the Secret. No production policy,
API shape or authorization behavior changed.

Executed on the guarded registration disposable fleet:

- Initial updated HTTP selection: two tests, four assertions, zero failures,
  errors or skips.
- After adding Secret preservation assertions, combined social link/contracts,
  credential, capacity and lookup checks:
  `bundle exec ruby /tmp/umaxica-registration-fresh-db-task.rb test
  test/integration/social_link_unlink_test.rb
  test/integration/social_auth_app_flow_contract_test.rb
  test/models/client_secret_credential_rebuild_test.rb
  test/queries/client_secret_capacity_query_test.rb
  test/queries/client_secret_lookup_query_test.rb`:
  **43 tests, 354 assertions, zero failures/errors/skips**.
- `bundle exec rubocop test/integration/social_link_unlink_test.rb`: one file,
  no offenses. `git diff --check`: PASS.

NOT_RUN: full suite, live provider network, actual Secret issuance/presentation
or canonical login, Chronicle dispatch and purge. The persistence refinements
awaiting explicit approval remain unchanged. This test preparation is not proof
of a completed Secret login system or of overall regression success.
