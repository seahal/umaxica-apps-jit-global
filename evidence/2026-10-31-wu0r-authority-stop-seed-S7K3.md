# Authority-stop reference reconstruction

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive uncommitted changes affecting this result.
- Added seed replay for the APP and ORG OP authority-stop cause, scope and participant-status IDs using each owning migration's fixed catalogs and the current prefixed table names. The seed fails if a required table is absent; existing IDs are left unchanged.
- Executed the actual relevant seed fragment twice against temporary tables in rolled-back development OP connection transactions. Both realm catalogs matched: nine causes, three scopes and four participant statuses each. The wider probe also checked the 19 previously recorded token, sign-flow and session-limit sets. No persistent rows were changed by the probe.
- Scoped `git diff --check` passed. An initial RuboCop run reported one new line-length offense, corrected after the run, and one pre-existing `Rails/SkipsModelValidations` offense on an unchanged line. Full reset, full seed, other reference catalogs, production and Neon were not tested.
- A subsequent RuboCop run after the formatting correction reported only the same pre-existing `Rails/SkipsModelValidations` offense on the unchanged `insert_all` line.

- Clarification: the temporary-table transactions themselves were rolled back. Development Rails boot also runs the existing Preference reference initializer, which can write fixed status/audit/binding IDs outside those transactions; its actual writes during each boot were not separately measured. Statements above about no persistent changes refer to the probe transaction, not a guarantee that boot had no writes.
