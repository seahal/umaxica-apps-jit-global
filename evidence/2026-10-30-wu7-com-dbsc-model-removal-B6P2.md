# WU-7 com DBSC model behavior removal

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained staged, unstaged and untracked changes.
- Removed `DbscBindable` and its DBSC class constants from `ComPreference`, and removed the com entries from the concern's static binding/status maps. A com model test verifies DBSC transition/query methods are not exposed. App/org and token entries remain in the shared maps.
- Before the change, the com model, write-journey, Web Push API and binding tests passed: 78 runs, 496 assertions. Afterward, those tests plus Web Push initialization passed: 108 runs, 880 assertions, zero failures, errors or skips. Shared DBSC concern and registration-service tests also passed: 15 runs, 64 assertions. RuboCop passed on the three changed Ruby files.
- The com DBSC columns, reference models/tables, generic creation attributes and other callers remain; this slice does not claim complete DBSC removal. No migration or full suite was run. The Mermaid README notes the distinction between retired com behavior and legacy storage.
