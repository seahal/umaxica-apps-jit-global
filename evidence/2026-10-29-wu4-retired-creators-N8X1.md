# WU-4 retired corporate resource creators

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected these results.
- Removed `CompanyCreator` and `IndividualCreator`, whose only application behavior required deleted Visitor authentication models. Search for their constants in `app/` and `test/` returned no remaining references. Existing Company and Individual models and data were not changed.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/surface_resource_creators_test.rb`: 4 runs, 28 assertions, no failures, errors, or skips. The surviving agent and bureau creation and authorization cases ran.
- `bin/rails zeitwerk:check` exited 0; its output warned that the vendor `rails_db` directory is not configured for eager-load checking.
- No full-suite rerun was performed. Test database preparation was used; no production persistence operation or external write was performed.
