# ADR: Make the Publishing Database the Sole Content Authority

## Status

Accepted (2026-07-16)

## Date

2026-07-16

## Context

Content persistence was duplicated:

1. A lean read model added in June 2026 placed docs, news, and help content-entry tables in each
   app/com/org zenith database. The public `GET /api/v0/entries(/:slug)` API reads these nine
   tables.
2. A legacy CMS model added in July 2026 created 13 tables for each of 12 app/com/org and
   info/docs/news/help combinations: 156 tables containing revisions, versions, publications,
   taxonomy, and media. No delivery path uses this model.

Earlier decisions assigned info globally and docs/news/help regionally, removed taxonomy, and left
revisions and versions as future work. The CMS already added those concepts to main, creating
decision drift.

## Decision

### 1. The Publishing Database Is the Sole Content Authority

Create a central `publishing` publisher/replica database and store canonical content only there.
Rails remains the sole authority for content administration, editing, publication, and delivery
decisions. After cutover, remove content, revision, version, publication, taxonomy, and media
authority from the zenith databases, including the nine lean tables and 156 CMS tables.

### 2. Info, Docs, News, and Help Are Global Content Surfaces

Retire the info-global versus docs/news/help-regional placement split. Unlike regional application
surfaces such as palm/core/side, all four content authorities belong in the central publishing
database. App/com/org identify the publication **audience**, not database placement, retaining the
12 public audience/surface combinations.

### 3. Edition Model

**Superseded 2026-09-04 by `adr/publishing-twelve-family-encrypted-persistence.md`.**
`Publishing::Edition` is removed. The twelve cells are physical table families. Locale remains a
column inside each family. Region is a family constant, not a persisted Edition attribute.

### 4. Keep the `entries` API Noun

Keep these public URLs:

```text
GET /api/v0/entries
GET /api/v0/entries/:public_id
```

Resource identity is the opaque `public_id`. `slug` is a presentation field on the serialized
entry, not the path parameter. Do not add slug lookup, `by-slug` routes, or a slug query filter.

Do not rename them to posts, documents, or publications. Do not expose audience, surface, placement,
or region as query parameters. `Publishing::EditionResolver` derives them from host and route
boundaries.

### 5. Do Not Dual-Write

There is no connected canonical write path, so do not write to both old and new databases. Import
existing data once with an idempotent, audited, dry-run-by-default process; switch read authority;
then remove the old structures.

### 6. Defer Taxonomy

**Superseded 2026-08-01 by `adr/publishing-taxonomy-architecture.md`, which is the ADR this section
required. Taxonomy now exists in the publishing schema as vocabularies, locale-specific terms, and
revision/version assignments. The legacy taxonomy tables were never copied and their DDL has since
been removed from the repository.**

Original decision: do not copy the six legacy taxonomy tables. Future taxonomy may extend beyond
Category and Tag and requires its own ADR and implementation plan. This change documents direction
only and adds no taxonomy migration, model, service, or API. If legacy taxonomy contains data, its
tables may remain until a taxonomy migration plan is complete.

### 7. Documentation Precedes Implementation

Approve this ADR and the architecture documentation before implementing publishing migrations or
models.

### 8. Database Connections

- Add `publishing` and `publishing_replica` using `POSTGRESQL_PUBLISHING_PUB/SUB`,
  `db/publishing_migrate`, and `publishing_structure.sql`.
- Remove dead app/com/org principal connections and replicas. Their reserved migration directories
  are empty and no models use them.
- Keep `storage` and `storage_replica`; they are reserved for another purpose. Publishing owns media
  metadata, but does not repurpose the storage database.
- Treat CI `POSTGRESQL_PUBLICATION_PUB/SUB` variables as remnants of an abandoned publication
  database proposal, not evidence of current behavior.

### 9. Models and Naming

**Superseded 2026-09-04 by `adr/publishing-twelve-family-encrypted-persistence.md`.** Define twelve
explicit family model trees under `Publishing::{Surface}::{Audience}` plus global
`Publishing::MediaFile`. Prohibit `constantize` / `Object.const_get` for runtime family selection.
Persistence naming is surface first, matching management URLs.

## Consequences

- This ADR supersedes the zenith placement, regional content-model, and regional help decisions in
  the related ADRs and `docs/architecture/regional-content.md`.
- The boundary keeping content outside the Avatar database remains; authority merely moves from
  zenith databases to publishing.
- Next.js continues to own public HTML, SEO, sitemaps, and UI, while Rails owns content authority
  and the read API.
- Preserve the useful legacy CMS concepts: revision edit history, immutable version snapshots,
  scheduled publications with GiST overlap exclusion, and JSONB bodies with schema version and
  content digest.
- Present the read-only `publishing:migration:audit` result and obtain explicit approval before any
  deletion or drop.

## Related

- `docs/architecture/docs-help-news-content-boundary.md`
- `docs/architecture/regional-content.md`
- `adr/read-only-content-surfaces-in-rails.md`
- `adr/regional-docs-news-content-model.md`
- `adr/regional-help-surface-direction.md`
- `adr/avatar-db-content-db-boundary.md`
- `plans/publishing-db-valiant-moore.md`
