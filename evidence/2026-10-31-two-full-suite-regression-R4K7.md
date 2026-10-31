# Full Rails suite after Passkey audit changes

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes affecting the application and tests.

With the configured local test database and COM Preference JWT settings, `PARALLEL_WORKERS=1 bin/rails test --seed 40202` completed in 864.77 seconds with exit status 1: 16,446 runs, 161,530 assertions, 110 failures, 117 errors and 0 skips.

The run's 227 distinct failure/error IDs were compared against `plans/2026-10-28-baseline-failing-tests.md`, using exact IDs or the same test method name, and against the prior seed-40202 run in `evidence/2026-10-31-two-full-suite-after-corrections-N5R8.md`. Three failures remain outside the recorded baseline: `DatabaseReconstructionAuthorityTest#test_committed_structure_dumps_contain_real_table_definitions`, `#test_primary_uses_the_conventional_db/structure.sql_dump_path`, and `#test_publishing_reconstructs_from_migrations_rather_than_publishing_structure.sql`. No current failure/error ID was new relative to the prior full run. These comparisons do not make the suite green or resolve the previously identified schema-dump discrepancies.

The raw test output was kept in a restricted temporary file for comparison and then removed. No production or Neon database operation was performed. Test outcomes do not establish completion of the other open requirements in two.md.
