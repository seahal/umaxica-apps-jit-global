# ORG sign-flow reference reconstruction

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive uncommitted changes affecting this result.
- The ORG sign-flow data migration and `db/seeds.rb` now share its fixed-ID writer, matching the APP reconstruction path. On a schema-only load the seed can restore the same ORG reference catalog without application models in the migration.
- Executed the actual relevant seed fragment twice against temporary tables inside rolled-back development APP and ORG OP connection transactions. All 11 inspected APP/ORG flow and session-limit reference sets matched their migration catalogs. ORG sign-in, signup, signout and signout-kind sets contained 14, nine, 10 and four IDs respectively. No persistent rows were changed by the probe.
- Scoped `git diff --check` passed. RuboCop on the ORG migration and seed reported only the pre-existing `Rails/SkipsModelValidations` offense on an unchanged seed line. A full reconstruction, all reference catalogs and a full `db:seed` were not verified. Production and Neon were not touched.

## Superseding correction

The earlier temporary probe also created historical signout Flow reference tables, which `20261025120400_drop_sign_out_flows` removes in the current schema. A first execution against the real local development OP database failed when it reached a missing APP signout reference table; earlier APP sign-in/signup rows may have been inserted. The seed now selects only current APP/ORG sign-in/signup tables while the historical migration still defaults to its complete original catalog. A revised temporary-table probe without the retired tables passed twice. The earlier temporary probe did not establish compatibility with current schema.

- Clarification: the temporary-table transactions themselves were rolled back. Development Rails boot also runs the existing Preference reference initializer, which can write fixed status/audit/binding IDs outside those transactions; its actual writes during each boot were not separately measured. Statements above about no persistent changes refer to the probe transaction, not a guarantee that boot had no writes.
