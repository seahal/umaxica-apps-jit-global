# Authority writer connection slice

- Date: 2026-09-17
- Branch: `feature`
- Review HEAD before this slice: `efa5c1a34da56f50e67a2bc9da0c6473157f5560`
- Pre-existing worktree changes were preserved, including the README change, the deleted
  `misc.md`/`refactor.md`, and the browser-block notification files.

## Change

The six semantic RP/principal base classes now inherit from one canonical connection owner per
surface: `AppZenithRecord`, `ComZenithRecord`, or `OrgZenithRecord`. This keeps RP and principal
Ruby interfaces separate while allowing an authority transaction to use one physical writer pool.
The three identity-backed resource creators also re-read and lock the selected identity after the
surface principal lock, so an identity status change racing with creation is revalidated before the
resource row is written.

## Verification

- `bundle exec bin/rails runner ...` printed equal connection specification names and equal pool
  object IDs for each app, com, and org RP/principal pair.
- Ruby syntax checks for the changed models, creators, and tests passed.
- RuboCop for the changed models, creators, and tests passed with no offenses.
- `bundle exec bin/rails zeitwerk:check` passed.
- The focused Minitest command was attempted with an isolated test host. It could not reach an
  assertion because PostgreSQL was unavailable (`ActiveRecord::ConnectionNotEstablished` /
  `PG::ConnectionBad`); no development or production database was used.
- The migration and rollback test were not executed because the required isolated test database was
  unavailable. The rollback assertion is authored in
  `test/operations/client_persona_creator_test.rb` and must pass before enabling the authority
  cutover.

## Limits

Source-level pool sharing is not a substitute for the required runtime PostgreSQL rollback,
concurrency, migration, and existing-data owner-mapping checks. Those remain blocked by the missing
isolated database service and are tracked in `conflict.md` under CF-002 and CF-003.
