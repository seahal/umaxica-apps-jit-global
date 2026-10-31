# Baseline Rails test result

- Commit: `b6e7871073bdc43a55fc5f05e8476de8ee71252f` in detached checkout; main checkout HEAD `336811e5072a93c0523e484f905082635b28f48f` had unrelated untracked files. The baseline checkout used the workspace bundle, fork dependencies, and node_modules. Ruby was 4.0.9; baseline `.ruby-version` specifies 4.0.7.
- Command: `BUNDLE_PATH=/home/global/workspace/vendor/bundle bin/rails test`. Exit 1 after 288.157 seconds of test execution: 18,479 runs, 149,911 assertions, 257 failures, 725 errors, 0 skips.
- The 982 distinct failing test identifiers are recorded in `plans/2026-10-28-baseline-failing-tests.md`; one error was printed twice. Raw output remains in `/tmp/umaxica-baseline-test-v1.log` for this session only.
- The baseline used the configured test databases and their parallel clones; it is not an isolated database environment. No application source changes were included.
