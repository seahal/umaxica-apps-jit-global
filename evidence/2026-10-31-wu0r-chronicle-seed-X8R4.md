# Chronicle reference reconstruction

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive uncommitted changes affecting this result.
- The existing seed replayed only two APP social event IDs and one APP level ID. It now replays the complete existing APP/ORG Chronicle event and level model catalogs; source consumers include social delivery, credential audit and session revocation. The insertion is idempotent and fails on a missing table.
- Executed the actual relevant seed fragment twice against temporary tables on rolled-back local development APP/ORG Zenith and OP connections and the Chronicle connection. APP event/level catalogs contained 36 and five IDs; ORG event/level catalogs contained 18 and one ID. All other previously covered reference sets were checked in the same run. No persistent data was changed by this probe.
- Scoped `git diff --check` passed. RuboCop on the seed reported only the pre-existing `Rails/SkipsModelValidations` offense on an unchanged line. Full seed, fresh reconstruction and all other reference catalogs remain unverified; production and Neon were not touched.

- Clarification: the temporary-table transactions themselves were rolled back. Development Rails boot also runs the existing Preference reference initializer, which can write fixed status/audit/binding IDs outside those transactions; its actual writes during each boot were not separately measured. Statements above about no persistent changes refer to the probe transaction, not a guarantee that boot had no writes.
