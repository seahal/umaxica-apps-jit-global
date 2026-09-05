# Publishing Persistence And Controller Design

Current architecture for the global publishing/CMS boundary. Historical ADRs remain
in `adr/`; this document records the rules in force after the media-usage split.

## Persistence is global

The 3 × 4 content matrix (`app`/`com`/`org` × `info`/`docs`/`news`/`help`) shares
one `publishing` database. There are not twelve CMS databases and not separate
regional publishing databases. Edge hostname or region naming does not change
persistence ownership.

## Persistence polymorphism is prohibited

Publishing relations must have one ownership meaning. Do not represent
heterogeneous owners through:

- Rails `polymorphic: true` associations
- `*_type` + `*_id` columns
- STI (`type` inheritance columns)
- exclusive-arc / union-owner tables (nullable alternative foreign keys)
- discriminator values that change the foreign-key graph or lifecycle
- EAV used to emulate different entity types
- dynamic model or table selection (`constantize`, `safe_constantize`)

Ordinary classification is allowed. Taxonomy `kind` classifies a vocabulary that
is still one entity with one ownership and lifecycle.

Ruby polymorphism (modules, composition, ordinary method dispatch) is allowed.

## Media ownership

A fresh database creates two owner-explicit relations directly. There is no
`publishing_media_usages` table and no compatibility/data-copy migration: this
correction landed before any deployment.

- `publishing_revision_media_usages` belongs only to `entry_revision_id`
- `publishing_version_media_usages` belongs only to `entry_version_id`

`entry_id` and `locale` are not stored on these relations. They are determined
by the owner revision or version. BCNF is the baseline; there is no measured
reason to duplicate those attributes.

Promotion copies placement (`media_file_id`, `role`, `field_path`, `block_path`,
`position`) and presentation (`alt_text`, `caption`, `presentation_metadata`).
A deferred PostgreSQL completeness trigger requires those fields to match at
COMMIT. Version media is immutable. Promoted revision media cannot change.

## Schema authority

Migrations define the schema. `db/seeds.rb` only populates development sample
data. Seeds must conform to the schema; the schema must not be weakened for
seeds.

## Migration DSL

Prefer Rails migration DSL (`create_table`, `add_foreign_key`, `add_index`,
`add_check_constraint`). Raw SQL, triggers, and exclusion constraints are
exceptions: they must be justified, narrowly scoped, tested, and must not drop
an integrity constraint for portability theatre.

Permanent PostgreSQL exceptions for media:

- `publishing_reject_mutation` on version media (immutability Rails callbacks
  cannot enforce against `update_all` / raw SQL)
- `publishing_promoted_revision_guard` on revision media
- `publishing_assert_version_media_complete` deferred completeness at COMMIT

## Rails controllers

The twelve public entry controllers stay explicit and thin. Shared list/detail
rendering lives in `PublishingContentRendering`. Each controller declares
`PUBLISHING_AUDIENCE` and `PUBLISHING_SURFACE`. Including that concern must not
infer those values from the class name.

`included do` is an exception. Keep it only when it is the clearest statement of
a persistence or request-filter contract, and document why.

## Related

- `adr/publishing-persistence-polymorphism-prohibition.md`
- `adr/publishing-db-content-authority.md`
- `docs/architecture/content-surface-matrix.md`
