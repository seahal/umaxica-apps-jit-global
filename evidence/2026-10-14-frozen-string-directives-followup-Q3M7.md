# Frozen string literal follow-up

Recorded 2026-10-14 against full commit `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5` on branch
`feature`. The worktree was extensively dirty; the implementation and full-suite results below ran
with those uncommitted changes present. `one.md` and `two.md` remain unchanged at SHA-256
`663bb1a858f537edde4da80e53631a73e08a8022c59123fb2df391601d4cbe4c` and
`7297a6e0eb52fc4df2768c926e084297e654f827c0acd83f0d462c6c8ae4086d`.

Moved 55 misplaced frozen-string directives into the leading comment block and added a repository
inventory script to the local CI entry point. The custom inventory rejects missing, false, late and
duplicate directives and inline cop disables; four temporary negative controls were all rejected.
The final inventory reports exactly ten remaining missing directives, all in Ruby launchers under
`bin/`. The frozen-only RuboCop invocation inspected 6,785 files and reported the same ten offenses
with no others. Normal RuboCop passed for `config/ci.rb` and
`scripts/check_frozen_string_literal_directives.rb`. `git diff --check` passed.

`findmnt` confirmed that `/home/global/workspace/bin` and `/home/global/workspace/.github` are
separate read-only ZFS mounts. The ten launcher files and GitHub Actions lint workflow therefore
could not be changed in this workspace. A development Rails boot passed with
`env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=development bin/rails runner 'puts "development_boot=ok"'`.
No migration replay was run: the user limited database work to the standard development and test
databases, and the ADR's migration replay requires an isolated disposable fleet.

The full standard Rails suite was run with
`env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test` and
finished with 15,256 runs, 128,991 assertions, 1 failure, 14 errors and 0 skips. The 14 errors are
Avatar committed-history cases refused by the run-owned worker receipt guard. The one failure was
`AuthCeremonyRevocationConcurrencyTest#test_independent_writers_can_create_only_one_remaining_Passkey_slot_on_each_surface`;
the exact case passed immediately when run alone (1 run, 9 assertions), so the full run remains
non-clean and the isolated result points to a suite interaction or race. No Strict Loading error
appeared in the full run. No database reset, manual cleanup, migration, isolated database or guard
bypass was performed; the isolated test's own `ensure` block removed only the test-owned rows it
created.

The frozen-string change is partial. The writable repository files and local checks conform; the
ten read-only launchers, GitHub Actions check and migration replay remain open. The diagnostic test
result does not establish a clean full-suite pass.
