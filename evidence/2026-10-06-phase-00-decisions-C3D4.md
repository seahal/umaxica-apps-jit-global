# Phase 00 decisions

- Commit: `bfe569a162078df62e8e3b3011367840780e3078`
- Worktree: dirty before and during this check; the pre-existing `.gitignore` edit was preserved. The Phase 0 implementation and ADR files are also uncommitted because the user prohibited commits.
- `git diff --check -- adr config/environments/test.rb`: passed.
- Added `adr/authentication-state-machine-normalization.md`, `adr/base-authority-and-self-rp-separation.md`, and `adr/identity-resolution-and-credential-binding.md`.
- Amended the seven ADRs listed by Phase 0.3. Each affected ADR records whether the plan amends, partially supersedes, fully supersedes, or retains its earlier decision and identifies the retained boundaries.
- `env POSTGRESQL_TEST_PREPARE_DATABASES=test_missing_db bin/rails test test/lib/config_values/host_family_values_test.rb:10` exited 1 with `Umaxica::TestEnvironment::ConfigurationError: POSTGRESQL_TEST_PREPARE_DATABASES contains unverified databases: test_missing_db`; no test ran. This verifies that a `db:test:prepare` failure propagates as a non-zero test-process exit. No environment-construction Minitest was added.
