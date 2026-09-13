# ADR: Publishing Taxonomy and Facet Architecture

## Status

Accepted (2026-08-01)

## Date

2026-08-01

## Context

`adr/publishing-db-content-authority.md` §6 deferred taxonomy: the central `publishing` database
shipped with eight tables and no vocabulary of any kind, and the six legacy CMS taxonomy tables per
surface family were not copied. That deferral required a separate ADR before any taxonomy migration,
model, service, or API could be added. This is that ADR.

At the time of writing nothing in this system is deployed. The edge repository
(`seahal/umaxica-apps-edge`) contains no consumer of the Rails read API, so the public JSON contract
has no downstream dependency yet. Deliberate breaking corrections are therefore cheaper now than
they will ever be again.

Two questions had to be settled together. The first is what taxonomy _is_ in this codebase, given
that "category", "language", "region", "author", and "version" had all been described as filtering
dimensions at various points. The second is where the integrity of an assignment lives, given that
the rest of the publishing schema already proves locale coherence with composite foreign keys rather
than with Active Record validations.

## Decision

### Taxonomy is persisted, assignable vocabulary. Facet is deferred.

**Taxonomy** is a controlled vocabulary whose terms an author assigns to content. Category and Tag
are the initial vocabularies.

**Facet** — a read-side filtering or navigation dimension — is deliberately _not_ built as an
abstraction in this change. There is no generic facet registry and no provider protocol, because
there is no caller that two providers would serve. Language and Region remain derivable from data
that is already authoritative:

```text
Language ← locale
Region   ← Edition / host / region_code
```

Neither is persisted as taxonomy. Introducing a facet protocol before a real caller exists would add
indirection with no replacement path; it can be revisited when filtering grows beyond the narrow
`?category=` / `?tag=` support added here.

The following remain lifecycle or provenance concepts and are never modelled as taxonomy, never
exposed as taxonomy fields, and never surfaced publicly:

```text
Revision
Version
Publication
created_by_operator_public_id
```

There is no displayed-author entity and no country taxonomy. Country applicability stays out of
scope until its semantics are separated from deployment region and publication placement.

### Fixed structural kinds, runtime vocabulary rows

A vocabulary is a **row**, not a table and not a class. Adding "topic" or "audience_level" later
requires no migration and no Ruby.

A vocabulary's _structural kind_ is fixed and closed:

| Kind                    | Cardinality                                             | Shape     |
| ----------------------- | ------------------------------------------------------- | --------- |
| `single_hierarchical`   | at most one term per vocabulary per revision or version | tree      |
| `multiple_ordered_flat` | any number of terms, author-ordered                     | flat list |

Category is `single_hierarchical`; Tag is `multiple_ordered_flat`. Adding a _kind_ is a deliberate
change to tables, constraints, code, and tests — not a configuration value.

`Publishing::TaxonomyKind` is an explicit frozen map of two provider objects. There is no
`constantize`, no `const_get`, no naming-convention discovery, and no subclass scanning. Dispatch is
on the structural kind, never on an individual vocabulary key: no code branches on
`vocabulary.key == "category"`.

### Vocabulary is scoped by physical content family

**Amended 2026-09-04 by `adr/publishing-twelve-family-encrypted-persistence.md`.** A vocabulary
belongs to exactly one of the twelve physical families (for example
`publishing_docs_app_vocabularies`). `UNIQUE(key)` is per family table. There are no
`audience`/`surface` columns on vocabulary rows.

Locale is _not_ part of vocabulary scope. One vocabulary row serves every locale, because locale
belongs to terms.

### Terms are locale-specific

The Japanese and English term for the same idea are independent rows carrying `locale NOT NULL`.
This is what makes locale coherence provable: an assignment's locale is tied by composite foreign
key to both its revision or version _and_ its term, so a `ja` revision cannot reference an `en`
term. A shared-concept-with-translated-labels design would have moved that guarantee out of
PostgreSQL and into Rails, which the surrounding schema does not do.

Cross-language equivalence, if it is ever needed, can be added later as a nullable concept
identifier without restructuring anything.

Hierarchy uses adjacency (`parent_id`, `depth`) on the term table itself. No edge table, closure
table, or `ltree` is used: adjacency satisfies every constraint the design requires, and the
composite foreign key `(parent_id, vocabulary_id, locale)` proves parent and child share a
vocabulary and a locale.

### Revision assignments are editable; version assignments are immutable snapshots

```text
Publishing::Entry
├── EntryRevision   -- editable draft, live taxonomy assignments
├── EntryVersion    -- immutable, frozen taxonomy assignment snapshots
└── Publication     -- publishes one immutable EntryVersion
```

At promotion, each draft assignment is copied into a version assignment carrying both a live foreign
key (authoritative for referential tracking) and snapshot columns (authoritative for historical
rendering): vocabulary public id, key and kind, term public id, slug and name, the root-to-term
breadcrumb path, locale, and position. Renaming, reordering, or moving a term afterwards cannot
change what an already-published version displays.

The breadcrumb path is the only JSONB column in the taxonomy schema, and it is not a metadata bag: a
CHECK constraint validates that it is an array of objects whose `public_id`, `slug`, and `name` are
all strings.

Vocabulary and term rows are archived, never deleted. Every foreign key uses `ON DELETE RESTRICT`.

### A promoted revision is frozen

Once a revision has been promoted, it is the historical record of what was published. If it could
still change, the revision and its version would describe different promotion events, and
`UNIQUE(entry_revision_id)` makes a corrected second version impossible. PostgreSQL therefore
rejects UPDATE and DELETE of a promoted revision, and rejects INSERT, UPDATE, and DELETE of its
taxonomy assignments. Draft revisions remain fully editable.

### Snapshots are derived, never trusted

Version snapshot columns are written by a `BEFORE INSERT` trigger that reads the live vocabulary and
term and computes the breadcrumb with a recursive CTE. A caller using direct SQL cannot claim a term
name, slug, key, kind, locale, position, or path that never existed: the values are overwritten
deterministically from the authoritative rows.

Completeness is checked by a `DEFERRABLE INITIALLY DEFERRED` constraint trigger that compares the
version's assignment set against its revision's at commit. A version cannot commit with missing,
extra, or misordered snapshots, whether it was created by the operation or by hand.

### Retirement never recycles identity

Vocabularies and terms are archived, never deleted; PostgreSQL rejects DELETE on both tables even
when nothing references the row. An archived slug or key stays reserved, so a published snapshot
naming a term can never be silently reinterpreted by a different term that reused its identity.
Archiving is reversible through an ordinary update.

A vocabulary's `public_id`, `audience`, `surface`, `key`, and `kind` are frozen once it has terms. A
vocabulary with no terms may still be corrected.

Sibling order is deterministic:
`UNIQUE NULLS NOT DISTINCT (vocabulary_id, locale, parent_id, position)` covers hierarchical
siblings and, because flat vocabularies always have a NULL parent, gives them
per-vocabulary-and-locale position uniqueness through the same index.

### Archived terms restore into drafts but block promotion

Restoring a version rebuilds a draft from the version's _live_ foreign keys, never by looking terms
up again by snapshot slug or name, so restoration is deterministic. A term that has since been
archived is allowed into the restored draft — otherwise old content could never be reopened — and
`Publishing::PromoteRevision` refuses to publish it, raising
`Publishing::ArchivedTaxonomyAssignmentError` with the vocabulary key, term public id, term slug,
and revision public id a future authoring UI needs to resolve the conflict.

An archived _ancestor_ blocks promotion too. A category whose breadcrumb passes through a retired
parent cannot be rendered coherently, so the error reports every obsolete step on the path, not only
the assigned leaf.

Restoring the same version twice deliberately produces two distinct revisions: each restore is a new
editing session. Restoration is therefore _not_ idempotent, and a future public write endpoint must
carry its own transport-level idempotency key. A disabled button in a UI is not network idempotency.

### Lifecycle operations own their transactions

`Publishing::PromoteRevision`, `RestoreVersion`, and `MoveTaxonomySubtree` are explicit domain
operations, not model callbacks and not generic `*Service` dumping grounds. Each opens its own
transaction and takes the row locks it needs. Promotion in particular must commit a version and
every one of its snapshots together or not at all, and that boundary belongs somewhere a reader can
see it rather than scattered across `after_create` hooks.

Promotion is retry-safe. `UNIQUE(entry_revision_id)` on `publishing_entry_versions` is the
idempotency anchor: a concurrent second attempt loses the insert, re-reads the winner, and
_verifies_ it is a complete snapshot of the same revision before returning it, rather than trusting
whatever row it happens to find.

### PostgreSQL is the final integrity authority

Active Record validations exist for readable errors only. Every invariant that spans rows or tables
is enforced by the database, including invariants that a `CHECK` constraint cannot express:

| Invariant                                            | Mechanism                                                                   |
| ---------------------------------------------------- | --------------------------------------------------------------------------- |
| vocabulary kind matches the assignment table         | `CHECK` + composite FK `(vocabulary_id, vocabulary_kind) → (id, kind)`      |
| term belongs to the assigned vocabulary and locale   | composite FK `(taxonomy_term_id, vocabulary_id, locale)`                    |
| assignment locale matches its revision or version    | composite FK `(owner_id, locale)`                                           |
| single-valued cardinality                            | `UNIQUE(owner_id, vocabulary_id)`                                           |
| ordered multi-valued uniqueness                      | `UNIQUE(owner, vocabulary, term)` and `UNIQUE(owner, vocabulary, position)` |
| flat vocabularies have no hierarchy                  | `CHECK` on `parent_id` / `depth`                                            |
| depth equals parent depth plus one                   | `publishing_taxonomy_term_hierarchy_guard` trigger                          |
| no cycles                                            | same trigger, recursive CTE over ancestors                                  |
| vocabulary scope matches the entry's edition         | `publishing_taxonomy_assignment_scope_guard` constraint trigger             |
| version rows and snapshots never change              | `publishing_reject_mutation` trigger                                        |
| a promoted revision and its assignments never change | `publishing_promoted_revision_guard` trigger                                |
| snapshots are derived, not supplied                  | `publishing_derive_taxonomy_snapshot` BEFORE INSERT trigger                 |
| a version's snapshots match its revision exactly     | `publishing_assert_version_snapshot_complete` deferred constraint trigger   |
| vocabularies and terms are never deleted             | `publishing_reject_retirement_by_deletion` trigger                          |
| a vocabulary's structure is frozen once it has terms | `publishing_vocabulary_structure_guard` trigger                             |
| sibling order is deterministic                       | `UNIQUE NULLS NOT DISTINCT (vocabulary_id, locale, parent_id, position)`    |
| breadcrumb steps carry exactly three string keys     | `publishing_valid_term_path` + CHECK                                        |

Version immutability is enforced by trigger rather than by callback alone because `update_column`,
`update_all`, direct SQL, and maintenance scripts all bypass Active Record. The model-level
`ReadOnlyRecord` guards are kept for useful application errors, but they are not the guarantee.

The vocabulary-scope rule is a constraint trigger rather than a composite foreign key because the
owner reaches its edition through its entry. Denormalizing `audience` and `surface` down the entry,
revision, and version tables would have created four more columns capable of drifting; the trigger
introduces no duplicated state at all.

### Edition region is constrained, but edition identity is unchanged

Edition identity remains `(audience, surface, locale)`. No `placement` column was added and
`region_code` was not added to the unique key. A CHECK constraint now states the actual rule:

```sql
(surface = 'info' AND region_code IS NULL)
OR (surface IN ('docs','news','help') AND region_code IS NOT NULL AND region_code ~ '^[a-z]{2}$')
```

The regional surfaces are enumerated explicitly rather than written as `surface <> 'info'` so that
an unknown future surface cannot silently become regional.

### Archive semantics, stated explicitly

| Question                                                     | Answer                                                                           |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| Can a vocabulary or term be unarchived?                      | Yes, by clearing `archived_at` and `archive_reason` together.                    |
| Can a parent be archived while active children remain?       | Yes. The children stay addressable and editable; they simply cannot be promoted. |
| Can a term slug or vocabulary key be reused after archiving? | No. The uniqueness index still covers archived rows, so identity stays reserved. |
| Can a live draft retain archived terms?                      | Yes — that is how restoring an old version stays possible.                       |
| Can published versions retain archived terms?                | Yes. A published snapshot is history and does not become invalid.                |
| Can a vocabulary or term be physically deleted?              | Never, by trigger, even with no references.                                      |
| Does archiving a term hide already-published content?        | No. The entry stays published and stays findable by its published snapshot slug. |

## Deliberate breaking API changes

No deployed consumer exists, so no backward compatibility is preserved. Three changes were made at
once:

1. **`body` is always a JSON object.** It previously collapsed to a bare String whenever the body
   JSONB carried a `text` key, leaving consumers unable to rely on the field's type.
2. **`taxonomy` is a new required key** on every serialized entry, rendered from the published
   version's snapshots. An unassigned entry renders `{"category": null, "tag": []}`.
3. **An archived entry is no longer served**, even while a publication window is still open. This
   was previously a gap rather than a decision.

The serialized entry now has exactly these keys, and a contract test pins them:

```text
namespace  surface  slug  locale  title  summary  body  published_at  taxonomy
```

`namespace` remains the content surface (`info`/`docs`/`news`/`help`) and `surface` remains the
audience (`app`/`com`/`org`). These names are confusing but were left alone: renaming them is a
separate decision from this change.

Index filtering accepts `?category=<slug>` and `?tag=<slug>`, matched against the published
version's **snapshot** slugs — the same frozen values the response renders, never the live term. A
URL built from published JSON therefore keeps working after the term is renamed, moved, or archived,
and a term's new name never retroactively matches content published under its old one. Matching is
exact: a parent category does not select its descendants. An unknown filter term returns an empty
list rather than falling back to the unfiltered one. No general query-language syntax was invented.

The taxonomy object is assembled from the vocabularies that exist for the edition's audience and
surface, keyed by vocabulary key and shaped by structural kind. Adding a vocabulary row adds a key
to the response; no serializer, promotion, or restore branch knows the words "category" or "tag".

The nine nested public Revision endpoints for docs, news, and help were deleted. They returned `[]`
and `{}` unconditionally and never represented a real contract.

## Consequences

- Adding a vocabulary is a row insert. Adding a structural kind is a deliberate schema change.
- Historical rendering is stable under vocabulary maintenance: archive, rename, and reorder freely.
- An author must resolve archived terms before republishing restored content. This is intentional
  friction at the publishing boundary, not an error to be worked around.
- Cross-database transactions remain unnecessary: taxonomy lives in the same `publishing` database
  as the content it describes, so promotion stays atomic.
- The legacy CMS taxonomy DDL, its drop-approval infrastructure, and the migration audit task were
  removed rather than retained alongside the new schema. Nothing was deployed, so there is no
  production cleanup left pending and no risk of table-name collision (`{surface}_{family}_*` versus
  `publishing_*`).

## Supersedes

- `adr/publishing-db-content-authority.md` §6 ("Defer Taxonomy"), which required this ADR. The rest
  of that ADR stands.
- The taxonomy sections of `adr/regional-docs-news-content-model.md` and
  `adr/read-only-content-surfaces-in-rails.md`, both already marked superseded.
- The claim in `adr/news-is-timeline.md` that category and tag models already exist. They did not,
  and the vocabularies described here are their replacement.
