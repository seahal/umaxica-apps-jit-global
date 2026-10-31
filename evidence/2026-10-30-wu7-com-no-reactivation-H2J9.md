# WU-7 com preference model reactivation guard

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; staged, unstaged and untracked changes affected the result.
- `ComPreference` model validation rejects an update from the persisted retired status to active. The com status diagram and transition inventory describe this guard and its limits.
- Before the change, the com model and write-journey tests passed: 60 runs, 345 assertions. After the change the same files passed: 61 runs, 347 assertions, zero failures, errors or skips. The added public model test retires a preference, attempts reactivation, and confirms the persisted status remains retired. RuboCop passed on the changed model.
- Model validation is bypassable by direct SQL or validation-skipping operations and does not by itself prevent a stale concurrent update; those cases and the complete lifecycle contract remain unverified. The accepted `adr/database-trigger-usage-boundary.md` forbids a trigger that merely duplicates model validation, so no trigger migration was added. No database migration or full suite was run.
