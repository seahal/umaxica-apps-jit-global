# Merging origin/feature, updating packages, and the review that followed

## Scope

On 2026-09-05, in `/home/global/workspace`: completed the `origin/feature` merge that the previous
session could only stage in a linked worktree, updated the Ruby and JavaScript dependencies,
established why 190 cases were not passing, and made the conservative fixes that follow from that.

## Completing the merge in the main worktree

`evidence/2026-09-05-merge-origin-feature-verification.md` records that the merge could not be
applied here because `.github`, `.devcontainer` and `bin` are read-only bind mounts and the merge
updates `.github/workflows/ci.yml` and `.devcontainer/compose.override.yml`.

It was applied by pointing those two index entries at the merged blobs directly, which needs no
write to the mount:

```bash
git update-index --cacheinfo 100644,<blob>,.devcontainer/compose.override.yml
git update-index --cacheinfo 100644,<blob>,.github/workflows/ci.yml
git update-index --skip-worktree .devcontainer/compose.override.yml .github/workflows/ci.yml
git merge --ff-only feature-merged      # 7554692da -> 6c4bacec5
git merge --no-edit origin/feature      # + 1012fedb8 -> 971b83866
```

The 249 untracked files in the worktree were each verified byte-identical to their `feature-merged`
blob before the fast-forward, so nothing local was discarded.

**Consequence, and it is not cosmetic:** the git content of those two files is correct, but their
worktree copies still hold the pre-merge text and cannot be updated from inside this container.
`ComposeLocalOverrideOptionalTest` reads the file from disk and therefore still fails here. The
committed file names `valkey-cache` and `valkey-rate-limit`; the stale copy on disk names the
retired single `valkey`. Clear the flags with `git update-index --no-skip-worktree` once the mounts
are writable.

## Package updates

`bundle update`: rails/propshaft/flipper git checkouts moved (rails `7ba5fa3` -> `44cf1d3`, still
8.2.0.alpha on main), `sorbet*` 0.6.13459 -> 0.6.13466, `rubydex` 0.4.0 -> 0.4.1. Everything else
offered by `bundle outdated` was inside the Gemfile's `cooldown: 3` window.

`pnpm update`: `react-aria-components` 1.20.0 -> 1.21.0, `@redocly/cli` 2.49.0 -> 2.51.0,
`@testing-library/user-event` 14.6.6 -> 14.6.7.

`@types/node` 26.4.1, `oxfmt` 0.66.0 and `oxlint` 1.81.0 were **not** taken. All three are
`catalog:` entries pinned in `pnpm-workspace.yaml`, and that file sets `minimumReleaseAge: 4320`
with `minimumReleaseAgeStrict: true` — a deliberate 3-day quarantine that a person, not a tool,
lifts. Bumping a pinned formatter or linter also reformats or re-lints the whole repository, which
is not an update to make in the same pass as a merge.

## Why 182 errors and part of the 9 failures existed

181 of the 182 errors were `PG::UndefinedTable` for the twelve-family publishing tables. The
previous session's evidence concluded that no migration creates them. That conclusion was wrong:
`db/publishing_migrate/20260716180000_create_publishing_schema.rb` calls
`PublishingSchema.create_schema`, which builds all 159 of them. It does not appear in
`git grep publishing_docs_app_vocabularies -- db/` because the names are composed at migration time
from `FAMILIES`.

The real cause is that `origin/feature` squashed the publishing migrations **in place** (`0c2544695`
rewrote the already-applied `20260716180000`, deleting `20260801142552` and `20260801143622`), so
every database that had already run the old version kept the old single-family schema and reported
nothing pending. `test_publishing_db` held 17 tables, including `publishing_editions`, which
`Publishing::SchemaAndModelsTest` asserts is gone.

`docs/operations/db-workflow.md` names the remedy: migrations are the reconstruction authority and a
squash is recovered with a reset. Applied to the test database only:

```bash
RAILS_ENV=test bin/rails db:drop:publishing db:create:publishing db:migrate:publishing
```

`test_publishing_db` went from 17 tables to 159. Worker clones re-template themselves because
`ParallelTestDatabaseCloner#schema_sha` digests the base catalogue.

**Not done, and it matters:** `development_publishing_db` still holds the old 16-table schema. Reset
it with `bin/rails db:migrate:reset` before running the app locally. It was left alone because
dropping a development database is not a change to make without asking.

## Test results

| Run                                                     | Result                                                              |
| ------------------------------------------------------- | ------------------------------------------------------------------- |
| Baseline, merged tree, before any change                | 12361 runs, 70283 assertions, 9 failures, 182 errors, 1 skip (841s) |
| After the DB reset, package updates and the fixes below | 12361 runs, 71784 assertions, 3 failures, 0 errors, 1 skip (732s)   |

`pnpm test`: 84 files, 1020 tests, all passing, before and after.

The three remaining failures are one environment artefact and one invariant that is not mine to
resolve; both are described below.

## Fixes made

### `db/app_ticket_structure.sql` was a real 40-table dump

`test/tooling/database_reconstruction_authority_test.rb` pins that committed structure dumps are
session-setting stubs, because migrations — not dumps — reconstruct a database here. `9a9483e86`
committed a populated 109 KB dump for `app_ticket`, presumably a stray `db:schema:dump` while adding
`security_one_time_reveals`. Restored to the 448-byte stub every other dump uses.

### Two tests that no longer tested what they claimed

- `HtmlTitleContractTest` still asserted `/\Astatus: /` for `GET /health`. `9a9483e86` had added
  `title:` and `namespace:` lines ahead of it, and `HealthCheckRendering#render_snapshot` documents
  the resulting seven-line order. The assertion now matches that documented shape.
- `TaxonomyConstraintsTest`'s cross-vocabulary parent case borrowed a term id from **docs/com** to
  parent a **docs/app** term. After the twelve-family split those are different physical tables on
  their own id sequences, so the id usually addressed a legitimate docs/app row and
  `fk_docs_app_term_parent_scope` never fired. The other vocabulary is now a second docs/app
  vocabulary, which is what actually exercises the composite foreign key.

### `PromoteRevisionOperation::IDEMPOTENCY_INDEX` did not exist

`PromoteRevisionRaceVerificationTest` referenced a constant no version of the operation defines, so
the test raised `NameError`. The index name was a bare string inside a `rescue`; it is now
`PromoteRevisionOperation.idempotency_index_name`, used by that rescue, and the test asserts the
real index in the catalogue is unique and keyed on `entry_revision_id` alone.

### The CMS `errors` prop had two shapes

`ReviseEntryForm#message_hash` produces `{attribute => String}`; `ReviseEntryOperation` produced
`{attribute => [String]}`. Both reach `ManagementEdit` through the same `errors` prop, which is
typed `Record<string, string>` and renders each value directly — an array only reads as a message
because React concatenates its elements. The operation now emits strings.

### `security_one_time_reveals` had no purge job

Every other `expires_at`-keyed single-use table in this repository has a purge job and a
`config/recurring.yml` entry: `SecurityConsumedJtiPurgeJob`, `DpopProofStatePurgeJob`, the seven
ceremony-transaction jobs. `security_one_time_reveals`, added in this branch, has none, and each of
its rows holds an encrypted recovery-secret payload that `SecurityOneTimeReveal.consume` already
refuses once expired. Added `SecurityOneTimeRevealPurgeJob`, modelled on the consumed-jti job and
scheduled beside it in both environments, with a test that fails if the job is written but never
scheduled.

### Removed junk that had been committed

- `539376{path}` — a repository-root file, added 2026-08-30, holding a single 63-character random
  string and referenced by nothing. See "Still open" below.
- Three `.orig` merge backups committed by `9a9483e86` (`health_check_rendering.rb.orig`,
  `health_status_serializer.rb.orig`, `health_endpoints_test.rb.orig`).
- `.gitignore` now covers `*.orig` and `*.rej` so the backups cannot be committed again.

## Coverage

Vitest, `src/features/publishing` before: 68.75% statements, 50% branches, 55.55% functions. The
existing spec used `renderToStaticMarkup`, so no handler in `ManagementEdit` ever ran. Global branch
coverage was 97.68% against a 98% threshold — the suite was failing its own gate.

Added interactive tests (`@testing-library/react` + `user-event`) for the submit path, the alert
branches, and the all-fields-null render, plus static cases for the empty index, a row with no
revision, and a show page with no summary.

| Metric     | Before                  | After  |
| ---------- | ----------------------- | ------ |
| Statements | 99.31%                  | 99.54% |
| Branches   | 97.68% (fails 98% gate) | 98.98% |
| Functions  | 98.29%                  | 98.82% |
| Lines      | 99.58%                  | 99.81% |

`src/features/publishing` is now 100% statements/functions/lines and 97.36% branches.

New Minitest files, all for code that had no test of its own:

- `test/forms/publishing/revise_entry_form_test.rb`
- `test/queries/publishing_management_entries_query_test.rb` — including that a public id from
  another family is a 404 rather than a cross-family read
- `test/values/publishing_revise_entry_result_test.rb`
- `test/models/security_one_time_reveal_test.rb` — the expiry branch of `consume`, which nothing
  reached
- `test/jobs/security_one_time_reveal_purge_job_test.rb`

Added to existing files: the stale-`lock_version` 422 path through the CMS controller, and the
nil-lock and no-current-revision guards in `ReviseEntryOperation`.

## Still open

- **`539376{path}` is still in history** (`d0c006c96`, `eabda37cf`). Deleting the file does not
  remove the value. If that string is a live credential it has to be rotated; nothing in the tree
  reads it, so its origin could not be determined from the repository.
- **`Security::Invariants::FlatRubySourceLayoutInvariantTest` fails on 11 files.** The publishing
  model concerns live at `app/models/concerns/publishing/*.rb` and define `Publishing::EntryRecord`
  and friends; the invariant requires `app/models/concerns` to be flat with a matching top-level
  constant. Satisfying it means renaming 11 files and updating 158 includers. That is mechanical and
  zero-behaviour, but it is a layout decision on code still being written on `origin/feature`, and a
  rename of that size would conflict with the next merge. Left for the author of that branch.
- **`ComposeLocalOverrideOptionalTest`** fails only because of the read-only mount described above.
  The committed file is correct.
- **The staff publishing CMS is unauthenticated.** `Base::Org::Publishing::*::EntriesController`
  inherits `Base::Org::BareController` with `AUTHENTICATION_MODE = :bare` and takes `PATCH`.
  `notes/implementation/2026-09-04-publishing-management-ui.md` records this as a deliberate alpha
  posture with Cloudflare Access to be placed in front, and names the follow-up. Not changed here,
  but it is the largest open risk in the merged branch.
- **`PublishingManagementEntriesQuery#call` is unbounded.** The CMS index orders every entry in the
  family with no limit or pagination and builds two `url_for` calls per row. Correct and cheap at
  alpha volume; it is the first thing that will not scale.
- **`resuts.md`** (sic) is a 2026-08-15 quality-gate report at the repository root. It predates this
  session and belongs under `evidence/`; left alone rather than moved as unrelated cleanup.
