# SocialAuth link-intent flow issuer evidence

- Date: 2026-10-12
- Code revision under test: `00c0b3671b837c46b91ed33b1557dff827c19496`
- Working tree: 51 pre-existing modified or untracked paths, including earlier implementation work
  and the SocialAuth source/test change. No unrelated path was reset, cleaned or staged.
- Scope: replace only newly issued `SocialAuth` link-intent `social_auth_flow_id` values with
  `PublicId.generate`. Existing session keys, TTL, provider binding, callback state, authorization,
  cleanup and protocol-specific state/nonce issuers remain unchanged. No migration, database write,
  raw SQL, provider-secret, CI, Podman, production or shared destructive operation was used.

## TDD and verification

- Red, before the production edit:
  `RAILS_ENV=test PARALLEL_WORKERS=1 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres POSTGRESQL_TEST_PREPARE_DATABASES=<manifest databases> bundle exec rails test test/integration/social_auth_link_test.rb`
  Result: `16 runs, 100 assertions, 1 failure, 0 errors, 0 skips`; the failure was the expected
  32-character hexadecimal value not matching the NanoID-21 contract.
- Green focused collection:
  `test/integration/social_auth_link_test.rb test/integration/social_auth_unlink_test.rb` Result:
  `29 runs, 138 assertions, 0 failures, 0 errors, 0 skips`.
- Targeted RuboCop:
  `bundle exec rubocop app/controllers/concerns/social_auth.rb test/integration/social_auth_link_test.rb test/integration/social_auth_unlink_test.rb`
  Result: no offenses.
- Rails Gate 2, run-owned twenty-database manifest with four workers:
  `15146 runs, 128226 assertions, 0 failures, 0 errors, 0 skips`.
- Vitest Gate 2 using the same manifest scope: `99 files, 1140 tests, 0 failures`.
- `git diff --check`: passed.

These results are implementation evidence for this dirty worktree, not an independent acceptance
decision. OAuth/OIDC provider callback state, Apple nonce, PKCE, protocol secrets and other
ceremony-specific identifiers were intentionally not converted. D-11 committed-transaction
isolation, operational Avatar cutover, retained legacy identifier semantics, host Alloy
recreation/runtime verification, privacy-retention policy and the user-excluded independent
acceptance work remain outside this slice.
