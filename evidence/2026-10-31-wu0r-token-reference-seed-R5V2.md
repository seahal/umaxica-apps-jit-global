# Token reference reconstruction

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive uncommitted changes affecting this result.
- Added seed replay for APP/ORG token kinds, token statuses, binding methods and DBSC statuses, using the existing model fixed-ID catalogs on each OP writer. The SQL insertion fails if a required reference table is absent and leaves existing IDs unchanged.
- Executed the actual relevant seed fragment twice against temporary tables inside rolled-back development APP and ORG OP connection transactions. The eight token sets matched their model catalogs: three kinds, five statuses, three binding methods and five DBSC statuses per realm. All 19 inspected token, flow and session-limit sets matched; no persistent rows were changed by this probe.
- Scoped `git diff --check` passed. RuboCop reported only the pre-existing `Rails/SkipsModelValidations` offense on an unchanged seed line. A complete reset, full seed and other reference catalogs remain unverified. Production and Neon were not touched.

- Clarification: the temporary-table transactions themselves were rolled back. Development Rails boot also runs the existing Preference reference initializer, which can write fixed status/audit/binding IDs outside those transactions; its actual writes during each boot were not separately measured. Statements above about no persistent changes refer to the probe transaction, not a guarantee that boot had no writes.
