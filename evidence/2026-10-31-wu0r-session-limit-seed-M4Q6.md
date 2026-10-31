# Session-limit reference reconstruction

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes affecting this result.
- The SQL structure-load seed now also inserts the APP and ORG session-limit resolution states using the fixed ID catalogs from their owning migrations, on their respective OP writer connections. The insertion is idempotent. No schema change is included.
- Executed the actual relevant `db/seeds.rb` fragment twice against seven temporary PostgreSQL tables inside rolled-back development connection transactions. All five previously recorded app sign-flow sets and both session-limit sets matched their migration catalogs; the APP and ORG session-limit sets each contained five expected IDs. No persistent rows were changed by this probe.
- Scoped `git diff --check` passed. RuboCop on `db/seeds.rb` reported the single pre-existing `Rails/SkipsModelValidations` offense on its unchanged `insert_all` call. Full `db:seed`, a complete reconstruction, and other reference catalogs were not verified; production and Neon were not touched.

- Clarification: the temporary-table transactions themselves were rolled back. Development Rails boot also runs the existing Preference reference initializer, which can write fixed status/audit/binding IDs outside those transactions; its actual writes during each boot were not separately measured. Statements above about no persistent changes refer to the probe transaction, not a guarantee that boot had no writes.
