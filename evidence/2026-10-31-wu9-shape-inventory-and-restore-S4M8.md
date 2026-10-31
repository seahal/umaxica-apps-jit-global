# WU-9 local Preference shape inventory and restore rehearsal

Work was performed against HEAD
`336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive pre-existing staged,
unstaged, and untracked changes. No commit was created.

On 2026-10-31, read-only Rails runner inventories covered local development and test APP/ORG
setting and Zenith databases. All four development Preference parent tables were empty. The test
databases each contained two Preference parent rows. APP setting also had one theme child; ORG
setting had two cookie children and one theme child; each test Zenith had two each of language,
region, theme, and timezone children. The retired setting transport reference counts were three
binding-method rows and five DBSC-status rows in each realm. Status reference counts were three APP
and two ORG. Existing option rows were present and retained: development held 39 APP-setting, 34
ORG-setting, 39 APP-Zenith, and 39 ORG-Zenith option rows; test held 40 APP-setting, 15 ORG-setting,
39 APP-Zenith, and 17 ORG-Zenith option rows. No account Preference row with unknown explicit-field
provenance was observed. The test rows have non-null legacy token digests/direct snapshots and will
lose those values if the destructive shape is applied; their counts and NULL profile are in the
execution ticket.

Eight local custom-format database dumps were created under the private
`/tmp/wu9-preference-shape-20261031/` directory. Their SHA-256 values are recorded in
`plans/2026-10-31-wu9-preference-shape-execution-ticket.md`. `pg_restore --list` succeeded for all
eight. Each dump was restored into a separate temporary local database, public base-table counts
were checked, and the temporary databases were removed. Development restore times were 130 ms (APP
setting), 128 ms (ORG setting), 629 ms (APP Zenith), and 575 ms (ORG Zenith); test restore times
were 131 ms, 139 ms, 704 ms, and 597 ms respectively. These times describe only this local
environment.

The owner-approved P0 decisions were applied to the Preference ADR index, superseded ADRs, option
reference ADR, invalid-credential recovery ADR, cookie-scope note, and P0 revision plan. The
one-directional sign-in and realm-JWT/host-bound-binding ADRs were added. `git diff --check` passed
for the changed ADR and plan files. No schema migration was run.

`bin/rails test test/controllers/concerns/preference_write_boundary_test.rb` passed: 8 runs, 30
assertions, 0 failures, 0 errors, 0 skips. This was a focused contract test; it does not verify the
planned APP/ORG Preference implementation.

The minimum Base identity-resolution slice also passed focused checks during this work: resolver,
Base preference identity integration, and signed-in dual-write tests passed with 11 runs and 44
assertions; the Base preference authority and theme/cookie API checks passed with 18 runs and 111
assertions. Scoped RuboCop passed on 11 touched files with no offenses. These checks verify the Base
actor resolution/authorization boundary only; they do not verify the WU-9 Visa writer or schema.

An earlier full-suite process ended before its exit status and summary could be recovered from the
expired runner session. Its result is unverified and is not counted as a pass or failure here.
