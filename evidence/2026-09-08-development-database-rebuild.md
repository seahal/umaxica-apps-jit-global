# Development Database Rebuild and Verification

Performed 2026-09-08 inside `global-devcontainer-core`, against the Compose stack described in
`2026-09-08-podman-compose-devcontainer-coexistence.md`. The developer approved destroying the
development and test databases.

## Why the rebuild was needed

`bin/setup` aborted at `bin/rails db:prepare`:

    == 20260906120000 AddPublishingOperatorProvenance: migrating ==
    PG::UndefinedTable: ERROR:  relation "publishing_info_app_entries" does not exist

`development_publishing_db` held 16 tables in a superseded single-family shape
(`publishing_entries`) and recorded four versions, two of which no longer exist in
`db/publishing_migrate`:

    ["20260716180000", "20260801142552", "20260801143622", "20260810013000"]

`20260716180000_create_publishing_schema.rb` was modified after it had been applied (commits
`0c2544695`, `e06379597`, `6757df509`, which also deleted the two missing migrations). Because its
version was already recorded it never re-ran, so the twelve `publishing_<surface>_<audience>_*`
families the current `db/migration_support/publishing_schema.rb` builds were absent.

Ruled out as the cause: missing environment configuration. A scratch database
(`scratch_publishing_probe`, created and dropped for this check) ran all three
`db/publishing_migrate` migrations cleanly under the same environment, producing 159 tables
including `publishing_info_app_entries`. Stale data, not configuration.

## Method

`db:reset` was not used. All twenty `db/*_structure.sql` files are 448-byte stubs containing no
table definitions, so loading them would have produced empty databases despite
`config.active_record.schema_format = :sql`. Used instead:

    bin/rails db:drop      # exit 0
    bin/rails db:prepare   # exit 0, 2146 migrations applied, 0 aborts

`AddPublishingOperatorProvenance` applied in 0.0353s after `CreatePublishingSchema` rebuilt the
families in 4.0814s.

## Results

- `bin/setup --skip-server` — exit 0.
- `bin/dev` — ran its own `db:prepare` successfully, then started all three processes: Puma 8.0.2 on
  `0.0.0.0:3000`, Vite v8.2.2 on 3036, `jobs`.
- HTTP against the running server, `Host` header per `compose.env`:

  | Host               | `GET /`         | `GET /?ri=jp`   |
  | ------------------ | --------------- | --------------- |
  | core.app.localhost | 302 → `/?ri=jp` | 200, 3097 bytes |
  | core.org.localhost | 302 → `/?ri=jp` | 200, 3097 bytes |
  | core.com.localhost | 302 → `/?ri=jp` | 200, 3097 bytes |

  Before the rebuild the same requests returned 500 with `ActiveRecord::PendingMigrationError`.

- `bin/rails test` — 12472 runs, 72649 assertions, **2 failures**, 0 errors, 1 skip, 907.8s.
- `pnpm test` — exit 1. Node unit project passed: 281 tests, 22 of 84 test files. The browser
  project did not run.

## Failures observed, both pre-existing and unrelated to this rebuild

Working tree during these runs contained only Compose and documentation edits plus evidence files;
nothing under `app/`, `test/`, or `db/` was modified.

1. `Security::Invariants::FlatRubySourceLayoutInvariantTest`, two failures at
   `test/security/invariants/flat_ruby_source_layout_invariant_test.rb:58` and `:90`. Ten files
   under `app/models/concerns/publishing/` violate the flat-layout invariant and do not define the
   matching flat constants, e.g.
   `app/models/concerns/publishing/entry_record.rb: missing EntryRecord`. Last touched by commit
   `0c2544695`. Source layout, independent of database state.

2. `pnpm test`'s browser project cannot launch Chromium in this image:

       chrome-headless-shell: error while loading shared libraries:
       libatk-1.0.so.0: cannot open shared object file: No such file or directory

   Playwright's system libraries are absent from the container image, so 62 of 84 test files never
   executed. Not investigated further; adding image dependencies was outside the requested scope.
