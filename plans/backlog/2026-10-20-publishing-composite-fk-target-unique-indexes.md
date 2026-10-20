# Publishing Composite Foreign Key Targets Flagged by UniqueIndexChecker

Recorded 2026-10-20. Status: resolved 2026-10-20 without schema change.

Resolution: each primary-key unique index now has a matching uniqueness validation declared with
`allow_nil: true, if: :will_save_change_to_id?`. It runs no query for new records with a database-
assigned id or for updates, so behavior and query counts are unchanged, and it rejects an explicit
duplicate id before SQL. Covered by
`test/models/primary_key_unique_index_validation_contract_test.rb`. The original analysis below is
kept for history.

## Problem

`bundle exec database_consistency` reports 48 UniqueIndexChecker failures ("index is unique in the
database but does not have a uniqueness validator") on these indexes of
`publishing_<surface>_<audience>_entry_{versions,revisions}` (surfaces help, news, docs, info;
audiences org, com, app):

- `uidx_<s>_{ver,rev}_id_entry` on `(id, entry_id)`
- `uidx_<s>_{ver,rev}_id_locale` on `(id, locale)`

Both exist only as referenced keys for composite foreign keys created by
`db/migration_support/publishing_schema.rb`. Those foreign keys guarantee that a publication or a
restore source points at a version of the same entry, and that taxonomy assignments share the
owner's locale. `id` is the primary key, so the indexes enforce no extra uniqueness of their own.

The redundant `(id, entry_id, locale)` indexes were already removed on 2026-10-20
(`evidence/2026-10-20-publishing-redundant-locale-unique-indexes-R7M2.md`).

## Constraints

- Configuration-file exclusions (`.database_consistency.yml`) are not acceptable.
- A uniqueness validator on a set that contains the primary key checks nothing and, declared
  plainly, adds a query per save. (The resolution above declares it so that it adds none.)
- Dropping the indexes drops the composite foreign keys, and with them the database-level same-entry
  and same-locale guarantees. Moving those guarantees into application code alone is not acceptable
  without a separate decision.

## Options to evaluate

- Redesign how referencing tables carry the entry and locale invariants so that foreign keys can
  reference the primary key alone, for example by enforcing the same-entry and same-locale rule with
  constraints or triggers on the referencing side.
- Check whether a newer `database_consistency` release recognizes indexes that back foreign keys,
  and whether that is an acceptable resolution.

## Work required once a direction is chosen

1. Record the decision in `generic/data-shape-design.mdc` terms and get approval.
2. Replace the composite foreign keys and their referenced indexes in one migration family, with
   concurrent index operations and `validate: false` plus a separate validation for new foreign
   keys.
3. Cover the same-entry and same-locale rejections with tests at the database boundary.
